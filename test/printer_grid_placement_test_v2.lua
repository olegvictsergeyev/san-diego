--[[
    San Diego Agent — Standalone test v2: place all printers in apartment grid
    =======================================================================
    Исправлен выбор папки MoneyPrinters: расстояние считается до ближайшего
    уже стоящего принтера в папке, а не до центральной части квартиры.
    Это позволяет работать, даже если игрок стоит рядом с принтерами,
    но далеко от центральной части Unit'а.
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
    if writefile then pcall(function() writefile("printer_grid_test_v2_log.txt", text) end) end
end

local PRINTER_NAME = "Money Printer"
local MAX_PRINTERS = 50
local PLACE_DELAY = 0.6
local SAFETY_MAX_DIST_FROM_PLAYER = 200

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
    task.wait(0.3)
    local function scan(parent)
        for _, c in ipairs(parent:GetChildren()) do
            if c:IsA("Tool") and c.Name == PRINTER_NAME then
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
        if c:IsA("Tool") and c.Name == PRINTER_NAME then count += 1 end
    end
    return count
end

local function takePrinterFromBackpack()
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return nil end
    for _, c in ipairs(backpack:GetChildren()) do
        if c:IsA("Tool") and c.Name == PRINTER_NAME then return c end
    end
    return nil
end

-- ============================================================================
-- Поиск целевой папки MoneyPrinters
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

local function getExistingPrinterPositions(folder)
    local positions = {}
    for _, c in ipairs(folder:GetChildren()) do
        if c.Name == PRINTER_NAME then
            local part = c:FindFirstChild("Printer_d") or c:FindFirstChild("Handle")
            if part and part:IsA("BasePart") then
                table.insert(positions, part.Position)
            end
        end
    end
    return positions
end

local function chooseTargetFolder()
    local playerPos = getPlayerPos()
    if not playerPos then return nil, nil end
    local folders = findMoneyPrintersFolders()
    if #folders == 0 then return nil, nil end

    local scored = {}
    for _, folder in ipairs(folders) do
        local existingPositions = getExistingPrinterPositions(folder)
        local existingCount = #existingPositions
        local dist = math.huge

        if existingCount > 0 then
            -- Расстояние до ближайшего уже стоящего принтера.
            for _, pos in ipairs(existingPositions) do
                local d = (pos - playerPos).Magnitude
                if d < dist then dist = d end
            end
        else
            -- Если папка пустая, используем позицию родительской части.
            local function findPart(p)
                for _, cc in ipairs(p:GetChildren()) do
                    if cc:IsA("BasePart") then return cc.Position end
                    local f = findPart(cc)
                    if f then return f end
                end
                return nil
            end
            local pos = findPart(folder.Parent)
            if pos then dist = (pos - playerPos).Magnitude end
        end

        log("[Folder]", folder:GetFullName(), "existing=", tostring(existingCount), "dist=", round(dist, 1))

        -- Скор: ближе к существующим принтерам лучше; пустые папки штрафуются.
        local score = dist - existingCount * 20
        table.insert(scored, { folder = folder, dist = dist, existing = existingCount, score = score })
    end
    table.sort(scored, function(a, b) return a.score < b.score end)

    local best = scored[1]
    if best.dist > SAFETY_MAX_DIST_FROM_PLAYER then
        log("[ChooseFolder] Best folder too far:", round(best.dist, 1))
        return nil, nil
    end
    return best.folder, best.existing
end

-- ============================================================================
-- Анализ сетки существующих принтеров
-- ============================================================================

local function analyzeGrid(positions)
    if #positions == 0 then return nil, "no existing printers" end

    local pts = {}
    for _, p in ipairs(positions) do
        table.insert(pts, { x = p.X, z = p.Z, y = p.Y })
    end

    local function clusterBy(tolerance, axis)
        local clusters = {}
        local sorted = {}
        for _, p in ipairs(pts) do table.insert(sorted, p) end
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

    local tolerance = 1.5
    local clustersX = clusterBy(tolerance, "x")
    local clustersZ = clusterBy(tolerance, "z")

    local rowAxis, colAxis
    if #clustersX >= #clustersZ then
        rowAxis = "z"
        colAxis = "x"
    else
        rowAxis = "x"
        colAxis = "z"
    end

    local rows = clusterBy(tolerance, rowAxis)
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

    if not colSpacing or colSpacing <= 0 then colSpacing = 4 end
    if not rowSpacing or rowSpacing <= 0 then rowSpacing = 4 end

    local sumY = 0
    for _, p in ipairs(pts) do sumY += p.y end
    local floorY = sumY / #pts

    local dirRow = (rowAxis == "x") and Vector3.new(1, 0, 0) or Vector3.new(0, 0, 1)
    local dirCol = (colAxis == "x") and Vector3.new(1, 0, 0) or Vector3.new(0, 0, 1)
    local firstPoint = rows[1].points[1]
    local origin = Vector3.new(firstPoint.x, floorY, firstPoint.z)

    return {
        rows = rows,
        rowAxis = rowAxis,
        colAxis = colAxis,
        rowSpacing = rowSpacing,
        colSpacing = colSpacing,
        origin = origin,
        dirRow = dirRow,
        dirCol = dirCol,
        floorY = floorY,
        printersPerRow = #rows[1].points,
        rowCount = #rows,
        existingCount = #positions,
    }
end

local function generateNextSlots(grid, maxCount)
    local slots = {}
    local occupied = {}
    local function key(pos)
        return tostring(round(pos.X / 0.5)) .. "," .. tostring(round(pos.Z / 0.5))
    end
    for _, row in ipairs(grid.rows) do
        for _, p in ipairs(row.points) do
            occupied[key(Vector3.new(p.x, p.y, p.z))] = true
        end
    end

    local placed = grid.existingCount
    local rowIndex = 0
    local colIndex = 0

    while placed < maxCount do
        local lastRow = grid.rows[#grid.rows]
        local lastRowLen = #lastRow.points
        if lastRowLen < grid.printersPerRow then
            rowIndex = grid.rowCount - 1
            colIndex = lastRowLen
        else
            rowIndex = grid.rowCount
            colIndex = 0
        end

        local pos = grid.origin + grid.dirCol * (colIndex * grid.colSpacing) + grid.dirRow * (rowIndex * grid.rowSpacing)
        local k = key(pos)
        if occupied[k] then
            colIndex += 1
            if colIndex >= grid.printersPerRow then
                rowIndex += 1
                colIndex = 0
            end
            placed += 1
        else
            table.insert(slots, pos)
            occupied[k] = true
            placed += 1
        end
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

log("========== PRINTER GRID PLACEMENT TEST v2 ==========")
log("Player:", player.Name)
log("Start time:", tostring(tick()))

resetInventory()

local backpackCount = countPrintersInBackpack()
log("Printers in backpack at start:", tostring(backpackCount))

local folder, existingCount = chooseTargetFolder()
if not folder then
    log("ERROR: Could not find suitable MoneyPrinters folder")
    copy()
    return
end
log("Target folder:", folder:GetFullName(), "existing printers:", tostring(existingCount))

local positions = getExistingPrinterPositions(folder)
log("Existing printer positions:", tostring(#positions))

local grid, err = analyzeGrid(positions)
if not grid then
    log("ERROR: Failed to analyze grid:", tostring(err))
    copy()
    return
end

log("Grid analysis:")
log("  rowAxis:", grid.rowAxis, "colAxis:", grid.colAxis)
log("  rowSpacing:", round(grid.rowSpacing, 2), "colSpacing:", round(grid.colSpacing, 2))
log("  origin:", tostring(grid.origin))
log("  floorY:", round(grid.floorY, 2))
log("  printersPerRow:", tostring(grid.printersPerRow), "rowCount:", tostring(grid.rowCount))

local targetCount = math.min(grid.existingCount + backpackCount, MAX_PRINTERS)
log("Target total printers:", tostring(targetCount), "(existing + backpack, capped at 50)")

local slots = generateNextSlots(grid, targetCount)
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
    grid = {
        rowAxis = grid.rowAxis,
        colAxis = grid.colAxis,
        rowSpacing = round(grid.rowSpacing, 2),
        colSpacing = round(grid.colSpacing, 2),
        origin = { x = round(grid.origin.X, 2), y = round(grid.origin.Y, 2), z = round(grid.origin.Z, 2) },
        printersPerRow = grid.printersPerRow,
        rowCount = grid.rowCount,
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

log("========== END TEST v2 ==========")
copy()
