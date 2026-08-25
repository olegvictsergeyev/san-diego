local Players = game:GetService("Players")

local PopupCloser = {}
PopupCloser.__index = PopupCloser

local POPUPS = {
	StarterPackGui = {
		closePath = { "Frame", "TopFrame", "CloseButton", "Button" },
	},
	CustomServerHintGui = {
		closePath = { "Frame", "CloseButton" },
	},
}

function PopupCloser.new()
	return setmetatable({}, PopupCloser)
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

function PopupCloser:_click(btn)
	if not btn then
		return false
	end
	if getconnections then
		for _, conn in ipairs(getconnections(btn.MouseButton1Click)) do
			pcall(conn.Function)
		end
		return true
	end
	return false
end

function PopupCloser:_closePopup(sg, config)
	local closeBtn = config.closePath and self:_find(sg, config.closePath)
	if closeBtn then
		if self:_click(closeBtn) then
			return true
		end
	end
	-- Fallback: скрываем GUI целиком.
	sg.Enabled = false
	return true
end

function PopupCloser:_watchPopup(sg, config)
	if self._watched and self._watched[sg] then
		return
	end
	self._watched = self._watched or {}
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
			if self._watched then
				self._watched[sg] = nil
			end
		end
	end)
end

function PopupCloser:_checkExisting()
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	for name, config in pairs(POPUPS) do
		local sg = pg:FindFirstChild(name)
		if sg and sg:IsA("ScreenGui") then
			self:_watchPopup(sg, config)
		end
	end
end

function PopupCloser:start()
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")

	self:_checkExisting()

	pg.ChildAdded:Connect(function(child)
		if child:IsA("ScreenGui") and POPUPS[child.Name] then
			self:_watchPopup(child, POPUPS[child.Name])
		end
	end)

	-- Иногда GUI появляется/включается с задержкой после телепорта.
	-- Периодически проверяем первые 15 секунд.
	task.spawn(function()
		for _ = 1, 30 do
			task.wait(0.5)
			self:_checkExisting()
		end
	end)
end

return PopupCloser
