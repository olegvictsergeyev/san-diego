--[[
    Rayfield Theme Test
    ===================
    Тестируем создание окна с разными темами.
]]

print("[Rayfield Theme Test] Script started")

local ok, Rayfield = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)
if not ok then
    print("[Rayfield Theme Test] Library load failed:", tostring(Rayfield))
    return
end
print("[Rayfield Theme Test] Library loaded")

local function testTheme(themeName, themeValue)
    print("[Rayfield Theme Test] Testing theme:", themeName)
    local buildOk, buildErr = pcall(function()
        local window = Rayfield:CreateWindow({
            Name = "Theme: " .. tostring(themeName),
            ConfigurationSaving = { Enabled = false },
            Discord = { Enabled = false },
            KeySystem = false,
            Theme = themeValue
        })
        print("[Rayfield Theme Test] Theme", themeName, "OK")
    end)
    if not buildOk then
        print("[Rayfield Theme Test] Theme", themeName, "FAILED:", tostring(buildErr))
    end
end

-- Тесты
testTheme("None (default)", nil)
testTheme("Default", "Default")
testTheme("Light", "Light")

print("[Rayfield Theme Test] Done")
