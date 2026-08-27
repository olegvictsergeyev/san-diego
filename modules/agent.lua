local HttpService = game:GetService("HttpService")

local Agent = {}
Agent.__index = Agent

function Agent.new(config, httpClient, stateCollector, commandEngine, afk)
	local self = setmetatable({}, Agent)

	self.config = {
		baseUrl = config.baseUrl or "http://195.161.68.193:5173/api",
		gameSlug = config.gameSlug or "san-diego",
		statusInterval = config.statusInterval or 5,
		balancePath = config.balancePath or "leaderstats.Cash",
		customData = config.customData or {},
	}

	self.http = httpClient
	self.state = stateCollector
	self.engine = commandEngine
	self.afk = afk

	self.running = false
	self.lastCommandId = nil
	self.lastCommandStatus = nil
	self.lastCommandMessage = nil
	self.lastCommandResult = nil
	self.currentCommand = nil
	self.commandQueue = {}

	return self
end

function Agent:_log(level, ...)
	local msg = table.concat({ ... }, " ")
	print(string.format("[SanDiegoAgent][%s] %s", level, msg))
end

function Agent:_sendStatus()
	local data = self.state:getAll(self.config.customData)
	local ok, res = self.http:post("/game/update", data)
	if ok then
		self:_log("INFO", "status sent", res.statusCode)
	else
		self:_log("ERROR", "status send failed:", tostring(res))
	end
end

function Agent:reportDisconnect(info)
	if not info then
		return
	end
	self:_log("WARN", "disconnect detected:", tostring(info.title), tostring(info.code))
	if self.state and self.state.setStatusOverride then
		self.state:setStatusOverride("error")
	end
	self.config.customData.disconnect = info
	self:_sendStatus()
end

function Agent:clearDisconnect()
	if self.state and self.state.setStatusOverride then
		self.state:setStatusOverride(nil)
	end
	self.config.customData.disconnect = nil
	self:_sendStatus()
end

function Agent:_updateCommandStatus(commandId, status, message)
	if not commandId then return end
	local body = { status = status }
	if message then
		body.message = message
	end
	local ok, res = self.http:post("/commands/" .. tostring(commandId) .. "/status", body)
	if ok then
		self:_log("INFO", "command status updated", commandId, status, res.statusCode)
	else
		self:_log("ERROR", "command status update failed:", commandId, tostring(res))
	end
end

function Agent:_resultToString(result)
	local HttpService = game:GetService("HttpService")
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
	if not commandId then return end
	local resultString = self:_resultToString(result)
	local body = { result = resultString, status = status }
	local ok, res = self.http:post("/commands/" .. tostring(commandId) .. "/result", body)
	if ok then
		self:_log("INFO", "command result sent", commandId, res.statusCode)
	else
		self:_log("ERROR", "command result send failed:", commandId, tostring(res))
	end
end

function Agent:_finishCommand(commandId, status, result)
	self.lastCommandId = commandId
	self.lastCommandStatus = status
	self.lastCommandMessage = result.error or result.message
	self.lastCommandResult = result

	self:_sendCommandResult(commandId, result, status)
end

function Agent:_reportLastCommandAndClear()
	if self.lastCommandId and self.lastCommandStatus and self.lastCommandResult then
		self:_finishCommand(self.lastCommandId, self.lastCommandStatus, self.lastCommandResult)
		self.lastCommandId = nil
		self.lastCommandStatus = nil
		self.lastCommandMessage = nil
		self.lastCommandResult = nil
	end
end

function Agent:_fetchNextCommand()
	local nickname = self.state:getNickname()
	local query = {
		nickname = nickname,
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

	-- Backend может возвращать команду напрямую или в поле command.
	local command = res.body.command or res.body
	if not command or not command.id then
		return nil
	end

	-- Адаптируем поля backend'а к внутреннему формату агента.
	command.name = command.command_type or command.name
	if typeof(command.payload) == "string" and command.payload ~= "" then
		local parseOk, parsed = pcall(function()
			return game:GetService("HttpService"):JSONDecode(command.payload)
		end)
		if parseOk then
			command.payload = parsed
		end
	end

	return command
end

function Agent:_handleCommand(command)
	self.currentCommand = command
	self:_updateCommandStatus(command.id, "in_progress")

	local ok, result = pcall(function()
		return self.engine:execute(command)
	end)

	if not ok then
		result = { success = false, error = tostring(result) }
	end

	local status = "completed"
	if not result.success then
		status = "error"
	end
	if result.error == "cancelled" then
		status = "cancelled"
	end

	if status == "cancelled" then
		-- статус cancelled уже отправлен в _handleCancel, отправляем только result
		self.lastCommandId = command.id
		self.lastCommandStatus = "cancelled"
		self.lastCommandMessage = result.error
		self.lastCommandResult = result
		self:_sendCommandResult(command.id, result, "cancelled")
	else
		self:_finishCommand(command.id, status, result)
	end

	self.currentCommand = nil
	self:_log("INFO", "command finished", command.id, command.name, status)
end

function Agent:_handleCancel(command)
	local cancelledId = self.currentCommand and self.currentCommand.id
	self:_log("INFO", "received cancel command", command.id, "cancelling", cancelledId or "none")
	self.engine:requestCancel()
	if cancelledId then
		self:_updateCommandStatus(cancelledId, "cancelled", "cancelled by user")
	end
	local resultData = {}
	if cancelledId then resultData.cancelledCommandId = cancelledId end
	self:_finishCommand(command.id, "completed", { success = true, data = resultData })
end

function Agent:_fetcherLoop()
	while self.running do
		local command = self:_fetchNextCommand()
		if command then
			self:_log("INFO", "fetched command", command.id, command.name)
			if command.name == "cancel" then
				self:_handleCancel(command)
			else
				table.insert(self.commandQueue, command)
			end
		else
			task.wait(1)
		end
	end
end

function Agent:_workerLoop()
	while self.running do
		if #self.commandQueue > 0 then
			local command = table.remove(self.commandQueue, 1)
			self:_handleCommand(command)
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

function Agent:_fetcherLoop()
	while self.running do
		local ok, command = pcall(function()
			return self:_fetchNextCommand()
		end)
		if not ok then
			self:_log("ERROR", "fetcher loop error:", tostring(command))
			task.wait(1)
		elseif command then
			self:_log("INFO", "fetched command", command.id, command.name)
			if command.name == "cancel" then
				self:_handleCancel(command)
			else
				table.insert(self.commandQueue, command)
			end
		else
			task.wait(1)
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
				self:_finishCommand(command.id, "error", { success = false, error = tostring(err) })
			end
		else
			task.wait(0.1)
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

	self:_reportLastCommandAndClear()
	self:_sendStatus()

	task.spawn(function()
		self:_statusLoop()
	end)

	task.spawn(function()
		self:_fetcherLoop()
	end)

	task.spawn(function()
		self:_workerLoop()
	end)

	if self.afk then
		local afk = self.afk
		-- Связываем проверку занятости: AFK не мешает выполнению команд.
		afk:setBusyCheck(function()
			return self.currentCommand ~= nil
		end)
		afk:start()
	end
end

function Agent:stop()
	self.running = false
	self.engine:requestCancel()
	if self.afk then
		self.afk:stop()
	end
	self:_log("INFO", "agent stopped")
end

return Agent
