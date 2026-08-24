--[[
    Rayfield Ping Theme Demo
    =========================
    Запусти в Roblox-executor'е, чтобы посмотреть Rayfield в кастомной розовой теме.
]]

print("[Rayfield Ping] Script started")

local ok, Rayfield = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)
if not ok then
    print("[Rayfield Ping] Failed to load library:", tostring(Rayfield))
    return
end
print("[Rayfield Ping] Library loaded")

local pingTheme = {
    TextColor = Color3.fromRGB(255, 240, 245),
    Background = Color3.fromRGB(45, 15, 30),
    Topbar = Color3.fromRGB(60, 20, 40),
    Shadow = Color3.fromRGB(30, 10, 20),
    NotificationBackground = Color3.fromRGB(55, 20, 35),
    NotificationActionsBackground = Color3.fromRGB(230, 120, 170),
    TabBackground = Color3.fromRGB(90, 30, 55),
    TabStroke = Color3.fromRGB(110, 40, 70),
    TabBackgroundSelected = Color3.fromRGB(255, 100, 160),
    TabTextColor = Color3.fromRGB(255, 220, 235),
    SelectedTabTextColor = Color3.fromRGB(60, 10, 30),
    ElementBackground = Color3.fromRGB(65, 24, 42),
    ElementBackgroundHover = Color3.fromRGB(80, 30, 52),
    SecondaryElementBackground = Color3.fromRGB(55, 20, 35),
    ElementStroke = Color3.fromRGB(100, 36, 62),
    SecondaryElementStroke = Color3.fromRGB(85, 30, 55),
    SliderBackground = Color3.fromRGB(220, 50, 130),
    SliderProgress = Color3.fromRGB(255, 70, 160),
    SliderStroke = Color3.fromRGB(255, 100, 180),
    ToggleBackground = Color3.fromRGB(55, 20, 35),
    ToggleEnabled = Color3.fromRGB(255, 60, 150),
    ToggleDisabled = Color3.fromRGB(120, 60, 85),
    ToggleEnabledStroke = Color3.fromRGB(255, 90, 170),
    ToggleDisabledStroke = Color3.fromRGB(140, 70, 95),
    ToggleEnabledOuterStroke = Color3.fromRGB(180, 50, 110),
    ToggleDisabledOuterStroke = Color3.fromRGB(90, 40, 60),
    DropdownSelected = Color3.fromRGB(80, 30, 52),
    DropdownUnselected = Color3.fromRGB(55, 20, 35),
    InputBackground = Color3.fromRGB(55, 20, 35),
    InputStroke = Color3.fromRGB(100, 36, 62),
    PlaceholderColor = Color3.fromRGB(190, 130, 160)
}

local window = Rayfield:CreateWindow({
    Name = "Rayfield Ping Theme",
    ConfigurationSaving = { Enabled = false },
    Discord = { Enabled = false },
    KeySystem = false,
    Theme = pingTheme
})

local tabMain = window:CreateTab("Main", 4483362458)
local tabElements = window:CreateTab("Elements", 4483362458)

tabMain:CreateParagraph({
    Title = "Ping Theme",
    Content = "Это Rayfield с кастомной розовой темой."
})

tabMain:CreateButton({
    Name = "Notify",
    Callback = function()
        Rayfield:Notify({ Title = "Ping", Content = "Works!", Duration = 3, Image = 4483362458 })
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
    CurrentValue = 75,
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
    Color = Color3.fromRGB(255, 100, 160),
    Callback = function(v) print("Color:", v) end
})

print("[Rayfield Ping] Done")
