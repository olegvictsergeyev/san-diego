--[[
    San Diego Agent — Probe: decompile BackpackController and search placement
    =========================================================================
    Декомпилирует BackpackController, ищет MoneyPrinter, Place, Drop, Raycast,
   PLACEMENT_FORWARD_DISTANCE, FireServer и выводит релевантные куски.
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
    if writefile then pcall(function() writefile("backpack_controller_placement_log.txt", text) end) end
end

log("========== BACKPACK CONTROLLER PLACEMENT SEARCH ==========")

local module = ReplicatedStorage:FindFirstChild("ClientModules")
if module then module = module:FindFirstChild("BackpackController") end
if not module then
    log("ERROR: BackpackController not found")
    copy()
    return
end
log("Found:", module:GetFullName(), "Class:", module.ClassName)

local ok, source = pcall(function()
    if decompile then return decompile(module) else return module.Source end
end)
if not ok or not source or #source == 0 then
    log("ERROR: Failed to decompile:", tostring(source))
    copy()
    return
end
log("Source length:", tostring(#source))
if writefile then pcall(function() writefile("BackpackController_full_source.lua", source) end) end

local patterns = {
    "MoneyPrinter", "money printer", "Money Printer",
    "Place", "place", "PLACE",
    "Drop", "drop", "CanBeDropped",
    "Raycast", "raycast",
    "PLACEMENT_FORWARD_DISTANCE", "PLACEMENT_RAYCAST_UP", "PLACEMENT_RAYCAST_DOWN",
    "FireServer", "InvokeServer", "RemoteEvent", "RemoteFunction",
    "Tool", "tool", "Activated",
    "PickupMoneyPrinter",
}

local foundSet = {}
local snippets = {}

for _, pattern in ipairs(patterns) do
    for pos in string.gmatch(source, "()" .. pattern) do
        if not foundSet[pattern] then
            foundSet[pattern] = true
            local start = math.max(1, pos - 300)
            local finish = math.min(#source, pos + 700)
            table.insert(snippets, {pattern = pattern, pos = pos, text = string.sub(source, start, finish)})
        end
    end
end

log("Patterns found:", tostring(#snippets))
for _, snippet in ipairs(snippets) do
    log("\n--- '" .. snippet.pattern .. "' at " .. tostring(snippet.pos) .. " ---")
    log(snippet.text)
end

log("\n========== END ==========")
copy()
