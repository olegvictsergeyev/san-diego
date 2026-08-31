--[[
    San Diego Agent — Probe: find and decompile MoneyPrinter tool behavior module
    ==========================================================================
    BackpackController использует модули из ClientModules.Tools для поведения
    каждого Tool'а. Этот скрипт находит модуль для Money Printer и декомпилирует его.
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
    if not text then text = table.concat(logs, "\n") end
    if setclipboard then pcall(function() setclipboard(text) end) end
    if writefile then pcall(function() writefile("moneyprinter_tool_module_log.txt", text) end) end
end

log("========== MONEYPRINTER TOOL MODULE PROBE ==========")

local toolsFolder = ReplicatedStorage:FindFirstChild("ClientModules")
if toolsFolder then
    toolsFolder = toolsFolder:FindFirstChild("Tools")
end

if not toolsFolder then
    log("ERROR: ClientModules.Tools not found")
    copy()
    return
end

log("Tools folder:", toolsFolder:GetFullName())
log("\nChildren:")
local candidates = {}
for _, c in ipairs(toolsFolder:GetChildren()) do
    log("  ", c.Name, "Class:", c.ClassName)
    if c.Name:lower():find("print") or c.Name:lower():find("money") then
        table.insert(candidates, c)
    end
end

-- Also scan subfolders
local function scan(parent, depth)
    if depth > 3 then return end
    for _, c in ipairs(parent:GetChildren()) do
        if c.Name:lower():find("print") or c.Name:lower():find("money") then
            log("  found candidate at depth", tostring(depth), ":", c:GetFullName())
            table.insert(candidates, c)
        end
        scan(c, depth + 1)
    end
end
scan(toolsFolder, 1)

if #candidates == 0 then
    log("\nNo MoneyPrinter-specific module found. Will decompile all tool modules.")
    for _, c in ipairs(toolsFolder:GetChildren()) do
        if c:IsA("ModuleScript") then
            table.insert(candidates, c)
        end
    end
end

for _, candidate in ipairs(candidates) do
    log("\n--- Decompiling", candidate:GetFullName(), "---")
    local ok, source = pcall(function()
        if decompile then
            return decompile(candidate)
        else
            return candidate.Source
        end
    end)
    if not ok or not source then
        log("  failed:", tostring(source))
    else
        log("  length:", tostring(#source))
        if writefile then
            pcall(function() writefile(candidate.Name .. "_source.lua", source) end)
        end

        -- Search for placement patterns
        local patterns = {
            "Place", "place", "Deploy", "deploy", "Drop", "drop",
            "Activate", "activate", "Activated", "InputBegan",
            "Mouse", "mouse", "Click", "click",
            "FireServer", "InvokeServer", "Remote",
            "MoneyPrinter", "MoneyPrinterService",
            "Apartment", "Region", "CFrame", "Position",
            "CanBeDropped", "Backspace",
        }

        local foundAny = false
        for _, pattern in ipairs(patterns) do
            local pos = string.find(source, pattern)
            if pos then
                foundAny = true
                local start = math.max(1, pos - 100)
                local finish = math.min(#source, pos + 200)
                log("\n  Pattern '" .. pattern .. "' context:")
                log("  ..." .. string.sub(source, start, finish) .. "...")
            end
        end

        if not foundAny then
            log("  no relevant patterns found")
        end

        -- If this is the MoneyPrinter module, show full source preview
        if candidate.Name:lower():find("print") then
            log("\n  --- FULL SOURCE PREVIEW (first 2000 chars) ---")
            log(string.sub(source, 1, 2000))
            copy(source)
        end
    end
end

log("\n========== END ==========")
copy()
