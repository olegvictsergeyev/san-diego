--[[
    San Diego Agent — Test: VIM drop at computed grid slot
    =======================================================
    1. Находит папку MoneyPrinters и анализирует сетку существующих принтеров.
    2. Вычисляет следующую свободную позицию.
    3. Телепортирует персонажа на эту позицию.
    4. Экипирует Money Printer и дропает его через VirtualInputManager (Backspace).
    5. Ждёт 15 секунд и проверяет, появился ли новый принтер в папке.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")

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
    if writefile then pcall(function() writefile("printer_vim_drop_grid_test_log.txt", text) end) end
end

local function getPlayerPos()
    local char = player.Character or player.CharacterAdded:Wait()
    local hrp = char:FindFirstChild("HumanoidRootPart")
    return hrp and hrp.Position, hrp
end

local function findMoneyPrintersFolder()
    local playerPos, _ = getPlayerPos()
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
    if #folders == 0 then return nil end
    local best = folders[1]
    local bestDist = math.huge
    for _, f in ipairs(folders) do
        local dist = math.huge
        for _, child in ipairs(f:GetChildren()) do
            local part = child:FindFirstChild("Printer_d") or child:FindFirstChild("Handle")
            if part and part:IsA("BasePart") then
                local d = (part.Position - playerPos).Magnitude
                if d < dist then dist = d end
            end
        end
        if dist < bestDist then
            bestDist = dist
            best = f
        end
    end
    return best, bestDist
end

local function getExistingPrinterPositions(folder)
    local positions = {}
    for _, c in ipairs(folder:GetChildren()) do
        local part = c:FindFirstChild("Printer_d") or c:FindFirstChild("Handle")
        if part and part:IsA("BasePart") then
            table.insert(positions, part.Position)
        end
    end
    return positions
end

local function analyzeGrid(positions)
    if #positions == 0 then return nil end
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
    table.sort(colDists)
    local colSpacing = #colDists > 0 and colDists[math.floor(#colDists / 2) + 1] or 4

    local rowDists = {}
    for i = 2, #rows do
        table.insert(rowDists, math.abs(rows[i].center - rows[i - 1].center))
    end
    table.sort(rowDists)
    local rowSpacing = #rowDists > 0 and rowDists[math.floor(#rowDists / 2) + 1] or 4

    local first = rows[1].points[1]
    local origin = Vector3.new(first.x, first.y, first.z)
    local dirRow = (rowAxis == "x") and Vector3.new(1, 0, 0) or Vector3.new(0, 0, 1)
    local dirCol = (colAxis == "x") and Vector3.new(1, 0, 0) or Vector3.new(0, 0, 1)

    return {
        rows = rows,
        rowAxis = rowAxis,
        colAxis = colAxis,
        rowSpacing = rowSpacing,
        colSpacing = colSpacing,
        origin = origin,
        dirRow = dirRow,
        dirCol = dirCol,
        printersPerRow = #rows[1].points,
        rowCount = #rows,
        existingCount = #positions,
    }
end

local function generateNextSlot(grid)
    local occupied = {}
    local function key(pos)
        return tostring(math.round(pos.X / 0.5)) .. "," .. tostring(math.round(pos.Z / 0.5))
    end
    for _, row in ipairs(grid.rows) do
        for _, p in ipairs(row.points) do
            occupied[key(Vector3.new(p.x, p.y, p.z))] = true
        end
    end

    local lastRow = grid.rows[#grid.rows]
    local lastRowLen = #lastRow.points
    local rowIndex, colIndex
    if lastRowLen < grid.printersPerRow then
        rowIndex = grid.rowCount - 1
        colIndex = lastRowLen
    else
        rowIndex = grid.rowCount
        colIndex = 0
    end

    for attempt = 0, 200 do
        local pos = grid.origin + grid.dirCol * (colIndex * grid.colSpacing) + grid.dirRow * (rowIndex * grid.rowSpacing)
        local k = key(pos)
        if not occupied[k] then
            return pos
        end
        occupied[k] = true
        colIndex += 1
        if colIndex >= grid.printersPerRow then
            rowIndex += 1
            colIndex = 0
        end
    end
    return nil
end

local function countPrinters(folder)
    local count = 0
    for _, c in ipairs(folder:GetChildren()) do
        if c.Name:lower():find("print") or c:HasTag("MoneyPrinter") then
            count += 1
        end
    end
    return count
end

log("========== VIM DROP AT GRID SLOT TEST ==========")
log("Player:", player.Name)

local folder, folderDist = findMoneyPrintersFolder()
if not folder then
    log("ERROR: No MoneyPrinters folder found")
    copy()
    return
end
log("Target folder:", folder:GetFullName(), "dist:", tostring(math.round(folderDist * 10) / 10))

local positions = getExistingPrinterPositions(folder)
if #positions == 0 then
    log("ERROR: no existing printers to infer grid")
    copy()
    return
end

local grid = analyzeGrid(positions)
if not grid then
    log("ERROR: could not analyze grid")
    copy()
    return
end
log("Grid analysis: rows=" .. grid.rowCount .. ", perRow=" .. grid.printersPerRow .. ", rowAxis=" .. grid.rowAxis .. ", colAxis=" .. grid.colAxis)
log("Spacing row=" .. tostring(math.round(grid.rowSpacing * 100) / 100) .. " col=" .. tostring(math.round(grid.colSpacing * 100) / 100))

local slotPos = generateNextSlot(grid)
if not slotPos then
    log("ERROR: could not generate next slot")
    copy()
    return
end
log("Next slot position:", tostring(slotPos))

local backpack = player:FindFirstChild("Backpack")
local tool = nil
if backpack then
    for _, c in ipairs(backpack:GetChildren()) do
        if c:IsA("Tool") and c.Name:lower():find("print") then
            tool = c
            break
        end
    end
end
if not tool then
    log("ERROR: No Money Printer in backpack")
    copy()
    return
end
log("Tool found:", tool.Name)

local char = player.Character or player.CharacterAdded:Wait()
local humanoid = char:FindFirstChildOfClass("Humanoid")
local hrp = char:FindFirstChild("HumanoidRootPart")
if not humanoid or not hrp then
    log("ERROR: No humanoid or HRP")
    copy()
    return
end

-- Teleport to slot position
log("Teleporting to slot position...")
pcall(function()
    hrp.CFrame = CFrame.new(slotPos + Vector3.new(0, 3, 0))
end)
task.wait(0.5)

local before = countPrinters(folder)
log("Printers in folder before:", tostring(before))

-- Unequip any tool
pcall(function() humanoid:UnequipTools() end)
task.wait(0.3)

-- Equip
log("Equipping tool...")
pcall(function() humanoid:EquipTool(tool) end)
task.wait(0.5)
log("Tool parent after equip:", tool.Parent and tool.Parent.Name or "nil")

-- Drop via VIM Backspace
log("Dropping with VIM Backspace at slot position...")
pcall(function()
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Backspace, false, game)
    task.wait(0.1)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Backspace, false, game)
end)

log("Tool parent after drop:", tool.Parent and tool.Parent:GetFullName() or "nil")

log("Waiting 15s for conversion...")
local converted = false
for i = 1, 15 do
    task.wait(1)
    local now = countPrinters(folder)
    log("t+", tostring(i), "printers:", tostring(now))
    if now > before then
        converted = true
        break
    end
end

if converted then
    log("*** VIM DROP AT GRID SLOT WORKED! ***")
else
    log("No placement detected at grid slot")
end

log("\n========== END ==========")
copy()
