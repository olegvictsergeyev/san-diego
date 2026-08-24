--[[
    Rayfield Simple Test
    ====================
    Минимальный пример для проверки, что Rayfield вообще отображается.
]]

print("[Rayfield Simple] Loading library...")
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
print("[Rayfield Simple] Library loaded")

local window = Rayfield:CreateWindow({
    Name = "Rayfield Simple Test",
    LoadingTitle = "Loading...",
    LoadingSubtitle = "test",
    ConfigurationSaving = {
        Enabled = false,
        FolderName = "RayfieldSimpleTest",
        FileName = "config"
    },
    Discord = { Enabled = false },
    KeySystem = false
})

print("[Rayfield Simple] Window created")

local tab = window:CreateTab("Main", 4483362458)
print("[Rayfield Simple] Tab created")

tab:CreateButton({
    Name = "Click Me",
    Callback = function()
        print("[Rayfield Simple] Button clicked")
    end
})
print("[Rayfield Simple] Button created")

Rayfield:Notify({
    Title = "Loaded",
    Content = "Rayfield simple test loaded",
    Duration = 3,
    Image = 4483362458
})

print("[Rayfield Simple] Done")
