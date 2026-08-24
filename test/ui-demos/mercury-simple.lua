--[[
    Mercury Simple Test
    ===================
    Минимальный пример для проверки Mercury.
]]

print("[Mercury Simple] Loading library...")
local ok, Mercury = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/deeeity/mercury-lib/master/src.lua"))()
end)
if not ok then
    print("[Mercury Simple] Failed to load:", tostring(Mercury))
    return
end
print("[Mercury Simple] Library loaded:", tostring(Mercury))

local ok2, gui = pcall(function()
    return Mercury:Create({
        Name = "Mercury Simple",
        Size = UDim2.fromOffset(500, 300),
        Theme = Mercury.Themes.Dark
    })
end)
if not ok2 then
    print("[Mercury Simple] Create failed:", tostring(gui))
    return
end
print("[Mercury Simple] GUI created:", tostring(gui))

local ok3, tab = pcall(function()
    return gui:Tab({
        Name = "Main",
        Icon = "rbxassetid://4483362458"
    })
end)
if not ok3 then
    print("[Mercury Simple] Tab failed:", tostring(tab))
    return
end
print("[Mercury Simple] Tab created:", tostring(tab))

local ok4 = pcall(function()
    tab:Button({
        Name = "Click Me",
        Callback = function()
            print("[Mercury Simple] Button clicked")
        end
    })
end)
print("[Mercury Simple] Button added:", ok4)

print("[Mercury Simple] Done")
