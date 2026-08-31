--[[
    San Diego Agent — Place printers inside measured room bounds
    ==============================================================
    Использует координаты из getgenv().RoomPerimeter (или захардкоженный fallback)
    и расставляет принтеры впритык к стенам:
    - ряды идут вдоль более длинной стороны комнаты;
    - внутри ряда принтеры могут немного накладываться (экономия места);
    - между рядами зазора нет.

    Перед раскладкой собирает все уже стоящие принтеры.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local logs = {}

local ROW_OVERLAP = 0.3
local MAX_PRINTERS = 50

local function log(...)
    local parts = {}
    for _, v in ipairs({ ... }) do table.insert(parts, tostring(v)) end
    local msg = "[" .. os.date("%H:%M:%S") .. "] " .. table.concat(parts, " ")
    table.insert(logs, msg)
    print(msg)
    warn(msg)
end

local function copy()
    local text = table.concat(logs, "\n")
    if setclipboard then pcall(function() setclipboard(text) end) end
    if writefile then pcall(function() writefile("printer_place_within_measured_bounds_log.txt", text) end) end
end

log("========== PLACE WITHIN MEASURED BOUNDS ==========")
log("Player:", player.Name)

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local function getCharacter()
    local char = player.Character
    if char then return char end
    return player.CharacterAdded:Wait()
end

local function getHrp()
    return getCharacter():FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    return getCharacter():FindFirstChildOfClass("Humanoid")
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
    local hrp = getHrp()
    if hrp then
        local params
        pcall(function()
            local p = RaycastParams.new()
            p.FilterType = Enum.RaycastFilterType.Blacklist
            p.FilterDescendantsInstances = { getCharacter() }
            params = p
        end)
        local result
        pcall(function()
            result = Workspace:Raycast(hrp.Position + Vector3.new(0, 5, 0), Vector3.new(0, -50, 0), params)
        end)
        if result then
            local unit = result.Instance
            local depth = 0
            while unit and depth < 10 do
                local mp = findMoneyPrintersFolderInUnit(unit)
                if mp then return mp, unit end
                unit = unit.Parent
                depth = depth + 1
            end
        end
    end
    return nil, nil
end

local function countBackpackPrinters()
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return 0 end
    local n = 0
    for _, c in ipairs(backpack:GetChildren()) do
        if c:IsA("Tool") and c.Name:lower():find("print") then n += 1 end
    end
    return n
end

local function takePrinterTool()
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return nil end
    for _, c in ipairs(backpack:GetChildren()) do
        if c:IsA("Tool") and c.Name:lower():find("print") then return c end
    end
    return nil
end

local function getToolSize()
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return 4 end
    for _, c in ipairs(backpack:GetChildren()) do
        if c:IsA("Tool") and c.Name:lower():find("print") then
            local part = c:FindFirstChild("Printer_d") or c:FindFirstChild("Handle")
            if part and part:IsA("BasePart") then
                local s = math.max(part.Size.X, part.Size.Z)
                log("Tool footprint size:", tostring(s))
                return s
            end
        end
    end
    return 4
end

local function countRealPrinters(folder)
    local n = 0
    for _, c in ipairs(folder:GetChildren()) do
        if c:IsA("Model") and c:GetAttribute("MoneyPrinterId") then n += 1 end
    end
    return n
end

-- ---------------------------------------------------------------------------
-- Get bounds
-- ---------------------------------------------------------------------------
local bounds
if getgenv and getgenv().RoomPerimeter then
    bounds = getgenv().RoomPerimeter
    log("Using getgenv().RoomPerimeter")
else
    -- Fallback from measured log
    bounds = {
        minX = 997.1759033203125,
        maxX = 1010.9700927734375,
        minZ = -5993.724609375,
        maxZ = -5977.5517578125,
        floorY = -49.74806213378906,
    }
    log("Using fallback measured bounds")
end

log("Bounds:")
log("  X:", tostring(bounds.minX), "..", tostring(bounds.maxX))
log("  Z:", tostring(bounds.minZ), "..", tostring(bounds.maxZ))
log("  floorY:", tostring(bounds.floorY))

-- ---------------------------------------------------------------------------
-- Find folder
-- ---------------------------------------------------------------------------
local folder, unit = chooseTargetFolder()
if not folder then
    log("ERROR: MoneyPrinters folder not found")
    copy()
    return
end
log("Target folder:", folder:GetFullName())

-- ---------------------------------------------------------------------------
-- Collect existing printers
-- ---------------------------------------------------------------------------
local pickupRemote = ReplicatedStorage:FindFirstChild("__remotes", true)
if pickupRemote then
    pickupRemote = pickupRemote:FindFirstChild("MoneyPrinterService")
    if pickupRemote then pickupRemote = pickupRemote:FindFirstChild("PickupMoneyPrinter") end
end

local function collectAllPrinters()
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return end
    for _, c in ipairs(folder:GetChildren()) do
        if c.Name:lower():find("print") or c:HasTag("MoneyPrinter") then
            log("Collecting:", c.Name)
            local ok = false
            if pickupRemote and pickupRemote:IsA("RemoteFunction") then
                for _, args in ipairs({ { c }, { c, getHrp() and getHrp().Position }, { folder, c }, {} }) do
                    local rOk, res = pcall(function() return pickupRemote:InvokeServer(unpack(args)) end)
                    if rOk then
                        ok = true
                        break
                    end
                end
            end
            if not ok then
                pcall(function() c.Parent = backpack end)
            end
            task.wait(0.2)
        end
    end
end

collectAllPrinters()
task.wait(0.5)

-- Delete leftover fakes
for _, c in ipairs(folder:GetChildren()) do
    if (c.Name:lower():find("print") or c:HasTag("MoneyPrinter")) and not c:GetAttribute("MoneyPrinterId") then
        pcall(function() c:Destroy() end)
    end
end

local backpackCount = countBackpackPrinters()
log("Backpack printers:", tostring(backpackCount))
if backpackCount == 0 then
    log("ERROR: No printers to place")
    copy()
    return
end

local size = getToolSize()
local half = size / 2

-- ---------------------------------------------------------------------------
-- Choose orientation: rows along the longer side
-- ---------------------------------------------------------------------------
local widthX = bounds.maxX - bounds.minX
local widthZ = bounds.maxZ - bounds.minZ

local rowDir, colDir, startX, startZ, usableRow, usableCol
if widthZ >= widthX then
    rowDir = Vector3.new(0, 0, 1)
    colDir = Vector3.new(1, 0, 0)
    startX = bounds.minX + half
    startZ = bounds.minZ + half
    usableRow = widthZ - size
    usableCol = widthX - size
    log("Rows along Z (longer wall). Cols along X.")
else
    rowDir = Vector3.new(1, 0, 0)
    colDir = Vector3.new(0, 0, 1)
    startX = bounds.minX + half
    startZ = bounds.minZ + half
    usableRow = widthX - size
    usableCol = widthZ - size
    log("Rows along X (longer wall). Cols along Z.")
end

local startPos = Vector3.new(startX, bounds.floorY, startZ)
local rowSpacing = math.max(size - ROW_OVERLAP, 0.1)
local colSpacing = size

local maxCols = math.max(1, math.floor(usableRow / rowSpacing) + 1)
local maxRows = math.max(1, math.floor(usableCol / colSpacing) + 1)
local capacity = maxCols * maxRows
local totalToPlace = math.min(backpackCount, capacity, MAX_PRINTERS)

log("Usable row length:", tostring(usableRow), "max cols:", tostring(maxCols))
log("Usable col length:", tostring(usableCol), "max rows:", tostring(maxRows))
log("Capacity:", tostring(capacity), "Will place:", tostring(totalToPlace))
log("Start pos:", tostring(startPos))

-- ---------------------------------------------------------------------------
-- Placement
-- ---------------------------------------------------------------------------
local realNow = countRealPrinters(folder)
local placed = 0
local failed = 0
local errors = {}

for i = 1, totalToPlace do
    log("\n--- Slot", tostring(i), "of", tostring(totalToPlace), "---")

    local tool = takePrinterTool()
    if not tool then
        log("No more tools")
        break
    end

    local col = (i - 1) % maxCols
    local row = math.floor((i - 1) / maxCols)
    local targetPos = startPos + rowDir * (col * rowSpacing) + colDir * (row * colSpacing)

    -- Clamp strictly inside bounds just in case
    targetPos = Vector3.new(
        math.clamp(targetPos.X, bounds.minX + half, bounds.maxX - half),
        targetPos.Y,
        math.clamp(targetPos.Z, bounds.minZ + half, bounds.maxZ - half)
    )

    log("Target pos:", tostring(targetPos))

    local ok, success, errMsg = pcall(function()
        local h = getHrp()
        if h then
            h.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
        end
        task.wait(0.3)
        local hum = getHumanoid()
        if hum then
            pcall(function() hum:UnequipTools() end)
            task.wait(0.2)
            pcall(function() hum:EquipTool(tool) end)
            task.wait(0.3)
        end
        pcall(function() tool:Activate() end)
        for w = 1, 30 do
            task.wait(0.2)
            local newCount = countRealPrinters(folder)
            if newCount > realNow then
                realNow = newCount
                return true
            end
        end
        return false, "conversion timeout"
    end)

    if ok and success == true then
        placed += 1
        log("OK. Real printers:", tostring(realNow))
    else
        failed += 1
        local msg = tostring((ok and errMsg) or success or "unknown")
        log("FAILED:", msg)
        table.insert(errors, { slot = i, pos = tostring(targetPos), error = msg })
        pcall(function() tool.Parent = player.Backpack end)
    end

    task.wait(0.1)
end

log("\n--- RESULTS ---")
log("Placed:", tostring(placed))
log("Failed:", tostring(failed))
log("Final real printers:", tostring(countRealPrinters(folder)))
log("Remaining backpack:", tostring(countBackpackPrinters()))
if #errors > 0 then
    log("Errors:", tostring(#errors))
    for _, e in ipairs(errors) do
        log("  slot", tostring(e.slot), "@", e.pos, "-", e.error)
    end
end
log("========== END ==========")
copy()
