--[[
    San Diego Agent — Probe: inspect MoneyPrinterConfig consumers
    ============================================================
    Находит все загруженные модули, которые require'ят MoneyPrinterConfig,
    и ищет в них Tool/Drop/Place/Equipped/Activated/Raycast/FireServer.
]]

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
    if writefile then pcall(function() writefile("moneyprinter_config_consumers_log.txt", text) end) end
end

log("========== MONEYPRINTERCONFIG CONSUMERS ==========")

local getloadedmodules = getloadedmodules
if not getloadedmodules then
    log("ERROR: getloadedmodules unavailable")
    copy()
    return
end

local modules = getloadedmodules()
log("Loaded modules:", tostring(#modules))

local function formatPath(module)
    local ok, fullName = pcall(function() return module:GetFullName() end)
    if ok then return fullName end
    local ok2, name = pcall(function() return module.Name end)
    return ok2 and name or "unknown"
end

local consumers = {}
for _, module in ipairs(modules) do
    if typeof(module) == "Instance" and module:IsA("ModuleScript") then
        local ok, source = pcall(function()
            if decompile then return decompile(module) else return module.Source end
        end)
        if ok and source and #source > 0 then
            if source:find("MoneyPrinterConfig") or source:find("PLACEMENT_") then
                table.insert(consumers, {module = module, path = formatPath(module), source = source})
            end
        end
    end
end

log("Consumers found:", tostring(#consumers))

local keywords = {
    "Tool", "tool",
    "Drop", "drop", "CanBeDropped",
    "Place", "place", "PLACE",
    "Equipped", "Unequipped", "Activated", "Activate",
    "Raycast", "raycast",
    "FireServer", "InvokeServer",
    "MouseButton1", "InputBegan", "ContextActionService",
    "Backpack", "backpack",
    "Handle", "Printer_d",
}

for _, data in ipairs(consumers) do
    log("\n==============================")
    log("MODULE:", data.path)
    log("Size:", tostring(#data.source))
    
    local foundAny = false
    for _, keyword in ipairs(keywords) do
        local pos = data.source:find(keyword)
        if pos then
            foundAny = true
            local start = math.max(1, pos - 300)
            local finish = math.min(#data.source, pos + 600)
            log("\n--- '" .. keyword .. "' ---")
            log(string.sub(data.source, start, finish))
        end
    end
    
    if not foundAny then
        log("  No relevant keywords found")
    end
    
    if writefile then
        local safeName = data.path:gsub("[^%w%._-]", "_")
        pcall(function() writefile("mpc_consumer_" .. safeName .. ".lua", data.source) end)
    end
end

log("\n========== END ==========")
copy()
