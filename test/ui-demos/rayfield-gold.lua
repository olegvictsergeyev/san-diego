--[[
    Rayfield Gold Theme Demo
    =========================
    Запусти в Roblox-executor'е, чтобы посмотреть Rayfield в кастомной золотой теме.
]]

print("[Rayfield Gold] Script started")

local ok, Rayfield = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)
if not ok then
    print("[Rayfield Gold] Failed to load library:", tostring(Rayfield))
    return
end
print("[Rayfield Gold] Library loaded")

local goldTheme = {
    TextColor = Color3.fromRGB(255, 245, 220),
    Background = Color3.fromRGB(45, 35, 15),
    Topbar = Color3.fromRGB(60, 48, 22),
    Shadow = Color3.fromRGB(30, 24, 10),
    NotificationBackground = Color3.fromRGB(55, 44, 20),
    NotificationActionsBackground = Color3.fromRGB(230, 200, 120),
    TabBackground = Color3.fromRGB(90, 72, 30),
    TabStroke = Color3.fromRGB(110, 88, 40),
    TabBackgroundSelected = Color3.fromRGB(255, 200, 80),
    TabTextColor = Color3.fromRGB(255, 235, 180),
    SelectedTabTextColor = Color3.fromRGB(50, 40, 10),
    ElementBackground = Color3.fromRGB(65, 52, 24),
    ElementBackgroundHover = Color3.fromRGB(80, 65, 30),
    SecondaryElementBackground = Color3.fromRGB(55, 44, 20),
    ElementStroke = Color3.fromRGB(100, 80, 36),
    SecondaryElementStroke = Color3.fromRGB(85, 68, 30),
    SliderBackground = Color3.fromRGB(220, 170, 50),
    SliderProgress = Color3.fromRGB(255, 200, 70),
    SliderStroke = Color3.fromRGB(255, 215, 100),
    ToggleBackground = Color3.fromRGB(55, 44, 20),
    ToggleEnabled = Color3.fromRGB(255, 190, 40),
    ToggleDisabled = Color3.fromRGB(120, 100, 60),
    ToggleEnabledStroke = Color3.fromRGB(255, 210, 80),
    ToggleDisabledStroke = Color3.fromRGB(140, 120, 70),
    ToggleEnabledOuterStroke = Color3.fromRGB(180, 140, 50),
    ToggleDisabledOuterStroke = Color3.fromRGB(90, 75, 40),
    DropdownSelected = Color3.fromRGB(80, 65, 30),
    DropdownUnselected = Color3.fromRGB(55, 44, 20),
    InputBackground = Color3.fromRGB(55, 44, 20),
    InputStroke = Color3.fromRGB(100, 80, 36),
    PlaceholderColor = Color3.fromRGB(190, 170, 130)
}

local window = Rayfield:CreateWindow({
    Name = "Rayfield Gold Theme",
    ConfigurationSaving = { Enabled = false },
    Discord = { Enabled = false },
    KeySystem = false,
    Theme = goldTheme
})

local tabMain = window:CreateTab("Main", 4483362458)
local tabElements = window:CreateTab("Elements", 4483362458)

tabMain:CreateParagraph({
    Title = "Gold Theme",
    Content = "Это Rayfield с кастомной золотой темой."
})

tabMain:CreateButton({
    Name = "Notify",
    Callback = function()
        Rayfield:Notify({ Title = "Gold", Content = "Works!", Duration = 3, Image = 4483362458 })
    end
})

tabElements:CreateToggle({
    Name = "Toggle",
    CurrentValue = true,
    Callback = function(v) print("Toggle:", v) end
})

tabElements:CreateSlider({
    Name = "Slider",
    Range = {0, 100},
    Increment = 1,
    CurrentValue = 60,
    Callback = function(v) print("Slider:", v) end
})

tabElements:CreateDropdown({
    Name = "Dropdown",
    Options = {"A", "B", "C"},
    CurrentOption = "A",
    Callback = function(v) print("Dropdown:", v) end
})

tabElements:CreateInput({
    Name = "Input",
    PlaceholderText = "text",
    Callback = function(v) print("Input:", v) end
})

tabElements:CreateColorPicker({
    Name = "Color",
    Color = Color3.fromRGB(255, 200, 80),
    Callback = function(v) print("Color:", v) end
})

print("[Rayfield Gold] Done")
