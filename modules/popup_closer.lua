local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")

local PopupCloser = {}
PopupCloser.__index = PopupCloser

local POPUPS = {
	StarterPackGui = {
		closePath = { "Frame", "TopFrame", "CloseButton", "Button" },
	},
	ChangelogGui = {
		closePath = { "Frame", "TopFrame", "CloseButton", "Button" },
	},
	CustomServerHintGui = {
		closePath = { "Frame", "CloseButton" },
	},
	TutorialUI = {},
	DailyRewardsGui = {
		closePath = { "XpTeamPrompt", "TopFrame", "CloseButton", "Button" },
	},
	GroupRewardGui = {
		closePath = { "Frame", "TopFrame", "CloseButton", "Button" },
	},
}

-- Кнопки с такими именами/текстами считаем закрывающими.
local CLOSE_HINTS = { "close", "x", "skip", "ok", "continue", "got it", "maybe later", "no thanks" }

function PopupCloser.new(compat)
	return setmetatable({
		compat = compat,
		_watched = {},
	}, PopupCloser)
end

function PopupCloser:_find(root, path)
	local current = root
	for _, name in ipairs(path) do
		current = current:FindFirstChild(name)
		if not current then
			return nil
		end
	end
	return current
end

function PopupCloser:_normalizeText(text)
	return tostring(text or ""):lower():gsub("%s+", " ")
end

function PopupCloser:_isCloseButton(btn)
	if not (btn:IsA("TextButton") or btn:IsA("ImageButton")) then
		return false
	end
	local name = btn.Name:lower()
	local text = self:_normalizeText(btn.Text)
	for _, hint in ipairs(CLOSE_HINTS) do
		if name:find(hint, 1, true) or text:find(hint, 1, true) then
			return true
		end
	end
	return false
end

function PopupCloser:_findCloseButton(sg)
	for _, desc in ipairs(sg:GetDescendants()) do
		if self:_isCloseButton(desc) then
			return desc
		end
	end
	return nil
end

function PopupCloser:_click(btn)
	if not btn then
		return false
	end
	local clicked = false

	-- Пробуем стандартный метод GuiButton:Activate().
	pcall(function()
		btn:Activate()
		clicked = true
	end)

	-- Пробуем firesignal (некоторые executor'ы поддерживают).
	if typeof(firesignal) == "function" then
		pcall(function()
			firesignal(btn.MouseButton1Click)
			clicked = true
		end)
		pcall(function()
			firesignal(btn.Activated)
			clicked = true
		end)
	end

	-- Пробуем getconnections.
	local getConn = self.compat and self.compat.getConnections or getconnections
	if typeof(getConn) == "function" then
		local signals = { "MouseButton1Click", "Activated" }
		for _, signalName in ipairs(signals) do
			local signal = btn[signalName]
			if signal then
				local conns = getConn(signal)
				for _, conn in ipairs(conns) do
					pcall(conn.Function)
					clicked = true
				end
			end
		end
	end

	-- Fallback через VirtualUser (клик по центру экрана, если кнопка видна).
	pcall(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton1(Vector2.new(0, 0))
		clicked = true
	end)

	return clicked
end

function PopupCloser:_closePopup(sg, config)
	local closeBtn = config.closePath and self:_find(sg, config.closePath)
	if not closeBtn then
		closeBtn = self:_findCloseButton(sg)
	end
	if closeBtn then
		self:_click(closeBtn)
	end
	-- Fallback: скрываем GUI целиком.
	pcall(function()
		sg.Enabled = false
	end)
	return true
end

function PopupCloser:_watchPopup(sg, config)
	if self._watched[sg] then
		return
	end
	self._watched[sg] = true

	-- Закрываем, если уже видим.
	if sg.Enabled then
		self:_closePopup(sg, config)
	end

	-- Следим за включением GUI.
	local conn
	conn = sg:GetPropertyChangedSignal("Enabled"):Connect(function()
		if sg.Enabled then
			self:_closePopup(sg, config)
		end
	end)

	-- Отключаем соединение, если GUI удалён.
	sg.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			conn:Disconnect()
			self._watched[sg] = nil
		end
	end)
end

function PopupCloser:_checkExisting()
	local player = Players.LocalPlayer
	if not player then
		return
	end
	local pg = player:WaitForChild("PlayerGui")
	for name, config in pairs(POPUPS) do
		local sg = pg:FindFirstChild(name)
		if sg and sg:IsA("ScreenGui") then
			self:_watchPopup(sg, config)
		end
	end
end

function PopupCloser:start()
	self:_checkExisting()

	local player = Players.LocalPlayer
	if not player then
		return
	end
	local pg = player:WaitForChild("PlayerGui")

	pg.ChildAdded:Connect(function(child)
		if child:IsA("ScreenGui") and POPUPS[child.Name] then
			self:_watchPopup(child, POPUPS[child.Name])
		end
	end)

	-- Иногда GUI появляется/включается с задержкой после телепорта.
	-- Периодически проверяем первые 20 секунд.
	task.spawn(function()
		for _ = 1, 40 do
			task.wait(0.5)
			self:_checkExisting()
		end
	end)
end

return PopupCloser
