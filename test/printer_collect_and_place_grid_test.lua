--[[
    San Diego Agent — Test: collect all printers then place full grid flush against walls
    ===================================================================================
    1. Собирает все принтеры из папки MoneyPrinters текущей квартиры (через remote или Parent=Backpack).
    2. Удаляет оставшиеся фейковые Tool/Model.
    3. Расставляет все собранные принтеры сеткой от текущей позиции игрока, впритык к стенам.

    Как использовать:
    - Встань в верхний левый угол комнаты.
    - Повернись лицом вдоль стены, по которой должен идти первый ряд (LookVector = вдоль стены).
    - Правый бок должен смотреть вглубь комнаты (RightVector = вглубь комнаты).
    - Запусти скрипт.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

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
    if writefile then pcall(function() writefile("printer_collect_and_place_grid_log.txt", text) end) end
end

log("========== COLLECT AND PLACE GRID TEST ==========")
log("Player:", player.Name)

-- Helpers
local function getCharacter()
    local char = player.Character
    if char then return char end
    return player.CharacterAdded:Wait()
end

local function getHrp()
    local char = getCharacter()
    return char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local char = getCharacter()
    return char:FindFirstChildOfClass("Humanoid")
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
                if mp then return mp end
                unit = unit.Parent
                depth = depth + 1
            end
        end
    end

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
    return folders[1]
end

local backpack = player:FindFirstChild("Backpack")
if not backpack then
    log("ERROR: Backpack not found")
    copy()
    return
end

local folder = chooseTargetFolder()
if not folder then
    log("ERROR: MoneyPrinters folder not found")
    copy()
    return
end
log("Target folder:", folder:GetFullName())

local pickupRemote = ReplicatedStorage:FindFirstChild("__remotes", true)
if pickupRemote then
    pickupRemote = pickupRemote:FindFirstChild("MoneyPrinterService")
    if pickupRemote then
        pickupRemote = pickupRemote:FindFirstChild("PickupMoneyPrinter")
    end
end
if pickupRemote then
    log("Found pickup remote:", pickupRemote:GetFullName())
else
    log("WARNING: PickupMoneyPrinter remote not found, will use fallback")
end

-- Collect all printers
local function collectAllPrinters()
    local collected = 0
    local remoteCollected = 0
    local failed = 0

    for _, c in ipairs(folder:GetChildren()) do
        if c.Name:lower():find("print") or c:HasTag("MoneyPrinter") then
            log("Collecting:", c.Name, "Class:", c.ClassName)

            local remoteOk = false
            if pickupRemote and pickupRemote:IsA("RemoteFunction") then
                local argsList = { { c }, { c, getHrp() and getHrp().Position }, { folder, c }, {} }
                for i, args in ipairs(argsList) do
                    local ok, result = pcall(function()
                        return pickupRemote:InvokeServer(unpack(args))
                    end)
                    if ok then
                        log("  remote call #" .. tostring(i) .. " success:", tostring(result))
                        remoteOk = true
                        remoteCollected += 1
                        break
                    else
                        log("  remote call #" .. tostring(i) .. " failed:", tostring(result))
                    end
                end
            end

            if not remoteOk then
                local ok, err = pcall(function() c.Parent = backpack end)
                if ok then
                    collected += 1
                    log("  Parent=Backpack success")
                else
                    failed += 1
                    log("  Parent=Backpack FAILED:", tostring(err))
                end
            else
                collected += 1
            end

            task.wait(0.2)
        end
    end

    log("--- Collect summary ---")
    log("Remote collected:", tostring(remoteCollected))
    log("Parent collected:", tostring(collected - remoteCollected))
    log("Failed:", tostring(failed))
end

collectAllPrinters()

task.wait(0.5)

-- Delete any remaining fake printers in the folder
local function deleteRemainingFakes()
    local deleted = 0
    for _, c in ipairs(folder:GetChildren()) do
        if c.Name:lower():find("print") or c:HasTag("MoneyPrinter") then
            if not c:GetAttribute("MoneyPrinterId") then
                pcall(function() c:Destroy() end)
                deleted += 1
            end
        end
    end
    log("Deleted fake printers remaining in folder:", tostring(deleted))
end

deleteRemainingFakes()

local function countToolsInBackpack()
    local count = 0
    for _, c in ipairs(backpack:GetChildren()) do
        if c:IsA("Tool") and c.Name:lower():find("print") then
            count += 1
        end
    end
    return count
end

local totalTools = countToolsInBackpack()
log("Money Printer tools in backpack:", tostring(totalTools))

if totalTools == 0 then
    log("ERROR: No tools to place")
    copy()
    return
end

-- Get tool size from first tool
local function getFirstPrinterTool()
    for _, c in ipairs(backpack:GetChildren()) do
        if c:IsA("Tool") and c.Name:lower():find("print") then
            return c
        end
    end
    return nil
end

local tool = getFirstPrinterTool()
local function getToolPartSize(t)
    if not t then return Vector3.new(4, 4, 4) end
    local sizes = {}
    for _, c in ipairs(t:GetDescendants()) do
        if c:IsA("BasePart") then
            table.insert(sizes, c.Size)
        end
    end
    if #sizes == 0 then return Vector3.new(4, 4, 4) end
    -- Use the largest horizontal size as footprint
    table.sort(sizes, function(a, b)
        return math.max(a.X, a.Z) > math.max(b.X, b.Z)
    end)
    return sizes[1]
end

local partSize = getToolPartSize(tool)
local sizeXZ = math.max(partSize.X, partSize.Z)
local spacing = sizeXZ
local half = sizeXZ / 2
log("Tool footprint size:", tostring(sizeXZ))

-- Capture start position and orientation
local hrp = getHrp()
local humanoid = getHumanoid()
if not hrp or not humanoid then
    log("ERROR: Character not ready")
    copy()
    return
end

local startPos = hrp.Position
local startCF = hrp.CFrame
local rowDir = startCF.LookVector
local colDir = startCF.RightVector
rowDir = Vector3.new(rowDir.X, 0, rowDir.Z).Unit
colDir = Vector3.new(colDir.X, 0, colDir.Z).Unit
if rowDir.Magnitude < 0.001 or colDir.Magnitude < 0.001 then
    rowDir = Vector3.new(0, 0, -1)
    colDir = Vector3.new(1, 0, 0)
end

log("Start pos:", tostring(startPos))
log("Row direction (along wall):", tostring(rowDir))
log("Col direction (into room):", tostring(colDir))

-- Raycast to walls to compute available space
local function raycastDistance(origin, direction)
    local params
    pcall(function()
        local p = RaycastParams.new()
        p.FilterType = Enum.RaycastFilterType.Blacklist
        p.FilterDescendantsInstances = { getCharacter(), folder }
        params = p
    end)
    local result
    pcall(function()
        result = Workspace:Raycast(origin + Vector3.new(0, 2, 0), direction * 200, params)
    end)
    if result then
        return (result.Position - origin).Magnitude
    end
    return nil
end

local dRowBack = raycastDistance(startPos, -rowDir) or 0
local dRowForward = raycastDistance(startPos, rowDir) or 100
local dColBack = raycastDistance(startPos, -colDir) or 0
local dColForward = raycastDistance(startPos, colDir) or 100

log("Wall distances row back/fwd:", tostring(dRowBack), "/", tostring(dRowForward))
log("Wall distances col back/fwd:", tostring(dColBack), "/", tostring(dColForward))

-- First printer center should be half size away from each near wall
local firstPos = startPos + rowDir * (-dRowBack + half) + colDir * (-dColBack + half)

-- Compute max columns and rows that fit without crossing far walls
local function fitCount(dist, s)
    if dist < s then return 0 end
    return math.floor((dist - s) / s) + 1
end

local maxCols = fitCount(dRowBack + dRowForward, sizeXZ)
local maxRows = fitCount(dColBack + dColForward, sizeXZ)
if maxCols < 1 then maxCols = 1 end
if maxRows < 1 then maxRows = 1 end
log("Estimated max cols/rows:", tostring(maxCols), "/", tostring(maxRows))

-- We place all tools, but limit to the computed grid
local totalToPlace = math.min(totalTools, maxCols * maxRows)
log("Will place:", tostring(totalToPlace))

local function countRealPrintersInFolder()
    local count = 0
    for _, c in ipairs(folder:GetChildren()) do
        if c:IsA("Model") and c:GetAttribute("MoneyPrinterId") then
            count += 1
        end
    end
    return count
end

local realNow = countRealPrintersInFolder()
local placed = 0
local failed = 0
local errors = {}

local function takePrinterTool()
    for _, c in ipairs(backpack:GetChildren()) do
        if c:IsA("Tool") and c.Name:lower():find("print") then
            return c
        end
    end
    return nil
end

for i = 1, totalToPlace do
    log("\n--- Slot", tostring(i), "of", tostring(totalToPlace), "---")

    local t = takePrinterTool()
    if not t then
        log("No more tools in backpack")
        break
    end

    local col = (i - 1) % maxCols
    local row = math.floor((i - 1) / maxCols)
    local targetPos = firstPos + rowDir * (col * spacing) + colDir * (row * spacing)
    log("Target pos:", tostring(targetPos))

    local ok, success, errMsg = pcall(function()
        -- Move character above target position
        local h = getHrp()
        if h then
            h.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
        end
        task.wait(0.3)

        -- Equip and activate
        local hum = getHumanoid()
        if hum then
            pcall(function() hum:UnequipTools() end)
            task.wait(0.2)
            pcall(function() hum:EquipTool(t) end)
            task.wait(0.3)
        end

        log("Activating tool...")
        pcall(function() t:Activate() end)

        -- Wait for conversion
        for w = 1, 30 do
            task.wait(0.2)
            local newCount = countRealPrintersInFolder()
            if newCount > realNow then
                realNow = newCount
                return true
            end
        end
        return false, "conversion timeout"
    end)

    if ok and success == true then
        placed += 1
        log("SUCCESS. Total real printers:", tostring(realNow))
    else
        failed += 1
        local msg = tostring((ok and errMsg) or success or "unknown")
        log("FAILED:", msg)
        table.insert(errors, { slot = i, pos = tostring(targetPos), error = msg })
        pcall(function() t.Parent = backpack end)
    end

    task.wait(0.1)
end

log("\n--- PLACEMENT SUMMARY ---")
log("Placed:", tostring(placed))
log("Failed:", tostring(failed))
log("Final real printers in folder:", tostring(countRealPrintersInFolder()))
log("Remaining tools in backpack:", tostring(countToolsInBackpack()))
log("Errors:", tostring(#errors))
for _, e in ipairs(errors) do
    log("  slot", tostring(e.slot), "@", e.pos, "-", e.error)
end

log("========== END ==========")
copy()
