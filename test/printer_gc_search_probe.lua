--[[
    San Diego Agent — Probe: search GC and modules for MoneyPrinter placement
    =========================================================================
    Ищет функции и модули, связанные с установкой/созданием MoneyPrinter,
    через getgc, getloadedmodules и сканирование ReplicatedStorage/PlayerScripts.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
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
    if writefile then pcall(function() writefile("printer_gc_search_probe_log.txt", text) end) end
end

local keywords = {
    "MoneyPrinterId", "MoneyPrinterApartmentId", "MoneyPrinterApartmentRegionCFrame",
    "MoneyPrinterApartmentRegionSize", "MoneyPrinterToolName", "MoneyPrinterOwnerUserId",
    "PlaceMoneyPrinter", "PlacePrinter", "DeployPrinter", "DeployMoneyPrinter",
    "MoneyPrinterService", "PickupMoneyPrinter", "money printer", "MoneyPrinter"
}

local function safeString(obj)
    local ok, s = pcall(function() return tostring(obj) end)
    return ok and s or "???"
end

log("========== PRINTER GC SEARCH PROBE ==========")
log("Player:", player.Name)

-- 1. Search loaded modules via getloadedmodules
if getloadedmodules then
    log("\n--- getloadedmodules search ---")
    local ok, modules = pcall(function() return getloadedmodules() end)
    if ok and modules then
        for _, m in ipairs(modules) do
            local ok2, source = pcall(function()
                if decompile then
                    return decompile(m)
                else
                    return m.Source
                end
            end)
            if ok2 and source then
                local lower = source:lower()
                for _, kw in ipairs(keywords) do
                    if lower:find(kw:lower()) then
                        log("Module:", m.Name, "Class:", m.ClassName, "keyword:", kw)
                        log("  source first 400 chars:\n", string.sub(source, 1, 400))
                        break
                    end
                end
            end
        end
    else
        log("getloadedmodules failed:", tostring(modules))
    end
else
    log("getloadedmodules not available")
end

-- 2. Search scripts in PlayerScripts and ReplicatedStorage
log("\n--- Script source search ---")
local function scanScripts(parent, depth)
    if depth > 5 then return end
    for _, c in ipairs(parent:GetChildren()) do
        if c:IsA("LocalScript") or c:IsA("Script") or c:IsA("ModuleScript") then
            local ok, source = pcall(function()
                if decompile then
                    return decompile(c)
                else
                    return c.Source
                end
            end)
            if ok and source then
                local lower = source:lower()
                for _, kw in ipairs(keywords) do
                    if lower:find(kw:lower()) then
                        log("Script:", c:GetFullName(), "keyword:", kw)
                        log("  source first 500 chars:\n", string.sub(source, 1, 500))
                        break
                    end
                end
            end
        end
        scanScripts(c, depth + 1)
    end
end
scanScripts(player.PlayerScripts, 0)
scanScripts(ReplicatedStorage, 0)

-- 3. Search GC for functions/closures with MoneyPrinter strings
if getgc then
    log("\n--- getgc function search ---")
    local ok, gc = pcall(function() return getgc() end)
    if ok and gc then
        local foundCount = 0
        for _, obj in ipairs(gc) do
            if typeof(obj) == "function" then
                local ok2, info = pcall(function() return debug.getinfo(obj) end)
                if ok2 and info and info.source then
                    local srcLower = tostring(info.source):lower()
                    local nameLower = info.name and tostring(info.name):lower() or ""
                    for _, kw in ipairs(keywords) do
                        if srcLower:find(kw:lower()) or nameLower:find(kw:lower()) then
                            foundCount += 1
                            log("GC function #", tostring(foundCount), "name=", info.name or "nil", "source=", info.source, "linedefined=", tostring(info.linedefined))
                            if foundCount >= 30 then
                                log("... stopping after 30 matches")
                                break
                            end
                        end
                    end
                    if foundCount >= 30 then break end
                end
            end
        end
        if foundCount == 0 then
            log("No matching functions in GC")
        end
    else
        log("getgc failed:", tostring(gc))
    end
else
    log("getgc not available")
end

-- 4. Try to find local script environment for existing placed printer
log("\n--- Search for MoneyPrinter-tagged objects ---")
local function scanWorkspace(parent, depth)
    if depth > 6 then return end
    for _, c in ipairs(parent:GetChildren()) do
        if c:HasTag("MoneyPrinter") then
            log("Tagged object:", c:GetFullName(), "Class:", c.ClassName)
        end
        scanWorkspace(c, depth + 1)
    end
end
scanWorkspace(Workspace, 0)

log("\n========== END PROBE ==========")
copy()
