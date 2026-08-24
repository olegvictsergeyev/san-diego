--[[
    Mercury UI Demo
    =================
    Запусти в Roblox-executor'е, чтобы посмотреть визуал и возможности Mercury.
]]

local function runDemo()
    local Mercury = loadstring(game:HttpGet("https://raw.githubusercontent.com/deeeity/mercury-lib/master/src.lua"))()
    print("[Mercury Demo] Library loaded")

    local gui = Mercury:Create({
        Name = "Mercury Demo",
        Size = UDim2.fromOffset(600, 400),
        Theme = Mercury.Themes.Dark,
        Link = "https://github.com/deeeity/mercury-lib"
    })
    print("[Mercury Demo] Window created")

    local tabMain = gui:Tab({
        Name = "Main",
        Icon = "rbxassetid://8569322835"
    })
    print("[Mercury Demo] Main tab created")

    local tabElements = gui:Tab({
        Name = "Elements",
        Icon = "rbxassetid://4483362458"
    })
    print("[Mercury Demo] Elements tab created")

    local tabThemes = gui:Tab({
        Name = "Themes",
        Icon = "rbxassetid://8559790237"
    })
    print("[Mercury Demo] Themes tab created")

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

    tabElements:ColorPicker({
        Name = "Pick Color",
        Style = Mercury.ColorPickerStyles.Legacy,
        Callback = function(color)
            print("Color:", color)
        end
    })

    tabMain:Button({
        Name = "Show Prompt",
        Callback = function()
            gui:Prompt({
                Title = "Confirm",
                Text = "Are you sure you want to continue?",
                Followup = false,
                Buttons = {
                    yes = function()
                        print("Prompt: yes")
                        return true
                    end,
                    no = function()
                        print("Prompt: no")
                        return false
                    end
                }
            })
        end
    })

    -- Кастомные темы Light, Gold и Ping
    local lightTheme = {
        Main = Color3.fromRGB(245, 245, 250),
        Secondary = Color3.fromRGB(225, 225, 230),
        Tertiary = Color3.fromRGB(70, 130, 180),
        StrongText = Color3.fromRGB(40, 40, 45),
        WeakText = Color3.fromRGB(100, 100, 110),
        Light = true
    }

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

    Mercury.Themes.Light = lightTheme
    Mercury.Themes.Gold = goldTheme
    Mercury.Themes.Ping = pingTheme

    tabThemes:Dropdown({
        Name = "Select Theme",
        StartingText = "Dark",
        Items = {"Dark", "Light", "Gold", "Ping"},
        Callback = function(theme)
            if Mercury.Themes[theme] then
                local selected = Mercury.Themes[theme]
                -- Для светлой темы нужно поменять местами функции осветления/затемнения.
                if selected.Light then
                    Mercury.darken, Mercury.lighten = Mercury.lighten, Mercury.darken
                end
                Mercury:change_theme(selected)
            end
        end
    })

    print("[Mercury Demo] UI loaded")
end

local ok, err = pcall(runDemo)
if not ok then
    print("[Mercury Demo] ERROR:", tostring(err))
    warn("[Mercury Demo] ERROR:", tostring(err))
end
