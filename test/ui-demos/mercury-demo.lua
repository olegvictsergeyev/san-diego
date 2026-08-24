--[[
    Mercury UI Demo
    =================
    Запусти в Roblox-executor'е, чтобы посмотреть визуал и возможности Mercury.
]]

local Mercury = loadstring(game:HttpGet("https://raw.githubusercontent.com/PlutonusDev/MercuryUI/master/MercuryUI.lua"))()

local gui = Mercury:Create({
    Name = "Mercury Demo",
    Size = UDim2.fromOffset(600, 400),
    Theme = Mercury.Themes.Dark,
    Link = "https://github.com/PlutonusDev/MercuryUI"
})

local tabMain = gui:Tab({
    Name = "Main",
    Icon = "rbxassetid://8569322835"
})

local tabElements = gui:Tab({
    Name = "Elements",
    Icon = "rbxassetid://4483362458"
})

local tabThemes = gui:Tab({
    Name = "Themes",
    Icon = "rbxassetid://8559790237"
})

tabMain:Label("Mercury Demo")
tabMain:Label("Это демонстрационный скрипт для оценки визуала и функциональности Mercury.")

tabMain:Button({
    Name = "Show Notification",
    Callback = function()
        gui:Notification({
            Title = "Hello!",
            Text = "This is a Mercury notification.",
            Duration = 3
        })
    end
})

tabElements:Toggle({
    Name = "Enable Feature",
    StartingState = false,
    Callback = function(state)
        print("Toggle:", state)
    end
})

tabElements:Slider({
    Name = "Speed",
    Min = 0,
    Max = 100,
    Default = 50,
    Callback = function(value)
        print("Slider:", value)
    end
})

tabElements:Dropdown({
    Name = "Select Option",
    StartingText = "Choose...",
    Items = {"Option 1", "Option 2", "Option 3"},
    Callback = function(item)
        print("Dropdown:", item)
    end
})

tabElements:Textbox({
    Name = "Player Name",
    Callback = function(text)
        print("Textbox:", text)
    end
})

tabElements:Keybind({
    Name = "Toggle Key",
    Keybind = Enum.KeyCode.Delete,
    Callback = function()
        print("Keybind pressed")
    end
})

-- Кастомные темы Gold и Ping
local goldTheme = {
    Main = Color3.fromRGB(45, 35, 15),
    Secondary = Color3.fromRGB(65, 52, 24),
    Tertiary = Color3.fromRGB(255, 200, 80),
    StrongText = Color3.fromRGB(255, 245, 220),
    WeakText = Color3.fromRGB(200, 180, 140)
}

local pingTheme = {
    Main = Color3.fromRGB(45, 15, 30),
    Secondary = Color3.fromRGB(65, 24, 42),
    Tertiary = Color3.fromRGB(255, 100, 160),
    StrongText = Color3.fromRGB(255, 240, 245),
    WeakText = Color3.fromRGB(200, 160, 180)
}

Mercury.Themes.Gold = goldTheme
Mercury.Themes.Ping = pingTheme

tabThemes:Dropdown({
    Name = "Select Theme",
    StartingText = "Dark",
    Items = {"Dark", "Light", "Gold", "Ping"},
    Callback = function(theme)
        if Mercury.Themes[theme] then
            Mercury:change_theme(Mercury.Themes[theme])
        end
    end
})

print("[Mercury Demo] UI loaded")
