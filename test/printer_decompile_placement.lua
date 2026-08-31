--[[
    San Diego Agent — Probe: decompile placement-related controllers
    =================================================================
    Декомпилирует WorldBuyableItemController и BackpackController,
    ищет функции Place/Drop/Deploy/Activate для Money Printer.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local logs = {}
local function log(...)
    local msg = "[" .. os.date("%H:%M:%S") .. "] " .. table.concat({ ... }, " ")
    table.insert(logs, msg)
    print(msg)
    warn(msg)
end

local function save(name, text)
    if writefile then
        pcall(function() writefile(name .. "_source.lua", text) end)
    end
end

local function decompileModule(path)
    local obj = ReplicatedStorage
    for _, part in ipairs(path) do
        obj = obj:FindFirstChild(part)
        if not obj then return nil end
    end
    local ok, source = pcall(function()
        if decompile then
            return decompile(obj)
        else
            return obj.Source
        end
    end)
    if ok and source then
        return source
    end
    return nil
end

local function findPattern(source, patterns)
    local results = {}
    for _, pattern in ipairs(patterns) do
        for pos in string.gmatch(source, "()" .. pattern) do
            table.insert(results, { pattern = pattern, pos = pos })
        end
    end
    return results
end

log("========== PRINTER PLACEMENT DECOMPILE ==========")

local modules = {
    { name = "WorldBuyableItemController", path = {"ClientModules", "WorldBuyableItemController"} },
    { name = "BackpackController", path = {"ClientModules", "BackpackController"} },
    { name = "MoneyPrinterBoosterController", path = {"ClientModules", "MoneyPrinterBoosterController"} },
    { name = "ToolInfo", path = {"SharedModules", "ToolInfo"} },
}

local placementKeywords = {
    "Place", "place", "Deploy", "deploy", "Drop", "drop",
    "Activate", "activate", "Activated", "activated",
    "MouseButton1Down", "MouseButton1Click", "InputBegan", "Began", "UserInput",
    "MoneyPrinter", "money printer", "Money Printer",
    "WorldBuyableItem", "BuyableItem",
    "Raycast", "raycast", "Mouse", "mouse", "Camera",
    "FireServer", "InvokeServer", "Remote",
    "CanBeDropped", "Backspace", "DropTool", "Drop",
}

for _, moduleInfo in ipairs(modules) do
    log("\n--- Decompiling", moduleInfo.name, "---")
    local source = decompileModule(moduleInfo.path)
    if not source then
        log("ERROR: Could not decompile", moduleInfo.name)
    else
        log("Decompiled length:", tostring(#source))
        save(moduleInfo.name, source)

        local matches = findPattern(source, placementKeywords)
        log("Found", tostring(#matches), "keyword matches")

        local shown = {}
        for _, match in ipairs(matches) do
            local key = match.pattern
            if not shown[key] then
                shown[key] = true
                local start = math.max(1, match.pos - 80)
                local finish = math.min(#source, match.pos + 120)
                log("\n  Pattern '" .. key .. "' context:")
                log("  ..." .. string.sub(source, start, finish) .. "...")
            end
        end
    end
end

log("\n--- Also trying require + dump ---")
for _, moduleInfo in ipairs(modules) do
    local ok, mod = pcall(function()
        local obj = ReplicatedStorage
        for _, part in ipairs(moduleInfo.path) do
            obj = obj:WaitForChild(part, 2)
        end
        return require(obj)
    end)
    if ok and mod then
        log("\nModule", moduleInfo.name, "returned type:", typeof(mod))
        if typeof(mod) == "table" then
            log("  keys:")
            for k, v in pairs(mod) do
                log("    ", tostring(k), "->", typeof(v))
            end
        end
    else
        log("  require failed:", tostring(mod))
    end
end

log("\n========== END ==========")
if writefile then
    pcall(function() writefile("printer_placement_decompile_log.txt", table.concat(logs, "\n")) end)
end
if setclipboard then
    pcall(function() setclipboard(table.concat(logs, "\n")) end)
end
