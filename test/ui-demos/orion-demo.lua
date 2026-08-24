--[[
    Orion UI Demo
    =============
    Запусти в Roblox-executor'е, чтобы посмотреть визуал и возможности Orion.

    Особенности:
    - Библиотека не имеет встроенной смены темы (цвета зашиты в коде).
    - API отличается от MakeWindow/MakeTab: используется CreateOrion -> CreateSection.
]]

print("[Orion Demo] Loading library...")
local ok, Orion = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/OrionLibrary/Orion/main/source.lua"))()
end)
if not ok then
    print("[Orion Demo] Failed to load:", tostring(Orion))
    return
end
print("[Orion Demo] Library loaded")

local Window = Orion:CreateOrion("Orion Demo")

local tabMain = Window:CreateSection("Main")
local tabElements = Window:CreateSection("Elements")
local tabThemes = Window:CreateSection("Themes")

tabMain:TextLabel("Orion Demo")
tabMain:TextLabel("Демонстрация элементов Orion.")

tabMain:TextButton("Show Notification", "Click to print", function()
    print("[Orion Demo] Button clicked")
end)

tabElements:Toggle("Enable Feature", function(state)
    print("Toggle:", state)
end)

tabElements:Slider("Speed", 0, 100, function(value)
    print("Slider:", value)
end)

tabElements:Dropdown("Select Option", {"Option 1", "Option 2", "Option 3"}, function(option)
    print("Dropdown:", option)
end)

tabElements:TextBox("Player Name", "Enter text...", function(text)
    print("TextBox:", text)
end)

tabElements:KeyBind("Toggle Key", Enum.KeyCode.Q, function()
    print("Keybind pressed")
end)

tabThemes:TextLabel("Orion имеет фиксированную тему по умолчанию.")
tabThemes:TextLabel("Кастомные темы Dark/Light/Gold/Ping требуют модификации библиотеки.")

print("[Orion Demo] UI loaded")
