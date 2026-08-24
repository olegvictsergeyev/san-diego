--[[
    Material Lua UI Demo
    ====================
    Запусти в Roblox-executor'е, чтобы посмотреть визуал и возможности Material Lua.
]]

local Material = loadstring(game:HttpGet("https://raw.githubusercontent.com/Kinlei/MaterialLua/master/Module.lua"))()

local themes = {
    Dark = "Dark",
    Light = "Light",
    Gold = {
        MainFrame = Color3.fromRGB(45, 35, 15),
        Minimise = Color3.fromRGB(255, 200, 80),
        MinimiseAccent = Color3.fromRGB(220, 170, 50),
        Maximise = Color3.fromRGB(255, 220, 130),
        MaximiseAccent = Color3.fromRGB(230, 190, 90),
        NavBar = Color3.fromRGB(60, 48, 22),
        NavBarAccent = Color3.fromRGB(255, 200, 80),
        Content = Color3.fromRGB(55, 44, 20),
        Search = Color3.fromRGB(255, 240, 200),
        Text = Color3.fromRGB(255, 245, 220),
        Placeholder = Color3.fromRGB(200, 180, 140)
    },
    Ping = {
        MainFrame = Color3.fromRGB(45, 15, 30),
        Minimise = Color3.fromRGB(255, 100, 160),
        MinimiseAccent = Color3.fromRGB(220, 60, 130),
        Maximise = Color3.fromRGB(255, 140, 190),
        MaximiseAccent = Color3.fromRGB(230, 100, 160),
        NavBar = Color3.fromRGB(60, 20, 40),
        NavBarAccent = Color3.fromRGB(255, 100, 160),
        Content = Color3.fromRGB(55, 20, 35),
        Search = Color3.fromRGB(255, 220, 235),
        Text = Color3.fromRGB(255, 240, 245),
        Placeholder = Color3.fromRGB(200, 160, 180)
    }
}

local function createUI(theme)
    local options = {
        Title = "Material Lua Demo",
        Style = 3,
        SizeX = 500,
        SizeY = 350,
        Theme = theme
    }

    local UI = Material.Load(options)

    local tabMain = UI.New({
        Title = "Main",
        ImageID = 4483362458
    })

    local tabElements = UI.New({
        Title = "Elements",
        ImageID = 4483362458
    })

    local tabThemes = UI.New({
        Title = "Themes",
        ImageID = 4483362458
    })

    tabMain.Button({
        Text = "Show Info",
        Callback = function()
            print("[Material Lua Demo] Button clicked")
        end
    })

    tabMain.Label({ Text = "Material Lua Demo" })
    tabMain.Label({ Text = "Демонстрация элементов Material Lua." })

    local toggleValue = false
    tabElements.Toggle({
        Text = "Enable Feature",
        Callback = function(state)
            toggleValue = state
            print("Toggle:", state)
        end,
        Enabled = toggleValue
    })

    tabElements.Slider({
        Text = "Speed",
        Callback = function(value)
            print("Slider:", value)
        end,
        Min = 0,
        Max = 100,
        Def = 50
    })

    tabElements.Dropdown({
        Text = "Select Option",
        Callback = function(option)
            print("Dropdown:", option)
        end,
        Options = {"Option 1", "Option 2", "Option 3"}
    })

    tabElements.TextField({
        Text = "Player Name",
        Callback = function(text)
            print("TextField:", text)
        end
    })

    tabThemes.Dropdown({
        Text = "Select Theme",
        Callback = function(option)
            print("[Material Lua Demo] Theme changed to", option, "- reload UI to apply")
        end,
        Options = {"Dark", "Light", "Gold", "Ping"}
    })
end

createUI(themes.Dark)

print("[Material Lua Demo] UI loaded")
