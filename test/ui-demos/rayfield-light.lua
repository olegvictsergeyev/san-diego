--[[
    Rayfield Light Theme Demo
    ==========================
    Запусти в Roblox-executor'е, чтобы посмотреть Rayfield в светлой теме.
]]

print("[Rayfield Light] Script started")

local ok, Rayfield = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)
if not ok then
    print("[Rayfield Light] Failed to load library:", tostring(Rayfield))
    return
end
print("[Rayfield Light] Library loaded")

local window = Rayfield:CreateWindow({
    Name = "Rayfield Light Theme",
    ConfigurationSaving = { Enabled = false },
    Discord = { Enabled = false },
    KeySystem = false,
    Theme = "Light"
})

local tabMain = window:CreateTab("Main", 4483362458)
local tabElements = window:CreateTab("Elements", 4483362458)

tabMain:CreateParagraph({
    Title = "Light Theme",
    Content = "Это Rayfield со встроенной светлой темой."
})

tabMain:CreateButton({
    Name = "Notify",
    Callback = function()
        Rayfield:Notify({ Title = "Light", Content = "Works!", Duration = 3, Image = 4483362458 })
    end
})

tabElements:CreateToggle({
    Name = "Toggle",
    CurrentValue = true,
    Callback = function(v) print("Toggle:", v) end
})

tabElements:CreateSlider({
    Name = "Slider",
    Range = {0, 100},
    Increment = 1,
    CurrentValue = 30,
    Callback = function(v) print("Slider:", v) end
})

tabElements:CreateDropdown({
    Name = "Dropdown",
    Options = {"A", "B", "C"},
    CurrentOption = "A",
    Callback = function(v) print("Dropdown:", v) end
})

tabElements:CreateInput({
    Name = "Input",
    PlaceholderText = "text",
    Callback = function(v) print("Input:", v) end
})

tabElements:CreateColorPicker({
    Name = "Color",
    Color = Color3.fromRGB(0, 120, 215),
    Callback = function(v) print("Color:", v) end
})

print("[Rayfield Light] Done")
