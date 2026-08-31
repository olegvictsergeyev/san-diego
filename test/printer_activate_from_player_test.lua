--[[
    San Diego Agent — Test: place printers from player position (top-left anchor)
    ============================================================================
    1. Удаляет фейки.
    2. Берёт текущую позицию игрока как верхний левый угол.
    3. Ставит 3 принтера вправо от игрока, впритык.
    4. Использует Tool:Activate() вместо CFrame-размещения.
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
    if writefile then pcall(function() writefile("printer_activate_from_player_test_log.txt", text) end) end
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

log("========== PRINTER ACTIVATE FROM PLAYER TEST ==========")
log("Player:", player.Name)
log("Встань в верхний левый угол комнаты и запусти скрипт.")

local folder = findMoneyPrintersFolder()
if not folder then
    log("ERROR: No MoneyPrinters folder found")
    copy()
    return
end
log("Folder:", folder:GetFullName())

-- Delete fakes
log("Deleting fake printers...")
local toDelete = {}
for _, c in ipairs(folder:GetChildren()) do
    if c.Name:lower():find("print") or c:HasTag("MoneyPrinter") then
        if not c:GetAttribute("MoneyPrinterId") then
            table.insert(toDelete, c)
        end
    end
end
for _, c in ipairs(toDelete) do
    log("  Destroy:", c.ClassName, c.Name)
    pcall(function() c:Destroy() end)
end
log("Deleted:", tostring(#toDelete))
task.wait(0.3)

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
    log("ERROR: No part in tool")
    copy()
    return
end
local spacing = math.max(toolPart.Size.X, toolPart.Size.Z)
log("Spacing:", tostring(spacing))

local startPos = hrp.Position
local startCF = hrp.CFrame
local right = startCF.RightVector
log("Start pos:", tostring(startPos))
log("Right vector:", tostring(right))

local positions = {}
for i = 1, 3 do
    local pos = startPos + right * (spacing * (i - 1))
    table.insert(positions, pos)
    log("Slot " .. tostring(i) .. ":", tostring(pos))
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

    log("Moving...")
    pcall(function()
        hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0)) * CFrame.Angles(0, math.atan2(right.Z, right.X), 0)
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
    end

    if not converted then
        log("Slot " .. tostring(i) .. " failed")
        pcall(function() tool.Parent = backpack end)
    end
end

log("\nFinal real printers:", tostring(countRealPrinters()))
log("\n========== END ==========")
copy()
