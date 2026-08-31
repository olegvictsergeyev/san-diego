--[[
    San Diego Agent — Test: default tool drop placement
    ==================================================
    Проверяет, работает ли установка через стандартный "drop" Tool'а:
    берём настоящий Money Printer, экипируем, затем parent'им его в Workspace
    и позиционируем. Ждём, превратится ли он в Model.
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
    if writefile then pcall(function() writefile("printer_drop_test_v2_log.txt", text) end) end
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

log("========== DEFAULT TOOL DROP PLACEMENT TEST ==========")
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

log("\nEquipping tool...")
local ok, err = pcall(function()
    humanoid:EquipTool(tool)
end)
if not ok then
    log("Equip error:", tostring(err))
else
    log("Tool equipped, parent:", tool.Parent and tool.Parent.Name or "nil")
end

task.wait(1)

-- Position in front of player
local hrp = char:FindFirstChild("HumanoidRootPart")
local handle = tool:FindFirstChild("Handle")
if hrp and handle and handle:IsA("BasePart") then
    local cf = hrp.CFrame * CFrame.new(0, 0, -4)
    handle.CFrame = cf
    log("Handle positioned at", tostring(cf.Position))
end

log("Dropping tool (parent to Workspace)...")
local dropOk, dropErr = pcall(function()
    -- Ensure CanBeDropped
    tool.CanBeDropped = true
    -- Parent to workspace
    tool.Parent = Workspace
end)
if not dropOk then
    log("Drop error:", tostring(dropErr))
end

log("Tool parent after drop:", tool.Parent and tool.Parent.Name or "nil")

if hrp and handle and handle:IsA("BasePart") then
    local cf = hrp.CFrame * CFrame.new(0, 0, -4)
    handle.CFrame = cf
    log("Re-positioned handle at", tostring(cf.Position))
end

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

-- Inspect tool state
log("\nTool final state:")
log("  Parent:", tool.Parent and tool.Parent:GetFullName() or "nil")
log("  ClassName:", tool.ClassName)
if handle then
    log("  Handle position:", tostring(handle.Position))
end

log("\n========== END ==========")
copy()
