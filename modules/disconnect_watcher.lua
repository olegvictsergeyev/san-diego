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
