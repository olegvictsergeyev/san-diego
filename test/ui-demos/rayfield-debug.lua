--[[
    Rayfield Debug Test
    ===================
    Пошаговое добавление элементов Rayfield с pcall, чтобы найти ломающий элемент.
]]

print("[Rayfield Debug] Loading library...")
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
print("[Rayfield Debug] Library loaded")

local function add(name, fn)
    local ok, err = pcall(fn)
    if ok then
        print("[Rayfield Debug] OK:", name)
    else
        print("[Rayfield Debug] FAIL:", name, "->", tostring(err))
    end
end

local window = Rayfield:CreateWindow({
    Name = "Rayfield Debug",
    LoadingTitle = "Loading...",
    LoadingSubtitle = "debug",
    ConfigurationSaving = { Enabled = false },
    Discord = { Enabled = false },
    KeySystem = false
})

add("CreateWindow", function() return window end)

local tabMain = window:CreateTab("Main", 4483362458)
add("CreateTab Main", function() return tabMain end)

add("CreateParagraph", function()
    tabMain:CreateParagraph({
        Title = "Rayfield Debug",
        Content = "This is a debug test."
    })
end)

add("CreateButton", function()
    tabMain:CreateButton({
        Name = "Notify",
        Callback = function()
            Rayfield:Notify({ Title = "Test", Content = "Works", Duration = 3 })
        end
    })
end)

local tabElements = window:CreateTab("Elements", 4483362458)
add("CreateTab Elements", function() return tabElements end)

add("CreateToggle", function()
    tabElements:CreateToggle({
        Name = "Toggle",
        CurrentValue = false,
        Callback = function(v) print("Toggle:", v) end
    })
end)

add("CreateSlider", function()
    tabElements:CreateSlider({
        Name = "Slider",
        Range = {0, 100},
        Increment = 1,
        Suffix = "",
        CurrentValue = 50,
        Callback = function(v) print("Slider:", v) end
    })
end)

add("CreateDropdown", function()
    tabElements:CreateDropdown({
        Name = "Dropdown",
        Options = {"A", "B", "C"},
        CurrentOption = "A",
        Callback = function(v) print("Dropdown:", v) end
    })
end)

add("CreateInput", function()
    tabElements:CreateInput({
        Name = "Input",
        PlaceholderText = "text...",
        RemoveTextAfterFocusLost = false,
        Callback = function(v) print("Input:", v) end
    })
end)

add("CreateKeybind", function()
    tabElements:CreateKeybind({
        Name = "Keybind",
        CurrentKeybind = "Q",
        HoldToInteract = false,
        Callback = function(k) print("Keybind:", k) end
    })
end)

add("CreateColorPicker", function()
    tabElements:CreateColorPicker({
        Name = "Color",
        Color = Color3.fromRGB(255, 0, 0),
        Callback = function(v) print("Color:", v) end
    })
end)

add("CreateLabel", function()
    tabElements:CreateLabel("This is a label")
end)

local tabThemes = window:CreateTab("Themes", 4483362458)
add("CreateTab Themes", function() return tabThemes end)

add("ChangeTheme Default", function()
    Rayfield:ChangeTheme("Default")
end)

add("ChangeTheme Light", function()
    Rayfield:ChangeTheme("Light")
end)

add("ChangeTheme Custom Gold", function()
    Rayfield:ChangeTheme({
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
    })
end)

print("[Rayfield Debug] Done")
