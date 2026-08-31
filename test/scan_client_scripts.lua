--[[
    San Diego Agent — Probe: scan all ClientScripts for MoneyPrinter placement
    =========================================================================
    ReplicatedStorage.ClientScripts.Main только загружает модули.
    Этот скрипт декомпилирует все дочерние скрипты ClientScripts
    и ищет MoneyPrinter/Place/Activate/FireServer.
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
    if writefile then pcall(function() writefile("client_scripts_scan_log.txt", text) end) end
end

log("========== SCAN ALL CLIENT SCRIPTS ==========")

local clientScripts = ReplicatedStorage:FindFirstChild("ClientScripts")
if not clientScripts then
    log("ERROR: ClientScripts not found")
    copy()
    return
end

log("Scanning:", clientScripts:GetFullName())

local patterns = {
    "MoneyPrinter", "money printer", "Money Printer",
    "Place", "place", "Deploy", "deploy", "Drop", "drop",
    "Activate", "activate", "Activated",
    "FireServer", "InvokeServer",
    "RemoteEvent", "RemoteFunction",
    "MoneyPrinterService", "PickupMoneyPrinter",
    "Apartment", "Region", "CFrame", "Position",
    "Tool", "Handle", "Printer_d",
}

local function scanScript(scriptObj, depth)
    if depth > 3 then return end
    for _, child in ipairs(scriptObj:GetChildren()) do
        if child:IsA("LocalScript") or child:IsA("Script") or child:IsA("ModuleScript") then
            log("\n--- Found script:", child:GetFullName(), "Class:", child.ClassName, "---")
            local ok, source = pcall(function()
                if decompile then
                    return decompile(child)
                else
                    return child.Source
                end
            end)
            if ok and source then
                log("  length:", tostring(#source))
                if writefile then
                    pcall(function() writefile(child.Name .. "_source.lua", source) end)
                end

                local foundAny = false
                for _, pattern in ipairs(patterns) do
                    local pos = string.find(source, pattern)
                    if pos then
                        foundAny = true
                        local start = math.max(1, pos - 100)
                        local finish = math.min(#source, pos + 250)
                        log("\n  Pattern '" .. pattern .. "' context:")
                        log("  ..." .. string.sub(source, start, finish) .. "...")
                    end
                end

                if not foundAny then
                    log("  no relevant patterns")
                end
            else
                log("  failed to decompile:", tostring(source))
            end

            -- Recurse
            scanScript(child, depth + 1)
        elseif not child:IsA("BasePart") then
            scanScript(child, depth + 1)
        end
    end
end

scanScript(clientScripts, 0)

log("\n========== END ==========")
copy()
