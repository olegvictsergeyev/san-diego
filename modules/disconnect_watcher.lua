local CoreGui = game:GetService("CoreGui")

local DisconnectWatcher = {}
DisconnectWatcher.__index = DisconnectWatcher

function DisconnectWatcher.new(agent, compat, opts)
	return setmetatable({
		agent = agent,
		compat = compat,
		opts = opts or {},
		watching = false,
		handled = false,
	}, DisconnectWatcher)
end

function DisconnectWatcher:_log(...)
	print("[SanDiegoAgent][DisconnectWatcher]", table.concat({ ... }, " "))
end

function DisconnectWatcher:_getErrorPrompt()
	local promptGui = CoreGui:FindFirstChild("RobloxPromptGui")
	if not promptGui then
		return nil
	end
	local overlay = promptGui:FindFirstChild("promptOverlay")
	if not overlay then
		return nil
	end
	return overlay:FindFirstChild("ErrorPrompt")
end

function DisconnectWatcher:_readText(root, path)
	local current = root
	for _, name in ipairs(path) do
		current = current:FindFirstChild(name)
		if not current then
			return nil
		end
	end
	if current:IsA("TextLabel") or current:IsA("TextButton") then
		return current.Text
	end
	return nil
end

function DisconnectWatcher:_readErrorInfo()
	local prompt = self:_getErrorPrompt()
	if not prompt then
		return nil
	end
	local title = self:_readText(prompt, { "TitleFrame", "ErrorTitle" })
	local message = self:_readText(prompt, { "MessageArea", "ErrorFrame", "ErrorMessage" })
	local code = nil
	if message then
		code = message:match("%(Error Code:%s*(%d+)%)")
	end
	return {
		title = title,
		message = message,
		code = code,
	}
end

function DisconnectWatcher:_onPromptShown()
	if self.handled then
		return
	end

	-- Во время намеренного телепорта (join_private_server) Roblox может
	-- кратко показать ErrorPrompt — это НЕ дисконнект, бэкенду не шлём.
	local teleporting = getgenv().SanDiegoAgentTeleporting == true
		or (self.agent and self.agent.teleporting == true)
	if teleporting then
		self:_log("teleport in progress, ignoring ErrorPrompt")
		return
	end

	self.handled = true

	local info = self:_readErrorInfo()
	if not info then
		return
	end

	self:_log("error/disconnect prompt shown", tostring(info.title), tostring(info.code))

	if self.agent and self.agent.reportError then
		pcall(function()
			self.agent:reportError(info)
		end)
	end

	-- Авто-переподключение при 277/278: это сетевой обрыв/idle-кик, а не
	-- управляемый бэкендом переход. Ждём внешних команд бессмысленно —
	-- клиент сидит на ErrorPrompt, и пока его не перезапустят, фарм мёртв.
	-- Телепортимся обратно на ТОТ ЖЕ инстанс (jobId ещё читается), дальше
	-- срабатывает штатный queue_on_teleport и поднимает агента.
	if info.code == "277" or info.code == "278" then
		self:_scheduleReconnect(info)
	end
end

-- До 3 попыток с бэкофом; каждая — только если ErrorPrompt всё ещё висит
-- (если промпт исчез — переподключение уже состоялось другим путём).
function DisconnectWatcher:_scheduleReconnect(info)
	task.spawn(function()
		local Players = game:GetService("Players")
		local delays = {10, 60, 180}
		for attempt = 1, #delays do
			task.wait(delays[attempt])
			if self.agent and self.agent.running == false then
				self:_log("agent stopped by user, reconnect cancelled")
				return
			end
			if not self:_getErrorPrompt() then
				self:_log("ErrorPrompt gone, reconnect not needed")
				return
			end
			local ok, err = pcall(function()
				local TeleportService = game:GetService("TeleportService")
				local placeId = game.PlaceId
				local jobId = tostring(game.JobId or "")
				if jobId == "" then
					error("empty JobId, cannot reconnect to same instance")
				end
				self:_log("auto-reconnect attempt", attempt, "to place", tostring(placeId), "job", jobId)
				TeleportService:TeleportToPlaceInstance(placeId, jobId, Players.LocalPlayer)
			end)
			if not ok then
				self:_log("reconnect attempt", attempt, "failed:", tostring(err))
			end
		end
		self:_log("all reconnect attempts exhausted; leaving prompt for backend/user")
	end)
end

function DisconnectWatcher:_watchExisting()
	local prompt = self:_getErrorPrompt()
	if prompt then
		self:_log("ErrorPrompt already visible at start")
		self:_onPromptShown()
	end
end

function DisconnectWatcher:_watchPromptAdded()
	local promptGui = CoreGui:FindFirstChild("RobloxPromptGui")
	if not promptGui then
		self:_log("RobloxPromptGui not found")
		return
	end
	local overlay = promptGui:FindFirstChild("promptOverlay")
	if not overlay then
		self:_log("promptOverlay not found")
		return
	end
	overlay.ChildAdded:Connect(function(child)
		if child.Name == "ErrorPrompt" then
			self:_log("ErrorPrompt added")
			task.wait(0.1)
			self:_onPromptShown()
		end
	end)
end

function DisconnectWatcher:start()
	if self.watching then
		return
	end
	self.watching = true
	self:_log("starting")
	self:_watchExisting()
	self:_watchPromptAdded()
end

return DisconnectWatcher
