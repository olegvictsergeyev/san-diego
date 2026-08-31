--[[
    San Diego Agent — Standalone test v3.3: tighter rows + printer-size margins
    ========================================================================
    - Ряды расставляются на расстоянии = размер принтера + небольшой зазор.
    - Отступ от краёв комнаты = размер принтера.
    - Для пустой комнаты: сетка заполняет пол целиком с этими отступами.
    - Для существующей сетки: продолжает с тем же шагом (не DEFAULT_SPACING).
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local logs = {}

local function log(...)
    local parts = {}
    for _, v in ipairs({ ... }) do
        table.insert(parts, tostring(v))
    end
    local msg = "[" .. os.date("%H:%M:%S") .. "] " .. table.concat(parts, " ")
    table.insert(logs, msg)
    print(msg)
    warn(msg)
end

local function logError(label, err)
    log("[ERROR " .. tostring(label) .. "]: " .. tostring(err))
end

local function copy()
    local text = table.concat(logs, "\n")
    if setclipboard then pcall(function() setclipboard(text) end) end
    if writefile then pcall(function() writefile("printer_grid_test_v3_3_log.txt", text) end) end
end

local PRINTER_NAME = "Money Printer"
local MAX_PRINTERS = 50
local PLACE_DELAY = 0.6
local DEFAULT_SPACING = 4
local RAYCAST_DOWN_DISTANCE = 50

-- ============================================================================
-- Вспомогательные функции
-- ============================================================================

local function getCharacter()
    local char = player.Character
    if char then return char end
    log("[getCharacter] waiting for CharacterAdded...")
    return player.CharacterAdded:Wait()
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
    return hrp and hrp.Position
end

local function round(num, decimals)
    local d = 10 ^ (decimals or 0)
    return math.floor(num * d + 0.5) / d
end

local function resetInventory()
    log("[resetInventory] start")
    local char = getCharacter()
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then
        log("[resetInventory] no backpack")
        return
    end
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
    local function scan(parent, depth)
        if depth > 4 then return end
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
                    log("[Reset] Returning stray Tool to Backpack:", c:GetFullName())
                    pcall(function() c.Parent = backpack end)
                end
            end
            if not c:IsA("BasePart") then scan(c, depth + 1) end
        end
    end
    scan(Workspace, 0)
    task.wait(0.2)
    log("[resetInventory] done")
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
        local s = maxSize + 0.5
        log("[getToolSpacing] part size=", tostring(size), "spacing=", s)
        return s
    end
    return DEFAULT_SPACING
end

-- ============================================================================
-- Поиск комнаты через raycast
-- ============================================================================

local function findMoneyPrintersFolders()
    log("[findMoneyPrintersFolders] scanning workspace...")
    local folders = {}
    local seen = {}
    local function scan(parent, depth)
        if depth > 8 then return end
        for _, c in ipairs(parent:GetChildren()) do
            if c.Name == "MoneyPrinters" and not seen[c] and
               (c:IsA("Folder") or c:IsA("Model") or c:IsA("Configuration")) then
                seen[c] = true
                log("[findMoneyPrintersFolders] found:", c:GetFullName())
                table.insert(folders, c)
            end
            if not c:IsA("BasePart") then scan(c, depth + 1) end
        end
    end
    scan(Workspace, 0)
    log("[findMoneyPrintersFolders] total unique:", tostring(#folders))
    return folders
end

local function raycastDownFromPlayer()
    local playerPos = getPlayerPos()
    if not playerPos then
        log("[raycastDownFromPlayer] no player position")
        return nil
    end
    local char = getCharacter()
    local params = nil
    local ok, res = pcall(function()
        local p = RaycastParams.new()
        p.FilterType = Enum.RaycastFilterType.Blacklist
        p.FilterDescendantsInstances = { char }
        return p
    end)
    if not ok or not res then
        log("[raycastDownFromPlayer] RaycastParams not supported, falling back")
        return nil
    end
    params = res

    local origin = playerPos + Vector3.new(0, 5, 0)
    local direction = Vector3.new(0, -RAYCAST_DOWN_DISTANCE, 0)
    log("[raycastDownFromPlayer] from=", tostring(origin), "dir=", tostring(direction))

    local result = nil
    local ok2, err = pcall(function()
        result = Workspace:Raycast(origin, direction, params)
    end)
    if not ok2 then
        logError("raycast", err)
        return nil
    end
    if result and result.Instance then
        log("[raycastDownFromPlayer] hit=", result.Instance:GetFullName(), "pos=", tostring(result.Position))
        return result.Instance
    end
    log("[raycastDownFromPlayer] no hit")
    return nil
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

local function chooseTargetFolder()
    log("[chooseTargetFolder] start")

    local folders = findMoneyPrintersFolders()
    if #folders == 0 then
        log("[chooseTargetFolder] no MoneyPrinters folders found")
        return nil, nil
    end

    log("[chooseTargetFolder] trying raycast method")
    local hitPart = raycastDownFromPlayer()
    if hitPart then
        local unit = hitPart.Parent
        local depth = 0
        while unit and depth < 10 do
            local mp = findMoneyPrintersFolderInUnit(unit)
            if mp then
                log("[chooseTargetFolder] raycast found unit=", unit.Name, "folder=", mp:GetFullName())
                return mp, #getExistingPrinterPositions(mp)
            end
            unit = unit.Parent
            depth = depth + 1
        end
        log("[chooseTargetFolder] raycast hit but no MoneyPrinters in ancestors of", hitPart:GetFullName())
    end

    log("[chooseTargetFolder] trying player-on-floor method")
    local playerPos = getPlayerPos()
    if playerPos then
        for _, folder in ipairs(folders) do
            local unit = folder.Parent
            if unit then
                local floor = findFloorInUnit(unit)
                if floor then
                    local cf = floor.CFrame
                    local size = floor.Size
                    local localPos = cf:PointToObjectSpace(playerPos)
                    local halfX = size.X / 2
                    local halfZ = size.Z / 2
                    local halfY = size.Y / 2
                    local onFloor = math.abs(localPos.Y) <= halfY + 10
                        and localPos.X >= -halfX - 1 and localPos.X <= halfX + 1
                        and localPos.Z >= -halfZ - 1 and localPos.Z <= halfZ + 1
                    log("[chooseTargetFolder] folder=", folder:GetFullName(), "floor=", floor.Name,
                        "local=", tostring(localPos), "onFloor=", tostring(onFloor))
                    if onFloor then
                        return folder, #getExistingPrinterPositions(folder)
                    end
                end
            end
        end
    end

    log("[chooseTargetFolder] fallback to nearest")
    if not playerPos then
        log("[chooseTargetFolder] no player position")
        return nil, nil
    end
    local best = nil
    local bestDist = math.huge
    for _, folder in ipairs(folders) do
        local positions = getExistingPrinterPositions(folder)
        local dist = math.huge
        for _, pos in ipairs(positions) do
            local d = (pos - playerPos).Magnitude
            if d < dist then dist = d end
        end
        if dist == math.huge then
            local unit = folder.Parent
            local floor = findFloorInUnit(unit)
            if floor then
                dist = (floor.Position - playerPos).Magnitude
            end
        end
        log("[chooseTargetFolder] folder=", folder:GetFullName(), "dist=", round(dist, 1))
        if dist < bestDist then
            bestDist = dist
            best = folder
        end
    end
    if best then
        log("[chooseTargetFolder] nearest:", best:GetFullName())
        return best, #getExistingPrinterPositions(best)
    end

    log("[chooseTargetFolder] could not determine target folder")
    return nil, nil
end

-- ============================================================================
-- Анализ сетки / определение начальной позиции
-- ============================================================================

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

local function analyzeGrid(positions, spacing)
    log("[analyzeGrid] positions=", tostring(#positions), "spacing=", spacing)
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

    if #rows == 0 or #rows[1].points == 0 then return nil end

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

    if not colSpacing or colSpacing <= 0 then colSpacing = spacing end
    if not rowSpacing or rowSpacing <= 0 then rowSpacing = spacing end

    local sumY = 0
    for _, p in ipairs(pts) do sumY += p.y end
    local floorY = sumY / #pts

    local dirRow = (rowAxis == "x") and Vector3.new(1, 0, 0) or Vector3.new(0, 0, 1)
    local dirCol = (colAxis == "x") and Vector3.new(1, 0, 0) or Vector3.new(0, 0, 1)
    local firstPoint = rows[1].points[1]
    local origin = Vector3.new(firstPoint.x, floorY, firstPoint.z)

    log("[analyzeGrid] origin=", tostring(origin), "rowSpacing=", round(rowSpacing, 2),
        "colSpacing=", round(colSpacing, 2), "perRow=", #rows[1].points, "rows=", #rows)

    return {
        existingCount = #positions,
        origin = origin,
        dirRow = dirRow,
        dirCol = dirCol,
        rowSpacing = rowSpacing,
        colSpacing = colSpacing,
        printersPerRow = #rows[1].points,
        maxRows = nil,
        rows = rows,
    }
end

local function buildGridFromFloor(floor, spacing)
    log("[buildGridFromFloor] floor=", floor.Name, "size=", tostring(floor.Size), "spacing=", spacing)
    local size = floor.Size
    local cf = floor.CFrame

    local margin = spacing
    local originCf = cf * CFrame.new(-size.X / 2 + margin, 0, -size.Z / 2 + margin)
    local origin = originCf.Position

    local dirCol = cf.RightVector
    local dirRow = -cf.LookVector

    local usableX = size.X - 2 * margin
    local usableZ = size.Z - 2 * margin
    local printersPerRow = math.max(1, math.floor(usableX / spacing))
    local maxRows = math.max(1, math.floor(usableZ / spacing))

    log("[buildGridFromFloor] origin=", tostring(origin), "perRow=", printersPerRow, "maxRows=", maxRows)

    return {
        existingCount = 0,
        origin = origin,
        dirRow = dirRow,
        dirCol = dirCol,
        rowSpacing = spacing,
        colSpacing = spacing,
        printersPerRow = printersPerRow,
        maxRows = maxRows,
        rows = {},
    }
end

local function generateSlots(grid, maxCount)
    log("[generateSlots] maxCount=", tostring(maxCount))
    local slots = {}
    local function key(pos)
        return tostring(round(pos.X / 0.5)) .. "," .. tostring(round(pos.Z / 0.5))
    end
    local occupied = {}

    for _, row in ipairs(grid.rows or {}) do
        for _, p in ipairs(row.points) do
            occupied[key(Vector3.new(p.x, p.y, p.z))] = true
        end
    end

    local placed = grid.existingCount
    local index = 0
    local safety = maxCount * 10 + 100

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

    log("[generateSlots] generated=", tostring(#slots))
    return slots
end

-- ============================================================================
-- Размещение одного принтера
-- ============================================================================

local function placePrinterAt(tool, folder, position)
    log("[placePrinterAt] tool=", tool.Name, "pos=", tostring(position))
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
    local inFolder = tool:IsDescendantOf(folder)
    log("[placePrinterAt] inFolder=", tostring(inFolder))
    return inFolder, "not in folder after place"
end

-- ============================================================================
-- Основной цикл
-- ============================================================================

log("========== PRINTER GRID PLACEMENT TEST v3.3 ==========")
log("Player:", player.Name, "UserId:", tostring(player.UserId))

local function main()
    log("[main] calling resetInventory")
    resetInventory()

    log("[main] counting backpack")
    local backpackCount = countPrintersInBackpack()
    log("Printers in backpack at start:", tostring(backpackCount))

    if backpackCount == 0 then
        log("ERROR: No printers in backpack")
        return
    end

    log("[main] choosing target folder")
    local folder, existingCount = chooseTargetFolder()
    if not folder then
        log("ERROR: Could not find suitable MoneyPrinters folder")
        return
    end

    local unit = folder.Parent
    log("Target folder:", folder:GetFullName(), "existing printers:", tostring(existingCount))

    log("[main] finding floor")
    local floor = findFloorInUnit(unit)
    if floor then
        log("Floor found:", floor.Name, "size=", tostring(floor.Size), "pos=", tostring(floor.Position))
    else
        log("WARNING: No floor found in unit", unit and unit.Name or "nil")
    end

    log("[main] getting existing positions")
    local positions = getExistingPrinterPositions(folder)
    log("Existing printer positions:", tostring(#positions))

    log("[main] measuring tool spacing")
    local spacingTool = takePrinterFromBackpack()
    local spacing = spacingTool and getToolSpacing(spacingTool) or DEFAULT_SPACING
    if spacingTool then
        pcall(function() spacingTool.Parent = player.Backpack end)
    end
    log("Printer spacing:", round(spacing, 2))

    local grid = nil
    if #positions > 0 then
        log("[main] analyzing existing grid")
        grid = analyzeGrid(positions, spacing)
    else
        log("[main] no existing printers, building grid from floor")
        if not floor then
            log("ERROR: No existing printers and no floor found; cannot determine placement area")
            return
        end
        grid = buildGridFromFloor(floor, spacing)
    end

    if not grid then
        log("ERROR: Could not build grid")
        return
    end

    local targetCount = math.min(grid.existingCount + backpackCount, MAX_PRINTERS)
    if grid.maxRows then
        local capacity = grid.maxRows * grid.printersPerRow
        targetCount = math.min(targetCount, capacity)
    end
    log("Target total printers:", tostring(targetCount))

    log("[main] generating slots")
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

    log("[main] final reset")
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
end

local ok, err = pcall(main)
if not ok then
    logError("MAIN", err)
end

log("========== END TEST v3.3 ==========")
copy()
