--[[
    San Diego Agent — Probe: decompile ClientScripts.Main
    =====================================================
    Декомпилирует ReplicatedStorage.ClientScripts.Main и ищет
    MoneyPrinter, Tool, Drop, Place, Activated, Equipped, Unequipped, FireServer.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local logs = {}
local function log(...)
    local msg = "[" .. os.date("%H:%M:%S") .. "] " .. table.concat({ ... }, " ")
    table.insert(logs, msg)
    print(msg)
    warn(msg)
end

local function copy()
    local text = table.concat(logs, "\n")
    if setclipboard then pcall(function() setclipboard(text) end) end
    if writefile then pcall(function() writefile("clientscripts_main_log.txt", text) end) end
end

log("========== DECOMPILE ClientScripts.Main ==========")

local main = ReplicatedStorage:FindFirstChild("ClientScripts")
if main then main = main:FindFirstChild("Main") end
if not main then
    log("ERROR: ClientScripts.Main not found")
    copy()
    return
end
log("Found:", main:GetFullName(), "Class:", main.ClassName)

-- Try to get source size without full decompile first
local ok, source = pcall(function()
    if decompile then return decompile(main) else return main.Source end
end)
if not ok or not source or #source == 0 then
    log("ERROR: Failed to decompile:", tostring(source))
    copy()
    return
end

log("Source length:", tostring(#source))
if writefile then pcall(function() writefile("ClientScripts_Main_source.lua", source) end) end

local patterns = {
    "MoneyPrinter", "Money Printer", "money printer",
    "Tool", "tool",
    "Drop", "drop", "CanBeDropped",
    "Place", "place", "PLACE",
    "Equipped", "Unequipped", "Activated", "Activate",
    "MouseButton1", "InputBegan", "InputEnded",
    "ContextActionService", "UserInputService",
    "FireServer", "InvokeServer",
    "RemoteEvent", "RemoteFunction",
    "Backpack", "backpack",
    "Raycast", "raycast",
}

local shown = {}
for _, pattern in ipairs(patterns) do
    for pos in string.gmatch(source, "()" .. pattern) do
        if not shown[pattern] then
            shown[pattern] = true
            local start = math.max(1, pos - 500)
            local finish = math.min(#source, pos + 1000)
            log("\n--- '" .. pattern .. "' at " .. tostring(pos) .. " ---")
            log(string.sub(source, start, finish))
        end
    end
end

log("\n========== END ==========")
copy()
