--[[
    San Diego Agent — Probe: decompile MoneyPrinterController
    =========================================================
    Декомпилирует ReplicatedStorage.ClientModules.MoneyPrinterController
    и сохраняет полный исходник в файл. Также ищет в нём функции
    размещения/установки принтера.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local logs = {}
local function log(...)
    local msg = "[" .. os.date("%H:%M:%S") .. "] " .. table.concat({ ... }, " ")
    table.insert(logs, msg)
    print(msg)
    warn(msg)
end

local function copy(text)
    if setclipboard then pcall(function() setclipboard(text) end) end
    if writefile then pcall(function() writefile("MoneyPrinterController_source.lua", text) end) end
end

log("========== MONEYPRINTERCONTROLLER DECOMPILE ==========")

local module = ReplicatedStorage:FindFirstChild("ClientModules", true)
if module then
    module = module:FindFirstChild("MoneyPrinterController")
end

if not module then
    log("ERROR: MoneyPrinterController not found")
    if copy then copy(table.concat(logs, "\n")) end
    return
end

log("Found module:", module:GetFullName(), "Class:", module.ClassName)

local ok, source = pcall(function()
    if decompile then
        return decompile(module)
    else
        return module.Source
    end
end)

if not ok or not source then
    log("ERROR: Failed to decompile:", tostring(source))
    if copy then copy(table.concat(logs, "\n")) end
    return
end

log("Decompiled length:", tostring(#source), "chars")
copy(source)

-- Search for key patterns
log("\n--- Key patterns in source ---")
local patterns = {
    "Place", "place", "Deploy", "deploy", "Drop", "drop",
    "Activate", "activate", "Mouse", "mouse", "Click", "click",
    "Remote", "remote", "FireServer", "InvokeServer",
    "MoneyPrinterService", "PickupMoneyPrinter", "Confiscate",
    "Apartment", "Region", "CFrame", "Position",
    "Tool", "tool", "Equip", "equip", "Unequip", "unequip",
    "CanBeDropped", "Backspace", "InputBegan", "UserInput",
    "Raycast", "raycast", "Prompt", "ProximityPrompt",
    "CollectionService", "GetTagged", "AddTag",
}

for _, pattern in ipairs(patterns) do
    local count = 0
    local positions = {}
    for pos in string.gmatch(source, "()" .. pattern) do
        count += 1
        if count <= 3 then
            table.insert(positions, pos)
        end
    end
    if count > 0 then
        log("Pattern '" .. pattern .. "' found", tostring(count), "times")
        for _, pos in ipairs(positions) do
            local start = math.max(1, pos - 50)
            local finish = math.min(#source, pos + 80)
            log("  context: ..." .. string.sub(source, start, finish) .. "...")
        end
    end
end

-- Save full source
log("\nFull source saved to MoneyPrinterController_source.lua and copied to clipboard")
log("First 1000 chars preview:")
log(string.sub(source, 1, 1000))

log("\n========== END ==========")
if copy then copy(table.concat(logs, "\n") .. "\n\n" .. source) end
