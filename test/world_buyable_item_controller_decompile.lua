--[[
    San Diego Agent — Probe: decompile WorldBuyableItemController
    ============================================================
    Декомпилирует WorldBuyableItemController и ищет логику размещения
    (Tool/Drop/Place/Activate/Raycast/Input).
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
    if writefile then pcall(function() writefile("world_buyable_item_controller_log.txt", text) end) end
end

log("========== WORLDBUYABLEITEMCONTROLLER ==========")

local module = ReplicatedStorage:FindFirstChild("ClientModules")
if module then module = module:FindFirstChild("WorldBuyableItemController") end
if not module then
    log("ERROR: WorldBuyableItemController not found")
    copy()
    return
end
log("Found:", module:GetFullName())

local ok, source = pcall(function()
    if decompile then return decompile(module) else return module.Source end
end)
if not ok or not source or #source == 0 then
    log("ERROR: Failed to decompile:", tostring(source))
    copy()
    return
end

log("Source length:", tostring(#source))
if writefile then pcall(function() writefile("WorldBuyableItemController_source.lua", source) end) end

local patterns = {
    "Tool", "tool",
    "Drop", "drop", "CanBeDropped",
    "Place", "place", "PLACE",
    "Equipped", "Unequipped", "Activated", "Activate",
    "Raycast", "raycast",
    "MouseButton1", "InputBegan", "InputEnded", "ContextActionService",
    "FireServer", "InvokeServer",
    "Money Printer", "MoneyPrinter", "money printer",
    "Handle", "PromptAttachment",
}

local shown = {}
for _, pattern in ipairs(patterns) do
    for pos in string.gmatch(source, "()" .. pattern) do
        if not shown[pattern] then
            shown[pattern] = true
            local start = math.max(1, pos - 400)
            local finish = math.min(#source, pos + 900)
            log("\n--- '" .. pattern .. "' at " .. tostring(pos) .. " ---")
            log(string.sub(source, start, finish))
        end
    end
end

log("\n========== END ==========")
copy()
