--[[
    San Diego Agent — Place printers inside measured room bounds v2
    ==================================================================
    Использует getgenv().RoomPerimeter (или fallback) и расставляет принтеры
    строго внутри комнаты:
    - ряды вдоль более длинной стороны;
    - внутри ряда накладывание 50% (шаг = 0.5 * размер);
    - между рядами зазора нет;
    - отступ от стен = 0.3, чтобы не вылезать;
    - отслеживает MoneyPrinterId каждого поставленного принтера,
      исключая ложные срабатывания.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local logs = {}

local ROW_OVERLAP_RATIO = 0.0 -- без наложения: сервер отклоняет пересечения
local WALL_MARGIN = 1.0       -- серьёзный отступ от стен, чтобы модель не вылезала
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
    if writefile then pcall(function() writefile("printer_place_within_measured_bounds_v2_log.txt", text) end) end
end

log("========== PLACE WITHIN MEASURED BOUNDS v2 ==========")
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
-- Collect existing printers (robust)
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
        local ok = pcall(function()
            fireproximityprompt(prompt)
        end)
        if ok then return true end
    end
    local clicker = obj:FindFirstChildOfClass("ClickDetector")
    if clicker then
        local ok = pcall(function()
            fireclickdetector(clicker)
        end)
        if ok then return true end
    end
    return false
end

local function tryRemoteCollect(model)
    if not pickupRemote then return false end
    for _, args in ipairs({ { model }, { model, getHrp() and getHrp().Position }, { folder, model }, {} }) do
        local ok, res = pcall(function() return pickupRemote:InvokeServer(unpack(args)) end)
        if ok then
            return true
        end
    end
    return false
end

local function collectPrinter(model, backpack)
    local fullName = model:GetFullName()
    log("  Collecting:", model.Name, "Class:", model.ClassName)

    -- Try remote
    if tryRemoteCollect(model) then
        log("    remote ok")
        return true
    end

    -- Try prompt/clicker on model or descendants
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

    -- Fallback: move Tool to backpack
    local ok, err = pcall(function() model.Parent = backpack end)
    if ok then
        log("    Parent=Backpack ok")
        return true
    else
        log("    Parent=Backpack failed:", tostring(err))
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
                collectPrinter(c, backpack)
                task.wait(0.3)
            end
        end
        task.wait(0.5)
    end
end

collectAllPrinters()

-- Delete leftover fakes / uncollectable models
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
log("Backpack printers:", tostring(backpackCount))
if backpackCount == 0 then
    log("ERROR: No printers to place")
    copy()
    return
end

local size = getToolSize()
local half = size / 2

-- ---------------------------------------------------------------------------
-- Choose orientation: rows along longer side
-- ---------------------------------------------------------------------------
local widthX = bounds.maxX - bounds.minX
local widthZ = bounds.maxZ - bounds.minZ

local rowDir, colDir, startX, startZ, usableRow, usableCol
local margin = WALL_MARGIN
if widthZ >= widthX then
    rowDir = Vector3.new(0, 0, 1)
    colDir = Vector3.new(1, 0, 0)
    startX = bounds.minX + margin + half
    startZ = bounds.minZ + margin + half
    usableRow = widthZ - size - 2 * margin
    usableCol = widthX - size - 2 * margin
    log("Rows along Z (longer wall). Cols along X.")
else
    rowDir = Vector3.new(1, 0, 0)
    colDir = Vector3.new(0, 0, 1)
    startX = bounds.minX + margin + half
    startZ = bounds.minZ + margin + half
    usableRow = widthX - size - 2 * margin
    usableCol = widthZ - size - 2 * margin
    log("Rows along X (longer wall). Cols along Z.")
end

local startPos = Vector3.new(startX, bounds.floorY, startZ)
local rowSpacing = math.max(size * (1 - ROW_OVERLAP_RATIO), 0.1)
local colSpacing = size

local maxCols = math.max(1, math.floor(usableRow / rowSpacing) + 1)
local maxRows = math.max(1, math.floor(usableCol / colSpacing) + 1)
local capacity = maxCols * maxRows
local totalToPlace = math.min(backpackCount, capacity, MAX_PRINTERS)

log("Wall margin:", tostring(margin))
log("Usable row length:", tostring(usableRow), "max cols:", tostring(maxCols))
log("Usable col length:", tostring(usableCol), "max rows:", tostring(maxRows))
log("Capacity:", tostring(capacity), "Will place:", tostring(totalToPlace))
log("Start pos:", tostring(startPos))

-- ---------------------------------------------------------------------------
-- Placement with per-slot ID tracking
-- ---------------------------------------------------------------------------
local knownIds = getRealPrinterIds(folder)
local initialCount = countRealPrintersFromIds(knownIds)
log("Initial real printers:", tostring(initialCount))

local placed = 0
local failed = 0
local errors = {}

for i = 1, totalToPlace do
    log("\n--- Slot", tostring(i), "of", tostring(totalToPlace), "---")

    local tool = takePrinterTool()
    if not tool then
        log("No more tools in backpack")
        break
    end

    local col = (i - 1) % maxCols
    local row = math.floor((i - 1) / maxCols)
    local targetPos = startPos + rowDir * (col * rowSpacing) + colDir * (row * colSpacing)

    -- Clamp with margin
    targetPos = Vector3.new(
        math.clamp(targetPos.X, bounds.minX + margin + half, bounds.maxX - margin - half),
        targetPos.Y,
        math.clamp(targetPos.Z, bounds.minZ + margin + half, bounds.maxZ - margin - half)
    )

    log("Target pos:", tostring(targetPos))

    local slotOk, success, errMsg = pcall(function()
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

        -- Wait for a NEW MoneyPrinterId, not just any count increase
        for w = 1, 45 do
            task.wait(0.2)
            local foundId = nil
            for _, c in ipairs(folder:GetChildren()) do
                if c:IsA("Model") then
                    local id = c:GetAttribute("MoneyPrinterId")
                    if id and not knownIds[id] then
                        foundId = id
                        break
                    end
                end
            end
            if foundId then
                knownIds[foundId] = true
                return true
            end
        end
        return false, "conversion timeout"
    end)

    if slotOk and success == true then
        placed += 1
        log("OK. Confirmed real printers:", tostring(countRealPrintersFromIds(knownIds)))
    else
        failed += 1
        local msg = tostring((slotOk and errMsg) or success or "unknown")
        log("FAILED:", msg)
        table.insert(errors, { slot = i, pos = tostring(targetPos), error = msg })
        -- If tool still exists and is not destroyed, return to backpack
        pcall(function()
            if tool and tool.Parent then tool.Parent = player.Backpack end
        end)
    end

    task.wait(0.1)
end

local finalCount = countRealPrintersFromIds(knownIds)
log("\n--- RESULTS ---")
log("Initial real printers:", tostring(initialCount))
log("Placed (confirmed by new IDs):", tostring(placed))
log("Failed:", tostring(failed))
log("Final real printers:", tostring(finalCount))
log("Remaining backpack:", tostring(countBackpackPrinters()))
if #errors > 0 then
    log("Errors:", tostring(#errors))
    for _, e in ipairs(errors) do
        log("  slot", tostring(e.slot), "@", e.pos, "-", e.error)
    end
end
log("========== END ==========")
copy()
