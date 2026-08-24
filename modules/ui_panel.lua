local Players = game:GetService("Players")

local UIPanel = {}
UIPanel.__index = UIPanel

function UIPanel.new(config, callbacks)
	local self = setmetatable({}, UIPanel)
	self.config = config
	self.callbacks = callbacks or {}
	return self
end

function UIPanel:_loadLibrary()
	local ok, Orion = pcall(function()
		return loadstring(game:HttpGet("https://raw.githubusercontent.com/OrionLibrary/Orion/main/source.lua"))()
	end)
	if not ok then
		warn("[SanDiegoAgent][UI] Failed to load Orion:", tostring(Orion))
		return nil
	end
	return Orion
end

function UIPanel:_findTextBoxes()
	local gui = game.CoreGui:FindFirstChild("San Diego Agent")
	if not gui then return {} end
	local result = {}
	for _, desc in ipairs(gui:GetDescendants()) do
		if desc:IsA("TextBox") then
			local frame = desc.Parent and desc.Parent.Parent and desc.Parent.Parent.Parent
			if frame then
				local info = frame:FindFirstChild("textboxInfo")
				if info then
					result[info.Text] = desc
				end
			end
		end
	end
	return result
end

function UIPanel:_readConfigFromUI()
	local boxes = self:_findTextBoxes()
	local function get(name)
		local box = boxes[name]
		return box and box.Text or nil
	end

	local baseUrl = get("baseUrl")
	if baseUrl and baseUrl ~= "" then self.config.baseUrl = baseUrl end

	local gameSlug = get("gameSlug")
	if gameSlug and gameSlug ~= "" then self.config.gameSlug = gameSlug end

	local balancePath = get("balancePath")
	if balancePath and balancePath ~= "" then self.config.balancePath = balancePath end

	local statusInterval = tonumber(get("statusInterval"))
	if statusInterval then self.config.statusInterval = statusInterval end

	local commandPollTimeout = tonumber(get("commandPollTimeout"))
	if commandPollTimeout then self.config.commandPollTimeout = commandPollTimeout end

	local commandRetryDelay = tonumber(get("commandRetryDelay"))
	if commandRetryDelay then self.config.commandRetryDelay = commandRetryDelay end
end

function UIPanel:_startAgent()
	if self.callbacks.start then
		local ok, err = pcall(function()
			self.callbacks.start(self.config)
		end)
		if not ok then
			warn("[SanDiegoAgent][UI] Start failed:", tostring(err))
		end
	end
end

function UIPanel:_stopAgent()
	if self.callbacks.stop then
		local ok, err = pcall(self.callbacks.stop)
		if not ok then
			warn("[SanDiegoAgent][UI] Stop failed:", tostring(err))
		end
	end
end

function UIPanel:_sendStatusNow()
	if self.callbacks.sendStatus then
		local ok, err = pcall(self.callbacks.sendStatus)
		if not ok then
			warn("[SanDiegoAgent][UI] Send status failed:", tostring(err))
		end
	end
end

function UIPanel:_applyConfig()
	self:_readConfigFromUI()
	self:_stopAgent()
	task.wait(0.2)
	self:_startAgent()
	print("[SanDiegoAgent][UI] Config applied and agent restarted")
end

function UIPanel:build()
	local Orion = self:_loadLibrary()
	if not Orion then return end

	local window = Orion:CreateOrion("San Diego Agent")

	-- Main tab
	local tabMain = window:CreateSection("Main")
	tabMain:TextLabel("Status: see console for updates")
	tabMain:TextLabel("Use buttons below to control the agent")

	tabMain:TextButton("Start Agent", "Launch the agent", function()
		self:_startAgent()
	end)

	tabMain:TextButton("Stop Agent", "Stop the agent", function()
		self:_stopAgent()
	end)

	tabMain:TextButton("Send Status Now", "Send status manually", function()
		self:_sendStatusNow()
	end)

	-- Config tab
	local tabConfig = window:CreateSection("Config")
	tabConfig:TextLabel("Edit values and press Apply")

	tabConfig:TextLabel("baseUrl")
	tabConfig:TextBox("baseUrl", self.config.baseUrl, function() end)

	tabConfig:TextLabel("gameSlug")
	tabConfig:TextBox("gameSlug", self.config.gameSlug, function() end)

	tabConfig:TextLabel("balancePath")
	tabConfig:TextBox("balancePath", self.config.balancePath, function() end)

	tabConfig:TextLabel("statusInterval")
	tabConfig:TextBox("statusInterval", tostring(self.config.statusInterval), function() end)

	tabConfig:TextLabel("commandPollTimeout")
	tabConfig:TextBox("commandPollTimeout", tostring(self.config.commandPollTimeout), function() end)

	tabConfig:TextLabel("commandRetryDelay")
	tabConfig:TextBox("commandRetryDelay", tostring(self.config.commandRetryDelay), function() end)

	tabConfig:TextButton("Apply & Restart", "Save config and restart agent", function()
		self:_applyConfig()
	end)

	-- Commands tab
	local tabCommands = window:CreateSection("Commands")
	tabCommands:TextLabel("Available commands:")
	if self.callbacks.getCommandSpec then
		local ok, spec = pcall(self.callbacks.getCommandSpec)
		if ok and typeof(spec) == "table" then
			for _, cmd in ipairs(spec) do
				tabCommands:TextLabel("- " .. tostring(cmd.name) .. ": " .. tostring(cmd.description))
			end
		end
	end

	print("[SanDiegoAgent][UI] Panel built")
end

return UIPanel
