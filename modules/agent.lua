local HttpService = game:GetService("HttpService")

local function deepEqual(a, b)
	if typeof(a) ~= typeof(b) then
		return false
	end
	if typeof(a) ~= "table" then
		return a == b
	end
	for k, v in pairs(a) do
		if not deepEqual(v, b[k]) then
			return false
		end
	end
	for k, v in pairs(b) do
		if not deepEqual(v, a[k]) then
			return false
		end
	end
	return true
end

local Agent = {}
Agent.__index = Agent

function Agent.new(config, httpClient, stateCollector, commandEngine, afk, resultStore)
	local self = setmetatable({}, Agent)

	self.config = {
		baseUrl = config.baseUrl or "http://195.161.68.193:5173/api",
		gameSlug = config.gameSlug or "san-diego",
		statusInterval = config.statusInterval or 5,
		commandPollTimeout = config.commandPollTimeout or 30,
		commandRetryDelay = config.commandRetryDelay or 3,
		balancePath = config.balancePath or "leaderstats.Cash",
		customData = config.customData or {},
	}

	self.http = httpClient
	self.state = stateCollector
	self.engine = commandEngine
	self.afk = afk
	self.resultStore = resultStore

	self.running = false
	self.currentCommand = nil
	self.commandQueue = {}
	self.lastStatusData = nil
	self.lastStatusSendAt = 0
	self.currentCommandHeartbeat = nil

	return self
end

function Agent:_log(level, ...)
	local msg = table.concat({ ... }, " ")
	print(string.format("[SanDiegoAgent][%s] %s", level, msg))
end

function Agent:_sendStatus(force)
	local data = self.state:getAll(self.config.customData)
	local changed = not self.lastStatusData or not deepEqual(self.lastStatusData, data)
	local heartbeatDue = (tick() - self.lastStatusSendAt) >= 300
	if not changed and not force and not heartbeatDue then
		return
	end
	self.lastStatusData = data
	self.lastStatusSendAt = tick()
	local ok, res = self.http:post("/game/update", data)
	if not ok then
		self:_log("ERROR", "status send failed:", tostring(res))
	end
end

function Agent:reportError(info)
	if not info then
		return
	end
	self:_log("WARN", "error/disconnect detected:", tostring(info.title), tostring(info.code))
	if self.state and self.state.setStatusOverride then
		self.state:setStatusOverride("offline")
	end
	if self.state and self.state.clearAction then
		self.state:clearAction()
	end
	if self.state and self.state.resetTimers then
		self.state:resetTimers()
	end
	self.config.customData.disconnect = info
	self:_sendStatus()
end

function Agent:clearError()
	if self.state and self.state.setStatusOverride then
		self.state:setStatusOverride(nil)
	end
	if self.state and self.state.clearAction then
		self.state:clearAction()
	end
	if self.state and self.state.resetTimers then
		self.state:resetTimers()
	end
	self.config.customData.disconnect = nil
	self:_sendStatus()
end

function Agent:_resultToString(result)
	if typeof(result) == "string" then
		return result
	end
	if typeof(result) == "table" then
		if typeof(result.encoded) == "string" then
			return result.encoded
		end
		if result.data ~= nil then
			local ok, encoded = pcall(function()
				return HttpService:JSONEncode(result.data)
			end)
			if ok then
				return encoded
			end
		end
		if result.message then
			return tostring(result.message)
		end
		if result.error then
			return tostring(result.error)
		end
	end
	return tostring(result)
end

function Agent:_sendCommandResult(commandId, result, status)
	if not commandId then
		return false
	end
	local resultString = self:_resultToString(result)
	local body = { result = resultString, status = status }
	self:_log("INFO", "sending command result", commandId, status)
	local ok, res = self.http:post("/commands/" .. tostring(commandId) .. "/result", body)
	if ok then
		self:_log("INFO", "command result sent", commandId, status, res.statusCode)
		return true
	else
		self:_log("ERROR", "command result send failed:", commandId, tostring(res))
		return false
	end
end

function Agent:_updateCommandStatus(commandId, status, message)
	if not commandId then
		return false
	end
	local body = { status = status }
	if message then
		body.message = message
	end
	local ok, res = self.http:post("/commands/" .. tostring(commandId) .. "/status", body)
	if ok then
		self:_log("INFO", "command status updated", commandId, status, res.statusCode)
		return true
	else
		self:_log("ERROR", "command status update failed:", commandId, tostring(res))
		return false
	end
end

function Agent:_sendPendingResults()
	if not self.resultStore then
		return
	end
	local pending = self.resultStore:getPending()
	if not pending or next(pending) == nil then
		return
	end

	for commandId, item in pairs(pending) do
		if self:_sendCommandResult(commandId, item.result, item.status) then
			self.resultStore:markSent(commandId)
		else
			self.resultStore:incrementAttempt(commandId)
		end
	end
end

function Agent:_retryLoop()
	while self.running do
		task.wait(10)
		if not self.running then
			break
		end
		local ok, err = pcall(function()
			self:_sendPendingResults()
		end)
		if not ok then
			self:_log("ERROR", "retry loop error:", tostring(err))
		end
	end
end

function Agent:_getCommandTimeout(command)
	local payload = command.payload or {}
	if command.name == "pause" then
		local duration = tonumber(payload.duration) or 0
		return math.clamp(duration + 10, 10, 90000)
	end
	if command.name == "hold_key" then
		local duration = tonumber(payload.duration) or 0
		return math.clamp(duration / 1000 + 10, 10, 70)
	end
	if command.name == "join_private_server" then
		return 60
	end
	if command.name == "transfer_money_via_respawn" then
		local maxAttempts = tonumber(payload.max_attempts) or 100
		local waitSeconds = tonumber(payload.wait_seconds) or 5
		return math.clamp(maxAttempts * waitSeconds + 30, 30, 36000)
	end
	return 300
end

function Agent:_startCommandHeartbeat(command)
	if self.currentCommandHeartbeat then
		self.currentCommandHeartbeat = nil
	end
	local commandId = command.id
	self.currentCommandHeartbeat = true
	task.spawn(function()
		while self.currentCommandHeartbeat and self.currentCommand and self.currentCommand.id == commandId do
			task.wait(30)
			if self.currentCommand and self.currentCommand.id == commandId then
				local ok = pcall(function()
					self:_updateCommandStatus(commandId, "in_progress", "heartbeat")
				end)
				if not ok then
					self:_log("ERROR", "command heartbeat failed for", commandId)
				end
			end
		end
	end)
end

function Agent:_stopCommandHeartbeat()
	self.currentCommandHeartbeat = nil
end

function Agent:_fetchNextCommand()
	local nickname = self.state:getNickname()
	if not nickname or nickname == "unknown" then
		self:_log("ERROR", "cannot poll commands: nickname unknown")
		return nil
	end

	local query = {
		nickname = nickname,
		long_poll = true,
		timeout = self.config.commandPollTimeout,
	}

	local ok, res = self.http:get("/commands/next", query)
	if not ok then
		self:_log("ERROR", "command fetch failed:", tostring(res))
		return nil
	end

	if res.statusCode == 204 or not res.body then
		return nil
	end

	if typeof(res.body) ~= "table" then
		return nil
	end

	local command = res.body.command or res.body
	if not command or not command.id then
		return nil
	end

	command.name = command.command_type or command.name
	if typeof(command.payload) == "string" and command.payload ~= "" then
		local parseOk, parsed = pcall(function()
			return HttpService:JSONDecode(command.payload)
		end)
		if parseOk then
			command.payload = parsed
		end
	end

	return command
end

function Agent:_handleCommand(command)
	self.currentCommand = command
	local startedAt = os.time()
	self.state:setCommandState("in_progress", command.name, startedAt)

	local startSendOk, startSendErr = pcall(function()
		self:_sendStatus(true)
	end)
	if not startSendOk then
		self:_log("ERROR", "failed to send status at command start:", tostring(startSendErr))
	end

	if self.state and self.state.shouldResetAction and self.state:shouldResetAction(command.name) then
		self.state:clearAction()
	end

	-- Acknowledge command receipt to backend.
	pcall(function()
		self:_updateCommandStatus(command.id, "in_progress", "ack")
	end)

	-- Heartbeat so server does not mark command as declined while running.
	self:_startCommandHeartbeat(command)

	self:_log("INFO", "executing command", command.id, command.name)

	-- Command timeout to prevent worker from getting stuck forever.
	local commandFinished = false
	local timeout = self:_getCommandTimeout(command)
	local timeoutConn = task.delay(timeout, function()
		if not commandFinished then
			self:_log("WARN", "command timed out, requesting cancel", command.id, command.name, timeout)
			self.engine:requestCancel()
		end
	end)

	local ok, result = pcall(function()
		return self.engine:execute(command)
	end)

	commandFinished = true

	local status = "completed"
	if not ok then
		result = { success = false, error = tostring(result) }
	end
	if not result.success then
		status = "error"
	end
	if result.error == "cancelled" then
		status = "cancelled"
	end

	self:_stopCommandHeartbeat()

	if status == "error" then
		self.state:setCommandState("error", command.name, startedAt)
	else
		self.state:setCommandState("idle", nil, nil)
	end

	local resultString = self:_resultToString(result)

	-- Persist result for at-least-once delivery.
	if self.resultStore then
		local saved = self.resultStore:save(command.id, resultString, status)
		if not saved then
			self:_log("WARN", "failed to persist result for retry", command.id)
		else
			self:_log("INFO", "command result persisted for delivery", command.id)
		end
	end

	-- Try to send immediately, then retry loop will handle failures.
	self:_sendPendingResults()

	if self.resultStore then
		local stillPending = self.resultStore:getPending()[tostring(command.id)] ~= nil
		if stillPending then
			self:_log("WARN", "command finished but result not delivered; queued for retry", command.id, command.name)
		end
	end

	self.currentCommand = nil

	local sendOk, sendErr = pcall(function()
		self:_sendStatus(true)
	end)
	if not sendOk then
		self:_log("ERROR", "failed to send status after command:", tostring(sendErr))
	end

	self:_log("INFO", "command finished", command.id, command.name, status)
end

function Agent:_handleCancel(command)
	local cancelledId = self.currentCommand and self.currentCommand.id
	self:_log("INFO", "received cancel command", command.id, "cancelling", cancelledId or "none")
	self.engine:requestCancel()
	if cancelledId then
		pcall(function()
			self:_updateCommandStatus(cancelledId, "cancelled", "cancelled by user")
		end)
	end
	local resultData = {}
	if cancelledId then resultData.cancelledCommandId = cancelledId end
	local resultString = self:_resultToString({ success = true, data = resultData })
	if self.resultStore then
		self.resultStore:save(command.id, resultString, "completed")
	end
	self:_sendPendingResults()
end

function Agent:_fetcherLoop()
	while self.running do
		-- Пока выполняется обычная команда, новые команды могут быть важны (например, cancel),
		-- но мы не плодим очередь. Long poll продолжается, cancel обрабатывается сразу.
		local ok, command = pcall(function()
			return self:_fetchNextCommand()
		end)
		if not ok then
			self:_log("ERROR", "fetcher loop error:", tostring(command))
			task.wait(self.config.commandRetryDelay)
		elseif command then
			self:_log("INFO", "received command from backend", command.id, command.name)
			if command.name == "cancel" then
				self:_handleCancel(command)
			else
				table.insert(self.commandQueue, command)
			end
		else
			-- Таймаут long poll — сразу новый запрос.
		end
	end
end

function Agent:_workerLoop()
	while self.running do
		if #self.commandQueue > 0 then
			local command = table.remove(self.commandQueue, 1)
			local ok, err = pcall(function()
				self:_handleCommand(command)
			end)
			if not ok then
				self:_log("ERROR", "worker loop error:", tostring(err))
				local resultString = self:_resultToString({ success = false, error = tostring(err) })
				if self.resultStore then
					self.resultStore:save(command.id, resultString, "error")
					self:_log("WARN", "command failed; result persisted for retry", command.id)
				end
				self:_sendPendingResults()
				if self.resultStore and self.resultStore:getPending()[tostring(command.id)] ~= nil then
					self:_log("WARN", "command error result queued for retry", command.id)
				end
				self.currentCommand = nil
			end
		else
			task.wait(0.1)
		end
	end
end

function Agent:_statusLoop()
	while self.running do
		task.wait(self.config.statusInterval)
		if self.running then
			local ok, err = pcall(function()
				self:_sendStatus()
			end)
			if not ok then
				self:_log("ERROR", "status loop error:", tostring(err))
			end
		end
	end
end

function Agent:start()
	if self.running then
		self:_log("WARN", "agent already running")
		return
	end

	self.running = true
	self:_log("INFO", "starting agent for game", self.config.gameSlug)

	self:_sendStatus()

	-- Сбрасываем возможный disconnect из прошлой сессии.
	self:clearError()

	-- Пытаемся доставить результаты, оставшиеся с прошлого запуска.
	pcall(function()
		self:_sendPendingResults()
	end)

	task.spawn(function()
		self:_statusLoop()
	end)

	task.spawn(function()
		self:_fetcherLoop()
	end)

	task.spawn(function()
		self:_workerLoop()
	end)

	task.spawn(function()
		self:_retryLoop()
	end)

	if self.afk then
		local afk = self.afk
		afk:setBusyCheck(function()
			return self.currentCommand ~= nil
		end)
		afk:start()
	end
end

function Agent:stop()
	self.running = false
	self.engine:requestCancel()
	self:_stopCommandHeartbeat()
	if self.afk then
		self.afk:stop()
	end
	self:_log("INFO", "agent stopped")
end

return Agent
