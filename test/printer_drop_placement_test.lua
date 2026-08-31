--[[
    San Diego Agent — Test: place printer by dropping the Tool
    ==========================================================
    Проверяет, зарегистрирует ли сервер принтер, если экипировать Tool
    и сбросить его (Parent = Workspace) внутри квартиры.
    Затем наблюдает, появится ли принтер в папке MoneyPrinters,
    и начнёт ли он печатать деньги.
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
    if writefile then pcall(function() writefile("printer_drop_placement_test_log.txt", text) end) end
end

local RAYCAST_DOWN_DISTANCE = 50

local function getCharacter()
    local char = player.Character
    if char then return char end
    return player.CharacterAdded:Wait()
end

local function getPlayerPos()
    local char = getCharacter()
    local hrp = char:FindFirstChild("HumanoidRootPart")
    return hrp and hrp.Position
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

local function raycastDownFromPlayer()
    local playerPos = getPlayerPos()
    if not playerPos then return nil end
    local char = getCharacter()
    local params = nil
    local ok, res = pcall(function()
        local p = RaycastParams.new()
        p.FilterType = Enum.RaycastFilterType.Blacklist
        p.FilterDescendantsInstances = { char }
        return p
    end)
    if not ok or not res then return nil end
    local result = nil
    pcall(function()
        result = Workspace:Raycast(playerPos + Vector3.new(0, 5, 0), Vector3.new(0, -RAYCAST_DOWN_DISTANCE, 0), res)
    end)
    return result and result.Instance
end

local function chooseTargetFolder()
    local hitPart = raycastDownFromPlayer()
    if hitPart then
        local unit = hitPart.Parent
        local depth = 0
        while unit and depth < 10 do
            local mp = findMoneyPrintersFolderInUnit(unit)
            if mp then return mp end
            unit = unit.Parent
            depth = depth + 1
        end
    end
    return nil
end

log("========== PRINTER DROP PLACEMENT TEST ==========")
log("Player:", player.Name)
log("Stand in apartment where you want to place 1 printer")
log("Make sure you have at least 1 Money Printer in backpack")

local folder = chooseTargetFolder()
if not folder then
    log("ERROR: Could not find MoneyPrinters folder")
    copy()
    return
end
log("Target folder:", folder:GetFullName())

local backpack = player:FindFirstChild("Backpack")
if not backpack then
    log("ERROR: No backpack")
    copy()
    return
end

local tool = nil
for _, c in ipairs(backpack:GetChildren()) do
    if c:IsA("Tool") and c.Name:lower():find("print") then
        tool = c
        break
    end
end

if not tool then
    log("ERROR: No Money Printer in backpack")
    copy()
    return
end
log("Tool found:", tool.Name)

local char = getCharacter()
local humanoid = char:FindFirstChildOfClass("Humanoid")
if not humanoid then
    log("ERROR: No humanoid")
    copy()
    return
end

-- Before state
local beforeCount = #folder:GetChildren()
log("Printers in folder before:", tostring(beforeCount))

-- Equip
log("Equipping tool...")
local ok, err = pcall(function()
    humanoid:EquipTool(tool)
end)
if not ok then
    log("Equip failed:", tostring(err))
    copy()
    return
end
task.wait(0.5)
log("Tool equipped, parent:", tool.Parent and tool.Parent.Name or "nil")

-- Drop
log("Dropping tool (Parent = Workspace)...")
local dropOk, dropErr = pcall(function()
    tool.Parent = Workspace
end)
if not dropOk then
    log("Drop failed:", tostring(dropErr))
    copy()
    return
end
task.wait(0.5)
log("Tool parent after drop:", tool.Parent and tool.Parent.Name or "nil")

-- Wait and observe
log("\nWaiting 5 seconds to observe server reaction...")
for i = 1, 5 do
    local currentCount = #folder:GetChildren()
    log("t+", tostring(i), "folder count:", tostring(currentCount))
    if tool.Parent then
        log("  tool parent:", tool.Parent.Name)
        local handle = tool:FindFirstChild("Handle")
        if handle and handle:IsA("BasePart") then
            log("  tool position:", tostring(handle.Position))
        end
    end
    task.wait(1)
end

-- Final state
local afterCount = #folder:GetChildren()
log("\n--- Results ---")
log("Printers in folder before:", tostring(beforeCount))
log("Printers in folder after:", tostring(afterCount))
log("Tool final parent:", tool.Parent and tool.Parent:GetFullName() or "nil")

if afterCount > beforeCount then
    log("SUCCESS: Server registered the dropped printer")
else
    log("Server did NOT register the dropped printer in folder")
end

-- If tool is still in workspace, try to reclaim it
if tool.Parent == Workspace then
    log("Reclaiming dropped tool to backpack...")
    pcall(function() tool.Parent = backpack end)
end

log("========== END ==========")
copy()
