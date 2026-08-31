--[[
    San Diego Agent — Probe: focused BackpackController decompile
    =============================================================
    Декомпилирует только BackpackController, ищет в нём MoneyPrinter,
    Place, Activate, Drop, Tool, Input и выводит все найденные
    фрагменты с контекстом.
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
    if writefile then pcall(function() writefile("backpack_controller_focused_log.txt", text) end) end
end

log("========== BACKPACK CONTROLLER FOCUSED DECOMPILE ==========")

local obj = ReplicatedStorage:FindFirstChild("ClientModules")
if obj then
    obj = obj:FindFirstChild("BackpackController")
end

if not obj then
    log("ERROR: BackpackController not found")
    copy()
    return
end

log("Found:", obj:GetFullName(), "Class:", obj.ClassName)

local ok, source = pcall(function()
    if decompile then
        return decompile(obj)
    else
        return obj.Source
    end
end)

if not ok or not source then
    log("ERROR: Failed to decompile:", tostring(source))
    copy()
    return
end

log("Decompiled length:", tostring(#source))
if writefile then
    pcall(function() writefile("BackpackController_source.lua", source) end)
end

-- Find all relevant patterns and show context
local patterns = {
    "MoneyPrinter", "money printer", "Money Printer",
    "Place", "place", "Deploy", "deploy",
    "Drop", "drop", "CanBeDropped",
    "Activate", "activate", "Activated",
    "Tool", "tool", "Backpack", "backpack",
    "InputBegan", "InputEnded", "MouseButton1", "MouseButton2",
    "UserInputService", "ContextActionService",
    "FireServer", "InvokeServer",
    "Remote", "RemoteEvent", "RemoteFunction",
    "Raycast", "raycast",
    "World", "world",
}

local matches = {}
for _, pattern in ipairs(patterns) do
    for pos in string.gmatch(source, "()" .. pattern) do
        table.insert(matches, { pattern = pattern, pos = pos })
    end
end

log("Found", tostring(#matches), "keyword matches")

-- Sort by position
 table.sort(matches, function(a, b) return a.pos < b.pos end)

local shownPatterns = {}
local lastShownPos = -math.huge
for _, match in ipairs(matches) do
    if not shownPatterns[match.pattern] then
        shownPatterns[match.pattern] = true
        local start = math.max(1, match.pos - 150)
        local finish = math.min(#source, match.pos + 250)
        log("\n--- Pattern '" .. match.pattern .. "' at pos " .. tostring(match.pos) .. " ---")
        log(string.sub(source, start, finish))
    end
end

-- Also try require the module and dump its API
log("\n--- Trying require BackpackController ---")
local ok2, mod = pcall(function() return require(obj) end)
if ok2 and mod then
    log("Module type:", typeof(mod))
    if typeof(mod) == "table" then
        log("Public keys:")
        for k, v in pairs(mod) do
            log("  ", tostring(k), "=", typeof(v))
        end
    end
else
    log("require failed:", tostring(mod))
end

log("\n========== END ==========")
copy()
