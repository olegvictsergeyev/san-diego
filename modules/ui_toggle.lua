local TweenService = game:GetService("TweenService")

local ToggleUI = {}
ToggleUI.__index = ToggleUI

function ToggleUI.new(mainGui, options)
	local self = setmetatable({}, ToggleUI)
	self.mainGui = mainGui
	self.options = options or {}
	self.parent = self.options.parent or game.CoreGui
	self.visible = self.options.initialVisible == true
	self.buttonSize = self.options.buttonSize or 44
	self.iconText = self.options.icon or "▲"

	self:_destroyExisting()
	self:_createGui()
	self:_setIconRotation(self.visible and 180 or 0, false)
	self:setMainVisible(self.visible)
	self:_bindCloseButton()
	return self
end

function ToggleUI:_destroyExisting()
	local existing = self.parent:FindFirstChild("SanDiegoAgentToggle")
	if existing then
		existing:Destroy()
	end
end

function ToggleUI:_createGui()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SanDiegoAgentToggle"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = self.parent

	local frame = Instance.new("Frame")
	frame.Name = "ToggleButton"
	frame.Size = UDim2.new(0, self.buttonSize, 0, self.buttonSize)
	frame.Position = UDim2.new(0, 12, 1, -self.buttonSize - 12)
	frame.AnchorPoint = Vector2.new(0, 1)
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel = 0
	frame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Transparency = 0.6
	stroke.Thickness = 1
	stroke.Parent = frame

	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.new(1, 0, 1, 0)
	shadow.Position = UDim2.new(0, 2, 0, 2)
	shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	shadow.BackgroundTransparency = 0.6
	shadow.BorderSizePixel = 0
	shadow.ZIndex = -1
	shadow.Parent = frame
	Instance.new("UICorner").CornerRadius = UDim.new(0, 8)

	local scale = Instance.new("UIScale")
	scale.Parent = frame

	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.new(1, 0, 1, 0)
	icon.BackgroundTransparency = 1
	icon.Text = self.iconText
	icon.TextColor3 = Color3.fromRGB(255, 255, 255)
	icon.TextSize = 24
	icon.Font = Enum.Font.GothamBold
	icon.Parent = frame

	local button = Instance.new("TextButton")
	button.Name = "HitArea"
	button.Size = UDim2.new(1, 0, 1, 0)
	button.BackgroundTransparency = 1
	button.Text = ""
	button.Parent = frame

	self.gui = screenGui
	self.frame = frame
	self.icon = icon
	self.button = button
	self.scale = scale

	self:_connectEvents()
end

function ToggleUI:_connectEvents()
	self.button.MouseButton1Click:Connect(function()
		self:toggle()
	end)

	self.button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self:_pressFeedback(true)
		end
	end)

	self.button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self:_pressFeedback(false)
		end
	end)
end

function ToggleUI:_pressFeedback(pressed)
	local target = pressed and 0.92 or 1
	TweenService:Create(self.scale, TweenInfo.new(0.1), { Scale = target }):Play()
end

function ToggleUI:_setIconRotation(rotation, animate)
	local info = animate and TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) or TweenInfo.new(0)
	TweenService:Create(self.icon, info, { Rotation = rotation }):Play()
end

function ToggleUI:setMainVisible(visible)
	self.visible = visible
	if self.mainGui then
		self.mainGui.Enabled = visible
	end
end

function ToggleUI:toggle()
	self.visible = not self.visible
	self:setMainVisible(self.visible)
	self:_setIconRotation(self.visible and 180 or 0, true)
end

function ToggleUI:destroy()
	if self.gui then
		self.gui:Destroy()
	end
end

function ToggleUI:_findCloseButton()
	if not self.mainGui then
		return nil
	end
	local closeTexts = { ["×"] = true, ["x"] = true, ["X"] = true, ["✕"] = true, ["✖"] = true, ["Close"] = true, ["CLOSE"] = true }
	local closeImages = { ["rbxassetid://4988112250"] = true }
	for _, desc in ipairs(self.mainGui:GetDescendants()) do
		if desc:IsA("TextButton") or desc:IsA("ImageButton") then
			local nameLower = desc.Name:lower()
			if nameLower:find("close") or nameLower:find("exit") then
				return desc
			end
			if desc:IsA("TextButton") and (closeTexts[desc.Text] or closeTexts[desc.Text:lower()]) then
				return desc
			end
			if desc:IsA("ImageButton") and closeImages[desc.Image] then
				return desc
			end
		end
	end
	return nil
end

function ToggleUI:_createCloseOverlay(btn)
	local parent = btn.Parent
	if not parent then
		return
	end
	local overlay = Instance.new("TextButton")
	overlay.Name = "CloseOverlay"
	overlay.Size = btn.Size
	overlay.Position = btn.Position
	overlay.AnchorPoint = btn.AnchorPoint
	overlay.BackgroundTransparency = 1
	overlay.Text = ""
	overlay.ZIndex = btn.ZIndex + 10
	overlay.Parent = parent

	overlay.MouseButton1Click:Connect(function()
		self:toggle()
	end)
end

function ToggleUI:_bindCloseButton()
	local btn = self:_findCloseButton()
	if not btn then
		print("[SanDiegoAgent][ToggleUI] close button not found")
		return
	end
	print("[SanDiegoAgent][ToggleUI] close button found:", btn.Name, "class:", btn.ClassName, "text:", btn:IsA("TextButton") and btn.Text or "")

	if typeof(getconnections) == "function" then
		local conns = getconnections(btn.MouseButton1Click)
		print("[SanDiegoAgent][ToggleUI] close button connections:", #conns)
		for _, conn in ipairs(conns) do
			if typeof(conn.Enabled) == "boolean" then
				conn.Enabled = false
			end
		end
	end

	btn.MouseButton1Click:Connect(function()
		self:toggle()
	end)

	self:_createCloseOverlay(btn)
end

return ToggleUI
