--[[
    Material Lua UI Demo
    ====================
    Запусти в Roblox-executor'е, чтобы посмотреть визуал и возможности Material Lua.
]]

local themes = {
    Dark = "Dark",
    Light = "Light",
    Mocha = "Mocha",
    Aqua = "Aqua",
    Jester = "Jester",
    Gold = {
        MainFrame = Color3.fromRGB(45, 35, 15),
        Minimise = Color3.fromRGB(255, 200, 80),
        MinimiseAccent = Color3.fromRGB(220, 170, 50),
        Maximise = Color3.fromRGB(255, 220, 130),
        MaximiseAccent = Color3.fromRGB(230, 190, 90),
        NavBar = Color3.fromRGB(60, 48, 22),
        NavBarAccent = Color3.fromRGB(255, 200, 80),
        NavBarInvert = Color3.fromRGB(30, 24, 10),
        TitleBar = Color3.fromRGB(60, 48, 22),
        TitleBarAccent = Color3.fromRGB(255, 245, 220),
        Overlay = Color3.fromRGB(255, 200, 80),
        Banner = Color3.fromRGB(60, 48, 22),
        BannerAccent = Color3.fromRGB(255, 245, 220),
        Content = Color3.fromRGB(55, 44, 20),
        Button = Color3.fromRGB(255, 200, 80),
        ButtonAccent = Color3.fromRGB(50, 40, 10),
        ChipSet = Color3.fromRGB(255, 200, 80),
        ChipSetAccent = Color3.fromRGB(50, 40, 10),
        DataTable = Color3.fromRGB(255, 200, 80),
        DataTableAccent = Color3.fromRGB(50, 40, 10),
        Slider = Color3.fromRGB(55, 44, 20),
        SliderAccent = Color3.fromRGB(255, 200, 80),
        Toggle = Color3.fromRGB(255, 200, 80),
        ToggleAccent = Color3.fromRGB(50, 40, 10),
        Dropdown = Color3.fromRGB(55, 44, 20),
        DropdownAccent = Color3.fromRGB(255, 200, 80),
        ColorPicker = Color3.fromRGB(55, 44, 20),
        ColorPickerAccent = Color3.fromRGB(255, 200, 80),
        TextField = Color3.fromRGB(55, 44, 20),
        TextFieldAccent = Color3.fromRGB(255, 200, 80)
    },
    Ping = {
        MainFrame = Color3.fromRGB(45, 15, 30),
        Minimise = Color3.fromRGB(255, 100, 160),
        MinimiseAccent = Color3.fromRGB(220, 60, 130),
        Maximise = Color3.fromRGB(255, 140, 190),
        MaximiseAccent = Color3.fromRGB(230, 100, 160),
        NavBar = Color3.fromRGB(60, 20, 40),
        NavBarAccent = Color3.fromRGB(255, 100, 160),
        NavBarInvert = Color3.fromRGB(30, 10, 20),
        TitleBar = Color3.fromRGB(60, 20, 40),
        TitleBarAccent = Color3.fromRGB(255, 240, 245),
        Overlay = Color3.fromRGB(255, 100, 160),
        Banner = Color3.fromRGB(60, 20, 40),
        BannerAccent = Color3.fromRGB(255, 240, 245),
        Content = Color3.fromRGB(55, 20, 35),
        Button = Color3.fromRGB(255, 100, 160),
        ButtonAccent = Color3.fromRGB(50, 10, 30),
        ChipSet = Color3.fromRGB(255, 100, 160),
        ChipSetAccent = Color3.fromRGB(50, 10, 30),
        DataTable = Color3.fromRGB(255, 100, 160),
        DataTableAccent = Color3.fromRGB(50, 10, 30),
        Slider = Color3.fromRGB(55, 20, 35),
        SliderAccent = Color3.fromRGB(255, 100, 160),
        Toggle = Color3.fromRGB(255, 100, 160),
        ToggleAccent = Color3.fromRGB(50, 10, 30),
        Dropdown = Color3.fromRGB(55, 20, 35),
        DropdownAccent = Color3.fromRGB(255, 100, 160),
        ColorPicker = Color3.fromRGB(55, 20, 35),
        ColorPickerAccent = Color3.fromRGB(255, 100, 160),
        TextField = Color3.fromRGB(55, 20, 35),
        TextFieldAccent = Color3.fromRGB(255, 100, 160)
    }
}

local function buildUI(theme)
    local UI = Material.Load({
        Title = "Material Lua Demo",
        Style = 3,
        SizeX = 500,
        SizeY = 350,
        Theme = theme
    })

    local tabMain = UI.New({
        Title = "Main"
    })

    local tabElements = UI.New({
        Title = "Elements"
    })

    local tabThemes = UI.New({
        Title = "Themes"
    })

    tabMain.Button({
        Text = "Show Info",
        Callback = function()
            print("[Material Lua Demo] Button clicked")
        end
    })

    tabMain.Label({ Text = "Material Lua Demo" })
    tabMain.Label({ Text = "Демонстрация элементов Material Lua." })

    tabElements.Toggle({
        Text = "Enable Feature",
        Callback = function(state)
            print("Toggle:", state)
        end,
        Enabled = false
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

    tabElements.ColorPicker({
        Text = "Pick Color",
        Default = Color3.fromRGB(255, 0, 0),
        Callback = function(color)
            print("Color:", color)
        end
    })

    tabThemes.Dropdown({
        Text = "Select Theme",
        Callback = function(option)
            if themes[option] then
                buildUI(themes[option])
            end
        end,
        Options = {"Dark", "Light", "Mocha", "Aqua", "Jester", "Gold", "Ping"}
    })
end

local function runDemo()
    print("[Material Lua Demo] Loading library...")
    local ok, Material = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/Kinlei/MaterialLua/master/Module.lua"))()
    end)
    if not ok then
        print("[Material Lua Demo] Failed to load:", tostring(Material))
        return
    end
    print("[Material Lua Demo] Library loaded")

    buildUI(themes.Dark)
    print("[Material Lua Demo] UI loaded")
end

local ok, err = xpcall(runDemo, function(msg) return debug.traceback(tostring(msg), 2) end)
if not ok then
    print("[Material Lua Demo] ERROR:\n", tostring(err))
    warn("[Material Lua Demo] ERROR:\n", tostring(err))
end
