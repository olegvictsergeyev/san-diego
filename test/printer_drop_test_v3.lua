--[[
    San Diego Agent — Test: drop placement v3 (backpack intermediate)
    ================================================================
    Проверяет, сработает ли размещение, если:
    1. Экипировать Tool
    2. Разэкипировать (Tool уходит в Backpack)
    3. Переместить Tool из Backpack в Workspace с позицией
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
    if writefile then pcall(function() writefile("printer_drop_test_v3_log.txt", text) end) end
end

local function getPlayerPos()
    local char = player.Character or player.CharacterAdded:Wait()
    local hrp = char:FindFirstChild("HumanoidRootPart")
    return hrp and hrp.Position
end

local function findMoneyPrintersFolder()
    local playerPos = getPlayerPos()
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

local function countPrinters(folder)
    local count = 0
    for _, c in ipairs(folder:GetChildren()) do
        if c.Name:lower():find("print") or c:HasTag("MoneyPrinter") then
            count += 1
        end
    end
    return count
end

log("========== DROP PLACEMENT V3 (BACKPACK INTERMEDIATE) ==========")
log("Player:", player.Name)

local folder = findMoneyPrintersFolder()
if not folder then
    log("ERROR: No MoneyPrinters folder found")
    copy()
    return
end
log("Target folder:", folder:GetFullName())

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
if not humanoid then
    log("ERROR: No humanoid")
    copy()
    return
end

local before = countPrinters(folder)
log("Printers in folder before:", tostring(before))

-- Step 1: equip
log("Equipping tool...")
local ok, err = pcall(function() humanoid:EquipTool(tool) end)
if not ok then log("Equip error:", tostring(err)) end
log("Tool parent after equip:", tool.Parent and tool.Parent.Name or "nil")

task.wait(0.5)

-- Step 2: unequip (to backpack)
log("Unequipping tool...")
local ok2, err2 = pcall(function() humanoid:UnequipTools() end)
if not ok2 then log("Unequip error:", tostring(err2)) end
log("Tool parent after unequip:", tool.Parent and tool.Parent.Name or "nil")

task.wait(0.5)

-- Step 3: move from backpack to workspace
local hrp = char:FindFirstChild("HumanoidRootPart")
local handle = tool:FindFirstChild("Handle")
if hrp and handle and handle:IsA("BasePart") then
    local cf = hrp.CFrame * CFrame.new(0, 0, -4)
    handle.CFrame = cf
    log("Pre-set handle position:", tostring(cf.Position))
end

log("Parenting tool to Workspace from Backpack...")
tool.CanBeDropped = true
tool.Parent = Workspace

task.wait(0.2)
if hrp and handle and handle:IsA("BasePart") then
    local cf = hrp.CFrame * CFrame.new(0, 0, -4)
    handle.CFrame = cf
    log("Re-set handle position:", tostring(cf.Position))
end

log("Tool parent after drop:", tool.Parent and tool.Parent:GetFullName() or "nil")

log("\nWaiting 10 seconds...")
for i = 1, 10 do
    task.wait(1)
    log("t+", tostring(i))
end

local after = countPrinters(folder)
log("\nPrinters in folder after:", tostring(after))

if after > before then
    log("*** PLACEMENT WORKED! ***")
else
    log("No placement detected")
end

log("\nFinal tool parent:", tool.Parent and tool.Parent:GetFullName() or "nil")
if handle then
    log("Final handle position:", tostring(handle.Position))
end

log("\n========== END ==========")
copy()
