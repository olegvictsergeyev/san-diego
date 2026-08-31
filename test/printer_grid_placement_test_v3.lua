--[[
    San Diego Agent — Standalone test v3: place all printers from top-left corner
    =============================================================================
    Автономный скрипт для тестирования расстановки всех принтеров.
    - Если в комнате уже стоят принтеры — продолжает сетку (как v2).
    - Если в комнате пусто — начинает с "крайнего левого верхнего угла" пола
      (локальные координаты -X, -Z относительно пола) и заполняет
      рядами вправо и вниз.
    - Определяет комнату игрока по полу, на котором стоит персонаж.
    - Защита от последствий предыдущих запусков.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local logs = {}

local function log(...)
    local msg = table.concat({ ... }, " ")
    table.insert(logs, msg)
    print(msg)
    warn(msg)
end

local function copy()
    local text = table.concat(logs, "\n")
    if setclipboard then pcall(function() setclipboard(text) end) end
    if writefile then pcall(function() writefile("printer_grid_test_v3_log.txt", text) end) end
end

local PRINTER_NAME = "Money Printer"
local MAX_PRINTERS = 50
local PLACE_DELAY = 0.6
local SAFETY_MAX_DIST_FROM_PLAYER = 200
local FLOOR_MARGIN = 2
local DEFAULT_SPACING = 4

-- ============================================================================
-- Вспомогательные функции
-- ============================================================================

local function getCharacter()
    return player.Character or player.CharacterAdded:Wait()
end

local function getHumanoid()
    local char = getCharacter()
    return char:FindFirstChildOfClass("Humanoid")
end

local function getHrp()
    local char = getCharacter()
    return char:FindFirstChild("HumanoidRootPart")
end

local function getPlayerPos()
    local hrp = getHrp()
    return hrp and hrp.Position or nil
end

local function round(num, decimals)
    local d = 10 ^ (decimals or 0)
    return math.floor(num * d + 0.5) / d
end

local function resetInventory()
    local char = getCharacter()
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return end
    for _, c in ipairs(char:GetChildren()) do
        if c:IsA("Tool") then
            pcall(function() c.Parent = backpack end)
        end
    end
    pcall(function()
        local humanoid = getHumanoid()
        if humanoid then humanoid:UnequipTools() end
    end)
    task.wait(0.3)
    local function scan(parent)
        for _, c in ipairs(parent:GetChildren()) do
            if c:IsA("Tool") and c.Name:lower():find("print") then
                local inMoneyPrinters = false
                local p = c.Parent
                while p do
                    if p.Name == "MoneyPrinters" then
                        inMoneyPrinters = true
                        break
                    end
                    p = p.Parent
                end
                if not inMoneyPrinters then
                    log("[Reset] Returning stray Tool in Workspace to Backpack:", c:GetFullName())
                    pcall(function() c.Parent = backpack end)
                end
            end
            if not c:IsA("BasePart") then scan(c) end
        end
    end
    scan(Workspace)
    task.wait(0.2)
end

local function countPrintersInBackpack()
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return 0 end
    local count = 0
    for _, c in ipairs(backpack:GetChildren()) do
        if c:IsA("Tool") and c.Name:lower():find("print") then count += 1 end
    end
    return count
end

local function takePrinterFromBackpack()
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return nil end
    for _, c in ipairs(backpack:GetChildren()) do
        if c:IsA("Tool") and c.Name:lower():find("print") then return c end
    end
    return nil
end

local function getToolSpacing(tool)
    if not tool then return DEFAULT_SPACING end
    local part = tool:FindFirstChild("Printer_d") or tool:FindFirstChild("Handle")
    if part and part:IsA("BasePart") then
        local size = part.Size
        local maxSize = math.max(size.X, size.Z)
        return maxSize + 0.5
    end
    return DEFAULT_SPACING
end

-- ============================================================================
-- Поиск комнаты и пола
-- ============================================================================

local function findMoneyPrintersFolders()
    local folders = {}
    local function scan(parent)
        for _, c in ipairs(parent:GetChildren()) do
            if c.Name == "MoneyPrinters" and (c:IsA("Folder") or c:IsA("Model")) then
                table.insert(folders, c)
            end
            if not c:IsA("BasePart") then scan(c) end
        end
    end
    scan(Workspace)
    return folders
end

local function findFloorInUnit(unit)
    if not unit then return nil end
    local best = nil
    local bestArea = 0
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

local function isPlayerOnFloor(playerPos, floor)
    if not floor then return false end
    local cf = floor.CFrame
    local size = floor.Size
    local localPos = cf:PointToObjectSpace(playerPos)
    local halfX = size.X / 2
    local halfZ = size.Z / 2
    local halfY = size.Y / 2
    -- Небольшой допуск по высоте, чтобы считать, что персонаж стоит на полу или рядом.
    return math.abs(localPos.Y) <= halfY + 8
        and localPos.X >= -halfX - 1 and localPos.X <= halfX + 1
        and localPos.Z >= -halfZ - 1 and localPos.Z <= halfZ + 1
end

local function getFloorCorners(floor)
    if not floor then return nil end
    local cf = floor.CFrame
    local size = floor.Size
    local half = size / 2
    local corners = {
        cf * CFrame.new(-half.X, 0, -half.Z),
        cf * CFrame.new(half.X, 0, -half.Z),
        cf * CFrame.new(-half.X, 0, half.Z),
        cf * CFrame.new(half.X, 0, half.Z),
    }
    return corners
end

local function chooseTargetFolder()
    local playerPos = getPlayerPos()
    if not playerPos then return nil, nil end

    local folders = findMoneyPrintersFolders()
    if #folders == 0 then return nil, nil end

    -- Сначала ищем папку в юните, на полу которого стоит персонаж.
    for _, folder in ipairs(folders) do
        local unit = folder.Parent
        local floor = findFloorInUnit(unit)
        if floor and isPlayerOnFloor(playerPos, floor) then
            log("[ChooseFolder] Player is on floor of", folder:GetFullName())
            return folder, #getExistingPrinterPositions(folder)
        end
    end

    -- Если не нашли — берём ближайшую к персонажу папку (по принтерам или по центру юнита).
    local scored = {}
    for _, folder in ipairs(folders) do
        local unit = folder.Parent
        local floor = findFloorInUnit(unit)
        local dist = math.huge
        local positions = getExistingPrinterPositions(folder)
        for _, pos in ipairs(positions) do
            local d = (pos - playerPos).Magnitude
            if d < dist then dist = d end
        end
        if dist == math.huge and floor then
            dist = (floor.Position - playerPos).Magnitude
        end
        log("[Folder]", folder:GetFullName(), "existing=", tostring(#positions), "dist=", round(dist, 1))
        table.insert(scored, { folder = folder, dist = dist })
    end
    table.sort(scored, function(a, b) return a.dist < b.dist end)

    local best = scored[1]
    if best.dist > SAFETY_MAX_DIST_FROM_PLAYER then
        log("[ChooseFolder] Best folder too far:", round(best.dist, 1))
        return nil, nil
    end
    return best.folder, #getExistingPrinterPositions(best.folder)
end

-- ============================================================================
-- Анализ сетки / определение начальной позиции
-- ============================================================================

local function getExistingPrinterPositions(folder)
    local positions = {}
    for _, c in ipairs(folder:GetChildren()) do
        if c.Name:lower():find("print") then
            local part = c:FindFirstChild("Printer_d") or c:FindFirstChild("Handle")
            if part and part:IsA("BasePart") then
                table.insert(positions, part.Position)
            end
        end
    end
    return positions
end

local function clusterBy(points, tolerance, axis)
    local clusters = {}
    local sorted = {}
    for _, p in ipairs(points) do table.insert(sorted, p) end
    table.sort(sorted, function(a, b) return a[axis] < b[axis] end)
    for _, p in ipairs(sorted) do
        local added = false
        for _, c in ipairs(clusters) do
            if math.abs(c.center - p[axis]) <= tolerance then
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

local function analyzeGrid(positions)
    if #positions == 0 then return nil end

    local pts = {}
    for _, p in ipairs(positions) do
        table.insert(pts, { x = p.X, z = p.Z, y = p.Y })
    end

    local tolerance = 1.5
    local clustersX = clusterBy(pts, tolerance, "x")
    local clustersZ = clusterBy(pts, tolerance, "z")

    local rowAxis, colAxis
    if #clustersX >= #clustersZ then
        rowAxis = "z"
        colAxis = "x"
    else
        rowAxis = "x"
        colAxis = "z"
    end

    local rows = clusterBy(pts, tolerance, rowAxis)
    table.sort(rows, function(a, b) return a.center < b.center end)
    for _, row in ipairs(rows) do
        table.sort(row.points, function(a, b) return a[colAxis] < b[colAxis] end)
    end

    local colDists = {}
    for _, row in ipairs(rows) do
        for i = 2, #row.points do
            table.insert(colDists, math.abs(row.points[i][colAxis] - row.points[i - 1][colAxis]))
        end
    end
    local colSpacing = nil
    if #colDists > 0 then
        table.sort(colDists)
        colSpacing = colDists[math.floor(#colDists / 2) + 1]
    end

    local rowDists = {}
    for i = 2, #rows do
        table.insert(rowDists, math.abs(rows[i].center - rows[i - 1].center))
    end
    local rowSpacing = nil
    if #rowDists > 0 then
        table.sort(rowDists)
        rowSpacing = rowDists[math.floor(#rowDists / 2) + 1]
    end

    if not colSpacing or colSpacing <= 0 then colSpacing = DEFAULT_SPACING end
    if not rowSpacing or rowSpacing <= 0 then rowSpacing = DEFAULT_SPACING end

    local sumY = 0
    for _, p in ipairs(pts) do sumY += p.y end
    local floorY = sumY / #pts

    local dirRow = (rowAxis == "x") and Vector3.new(1, 0, 0) or Vector3.new(0, 0, 1)
    local dirCol = (colAxis == "x") and Vector3.new(1, 0, 0) or Vector3.new(0, 0, 1)
    local firstPoint = rows[1].points[1]
    local origin = Vector3.new(firstPoint.x, floorY, firstPoint.z)

    return {
        existingCount = #positions,
        origin = origin,
        dirRow = dirRow,
        dirCol = dirCol,
        rowSpacing = rowSpacing,
        colSpacing = colSpacing,
        printersPerRow = #rows[1].points,
        rowCount = #rows,
        rows = rows,
    }
end

local function buildGridFromFloor(floor, spacing)
    local size = floor.Size
    local cf = floor.CFrame

    -- Локальный "левый верхний" угол: -X, -Z относительно пола.
    local originCf = cf * CFrame.new(-size.X / 2 + FLOOR_MARGIN, 0, -size.Z / 2 + FLOOR_MARGIN)
    local origin = originCf.Position

    -- Направление вправо = +X локальный = RightVector.
    local dirCol = cf.RightVector
    -- Направление вниз = +Z локальный = -LookVector.
    local dirRow = -cf.LookVector

    local usableX = size.X - 2 * FLOOR_MARGIN
    local usableZ = size.Z - 2 * FLOOR_MARGIN
    local printersPerRow = math.max(1, math.floor(usableX / spacing))
    local maxRows = math.max(1, math.floor(usableZ / spacing))

    return {
        existingCount = 0,
        origin = origin,
        dirRow = dirRow,
        dirCol = dirCol,
        rowSpacing = spacing,
        colSpacing = spacing,
        printersPerRow = printersPerRow,
        maxRows = maxRows,
    }
end

local function generateSlots(grid, maxCount)
    local slots = {}
    local function key(pos)
        return tostring(round(pos.X / 0.5)) .. "," .. tostring(round(pos.Z / 0.5))
    end
    local occupied = {}

    -- Отмечаем уже занятые позиции.
    for _, row in ipairs(grid.rows or {}) do
        for _, p in ipairs(row.points) do
            occupied[key(Vector3.new(p.x, p.y, p.z))] = true
        end
    end

    local placed = grid.existingCount
    local index = 0
    local safety = maxCount * 10

    while placed < maxCount do
        if index > safety then
            log("[GenerateSlots] Loop protection triggered")
            break
        end

        local rowIndex = math.floor(index / grid.printersPerRow)
        local colIndex = index % grid.printersPerRow

        if grid.maxRows and rowIndex >= grid.maxRows then
            log("[GenerateSlots] Reached maxRows limit:", tostring(grid.maxRows))
            break
        end

        local pos = grid.origin + grid.dirCol * (colIndex * grid.colSpacing) + grid.dirRow * (rowIndex * grid.rowSpacing)
        local k = key(pos)
        if not occupied[k] then
            table.insert(slots, pos)
            occupied[k] = true
            placed += 1
        end

        index += 1
    end

    return slots
end

-- ============================================================================
-- Размещение одного принтера
-- ============================================================================

local function placePrinterAt(tool, folder, position)
    local char = getCharacter()
    local humanoid = getHumanoid()
    local backpack = player:FindFirstChild("Backpack")
    if not humanoid then return false, "no humanoid" end
    if not backpack then return false, "no backpack" end

    pcall(function() humanoid:UnequipTools() end)
    task.wait(0.2)

    local ok, err = pcall(function()
        tool.Parent = char
        task.wait(0.3)
        humanoid:UnequipTools()
        task.wait(0.3)
        tool.Parent = folder
        local handle = tool:FindFirstChild("Handle")
        local printerD = tool:FindFirstChild("Printer_d")
        if handle and handle:IsA("BasePart") then
            handle.CFrame = CFrame.new(position)
            handle.Anchored = true
            handle.CanCollide = true
        end
        if printerD and printerD:IsA("BasePart") then
            printerD.CFrame = CFrame.new(position)
            printerD.Anchored = true
            printerD.CanCollide = true
        end
    end)

    if not ok then return false, tostring(err) end
    task.wait(0.3)
    return tool:IsDescendantOf(folder), "not in folder after place"
end

-- ============================================================================
-- Основной цикл
-- ============================================================================

log("========== PRINTER GRID PLACEMENT TEST v3 ==========")
log("Player:", player.Name)
log("Start time:", tostring(tick()))

resetInventory()

local backpackCount = countPrintersInBackpack()
log("Printers in backpack at start:", tostring(backpackCount))

if backpackCount == 0 then
    log("ERROR: No printers in backpack")
    copy()
    return
end

local folder, existingCount = chooseTargetFolder()
if not folder then
    log("ERROR: Could not find suitable MoneyPrinters folder")
    copy()
    return
end

local unit = folder.Parent
local floor = findFloorInUnit(unit)
if floor then
    log("Floor found:", floor.Name, "size=", tostring(floor.Size), "pos=", tostring(floor.Position))
else
    log("WARNING: No floor found in unit", unit and unit.Name or "nil")
end

log("Target folder:", folder:GetFullName(), "existing printers:", tostring(existingCount))

local positions = getExistingPrinterPositions(folder)
log("Existing printer positions:", tostring(#positions))

local spacingTool = takePrinterFromBackpack()
local spacing = spacingTool and getToolSpacing(spacingTool) or DEFAULT_SPACING
if spacingTool then
    -- Вернём обратно, пока не начали расстановку.
    pcall(function() spacingTool.Parent = player.Backpack end)
end
log("Printer spacing:", round(spacing, 2))

local grid
if #positions > 0 then
    grid = analyzeGrid(positions)
    if grid then
        log("Using existing grid:")
        log("  origin:", tostring(grid.origin))
        log("  rowSpacing:", round(grid.rowSpacing, 2), "colSpacing:", round(grid.colSpacing, 2))
        log("  printersPerRow:", tostring(grid.printersPerRow))
    end
else
    if not floor then
        log("ERROR: No existing printers and no floor found; cannot determine placement area")
        copy()
        return
    end
    grid = buildGridFromFloor(floor, spacing)
    log("Using floor-based grid (top-left corner):")
    log("  origin:", tostring(grid.origin))
    log("  dirRow:", tostring(grid.dirRow))
    log("  dirCol:", tostring(grid.dirCol))
    log("  printersPerRow:", tostring(grid.printersPerRow), "maxRows:", tostring(grid.maxRows))
end

if not grid then
    log("ERROR: Could not build grid")
    copy()
    return
end

local targetCount = math.min(grid.existingCount + backpackCount, MAX_PRINTERS)
if grid.maxRows then
    local capacity = grid.maxRows * grid.printersPerRow
    targetCount = math.min(targetCount, capacity)
end
log("Target total printers:", tostring(targetCount))

local slots = generateSlots(grid, targetCount)
log("Slots to fill:", tostring(#slots))

local results = {
    placed = 0,
    failed = 0,
    skippedNoPrinter = 0,
    errors = {},
}

for i, pos in ipairs(slots) do
    log("\n--- Slot", tostring(i), "/", tostring(#slots), "pos=", tostring(pos), "---")

    local tool = takePrinterFromBackpack()
    if not tool then
        log("No more printers in backpack")
        results.skippedNoPrinter += 1
        break
    end

    local ok, err = placePrinterAt(tool, folder, pos)
    if ok then
        log("Placed successfully:", tool.Name, "->", tool:GetFullName())
        results.placed += 1
    else
        log("FAILED to place:", tostring(err))
        results.failed += 1
        table.insert(results.errors, { slot = i, pos = { x = pos.X, y = pos.Y, z = pos.Z }, error = tostring(err) })
        pcall(function() tool.Parent = player.Backpack end)
    end

    task.wait(PLACE_DELAY)
end

resetInventory()

local finalBackpackCount = countPrintersInBackpack()
log("\n--- Results ---")
log("Placed:", tostring(results.placed))
log("Failed:", tostring(results.failed))
log("Skipped (no printer):", tostring(results.skippedNoPrinter))
log("Remaining in backpack:", tostring(finalBackpackCount))

local finalPositions = getExistingPrinterPositions(folder)
log("Total printers in folder after:", tostring(#finalPositions))

log("\n========== JSON SUMMARY ==========")
local summary = {
    player = player.Name,
    userId = player.UserId,
    targetFolder = folder:GetFullName(),
    startBackpack = backpackCount,
    spacing = round(spacing, 2),
    grid = {
        origin = { x = round(grid.origin.X, 2), y = round(grid.origin.Y, 2), z = round(grid.origin.Z, 2) },
        printersPerRow = grid.printersPerRow,
        rowSpacing = grid.rowSpacing and round(grid.rowSpacing, 2) or nil,
        colSpacing = grid.colSpacing and round(grid.colSpacing, 2) or nil,
        maxRows = grid.maxRows,
        existingCount = grid.existingCount,
    },
    results = results,
    finalTotal = #finalPositions,
    finalBackpack = finalBackpackCount,
}
local ok, json = pcall(function() return HttpService:JSONEncode(summary) end)
if ok then
    log(json)
    if setclipboard then pcall(function() setclipboard(json) end) end
else
    log("JSON error:", tostring(json))
end

log("========== END TEST v3 ==========")
copy()
