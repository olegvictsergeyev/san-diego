--[[
    San Diego Agent — Probe: extract Function9 from BackpackController
    ================================================================
    Извлекает функцию обработки Tool (Function9) из BackpackController,
    а также любые функции с Activated/Unequipped/Equipped.
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
    if writefile then pcall(function() writefile("backpack_controller_function9_log.txt", text) end) end
end

log("========== BACKPACK CONTROLLER FUNCTION9 EXTRACT ==========")

local obj = ReplicatedStorage:FindFirstChild("ClientModules")
if obj then
    obj = obj:FindFirstChild("BackpackController")
end

if not obj then
    log("ERROR: BackpackController not found")
    copy()
    return
end

local ok, source = pcall(function()
    if decompile then
        return decompile(obj)
    else
        return obj.Source
    end
end)

if not ok or not source then
    log("ERROR: Failed to decompile")
    copy()
    return
end

log("Source length:", tostring(#source))

-- Find the section around "function Function9"
local pos = string.find(source, "function Function9")
if pos then
    local start = math.max(1, pos - 200)
    local finish = math.min(#source, pos + 4000)
    log("\n--- Function9 section (first 4000 chars) ---")
    log(string.sub(source, start, finish))
else
    log("Function9 not found, searching for Tool handling...")
    local patterns = {
        "Activated:Connect",
        "Equipped:Connect",
        "Unequipped:Connect",
        "Tool",
        "ClientInit",
    }
    for _, pattern in ipairs(patterns) do
        local p = string.find(source, pattern)
        if p then
            local start = math.max(1, p - 100)
            local finish = math.min(#source, p + 300)
            log("\nPattern '" .. pattern .. "' at", tostring(p), ":")
            log(string.sub(source, start, finish))
        end
    end
end

-- Also search for MoneyPrinterConfig usage
local pos2 = string.find(source, "MoneyPrinterConfig")
if pos2 then
    local start = math.max(1, pos2 - 200)
    local finish = math.min(#source, pos2 + 1000)
    log("\n--- MoneyPrinterConfig usage ---")
    log(string.sub(source, start, finish))
end

log("\n========== END ==========")
copy()
