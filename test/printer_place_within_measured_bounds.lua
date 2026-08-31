--[[
    San Diego Agent — Place printers inside measured room bounds v4 (snake / two-ended fill)
    ============================================================================================
    - Собирает старые принтеры.
    - Использует getgenv().RoomPerimeter (или fallback).
    - Заполняет комнату "змейкой": в каждом ряду выкладывает принтеры с двух сторон к центру,
      чтобы соседние выкладки не конфликтовали и ряд заполнялся полностью.
    - Целевые параметры:
        TARGET_COLS = 12  -- принтеров в ряду
        TARGET_ROWS = 5   -- рядов
        MAX_PRINTERS = 50 -- максимум всего
    - Если принтеров меньше 50 -- выкладывает все.
    - После каждого принтера и после каждого ряда выводит статистику.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local logs = {}

-- Targets
local TARGET_COLS = 12
local TARGET_ROWS = 5
local MAX_PRINTERS = 50

-- Side margins (in units of printer size). Final = size * multiplier.
local ROW_SIDE_MARGIN_MULT = 1.0  -- отступ от торцевых стен (начало и конец ряда)
local COL_SIDE_MARGIN_MULT = 0.5  -- отступ от длинных параллельных стен

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
    if writefile then pcall(function() writefile("printer_place_snake_fill_log.txt", text) end) end
end

log("========== PLACE PRINTERS SNAKE FILL ==========")
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

local function getExistingModelFootprint(folder)
    for _, c in ipairs(folder:GetChildren()) do
        if c:IsA("Model") and c:GetAttribute("MoneyPrinterId") then
            local ok, ext = pcall(function() return c:GetExtentsSize() end)
            if ok and ext then
                local s = math.max(ext.X, ext.Z)
                log("Existing model footprint size:", tostring(s))
                return s
            end
        end
    end
    return nil
end

local function getRealPrinterIds(folder)
    local ids = {}
    for _, c in ipairs(folder:GetChildren()) do
        if c:IsA("Model") then
            local id = c:GetAttribute("MoneyPrinterId")
            if id then ids[id] = true end
        end
    end
    return ids
end

local function countRealPrintersFromIds(ids)
    local n = 0
    for _ in pairs(ids) do n += 1 end
    return n
end

-- ---------------------------------------------------------------------------
-- Bounds
-- ---------------------------------------------------------------------------
local bounds
if getgenv and getgenv().RoomPerimeter then
    bounds = getgenv().RoomPerimeter
    log("Using getgenv().RoomPerimeter")
else
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
-- Measure footprint BEFORE collecting
-- ---------------------------------------------------------------------------
local existingFootprint = getExistingModelFootprint(folder)

-- ---------------------------------------------------------------------------
-- Collect existing printers
-- ---------------------------------------------------------------------------
local pickupRemote = ReplicatedStorage:FindFirstChild("__remotes", true)
if pickupRemote then
    pickupRemote = pickupRemote:FindFirstChild("MoneyPrinterService")
    if pickupRemote then pickupRemote = pickupRemote:FindFirstChild("PickupMoneyPrinter") end
end

local function tryFirePrompt(obj)
    if not obj then return false end
    local prompt = obj:FindFirstChildOfClass("ProximityPrompt")
    if prompt then
        local ok = pcall(function() fireproximityprompt(prompt) end)
        if ok then return true end
    end
    local clicker = obj:FindFirstChildOfClass("ClickDetector")
    if clicker then
        local ok = pcall(function() fireclickdetector(clicker) end)
        if ok then return true end
    end
    return false
end

local function tryRemoteCollect(model)
    if not pickupRemote then return false end
    for _, args in ipairs({ { model }, { model, getHrp() and getHrp().Position }, { folder, model }, {} }) do
        local ok, res = pcall(function() return pickupRemote:InvokeServer(unpack(args)) end)
        if ok then return true end
    end
    return false
end

local function collectPrinter(model, backpack)
    log("  Collecting:", model.Name)
    if tryRemoteCollect(model) then
        log("    remote ok")
        return true
    end
    if tryFirePrompt(model) then
        log("    prompt/click ok")
        return true
    end
    for _, d in ipairs(model:GetDescendants()) do
        if tryFirePrompt(d) then
            log("    descendant prompt/click ok")
            return true
        end
    end
    local ok = pcall(function() model.Parent = backpack end)
    if ok then
        log("    Parent=Backpack ok")
        return true
    end
    return false
end

local function collectAllPrinters()
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return end
    for attempt = 1, 3 do
        local remaining = {}
        for _, c in ipairs(folder:GetChildren()) do
            if c.Name:lower():find("print") or c:HasTag("MoneyPrinter") then
                table.insert(remaining, c)
            end
        end
        if #remaining == 0 then
            log("No printers left to collect on attempt", tostring(attempt))
            break
        end
        log("Collect attempt", tostring(attempt), "printers:", tostring(#remaining))
        for _, c in ipairs(remaining) do
            if c.Parent == folder then
                local part = c:FindFirstChild("Printer_d") or c:FindFirstChild("Handle") or c:FindFirstChildWhichIsA("BasePart")
                if part then
                    local h = getHrp()
                    if h then
                        h.CFrame = CFrame.new(part.Position + Vector3.new(0, 3, 0))
                        task.wait(0.2)
                    end
                end
                collectPrinter(c, backpack)
                task.wait(0.2)
            end
        end
        task.wait(0.5)
    end
end

collectAllPrinters()

-- Delete fakes
local function clearFakes()
    local deleted = 0
    for _, c in ipairs(folder:GetChildren()) do
        if (c.Name:lower():find("print") or c:HasTag("MoneyPrinter")) and not c:GetAttribute("MoneyPrinterId") then
            pcall(function() c:Destroy() end)
            deleted += 1
        end
    end
    log("Deleted fakes:", tostring(deleted))
end
clearFakes()

local backpackCount = countBackpackPrinters()
log("Backpack printers after collect:", tostring(backpackCount))
if backpackCount == 0 then
    log("ERROR: No printers to place")
    copy()
    return
end

-- Use the smaller of measured footprint and tool size to allow tighter packing
local toolSize = getToolSize()
local size = existingFootprint and math.min(existingFootprint, toolSize) or toolSize
local half = size / 2
log("Final spacing size:", tostring(size))

-- ---------------------------------------------------------------------------
-- Grid calculation
-- ---------------------------------------------------------------------------
local widthX = bounds.maxX - bounds.minX
local widthZ = bounds.maxZ - bounds.minZ

-- Choose rows along longer side
local rowDir, colDir, lengthAxis, widthAxis
local minL, maxL, minW, maxW
if widthZ >= widthX then
    rowDir = Vector3.new(0, 0, 1)
    colDir = Vector3.new(1, 0, 0)
    lengthAxis, widthAxis = "Z", "X"
    minL, maxL = bounds.minZ, bounds.maxZ
    minW, maxW = bounds.minX, bounds.maxX
    log("Rows along Z (length), cols along X (width)")
else
    rowDir = Vector3.new(1, 0, 0)
    colDir = Vector3.new(0, 0, 1)
    lengthAxis, widthAxis = "X", "Z"
    minL, maxL = bounds.minX, bounds.maxX
    minW, maxW = bounds.minZ, bounds.maxZ
    log("Rows along X (length), cols along Z (width)")
end

local rowSideMargin = size * ROW_SIDE_MARGIN_MULT  -- отступ от торцов
local colSideMargin = size * COL_SIDE_MARGIN_MULT  -- отступ от длинных стен

local startL = minL + rowSideMargin + half
local endL   = maxL - rowSideMargin - half
local rowSpacing = (endL - startL) / math.max(1, TARGET_COLS - 1)

local startW = minW + colSideMargin + half
local colSpacing = size

local maxRows = math.max(1, math.floor((maxW - minW - 2 * colSideMargin - size) / colSpacing) + 1)
local maxRows = math.min(maxRows, TARGET_ROWS)
local maxCols = TARGET_COLS

local capacity = maxCols * maxRows
local totalToPlace = math.min(backpackCount, capacity, MAX_PRINTERS)

log("Row side margin:", tostring(rowSideMargin), "Col side margin:", tostring(colSideMargin))
log("Row spacing:", tostring(rowSpacing), "Col spacing:", tostring(colSpacing))
log("Max rows:", tostring(maxRows), "Max cols:", tostring(maxCols))
log("Capacity:", tostring(capacity), "Will place:", tostring(totalToPlace))

-- ---------------------------------------------------------------------------
-- Placement (snake: fill each row from both ends to center)
-- ---------------------------------------------------------------------------
local knownIds = getRealPrinterIds(folder)
local initialCount = countRealPrintersFromIds(knownIds)
log("Initial real printers:", tostring(initialCount))

local placed = 0
local failed = 0

local function placeAt(slotIndex, row, col)
    local targetL = startL + (col - 1) * rowSpacing
    local targetW = startW + row * colSpacing

    local targetPos
    if lengthAxis == "Z" then
        targetPos = Vector3.new(targetW, bounds.floorY, targetL)
    else
        targetPos = Vector3.new(targetL, bounds.floorY, targetW)
    end

    log("--- Slot", tostring(slotIndex), "of", tostring(totalToPlace), "(row", tostring(row + 1), "col", tostring(col), ")---")
    log("Target pos:", tostring(targetPos))

    local tool = takePrinterTool()
    if not tool then
        log("No more tools")
        return false
    end

    local slotOk, success, errMsg = pcall(function()
        local h = getHrp()
        if h then
            h.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
        end
        task.wait(0.2)
        local hum = getHumanoid()
        if hum then
            pcall(function() hum:UnequipTools() end)
            task.wait(0.1)
            pcall(function() hum:EquipTool(tool) end)
            task.wait(0.2)
        end
        pcall(function() tool:Activate() end)

        -- Wait for a NEW MoneyPrinterId (3s timeout)
        for w = 1, 20 do
            task.wait(0.15)
            for _, c in ipairs(folder:GetChildren()) do
                if c:IsA("Model") then
                    local id = c:GetAttribute("MoneyPrinterId")
                    if id and not knownIds[id] then
                        knownIds[id] = true
                        return true
                    end
                end
            end
        end
        return false, "conversion timeout"
    end)

    if slotOk and success == true then
        placed += 1
        log("OK. Placed", tostring(placed), "/", tostring(totalToPlace), "remaining", tostring(totalToPlace - placed))
        return true
    else
        failed += 1
        local msg = tostring((slotOk and errMsg) or success or "unknown")
        log("FAILED:", msg)
        pcall(function()
            if tool and tool.Parent then tool.Parent = player.Backpack end
        end)
        return false
    end
end

local slotIndex = 1
for row = 0, maxRows - 1 do
    local rowPlaced = 0
    local leftCol = 1
    local rightCol = maxCols
    while leftCol <= rightCol and slotIndex <= totalToPlace do
        -- Place on left side
        if placeAt(slotIndex, row, leftCol) then
            rowPlaced += 1
        end
        slotIndex += 1
        task.wait(0.6)

        -- Place on right side
        if leftCol < rightCol and slotIndex <= totalToPlace then
            if placeAt(slotIndex, row, rightCol) then
                rowPlaced += 1
            end
            slotIndex += 1
            task.wait(0.6)
        end

        leftCol += 1
        rightCol -= 1
    end
    log("== Row", tostring(row + 1), "done. Placed in row:", tostring(rowPlaced),
        "Total placed:", tostring(placed), "/", tostring(totalToPlace),
        "Remaining:", tostring(math.max(0, totalToPlace - placed)), "==")
end

local finalCount = countRealPrintersFromIds(knownIds)
log("\n--- FINAL RESULTS ---")
log("Initial real printers:", tostring(initialCount))
log("Target total:", tostring(totalToPlace))
log("Placed (confirmed):", tostring(placed))
log("Failed:", tostring(failed))
log("Final real printers:", tostring(finalCount))
log("Remaining backpack:", tostring(countBackpackPrinters()))
log("========== END ==========")
copy()
