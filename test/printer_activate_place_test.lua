--[[
    San Diego Agent — Test: place Money Printer via Tool:Activate()
    ================================================================
    Экипирует Money Printer, перемещает персонажа в центр комнаты
    и вызывает Tool:Activate(). Проверяет, появится ли Model в MoneyPrinters.
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
    if writefile then pcall(function() writefile("printer_activate_place_test_log.txt", text) end) end
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
    return best, bestDist
end

local function getRegionInfo(folder)
    if not folder or not folder.Parent then return nil, nil end
    local regionPart = folder.Parent:FindFirstChild("Region")
    if regionPart and regionPart:IsA("BasePart") then
        return regionPart.CFrame, regionPart.Size
    end
    return nil, nil
end

log("========== PRINTER ACTIVATE PLACE TEST ==========")
log("Player:", player.Name)

local folder, dist = findMoneyPrintersFolder()
if not folder then
    log("ERROR: No MoneyPrinters folder found")
    copy()
    return
end
log("Folder:", folder:GetFullName())

local regionCF, regionSize = getRegionInfo(folder)
if not regionCF then
    log("ERROR: No Region part found")
    copy()
    return
end
log("Region CF:", tostring(regionCF))
log("Region Size:", tostring(regionSize))

local char = player.Character or player.CharacterAdded:Wait()
local humanoid = char:FindFirstChildOfClass("Humanoid")
local hrp = char:FindFirstChild("HumanoidRootPart")
if not humanoid or not hrp then
    log("ERROR: No humanoid or HRP")
    copy()
    return
end

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
    log("ERROR: No Money Printer tool in backpack")
    copy()
    return
end
log("Tool:", tool.Name)

-- Count real printers before
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

-- Teleport to center of region on floor
local half = regionSize / 2
local floorLocalY = -half.Y + 1
local centerLocal = Vector3.new(0, floorLocalY, 0)
local centerWorld = regionCF:PointToWorldSpace(centerLocal)
log("Teleporting to center:", tostring(centerWorld))
pcall(function()
    hrp.CFrame = CFrame.new(centerWorld + Vector3.new(0, 3, 0))
end)
task.wait(0.5)

-- Unequip and equip
pcall(function() humanoid:UnequipTools() end)
task.wait(0.3)
log("Equipping tool...")
pcall(function() humanoid:EquipTool(tool) end)
task.wait(0.5)
log("Tool parent after equip:", tool.Parent and tool.Parent.Name or "nil")

-- Try Activate
log("Calling tool:Activate()...")
pcall(function() tool:Activate() end)
task.wait(2)

-- Try firing Activated event directly
log("Trying tool.Activated:Fire()...")
pcall(function()
    tool.Activated:Fire()
end)
task.wait(2)

-- Try left mouse click via VirtualInputManager
log("Trying VIM left mouse click...")
pcall(function()
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
    task.wait(0.1)
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
end)
task.wait(2)

log("Tool parent after attempts:", tool.Parent and tool.Parent:GetFullName() or "nil")

log("Waiting 10s for conversion...")
for i = 1, 10 do
    task.wait(1)
    local now = countRealPrinters()
    log("t+", tostring(i), "real printers:", tostring(now))
    if now > before then
        log("*** ACTIVATE PLACEMENT WORKED! ***")
        copy()
        return
    end
end

log("No real printer appeared. Tool remained Tool or did not convert.")
log("\n========== END ==========")
copy()
