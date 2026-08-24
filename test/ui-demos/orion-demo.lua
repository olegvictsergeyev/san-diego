--[[
    Orion UI Demo
    =============
    Запусти в Roblox-executor'е, чтобы посмотреть визуал и возможности Orion.
]]

local OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/OrionLibrary/Orion/main/source.lua"))()

local Window = OrionLib:MakeWindow({
    Name = "Orion Demo",
    HidePremium = false,
    SaveConfig = true,
    ConfigFolder = "OrionDemo"
})

local tabMain = Window:MakeTab({
    Name = "Main",
    Icon = "rbxassetid://4483362458",
    PremiumOnly = false
})

local tabElements = Window:MakeTab({
    Name = "Elements",
    Icon = "rbxassetid://4483362458",
    PremiumOnly = false
})

local tabThemes = Window:MakeTab({
    Name = "Themes",
    Icon = "rbxassetid://4483362458",
    PremiumOnly = false
})

tabMain:AddSection({ Name = "Info" })
tabMain:AddLabel("Orion Demo")
tabMain:AddLabel("Демонстрация элементов Orion.")

tabMain:AddButton({
    Name = "Show Notification",
    Callback = function()
        OrionLib:MakeNotification({
            Name = "Hello!",
            Content = "This is an Orion notification.",
            Image = "rbxassetid://4483362458",
            Time = 4
        })
    end
})

tabElements:AddSection({ Name = "Inputs" })

tabElements:AddToggle({
    Name = "Enable Feature",
    Default = false,
    Callback = function(value)
        print("Toggle:", value)
    end
})

tabElements:AddSlider({
    Name = "Speed",
    Min = 0,
    Max = 100,
    Default = 50,
    Increment = 1,
    ValueName = "units",
    Callback = function(value)
        print("Slider:", value)
    end
})

tabElements:AddDropdown({
    Name = "Select Option",
    Default = "Option 1",
    Options = {"Option 1", "Option 2", "Option 3"},
    Callback = function(option)
        print("Dropdown:", option)
    end
})

tabElements:AddTextbox({
    Name = "Player Name",
    Default = "",
    TextDisappear = false,
    Callback = function(text)
        print("Textbox:", text)
    end
})

tabElements:AddBind({
    Name = "Toggle Key",
    Default = Enum.KeyCode.Q,
    Hold = false,
    Callback = function()
        print("Keybind pressed")
    end
})

tabElements:AddColorpicker({
    Name = "Pick Color",
    Default = Color3.fromRGB(255, 0, 0),
    Callback = function(color)
        print("Color:", color)
    end
})

tabThemes:AddSection({ Name = "Theme Info" })
tabThemes:AddLabel("Orion имеет фиксированную тему по умолчанию.")
tabThemes:AddLabel("Кастомные темы Dark/Light/Gold/Ping требуют модификации библиотеки.")

print("[Orion Demo] UI loaded")
