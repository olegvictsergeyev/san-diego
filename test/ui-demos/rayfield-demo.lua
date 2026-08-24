--[[
    Rayfield UI Demo
    ================
    Запусти в Roblox-executor'е, чтобы посмотреть визуал и возможности Rayfield.
    Внимание: Rayfield не поддерживает смену темы на лету. Этот файл использует тему Default.
    Для других тем смотри файлы rayfield-light.lua, rayfield-gold.lua, rayfield-ping.lua.
]]

print("[Rayfield Demo] Script started")

local ok, Rayfield = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)
if not ok then
    print("[Rayfield Demo] Failed to load library:", tostring(Rayfield))
    return
end
print("[Rayfield Demo] Library loaded")

local window = Rayfield:CreateWindow({
    Name = "Rayfield Demo",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "RayfieldDemo",
        FileName = "DemoConfig"
    },
    Discord = { Enabled = false },
    KeySystem = false
})
print("[Rayfield Demo] Window created")

local tabMain = window:CreateTab("Main", 4483362458)
local tabElements = window:CreateTab("Elements", 4483362458)
local tabThemes = window:CreateTab("Themes", 4483362458)
print("[Rayfield Demo] Tabs created")

tabMain:CreateParagraph({
    Title = "Rayfield Demo",
    Content = "Это демонстрационный скрипт для оценки визуала и функциональности библиотеки Rayfield."
})

tabMain:CreateButton({
    Name = "Show Notification",
    Callback = function()
        Rayfield:Notify({
            Title = "Hello!",
            Content = "This is a Rayfield notification.",
            Duration = 4,
            Image = 4483362458
        })
    end
})

tabElements:CreateToggle({
    Name = "Enable Feature",
    CurrentValue = false,
    Flag = "ToggleDemo",
    Callback = function(value)
        print("Toggle:", value)
    end
})

tabElements:CreateSlider({
    Name = "Speed",
    Range = {0, 100},
    Increment = 1,
    Suffix = " units",
    CurrentValue = 50,
    Flag = "SliderDemo",
    Callback = function(value)
        print("Slider:", value)
    end
})

tabElements:CreateDropdown({
    Name = "Select Option",
    Options = {"Option 1", "Option 2", "Option 3"},
    CurrentOption = "Option 1",
    Flag = "DropdownDemo",
    Callback = function(option)
        local value = typeof(option) == "table" and option[1] or tostring(option)
        print("Dropdown:", value)
    end
})

tabElements:CreateInput({
    Name = "Player Name",
    PlaceholderText = "Enter nickname...",
    RemoveTextAfterFocusLost = false,
    Flag = "InputDemo",
    Callback = function(text)
        print("Input:", text)
    end
})

tabElements:CreateKeybind({
    Name = "Toggle Key",
    CurrentKeybind = "Q",
    HoldToInteract = false,
    Flag = "KeybindDemo",
    Callback = function(keybind)
        print("Keybind pressed:", keybind)
    end
})

tabElements:CreateColorPicker({
    Name = "Pick Color",
    Color = Color3.fromRGB(255, 0, 0),
    Flag = "ColorDemo",
    Callback = function(color)
        print("Color:", color)
    end
})

tabElements:CreateLabel("This is a label element")

tabThemes:CreateLabel("Rayfield не поддерживает смену темы на лету.")
tabThemes:CreateLabel("Тема задаётся при создании окна.")
tabThemes:CreateLabel("Для просмотра других тем запусти:")
tabThemes:CreateLabel("rayfield-light.lua, rayfield-gold.lua, rayfield-ping.lua")

print("[Rayfield Demo] Done")
