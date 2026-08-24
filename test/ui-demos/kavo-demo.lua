--[[
    Kavo UI Demo
    ============
    Запусти в Roblox-executor'е, чтобы посмотреть визуал и возможности Kavo.
]]

local Kavo = loadstring(game:HttpGet("https://raw.githubusercontent.com/xHeptc/Kavo-UI-Library/main/source.lua"))()

-- Встроенные темы Kavo: Dark, Light, Blood, Grape, Ocean, Midnight, Sentinel, Synapse, Serpent
-- Кастомные темы Gold и Ping для демонстрации
local customThemes = {
    Gold = {
        SchemeColor = Color3.fromRGB(255, 190, 40),
        Background = Color3.fromRGB(45, 35, 15),
        Header = Color3.fromRGB(60, 48, 22),
        TextColor = Color3.fromRGB(255, 245, 220),
        ElementColor = Color3.fromRGB(65, 52, 24)
    },
    Ping = {
        SchemeColor = Color3.fromRGB(255, 60, 150),
        Background = Color3.fromRGB(45, 15, 30),
        Header = Color3.fromRGB(60, 20, 40),
        TextColor = Color3.fromRGB(255, 240, 245),
        ElementColor = Color3.fromRGB(65, 24, 42)
    }
}

local currentTheme = "Dark"
local Window

local function createWindow(theme)
    if typeof(theme) == "string" then
        Window = Kavo.CreateLib("Kavo Demo", theme)
    else
        Window = Kavo.CreateLib("Kavo Demo", theme)
    end
end

createWindow(currentTheme)

local tabMain = Window:NewTab("Main")
local tabElements = Window:NewTab("Elements")
local tabThemes = Window:NewTab("Themes")

local sectionInfo = tabMain:NewSection("Info")
sectionInfo:NewLabel("Kavo Demo")
sectionInfo:NewLabel("Демонстрация элементов Kavo.")
sectionInfo:NewButton("Show Notification", "Click me", function()
    -- Kavo не имеет встроенных уведомлений, выводим в консоль
    print("[Kavo Demo] Button clicked")
end)

local sectionInputs = tabElements:NewSection("Inputs")
sectionInputs:NewToggle("Enable Feature", "Toggle description", function(state)
    print("Toggle:", state)
end)

sectionInputs:NewSlider("Speed", "Slider description", 0, 100, 50, function(value)
    print("Slider:", value)
end)

sectionInputs:NewDropdown("Select Option", "Dropdown description", {"Option 1", "Option 2", "Option 3"}, function(option)
    print("Dropdown:", option)
end)

sectionInputs:NewTextBox("Player Name", "Enter text", function(text)
    print("TextBox:", text)
end)

sectionInputs:NewKeybind("Toggle Key", "Keybind description", Enum.KeyCode.Q, function()
    print("Keybind pressed")
end)

sectionInputs:NewColorPicker("Pick Color", "Color picker description", Color3.fromRGB(255, 0, 0), function(color)
    print("Color:", color)
end)

local sectionThemes = tabThemes:NewSection("Theme Switcher")
sectionThemes:NewDropdown("Select Theme", "Choose a theme", {"Dark", "Light", "Blood", "Grape", "Ocean", "Midnight", "Gold", "Ping"}, function(option)
    if option == "Gold" then
        createWindow(customThemes.Gold)
    elseif option == "Ping" then
        createWindow(customThemes.Ping)
    else
        createWindow(option)
    end
end)

print("[Kavo Demo] UI loaded")
