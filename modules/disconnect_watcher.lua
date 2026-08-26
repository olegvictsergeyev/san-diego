local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local DisconnectWatcher = {}
DisconnectWatcher.__index = DisconnectWatcher

function DisconnectWatcher.new(agent, compat, opts)
	return setmetatable({
		agent = agent,
		compat = compat,
		opts = opts or {},
		loaderUrl = opts and opts.loaderUrl,
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

function DisconnectWatcher:_shouldReconnect(info)
	if not info then
		return false
	end
	local title = (info.title or ""):lower()
	if title:find("disconnect") then
		return true
	end
	if info.code == "277" or info.code == "278" then
		return true
	end
	return false
end

function DisconnectWatcher:_getButton(name)
	local prompt = self:_getErrorPrompt()
	if not prompt then
		return nil
	end
	local area = prompt:FindFirstChild("MessageArea")
	if not area then
		return nil
	end
	local frame = area:FindFirstChild("ErrorFrame")
	if not frame then
		return nil
	end
	local buttons = frame:FindFirstChild("ButtonArea")
	if not buttons then
		return nil
	end
	return buttons:FindFirstChild(name)
end

function DisconnectWatcher:_fireButton(btn)
	if not btn then
		self:_log("fireButton: button is nil")
		return false
	end
	self:_log("firing button", btn.Name)
	local signals = { "Activated", "MouseButton1Click", "MouseButton1Down" }
	local fired = false

	if typeof(firesignal) == "function" then
		for _, signalName in ipairs(signals) do
			local signal = btn[signalName]
			if signal then
				local ok = pcall(firesignal, signal)
				if ok then
					fired = true
					self:_log("firesignal", signalName, "ok")
				end
			end
		end
	end

	local getConn = self.compat and self.compat.getConnections or getconnections
	if typeof(getConn) ~= "function" then
		self:_log("getconnections not available")
		return fired
	end

	for _, signalName in ipairs(signals) do
		local signal = btn[signalName]
		if signal then
			local conns = getConn(signal)
			self:_log("signal", signalName, "connections", tostring(#conns))
			for _, conn in ipairs(conns) do
				if typeof(conn.Function) == "function" then
					local ok = pcall(conn.Function)
					self:_log("fired connection", signalName, tostring(ok))
					fired = true
				end
			end
		end
	end

	return fired
end

function DisconnectWatcher:_queueReload()
	if not self.loaderUrl then
		return
	end
	local baseUrl = tostring(self.loaderUrl):match("(.+)/final/agent%.lua$") or self.loaderUrl
	local code = 'local baseUrl = "' .. baseUrl .. '"\ngetgenv().SanDiegoAgentBaseUrl = baseUrl\nloadstring(game:HttpGet(baseUrl .. "/final/agent.lua?nocache=" .. tostring(tick())))()'
	if self.compat and self.compat.queueOnTeleport then
		self.compat.queueOnTeleport(code)
	else
		local q = queue_on_teleport
		if typeof(q) == "function" then
			pcall(q, code)
		end
	end
end

function DisconnectWatcher:_onPromptShown()
	local info = self:_readErrorInfo()
	if not info then
		return
	end
	if self.agent and self.agent.reportDisconnect then
		pcall(function()
			self.agent:reportDisconnect(info)
		end)
	end
	if self.handled then
		return
	end
	self.handled = true

	if not self:_shouldReconnect(info) then
		return
	end

	self:_queueReload()

	if self.opts.autoReconnect then
		task.spawn(function()
			task.wait(0.5)
			self:clickReconnect()
		end)
	end
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

function DisconnectWatcher:clickReconnect()
	local btn = self:_getButton("ReconnectButton")
	if btn then
		self:_log("ReconnectButton found, class", btn.ClassName)
	else
		self:_log("ReconnectButton not found")
	end
	return self:_fireButton(btn)
end

function DisconnectWatcher:clickLeave()
	local btn = self:_getButton("LeaveButton")
	return self:_fireButton(btn)
end

function DisconnectWatcher:hidePrompt()
	local prompt = self:_getErrorPrompt()
	if prompt then
		prompt.Visible = false
	end
end

function DisconnectWatcher:reconnect()
	return self:clickReconnect()
end

return DisconnectWatcher
