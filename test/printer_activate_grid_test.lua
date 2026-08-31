--[[
    San Diego Agent — Test: place multiple printers via Tool:Activate() around existing
    ================================================================================
    Находит уже стоящий рабочий принтер, берёт 3 Tool'а и активирует их рядом
    с существующим принтером, смещая персонажа по сетке. Проверяет, останутся ли
    персонаж в комнате и заработают ли принтеры.
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
    if writefile then pcall(function() writefile("printer_activate_grid_test_log.txt", text) end) end
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

local function isInsideRegion(pos, regionCF, regionSize)
    local lp = regionCF:PointToObjectSpace(pos)
    local half = regionSize / 2
    return math.abs(lp.X) <= half.X and math.abs(lp.Y) <= half.Y and math.abs(lp.Z) <= half.Z
end

log("========== PRINTER ACTIVATE GRID TEST ==========")
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

-- Find an existing real printer Model
local existing = nil
for _, c in ipairs(folder:GetChildren()) do
    if c:IsA("Model") and c:GetAttribute("MoneyPrinterId") then
        existing = c
        break
    end
end
if not existing then
    log("ERROR: No existing real printer Model in folder")
    copy()
    return
end
log("Existing printer:", existing.Name)

local part = existing:FindFirstChild("Printer_d") or existing:FindFirstChild("Handle")
if not part or not part:IsA("BasePart") then
    log("ERROR: No part in existing printer")
    copy()
    return
end
local basePos = part.Position
local baseCF = part.CFrame
local spacing = math.max(part.Size.X, part.Size.Z) * 1.2
log("Base position:", tostring(basePos))
log("Base CFrame:", tostring(baseCF))
log("Spacing:", tostring(spacing))

-- Generate 3 positions: base + right, base + look, base + right + look
local positions = {}
local right = baseCF.RightVector
local look = baseCF.LookVector
for i = 1, 3 do
    local offset = Vector3.new(0, 0, 0)
    if i == 1 then
        offset = right * spacing
    elseif i == 2 then
        offset = look * spacing
    else
        offset = right * spacing + look * spacing
    end
    local pos = basePos + offset
    -- Clamp Y to base Y (same floor)
    pos = Vector3.new(pos.X, basePos.Y, pos.Z)
    if isInsideRegion(pos, regionCF, regionSize) then
        table.insert(positions, pos)
        log("Slot " .. tostring(i) .. ":", tostring(pos))
    else
        log("Slot " .. tostring(i) .. " outside region, skipped")
    end
end

local char = player.Character or player.CharacterAdded:Wait()
local humanoid = char:FindFirstChildOfClass("Humanoid")
local hrp = char:FindFirstChild("HumanoidRootPart")
if not humanoid or not hrp then
    log("ERROR: No humanoid/HRP")
    copy()
    return
end

local backpack = player:FindFirstChild("Backpack")
if not backpack then
    log("ERROR: No backpack")
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

    -- Take tool from backpack
    local tool = nil
    for _, c in ipairs(backpack:GetChildren()) do
        if c:IsA("Tool") and c.Name:lower():find("print") then
            tool = c
            break
        end
    end
    if not tool then
        log("No more tools in backpack")
        break
    end

    -- Move character above position
    log("Moving to position...")
    pcall(function()
        hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
    end)
    task.wait(0.5)

    -- Equip
    pcall(function() humanoid:UnequipTools() end)
    task.wait(0.3)
    log("Equipping tool...")
    local ok, err = pcall(function() humanoid:EquipTool(tool) end)
    if not ok then
        log("Equip error:", tostring(err))
    else
        log("Tool parent after equip:", tool.Parent and tool.Parent.Name or "nil")
    end
    task.wait(0.5)

    -- Activate
    log("Calling tool:Activate()...")
    pcall(function() tool:Activate() end)

    -- Wait for conversion
    local converted = false
    for t = 1, 10 do
        task.wait(0.5)
        local now = countRealPrinters()
        if now > before then
            log("Conversion detected at t+", tostring(t * 0.5), "printers:", tostring(now))
            before = now
            converted = true
            break
        end
        if tool.Parent == nil then
            log("Tool parent nil at t+", tostring(t * 0.5))
        end
    end

    if not converted then
        log("Slot " .. tostring(i) .. " did not convert")
        pcall(function() tool.Parent = backpack end)
    end
end

log("\nFinal real printers:", tostring(countRealPrinters()))
log("\n========== END ==========")
copy()
