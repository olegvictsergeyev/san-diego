--[[
    San Diego Agent — Probe: decompile ApartmentController
    =======================================================
    Декомпилирует ApartmentController и ищет MoneyPrinter, Place,
    Activate, Tool, Remote, FireServer, Apartment, Region.
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
    if writefile then pcall(function() writefile("apartment_controller_decompile_log.txt", text) end) end
end

log("========== APARTMENT CONTROLLER DECOMPILE ==========")

local obj = ReplicatedStorage:FindFirstChild("ClientModules")
if obj then
    obj = obj:FindFirstChild("ApartmentController")
end

if not obj then
    log("ERROR: ApartmentController not found")
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
    pcall(function() writefile("ApartmentController_source.lua", source) end)
end

local patterns = {
    "MoneyPrinter", "money printer", "Money Printer",
    "Place", "place", "Deploy", "deploy", "Drop", "drop",
    "Activate", "activate", "Activated", "Deactivated",
    "Tool", "tool", "Backpack", "backpack",
    "MouseButton1", "InputBegan", "InputEnded",
    "UserInputService", "ContextActionService",
    "FireServer", "InvokeServer",
    "Remote", "RemoteEvent", "RemoteFunction",
    "MoneyPrinterService", "PickupMoneyPrinter", "Confiscate",
    "Apartment", "Region", "CFrame", "Position",
    "CanBeDropped", "Backspace",
}

local matches = {}
for _, pattern in ipairs(patterns) do
    for pos in string.gmatch(source, "()" .. pattern) do
        table.insert(matches, { pattern = pattern, pos = pos })
    end
end

log("Found", tostring(#matches), "keyword matches")

table.sort(matches, function(a, b) return a.pos < b.pos end)

local shownPatterns = {}
for _, match in ipairs(matches) do
    if not shownPatterns[match.pattern] then
        shownPatterns[match.pattern] = true
        local start = math.max(1, match.pos - 150)
        local finish = math.min(#source, match.pos + 300)
        log("\n--- Pattern '" .. match.pattern .. "' at pos " .. tostring(match.pos) .. " ---")
        log(string.sub(source, start, finish))
    end
end

log("\n========== END ==========")
copy()
