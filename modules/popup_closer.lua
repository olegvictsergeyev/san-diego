local Players = game:GetService("Players")

local PopupCloser = {}
PopupCloser.__index = PopupCloser

local POPUPS = {
	StarterPackGui = {
		closePath = { "Frame", "TopFrame", "CloseButton", "Button" },
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
	local closeBtn = self:_find(sg, config.closePath)
	if closeBtn then
		if self:_click(closeBtn) then
			return
		end
	end
	-- Fallback: просто скрываем GUI, если кнопка не нашлась или getconnections не работает.
	sg.Enabled = false
end

function PopupCloser:_checkExisting()
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	for name, config in pairs(POPUPS) do
		local sg = pg:FindFirstChild(name)
		if sg and sg:IsA("ScreenGui") and sg.Enabled then
			self:_closePopup(sg, config)
		end
	end
end

function PopupCloser:start()
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	self:_checkExisting()

	pg.ChildAdded:Connect(function(child)
		if child:IsA("ScreenGui") and POPUPS[child.Name] then
			-- Даём GUI время создать кнопки.
			task.wait(0.5)
			if child.Enabled then
				self:_closePopup(child, POPUPS[child.Name])
			end
		end
	end)

	-- Если GUI добавлено до того, как ChildAdded подключился, проверим ещё раз.
	task.delay(2, function()
		self:_checkExisting()
	end)
end

return PopupCloser
