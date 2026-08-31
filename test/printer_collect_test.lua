--[[
    San Diego Agent — Test: collect all printers from the apartment
    ================================================================
    Собирает все принтеры из папки MoneyPrinters квартиры игрока
    и возвращает их в Backpack.
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
    if writefile then pcall(function() writefile("printer_collect_test_log.txt", text) end) end
end

local RAYCAST_DOWN_DISTANCE = 50

local function getCharacter()
    local char = player.Character
    if char then return char end
    return player.CharacterAdded:Wait()
end

local function getPlayerPos()
    local char = getCharacter()
    local hrp = char:FindFirstChild("HumanoidRootPart")
    return hrp and hrp.Position
end

local function findMoneyPrintersFolders()
    local folders = {}
    local seen = {}
    local function scan(parent, depth)
        if depth > 8 then return end
        for _, c in ipairs(parent:GetChildren()) do
            if c.Name == "MoneyPrinters" and not seen[c] and
               (c:IsA("Folder") or c:IsA("Model") or c:IsA("Configuration")) then
                seen[c] = true
                table.insert(folders, c)
            end
            if not c:IsA("BasePart") then scan(c, depth + 1) end
        end
    end
    scan(Workspace, 0)
    return folders
end

local function raycastDownFromPlayer()
    local playerPos = getPlayerPos()
    if not playerPos then return nil end
    local char = getCharacter()
    local params = nil
    local ok, res = pcall(function()
        local p = RaycastParams.new()
        p.FilterType = Enum.RaycastFilterType.Blacklist
        p.FilterDescendantsInstances = { char }
        return p
    end)
    if not ok or not res then return nil end
    params = res
    local origin = playerPos + Vector3.new(0, 5, 0)
    local direction = Vector3.new(0, -RAYCAST_DOWN_DISTANCE, 0)
    local result = nil
    pcall(function()
        result = Workspace:Raycast(origin, direction, params)
    end)
    return result and result.Instance
end

local function findMoneyPrintersFolderInUnit(unit)
    if not unit then return nil end
    local function scan(parent, depth)
        if depth > 8 then return nil end
        for _, c in ipairs(parent:GetChildren()) do
            if c.Name == "MoneyPrinters" and (c:IsA("Folder") or c:IsA("Model") or c:IsA("Configuration")) then
                return c
            end
            if not c:IsA("BasePart") then
                local found = scan(c, depth + 1)
                if found then return found end
            end
        end
        return nil
    end
    return scan(unit, 0)
end

local function chooseTargetFolder()
    local hitPart = raycastDownFromPlayer()
    if hitPart then
        local unit = hitPart.Parent
        local depth = 0
        while unit and depth < 10 do
            local mp = findMoneyPrintersFolderInUnit(unit)
            if mp then return mp end
            unit = unit.Parent
            depth = depth + 1
        end
    end
    -- fallback: первая найденная
    local folders = findMoneyPrintersFolders()
    return folders[1]
end

log("========== PRINTER COLLECT TEST ==========")
log("Player:", player.Name)

local folder = chooseTargetFolder()
if not folder then
    log("ERROR: No MoneyPrinters folder found")
    copy()
    return
end
log("Target folder:", folder:GetFullName())

local backpack = player:FindFirstChild("Backpack")
if not backpack then
    log("ERROR: No backpack")
    copy()
    return
end

local collected = 0
local failed = 0

for _, c in ipairs(folder:GetChildren()) do
    if c.Name:lower():find("print") and c:IsA("Tool") then
        log("Collecting:", c.Name, "->", c:GetFullName())
        local ok, err = pcall(function()
            c.Parent = backpack
        end)
        if ok then
            collected += 1
            log("  success")
        else
            failed += 1
            log("  FAILED:", tostring(err))
        end
        task.wait(0.1)
    end
end

log("\n--- Results ---")
log("Collected:", tostring(collected))
log("Failed:", tostring(failed))
log("========== END ==========")
copy()
