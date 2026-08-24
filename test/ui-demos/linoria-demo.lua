--[[
    Linoria UI Demo
    ===============
    Запусти в Roblox-executor'е, чтобы посмотреть визуал и возможности Linoria.
]]

local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/Library.lua"))()

local function applyTheme(name)
    if name == "Dark" then
        Library.MainColor = Color3.fromRGB(28, 28, 28)
        Library.BackgroundColor = Color3.fromRGB(20, 20, 20)
        Library.AccentColor = Color3.fromRGB(0, 85, 255)
        Library.FontColor = Color3.fromRGB(255, 255, 255)
        Library.OutlineColor = Color3.fromRGB(50, 50, 50)
    elseif name == "Light" then
        Library.MainColor = Color3.fromRGB(230, 230, 230)
        Library.BackgroundColor = Color3.fromRGB(245, 245, 245)
        Library.AccentColor = Color3.fromRGB(0, 120, 215)
        Library.FontColor = Color3.fromRGB(30, 30, 30)
        Library.OutlineColor = Color3.fromRGB(180, 180, 180)
    elseif name == "Gold" then
        Library.MainColor = Color3.fromRGB(45, 35, 15)
        Library.BackgroundColor = Color3.fromRGB(30, 24, 10)
        Library.AccentColor = Color3.fromRGB(255, 190, 40)
        Library.FontColor = Color3.fromRGB(255, 245, 220)
        Library.OutlineColor = Color3.fromRGB(100, 80, 36)
    elseif name == "Ping" then
        Library.MainColor = Color3.fromRGB(45, 15, 30)
        Library.BackgroundColor = Color3.fromRGB(30, 10, 20)
        Library.AccentColor = Color3.fromRGB(255, 60, 150)
        Library.FontColor = Color3.fromRGB(255, 240, 245)
        Library.OutlineColor = Color3.fromRGB(100, 36, 62)
    end
    Library:UpdateColorsUsingRegistry()
end

local Window = Library:CreateWindow({
    Title = "Linoria Demo",
    Center = true,
    AutoShow = true
})

local tabMain = Window:AddTab("Main")
local tabElements = Window:AddTab("Elements")
local tabThemes = Window:AddTab("Themes")

local leftMain = tabMain:AddLeftGroupbox("Info")
leftMain:AddLabel("Linoria Demo")
leftMain:AddLabel("Демонстрация элементов и тем Linoria.")
leftMain:AddButton("Show Notification", function()
    Library:Notify("This is a Linoria notification", 3)
end)

local leftElements = tabElements:AddLeftGroupbox("Inputs")
leftElements:AddToggle("ToggleDemo", { Text = "Enable Feature", Default = false }):OnChanged(function(value)
    print("Toggle:", value)
end)

leftElements:AddSlider("SliderDemo", { Text = "Speed", Default = 50, Min = 0, Max = 100, Rounding = 0 }):OnChanged(function(value)
    print("Slider:", value)
end)

leftElements:AddDropdown("DropdownDemo", { Values = {"Option 1", "Option 2", "Option 3"}, Default = 1, Multi = false, Text = "Select Option" }):OnChanged(function(value)
    print("Dropdown:", value)
end)

leftElements:AddInput("InputDemo", { Default = "", Numeric = false, Finished = false, Text = "Player Name" }):OnChanged(function(value)
    print("Input:", value)
end)

local rightElements = tabElements:AddRightGroupbox("More")
rightElements:AddColorPicker("ColorDemo", { Default = Color3.fromRGB(255, 0, 0), Title = "Pick Color" }):OnChanged(function(color)
    print("Color:", color)
end)

rightElements:AddKeyPicker("KeybindDemo", { Default = "Q", NoUI = false, Text = "Toggle Key" })

local leftThemes = tabThemes:AddLeftGroupbox("Theme Switcher")
leftThemes:AddDropdown("ThemeDemo", { Values = {"Dark", "Light", "Gold", "Ping"}, Default = 1, Multi = false, Text = "Select Theme" }):OnChanged(function(value)
    applyTheme(value)
end)

applyTheme("Dark")

Library:Notify("Linoria Demo loaded", 3)
print("[Linoria Demo] UI loaded")
