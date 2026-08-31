--[[
    San Diego Agent — Test: place printers from top-left corner via Tool:Activate()
    ==============================================================================
    1. Удаляет фейковые принтеры из папки MoneyPrinters (всё без MoneyPrinterId).
    2. Берёт размер Tool'а из backpack.
    3. Ставит принтеры с верхнего левого угла комнаты, впритык друг к другу.
    4. Работает даже если в комнате изначально нет принтеров.
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
    if writefile then pcall(function() writefile("printer_activate_corner_test_log.txt", text) end) end
end

local function findMoneyPrintersFolder()
    local char = player.Character or player.CharacterAdded:Wait()
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local playerPos = hrp and hrp.Position or Vector3.new(0, 0, 0)
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
    return best
end

local function getRegionInfo(folder)
    if not folder or not folder.Parent then return nil, nil end
    local regionPart = folder.Parent:FindFirstChild("Region")
    if regionPart and regionPart:IsA("BasePart") then
        return regionPart.CFrame, regionPart.Size
    end
    return nil, nil
end

log("========== PRINTER ACTIVATE CORNER TEST ==========")
log("Player:", player.Name)

local folder = findMoneyPrintersFolder()
if not folder then
    log("ERROR: No MoneyPrinters folder found")
    copy()
    return
end
log("Folder:", folder:GetFullName())

local regionCF, regionSize = getRegionInfo(folder)
if not regionCF then
    log("ERROR: No Region part")
    copy()
    return
end
log("Region CF:", tostring(regionCF))
log("Region Size:", tostring(regionSize))

-- Delete fake printers
log("Deleting fake printers from folder...")
local toDelete = {}
for _, c in ipairs(folder:GetChildren()) do
    if c.Name:lower():find("print") or c:HasTag("MoneyPrinter") then
        if not c:GetAttribute("MoneyPrinterId") then
            table.insert(toDelete, c)
        end
    end
end
for _, c in ipairs(toDelete) do
    log("  Destroying fake:", c.ClassName, c.Name)
    pcall(function() c:Destroy() end)
end
log("Deleted:", tostring(#toDelete))

task.wait(0.3)

-- Get tool size from backpack
local backpack = player:FindFirstChild("Backpack")
if not backpack then
    log("ERROR: No backpack")
    copy()
    return
end
local toolTemplate = nil
for _, c in ipairs(backpack:GetChildren()) do
    if c:IsA("Tool") and c.Name:lower():find("print") then
        toolTemplate = c
        break
    end
end
if not toolTemplate then
    log("ERROR: No Money Printer tool in backpack")
    copy()
    return
end
local toolPart = toolTemplate:FindFirstChild("Handle") or toolTemplate:FindFirstChild("Printer_d")
if not toolPart or not toolPart:IsA("BasePart") then
    log("ERROR: No Handle/Printer_d in tool")
    copy()
    return
end
local partSize = toolPart.Size
local spacing = math.max(partSize.X, partSize.Z)
log("Tool part size:", tostring(partSize))
log("Spacing:", tostring(spacing))

-- Floor height: region bottom + half spacing
local half = regionSize / 2
local floorLocalY = -half.Y + spacing / 2
log("Floor local Y:", tostring(floorLocalY))

-- Top-left corner: local (-half.X + spacing/2, floorLocalY, half.Z - spacing/2)
local margin = spacing * 0.5
local startLocal = Vector3.new(-half.X + margin, floorLocalY, half.Z - margin)
log("Start local (top-left):", tostring(startLocal))

-- Generate 3 positions: fill row along +X, next row -Z
local positions = {}
local maxCols = math.floor((regionSize.X - 2 * margin) / spacing)
local maxRows = math.floor((regionSize.Z - 2 * margin) / spacing)
log("Max cols:", tostring(maxCols), "max rows:", tostring(maxRows))

for i = 1, 3 do
    local row = math.floor((i - 1) / maxCols)
    local col = (i - 1) % maxCols
    local lx = startLocal.X + col * spacing
    local lz = startLocal.Z - row * spacing
    local worldPos = regionCF:PointToWorldSpace(Vector3.new(lx, floorLocalY, lz))
    table.insert(positions, worldPos)
    log("Slot " .. tostring(i) .. ":", tostring(worldPos))
end

local char = player.Character or player.CharacterAdded:Wait()
local humanoid = char:FindFirstChildOfClass("Humanoid")
local hrp = char:FindFirstChild("HumanoidRootPart")
if not humanoid or not hrp then
    log("ERROR: No humanoid/HRP")
    copy()
    return
end

local function countRealPrinters()
    local count = 0
    for _, c in ipairs(folder:GetChildren()) do
        if c:IsA("Model") and c:GetAttribute("MoneyPrinterId") then
            count += 1
        end
    end
    return count
end

local before = countRealPrinters()
log("Real printers before:", tostring(before))

for i, pos in ipairs(positions) do
    log("\n--- Slot " .. tostring(i) .. ":", tostring(pos), "---")

    local tool = nil
    for _, c in ipairs(backpack:GetChildren()) do
        if c:IsA("Tool") and c.Name:lower():find("print") then
            tool = c
            break
        end
    end
    if not tool then
        log("No more tools")
        break
    end

    -- Teleport above position
    log("Moving character...")
    pcall(function()
        hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
    end)
    task.wait(0.5)

    pcall(function() humanoid:UnequipTools() end)
    task.wait(0.3)
    log("Equipping...")
    pcall(function() humanoid:EquipTool(tool) end)
    log("Tool parent:", tool.Parent and tool.Parent.Name or "nil")
    task.wait(0.5)

    log("Activating...")
    pcall(function() tool:Activate() end)

    local converted = false
    for t = 1, 15 do
        task.wait(0.5)
        local now = countRealPrinters()
        if now > before then
            log("Converted at t+", tostring(t * 0.5), "printers:", tostring(now))
            before = now
            converted = true
            break
        end
        if tool.Parent == nil then
            log("Tool nil at t+", tostring(t * 0.5))
        end
    end

    if not converted then
        log("Slot " .. tostring(i) .. " failed")
        pcall(function() tool.Parent = backpack end)
    end
end

log("\nFinal real printers:", tostring(countRealPrinters()))
log("\n========== END ==========")
copy()
