--[[
    San Diego Agent — Probe: decompile ClientScripts.Main
    ====================================================
    Декомпилирует ReplicatedStorage.ClientScripts.Main и ищет в нём
    MoneyPrinter, Place, Activate, Tool, Remote, FireServer и т.д.
    Это самый крупный клиентский скрипт, и в нём, судя по всему,
    находится логика установки принтера.
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
    if writefile then pcall(function() writefile("client_main_decompile_log.txt", text) end) end
end

log("========== DECOMPILE ClientScripts.Main ==========")

local clientScripts = ReplicatedStorage:FindFirstChild("ClientScripts")
if not clientScripts then
    log("ERROR: ReplicatedStorage.ClientScripts not found")
    copy()
    return
end

local main = clientScripts:FindFirstChild("Main")
if not main then
    log("ERROR: ReplicatedStorage.ClientScripts.Main not found")
    copy()
    return
end

log("Found:", main:GetFullName(), "Class:", main.ClassName)

local ok, source = pcall(function()
    if decompile then
        return decompile(main)
    else
        return main.Source
    end
end)

if not ok or not source then
    log("ERROR: Failed to decompile:", tostring(source))
    copy()
    return
end

log("Decompiled length:", tostring(#source), "chars")
if writefile then
    pcall(function() writefile("ClientScripts_Main_source.lua", source) end)
end

local patterns = {
    "MoneyPrinter", "money printer", "Money Printer",
    "Place", "place", "Deploy", "deploy", "Drop", "drop",
    "Activate", "activate", "Activated", "Deactivated",
    "Tool", "tool", "Backpack", "backpack",
    "MouseButton1", "MouseButton2", "InputBegan", "InputEnded",
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

-- Sort and show context for each unique pattern
 table.sort(matches, function(a, b) return a.pos < b.pos end)

local shownPatterns = {}
local outputCount = 0
for _, match in ipairs(matches) do
    if not shownPatterns[match.pattern] then
        shownPatterns[match.pattern] = true
        outputCount += 1
        if outputCount > 50 then
            log("... stopping after 50 unique patterns")
            break
        end
        local start = math.max(1, match.pos - 150)
        local finish = math.min(#source, match.pos + 300)
        log("\n--- Pattern '" .. match.pattern .. "' at pos " .. tostring(match.pos) .. " ---")
        log(string.sub(source, start, finish))
    end
end

log("\nFull source saved to ClientScripts_Main_source.lua")
log("========== END ==========")
copy()
