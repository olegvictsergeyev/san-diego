--[[
    San Diego Agent — Collect all printers then place perpendicular grid v2
    =======================================================================
    1. Запоминает текущую раскладку принтеров (если есть) до сбора.
    2. Собирает все принтеры в рюкзак.
    3. Раскладывает их перпендикулярно старой раскладке:
       - ряды идут вдоль стены, перпендикулярной предыдущим рядам;
       - внутри ряда принтеры могут немного накладываться для экономии места;
       - между рядами зазора нет (шаг = размер принтера).
    4. Запоминает угол комнаты и оси в getgenv().PrinterGrid, чтобы в следующий
       раз не зависеть от позиции игрока и наличия старой раскладки.

    Если старой раскладки нет и getgenv().PrinterGrid ещё не сохранён,
    скрипт использует текущее направление взгляда игрока:
    - встань в нужный угол,
    - посмотри вдоль стены, по которой должен идти первый ряд,
    - правый бок — вглубь комнаты.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local logs = {}

local ROW_OVERLAP = 0.3 -- допустимое наложение принтеров внутри ряда (в студ)
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
    if writefile then pcall(function() writefile("printer_collect_and_place_perpendicular_v2_log.txt", text) end) end
end

log("========== COLLECT & PLACE PERPENDICULAR v2 ==========")
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

local function findFloorInUnit(unit)
    if not unit then return nil end
    local best, bestArea = nil, 0
    for _, c in ipairs(unit:GetDescendants()) do
        if c:IsA("BasePart") then
            local size = c.Size
            local area = size.X * size.Z
            local isFlat = size.Y < math.max(size.X, size.Z) * 0.2
            if isFlat and area > bestArea then
                bestArea = area
                best = c
            end
        end
    end
    return best
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
    -- fallback: nearest by existing printers
    local best, bestDist = nil, math.huge
    local function scan(parent, depth)
        if depth > 8 then return end
        for _, c in ipairs(parent:GetChildren()) do
            if c.Name == "MoneyPrinters" and (c:IsA("Folder") or c:IsA("Model") or c:IsA("Configuration")) then
                local dist = math.huge
                for _, p in ipairs(c:GetChildren()) do
                    local part = p:FindFirstChild("Printer_d") or p:FindFirstChild("Handle")
                    if part and part:IsA("BasePart") then
                        local d = (part.Position - (hrp and hrp.Position or Vector3.new())).Magnitude
                        dist = math.min(dist, d)
                    end
                end
                if dist < bestDist then bestDist = dist; best = c end
            end
            if not c:IsA("BasePart") then scan(c, depth + 1) end
        end
    end
    scan(Workspace, 0)
    return best, best and best.Parent
end

local function getExistingPrinterPositions(folder)
    local positions = {}
    for _, c in ipairs(folder:GetChildren()) do
        if c:GetAttribute("MoneyPrinterId") or c.Name:lower():find("print") then
            local part = c:FindFirstChild("Printer_d") or c:FindFirstChild("Handle") or c:FindFirstChildWhichIsA("BasePart")
            if part and part:IsA("BasePart") then
                table.insert(positions, part.Position)
            end
        end
    end
    return positions
end

local function getToolSpacing(tool)
    if not tool then return 4 end
    local part = tool:FindFirstChild("Printer_d") or tool:FindFirstChild("Handle")
    if part and part:IsA("BasePart") then
        local s = math.max(part.Size.X, part.Size.Z)
        log("[getToolSpacing] part size=", tostring(part.Size), "footprint=", tostring(s))
        return s
    end
    return 4
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

local function takePrinterFromBackpack()
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return nil end
    for _, c in ipairs(backpack:GetChildren()) do
        if c:IsA("Tool") and c.Name:lower():find("print") then return c end
    end
    return nil
end

local function round3(v)
    return Vector3.new(math.round(v.X * 1000) / 1000, math.round(v.Y * 1000) / 1000, math.round(v.Z * 1000) / 1000)
end

-- ---------------------------------------------------------------------------
-- Collect
-- ---------------------------------------------------------------------------
local pickupRemote = ReplicatedStorage:FindFirstChild("__remotes", true)
if pickupRemote then
    pickupRemote = pickupRemote:FindFirstChild("MoneyPrinterService")
    if pickupRemote then pickupRemote = pickupRemote:FindFirstChild("PickupMoneyPrinter") end
end
if pickupRemote then
    log("Found pickup remote:", pickupRemote:GetFullName())
else
    log("WARNING: PickupMoneyPrinter remote not found")
end

local folder, unit = chooseTargetFolder()
if not folder then
    log("ERROR: MoneyPrinters folder not found")
    copy()
    return
end
log("Target folder:", folder:GetFullName())

local floor = findFloorInUnit(unit)
if floor then
    log("Floor:", floor.Name, "size=", tostring(floor.Size), "pos=", tostring(floor.Position))
else
    log("WARNING: No floor part found")
end

-- Remember positions BEFORE collecting
local existingPositions = getExistingPrinterPositions(folder)
log("Existing printers before collect:", tostring(#existingPositions))

local function collectAllPrinters()
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return 0 end
    local remoteOkCount = 0
    local parentCount = 0
    local failed = 0
    for _, c in ipairs(folder:GetChildren()) do
        if c.Name:lower():find("print") or c:HasTag("MoneyPrinter") then
            log("Collecting:", c.Name, "Class:", c.ClassName)
            local ok = false
            if pickupRemote and pickupRemote:IsA("RemoteFunction") then
                for _, args in ipairs({ { c }, { c, getHrp() and getHrp().Position }, { folder, c }, {} }) do
                    local rOk, res = pcall(function() return pickupRemote:InvokeServer(unpack(args)) end)
                    if rOk then
                        log("  remote success:", tostring(res))
                                ok = true
                        remoteOkCount += 1
                        break
                    else
                        log("  remote failed:", tostring(res))
                    end
                end
            end
            if not ok then
                local pOk, pErr = pcall(function() c.Parent = backpack end)
                if pOk then
                    parentCount += 1
                    log("  Parent=Backpack ok")
                else
                    failed += 1
                    log("  Parent=Backpack failed:", tostring(pErr))
                end
            else
                parentCount += 1
            end
            task.wait(0.2)
        end
    end
    log("Collected:", tostring(parentCount), "(remote:", tostring(remoteOkCount), ") failed:", tostring(failed))
end

collectAllPrinters()
task.wait(0.5)

-- Delete any leftover fakes
local function deleteFakes()
    local deleted = 0
    for _, c in ipairs(folder:GetChildren()) do
        if (c.Name:lower():find("print") or c:HasTag("MoneyPrinter")) and not c:GetAttribute("MoneyPrinterId") then
            pcall(function() c:Destroy() end)
            deleted += 1
        end
    end
    log("Deleted fakes:", tostring(deleted))
end
deleteFakes()

local backpackCount = countBackpackPrinters()
log("Backpack printers after collect:", tostring(backpackCount))
if backpackCount == 0 then
    log("ERROR: No printers to place")
    copy()
    return
end

local toolSample = takePrinterFromBackpack()
local size = getToolSpacing(toolSample)
if toolSample then pcall(function() toolSample.Parent = player.Backpack end) end
log("Printer footprint size:", tostring(size))

-- ---------------------------------------------------------------------------
-- Grid analysis from existing positions
-- ---------------------------------------------------------------------------
local function analyzeExistingGrid(positions)
    if #positions < 2 then return nil end
    local pts = {}
    for _, p in ipairs(positions) do table.insert(pts, { x = p.X, z = p.Z, y = p.Y }) end

    local function cluster(axis, tol)
        local sorted = {}
        for _, p in ipairs(pts) do table.insert(sorted, p) end
        table.sort(sorted, function(a, b) return a[axis] < b[axis] end)
        local clusters = {}
        for _, p in ipairs(sorted) do
            local added = false
            for _, c in ipairs(clusters) do
                if math.abs(c.center - p[axis]) <= tol then
                    c.center = (c.center * #c.points + p[axis]) / (#c.points + 1)
                    table.insert(c.points, p)
                    added = true
                    break
                end
            end
            if not added then
                table.insert(clusters, { center = p[axis], points = { p } })
            end
        end
        return clusters
    end

    local tol = size * 0.4
    local xClusters = cluster("x", tol)
    local zClusters = cluster("z", tol)

    local rowAxis, colAxis
    if #xClusters >= #zClusters then
        rowAxis, colAxis = "z", "x"
    else
        rowAxis, colAxis = "x", "z"
    end

    local rows = cluster(rowAxis, tol)
    table.sort(rows, function(a, b) return a.center < b.center end)
    for _, r in ipairs(rows) do
        table.sort(r.points, function(a, b) return a[colAxis] < b[colAxis] end)
    end
    if #rows == 0 or #rows[1].points == 0 then return nil end

    local dirRow = (rowAxis == "x") and Vector3.new(1, 0, 0) or Vector3.new(0, 0, 1)
    local dirCol = (colAxis == "x") and Vector3.new(1, 0, 0) or Vector3.new(0, 0, 1)

    -- Determine signs: from first point, do points increase along +dirRow/+dirCol?
    local first = rows[1].points[1]
    local lastRow = rows[#rows].points[1]
    local lastCol = rows[1].points[#rows[1].points]
    if (Vector3.new(lastRow.x, 0, lastRow.z) - Vector3.new(first.x, 0, first.z)):Dot(dirRow) < 0 then
        dirRow = -dirRow
    end
    if (Vector3.new(lastCol.x, 0, lastCol.z) - Vector3.new(first.x, 0, first.z)):Dot(dirCol) < 0 then
        dirCol = -dirCol
    end

    local sumY = 0
    for _, p in ipairs(pts) do sumY += p.y end
    local floorY = sumY / #pts
    local origin = Vector3.new(first.x, floorY, first.z)

    return { origin = origin, dirRow = dirRow, dirCol = dirCol, size = size }
end

-- ---------------------------------------------------------------------------
-- Determine placement grid
-- ---------------------------------------------------------------------------
local grid

-- 1) Use stored grid if available
if getgenv and getgenv().PrinterGrid then
    grid = getgenv().PrinterGrid
    log("Using stored PrinterGrid:", "origin=", tostring(grid.origin), "rowDir=", tostring(grid.dirRow), "colDir=", tostring(grid.colDir))
end

-- 2) Build from existing layout
if not grid and #existingPositions >= 2 then
    local oldGrid = analyzeExistingGrid(existingPositions)
    if oldGrid then
        log("Old grid origin=", tostring(oldGrid.origin), "rowDir=", tostring(oldGrid.dirRow), "colDir=", tostring(oldGrid.dirCol))
        -- New layout is perpendicular: new rows go along old columns, new columns along old rows
        local newDirRow = oldGrid.dirCol
        local newDirCol = oldGrid.dirRow

        -- Find the floor corner from which +newDirRow and +newDirCol go inside the room
        local floorCF = floor and floor.CFrame
        if floor then
            local corners = {}
            local sx, sz = floor.Size.X / 2, floor.Size.Z / 2
            table.insert(corners, floorCF:PointToWorldSpace(Vector3.new(-sx, 0, -sz)))
            table.insert(corners, floorCF:PointToWorldSpace(Vector3.new(sx, 0, -sz)))
            table.insert(corners, floorCF:PointToWorldSpace(Vector3.new(-sx, 0, sz)))
            table.insert(corners, floorCF:PointToWorldSpace(Vector3.new(sx, 0, sz)))

            local function insideScore(corner)
                local toCenter = floorCF.Position - corner
                toCenter = Vector3.new(toCenter.X, 0, toCenter.Z)
                return (toCenter.Unit:Dot(newDirRow) > 0.5 and 1 or 0) + (toCenter.Unit:Dot(newDirCol) > 0.5 and 1 or 0)
            end

            local bestCorner = corners[1]
            local bestScore = insideScore(bestCorner)
            for i = 2, #corners do
                local s = insideScore(corners[i])
                if s > bestScore then
                    bestScore = s
                    bestCorner = corners[i]
                end
            end

            local startPos = bestCorner + newDirRow * (size / 2) + newDirCol * (size / 2)
            grid = { origin = startPos, dirRow = newDirRow, dirCol = newDirCol, size = size }
            log("New grid start corner=", tostring(bestCorner), "startPos=", tostring(startPos))
        else
            -- No floor: use old origin and rotate
            grid = { origin = oldGrid.origin, dirRow = newDirRow, dirCol = newDirCol, size = size }
        end
    end
end

-- 3) Fallback to player orientation + wall raycasts
if not grid then
    log("No existing/stored grid; using player orientation. Stand in the corner, look along first-row wall, right side into room.")
    local hrp = getHrp()
    if not hrp then
        log("ERROR: HRP not found")
        copy()
        return
    end
    local cf = hrp.CFrame
    local rowDir = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z).Unit
    local colDir = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z).Unit
    if rowDir.Magnitude < 0.001 or colDir.Magnitude < 0.001 then
        rowDir = Vector3.new(0, 0, -1)
        colDir = Vector3.new(1, 0, 0)
    end

    local function rayDist(origin, dir)
        local params
        pcall(function()
            local p = RaycastParams.new()
            p.FilterType = Enum.RaycastFilterType.Blacklist
            p.FilterDescendantsInstances = { getCharacter(), folder }
            params = p
        end)
        local r
        pcall(function() r = Workspace:Raycast(origin + Vector3.new(0, 2, 0), dir * 200, params) end)
        return r and (r.Position - origin).Magnitude or nil
    end

    local dRowBack = rayDist(hrp.Position, -rowDir) or 0
    local dColBack = rayDist(hrp.Position, -colDir) or 0
    local startPos = hrp.Position + rowDir * (-dRowBack + size / 2) + colDir * (-dColBack + size / 2)
    grid = { origin = startPos, dirRow = rowDir, dirCol = colDir, size = size }
    log("Player fallback startPos=", tostring(startPos))
end

-- Store for next runs
if getgenv then
    getgenv().PrinterGrid = grid
    log("Stored grid in getgenv().PrinterGrid")
end

-- ---------------------------------------------------------------------------
-- Compute rows/cols from floor bounds
-- ---------------------------------------------------------------------------
local rowSpacing = math.max(size - ROW_OVERLAP, 0.1)
local colSpacing = size

local maxCols, maxRows = 9999, 9999
if floor then
    local floorCF = floor.CFrame
    local halfX, halfZ = floor.Size.X / 2, floor.Size.Z / 2
    local corners = {}
    table.insert(corners, floorCF:PointToWorldSpace(Vector3.new(-halfX, 0, -halfZ)))
    table.insert(corners, floorCF:PointToWorldSpace(Vector3.new(halfX, 0, -halfZ)))
    table.insert(corners, floorCF:PointToWorldSpace(Vector3.new(-halfX, 0, halfZ)))
    table.insert(corners, floorCF:PointToWorldSpace(Vector3.new(halfX, 0, halfZ)))

    -- Project corners onto grid axes to get min/max along each axis
    local rowDists, colDists = {}, {}
    for _, corner in ipairs(corners) do
        local toCorner = corner - grid.origin
        toCorner = Vector3.new(toCorner.X, 0, toCorner.Z)
        table.insert(rowDists, toCorner:Dot(grid.dirRow))
        table.insert(colDists, toCorner:Dot(grid.dirCol))
    end
    table.sort(rowDists)
    table.sort(colDists)
    local rowRange = rowDists[#rowDists] - rowDists[1]
    local colRange = colDists[#colDists] - colDists[1]
    -- Subtract printer size because we offset by half size from both walls
    local usableRow = math.max(0, rowRange - size)
    local usableCol = math.max(0, colRange - size)
    maxCols = math.max(1, math.floor(usableRow / rowSpacing) + 1)
    maxRows = math.max(1, math.floor(usableCol / colSpacing) + 1)
    log("Floor usable row/col lengths:", tostring(usableRow), "/", tostring(usableCol))
    log("Max cols/rows:", tostring(maxCols), "/", tostring(maxRows))
end

local totalToPlace = math.min(backpackCount, maxCols * maxRows, MAX_PRINTERS)
log("Will place:", tostring(totalToPlace))

-- ---------------------------------------------------------------------------
-- Placement
-- ---------------------------------------------------------------------------
local function countRealPrinters()
    local n = 0
    for _, c in ipairs(folder:GetChildren()) do
        if c:IsA("Model") and c:GetAttribute("MoneyPrinterId") then n += 1 end
    end
    return n
end

local realNow = countRealPrinters()
local placed = 0
local failed = 0
local errors = {}

for i = 1, totalToPlace do
    log("\n--- Slot", tostring(i), "of", tostring(totalToPlace), "---")

    local tool = takePrinterFromBackpack()
    if not tool then
        log("No more tools")
        break
    end

    local col = (i - 1) % maxCols
    local row = math.floor((i - 1) / maxCols)
    local targetPos = grid.origin + grid.dirRow * (col * rowSpacing) + grid.dirCol * (row * colSpacing)
    log("Target pos:", tostring(round3(targetPos)))

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
            local newCount = countRealPrinters()
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
        table.insert(errors, { slot = i, pos = tostring(round3(targetPos)), error = msg })
        pcall(function() tool.Parent = player.Backpack end)
    end

    task.wait(0.1)
end

log("\n--- RESULTS ---")
log("Placed:", tostring(placed))
log("Failed:", tostring(failed))
log("Final real printers:", tostring(countRealPrinters()))
log("Remaining backpack:", tostring(countBackpackPrinters()))
log("Stored origin:", tostring(grid.origin))
log("Stored rowDir:", tostring(grid.dirRow))
log("Stored colDir:", tostring(grid.dirCol))
log("========== END ==========")
copy()
