--[[
    Rayfield UI Demo
    ================
    Запусти в Roblox-executor'е, чтобы посмотреть визуал и возможности Rayfield.
    Внимание: Rayfield не поддерживает смену темы на лету. Тема задаётся при создании окна.
]]

print("[Rayfield Demo] Script started")

local ok, err = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)
if not ok then
    print("[Rayfield Demo] Failed to load library:", tostring(err))
    return
end
local Rayfield = err
print("[Rayfield Demo] Library loaded")

local Players = game:GetService("Players")

local themes = {
    Dark = "Default",
    Light = "Light",
    Gold = {
        TextColor = Color3.fromRGB(255, 245, 220),
        Background = Color3.fromRGB(45, 35, 15),
        Topbar = Color3.fromRGB(60, 48, 22),
        Shadow = Color3.fromRGB(30, 24, 10),
        NotificationBackground = Color3.fromRGB(55, 44, 20),
        NotificationActionsBackground = Color3.fromRGB(230, 200, 120),
        TabBackground = Color3.fromRGB(90, 72, 30),
        TabStroke = Color3.fromRGB(110, 88, 40),
        TabBackgroundSelected = Color3.fromRGB(255, 200, 80),
        TabTextColor = Color3.fromRGB(255, 235, 180),
        SelectedTabTextColor = Color3.fromRGB(50, 40, 10),
        ElementBackground = Color3.fromRGB(65, 52, 24),
        ElementBackgroundHover = Color3.fromRGB(80, 65, 30),
        SecondaryElementBackground = Color3.fromRGB(55, 44, 20),
        ElementStroke = Color3.fromRGB(100, 80, 36),
        SecondaryElementStroke = Color3.fromRGB(85, 68, 30),
        SliderBackground = Color3.fromRGB(220, 170, 50),
        SliderProgress = Color3.fromRGB(255, 200, 70),
        SliderStroke = Color3.fromRGB(255, 215, 100),
        ToggleBackground = Color3.fromRGB(55, 44, 20),
        ToggleEnabled = Color3.fromRGB(255, 190, 40),
        ToggleDisabled = Color3.fromRGB(120, 100, 60),
        ToggleEnabledStroke = Color3.fromRGB(255, 210, 80),
        ToggleDisabledStroke = Color3.fromRGB(140, 120, 70),
        ToggleEnabledOuterStroke = Color3.fromRGB(180, 140, 50),
        ToggleDisabledOuterStroke = Color3.fromRGB(90, 75, 40),
        DropdownSelected = Color3.fromRGB(80, 65, 30),
        DropdownUnselected = Color3.fromRGB(55, 44, 20),
        InputBackground = Color3.fromRGB(55, 44, 20),
        InputStroke = Color3.fromRGB(100, 80, 36),
        PlaceholderColor = Color3.fromRGB(190, 170, 130)
    },
    Ping = {
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
}

local function destroyOldUI()
    print("[Rayfield Demo] Destroying old UI...")
    local coreGui = game:GetService("CoreGui")
    for _, child in ipairs(coreGui:GetChildren()) do
        if child.Name == "Rayfield" or child.Name == "Rayfield-Old" then
            child:Destroy()
        end
    end
    if gethui then
        for _, child in ipairs(gethui():GetChildren()) do
            if child.Name == "Rayfield" or child.Name == "Rayfield-Old" then
                child:Destroy()
            end
        end
    end
end

local function buildUI(themeName)
    print("[Rayfield Demo] Building UI with theme:", themeName)
    destroyOldUI()

    local selectedTheme = themes[themeName] or themes.Dark
    local window = Rayfield:CreateWindow({
        Name = "Rayfield Demo [" .. tostring(themeName) .. "]",
        LoadingTitle = "Загрузка интерфейса...",
        LoadingSubtitle = "by San Diego Agent",
        ConfigurationSaving = {
            Enabled = true,
            FolderName = "RayfieldDemo",
            FileName = "DemoConfig"
        },
        Discord = { Enabled = false },
        KeySystem = false,
        Theme = selectedTheme
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
    tabThemes:CreateLabel("Выберите тему и нажмите Apply Theme.")

    local selectedTheme = themeName
    tabThemes:CreateDropdown({
        Name = "Select Theme",
        Options = {"Dark", "Light", "Gold", "Ping"},
        CurrentOption = themeName,
        Callback = function(option)
            selectedTheme = typeof(option) == "table" and option[1] or tostring(option)
            print("[Rayfield Demo] Selected theme:", selectedTheme)
        end
    })

    tabThemes:CreateButton({
        Name = "Apply Theme",
        Callback = function()
            print("[Rayfield Demo] Applying theme:", selectedTheme)
            buildUI(selectedTheme)
        end
    })

    print("[Rayfield Demo] UI built successfully")
end

local buildOk, buildErr = pcall(function()
    buildUI("Dark")
end)

if not buildOk then
    print("[Rayfield Demo] Build UI failed:", tostring(buildErr))
else
    print("[Rayfield Demo] Done")
end
