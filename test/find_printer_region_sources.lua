--[[
    San Diego Agent — Test: find MoneyPrinterApartmentRegion attribute sources
    ===================================================================
    Если в папке MoneyPrinters нет принтеров, атрибуты региона могут быть
    на родителе или другом объекте. Этот тест ищет их в ветке Apartments.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

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
    if writefile then pcall(function() writefile("find_printer_region_sources_log.txt", text) end) end
end

log("========== FIND PRINTER REGION SOURCES ==========")
log("Player:", player.Name)

local function dumpRegionAttrs(obj)
    local rc = obj:GetAttribute("MoneyPrinterApartmentRegionCFrame")
    local rs = obj:GetAttribute("MoneyPrinterApartmentRegionSize")
    if typeof(rc) == "CFrame" and typeof(rs) == "Vector3" then
        log("  -> found on", obj.ClassName, obj:GetFullName())
        log("     CFrame:", tostring(rc))
        log("     Size:", tostring(rs))
        return true
    end
    return false
end

-- Scan Apartments branch
log("\nScanning Workspace.Gameplay.Apartments...")
local apartments = Workspace:FindFirstChild("Gameplay")
apartments = apartments and apartments:FindFirstChild("Apartments")
if apartments then
    local function scan(parent, depth)
        if depth > 10 then return end
        for _, c in ipairs(parent:GetChildren()) do
            if c.Name:lower():find("apartment") or c.Name:lower():find("unit") or c.Name:lower():find("region") then
                if dumpRegionAttrs(c) then
                    -- also print children names
                    local names = {}
                    for _, ch in ipairs(c:GetChildren()) do
                        table.insert(names, ch.Name)
                    end
                    log("     children:", table.concat(names, ", "))
                end
            end
            scan(c, depth + 1)
        end
    end
    scan(apartments, 0)
else
    log("Workspace.Gameplay.Apartments not found")
end

-- List all MoneyPrinters folders and their parents/attributes
log("\nAll MoneyPrinters folders:")
local seen = {}
local function scanAll(parent, depth)
    if depth > 10 then return end
    for _, c in ipairs(parent:GetChildren()) do
        if c.Name == "MoneyPrinters" and not seen[c] then
            seen[c] = true
            log("  Folder:", c:GetFullName())
            log("    Child count:", tostring(#c:GetChildren()))
            log("    Folder has region attrs:", tostring(dumpRegionAttrs(c)))
            log("    Parent:", c.Parent and c.Parent:GetFullName() or "nil")
            log("    Parent has region attrs:", tostring(dumpRegionAttrs(c.Parent)))
            for _, child in ipairs(c:GetChildren()) do
                log("    Child:", child.ClassName, child.Name)
                log("      has MoneyPrinterId:", tostring(typeof(child:GetAttribute("MoneyPrinterId")) == "string"))
                log("      has region attrs:", tostring(dumpRegionAttrs(child)))
            end
        end
        scanAll(c, depth + 1)
    end
end
scanAll(Workspace, 0)

-- Deep scan for any object with region attributes in Apartments
log("\nDeep scan for MoneyPrinterApartmentRegionCFrame in Apartments:")
if apartments then
    local function deepScan(parent, depth)
        if depth > 12 then return end
        for _, c in ipairs(parent:GetChildren()) do
            if dumpRegionAttrs(c) then
                log("     object class:", c.ClassName)
            end
            deepScan(c, depth + 1)
        end
    end
    deepScan(apartments, 0)
end

-- Scan all services for region attributes
log("\nScanning all services for MoneyPrinterApartmentRegionCFrame:")
local servicesToScan = {
    "Workspace",
    "ReplicatedStorage",
    "ReplicatedFirst",
    "Lighting",
    "StarterGui",
    "StarterPack",
    "StarterPlayer",
}
for _, serviceName in ipairs(servicesToScan) do
    local ok, service = pcall(function() return game:GetService(serviceName) end)
    if ok and service then
        local foundAny = false
        local function deepScan(parent, depth)
            if depth > 12 then return end
            for _, c in ipairs(parent:GetChildren()) do
                if dumpRegionAttrs(c) then
                    log("  Service", serviceName, "->", c.ClassName, c:GetFullName())
                    foundAny = true
                end
                deepScan(c, depth + 1)
            end
        end
        pcall(function() deepScan(service, 0) end)
        if not foundAny then
            log("  Service", serviceName, ": none")
        end
    else
        log("  Service", serviceName, ": not accessible")
    end
end

-- Inspect backpack tool attributes
log("\nInspecting backpack tools:")
local backpack = player:FindFirstChild("Backpack")
if backpack then
    for _, c in ipairs(backpack:GetChildren()) do
        if c.Name:lower():find("print") then
            log("  Backpack tool:", c.ClassName, c.Name)
            log("    has MoneyPrinterId:", tostring(typeof(c:GetAttribute("MoneyPrinterId")) == "string"))
            log("    has region attrs:", tostring(dumpRegionAttrs(c)))
            local part = c:FindFirstChild("Handle") or c:FindFirstChild("Printer_d")
            if part and part:IsA("BasePart") then
                log("    part Size:", tostring(part.Size))
            end
        end
    end
else
    log("  No backpack")
end

-- Inspect apartment unit children
log("\nInspecting apartment unit children:")
local moneyPrintersFolder = nil
for _, c in ipairs(seen) do moneyPrintersFolder = c break end
if not moneyPrintersFolder then
    local function findFolder(parent, depth)
        if depth > 8 then return nil end
        for _, c in ipairs(parent:GetChildren()) do
            if c.Name == "MoneyPrinters" then return c end
            local f = findFolder(c, depth + 1)
            if f then return f end
        end
        return nil
    end
    moneyPrintersFolder = findFolder(Workspace, 0)
end
if moneyPrintersFolder and moneyPrintersFolder.Parent then
    local unit = moneyPrintersFolder.Parent
    log("  Unit:", unit:GetFullName())
    for _, c in ipairs(unit:GetChildren()) do
        if c == moneyPrintersFolder then continue end
        if c:IsA("BasePart") then
            log("    BasePart:", c.Name, "Size:", tostring(c.Size), "Pos:", tostring(c.Position))
        elseif c:IsA("Model") or c:IsA("Folder") or c:IsA("Configuration") then
            log("    Container:", c.ClassName, c.Name, "children:", tostring(#c:GetChildren()))
        else
            log("    Other:", c.ClassName, c.Name)
        end
    end
else
    log("  No MoneyPrinters folder found")
end

-- Print player current position and nearest MoneyPrinters folder
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:FindFirstChild("HumanoidRootPart")
if hrp then
    log("\nPlayer position:", tostring(hrp.Position))
end

log("\n========== END ==========")
copy()
