--[[
    San Diego Agent — Test: CFrame placement inside apartment region
    ================================================================
    Берёт Tool из рюкзака, перекладывает в MoneyPrinters и выставляет
    Handle CFrame в точку рядом с существующим принтером, но строго внутри
    MoneyPrinterApartmentRegion. Ждёт, появится ли атрибут MoneyPrinterId.
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
    if writefile then pcall(function() writefile("printer_cframe_in_region_test_log.txt", text) end) end
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
        for _, child in ipairs(f:GetChildren()) do
            local part = child:FindFirstChild("Printer_d") or child:FindFirstChild("Handle")
            if part and part:IsA("BasePart") then
                local d = (part.Position - playerPos).Magnitude
                if d < bestDist then
                    bestDist = d
                    best = f
                end
            end
        end
    end
    return best, bestDist
end

local function getExistingPrinter(folder)
    for _, c in ipairs(folder:GetChildren()) do
        if c.Name:lower():find("print") or c:HasTag("MoneyPrinter") then
            return c
        end
    end
    return nil
end

local function getRegionBounds(printer)
    local regionCFrame = printer:GetAttribute("MoneyPrinterApartmentRegionCFrame")
    local regionSize = printer:GetAttribute("MoneyPrinterApartmentRegionSize")
    if typeof(regionCFrame) ~= "CFrame" or typeof(regionSize) ~= "Vector3" then
        return nil
    end
    local half = regionSize / 2
    local min = regionCFrame:PointToWorldSpace(-half)
    local max = regionCFrame:PointToWorldSpace(half)
    -- min/max may be swapped due to rotation; normalize
    local actualMin = Vector3.new(
        math.min(min.X, max.X),
        math.min(min.Y, max.Y),
        math.min(min.Z, max.Z)
    )
    local actualMax = Vector3.new(
        math.max(min.X, max.X),
        math.max(min.Y, max.Y),
        math.max(min.Z, max.Z)
    )
    return actualMin, actualMax, regionCFrame, regionSize
end

log("========== CFRAME PLACEMENT IN REGION TEST ==========")
log("Player:", player.Name)

local folder, dist = findMoneyPrintersFolder()
if not folder then
    log("ERROR: No MoneyPrinters folder found")
    copy()
    return
end
log("Folder:", folder:GetFullName(), "dist:", tostring(math.round(dist * 10) / 10))

local existing = getExistingPrinter(folder)
if not existing then
    log("ERROR: No existing printer in folder to infer region")
    copy()
    return
end
log("Existing printer:", existing.Name)

local rMin, rMax, regionCF, regionSize = getRegionBounds(existing)
if not rMin then
    log("ERROR: No region attributes on printer")
    copy()
    return
end
log("Region min:", tostring(rMin))
log("Region max:", tostring(rMax))

local part = existing:FindFirstChild("Printer_d") or existing:FindFirstChild("Handle")
if not part or not part:IsA("BasePart") then
    log("ERROR: No base part on existing printer")
    copy()
    return
end
local existingPos = part.Position
local existingCF = part.CFrame
log("Existing part pos:", tostring(existingPos))
log("Existing part CFrame:", tostring(existingCF))

-- Compute target position: offset by 4 along local X of region, same Y/Z
local offset = regionCF.RightVector * 4
local targetPos = existingPos + offset
-- Clamp to region
local clampedPos = Vector3.new(
    math.clamp(targetPos.X, rMin.X + 1, rMax.X - 1),
    math.clamp(targetPos.Y, rMin.Y + 1, rMax.Y - 1),
    math.clamp(targetPos.Z, rMin.Z + 1, rMax.Z - 1)
)
log("Target position (clamped):", tostring(clampedPos))

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

-- Unequip
local char = player.Character or player.CharacterAdded:Wait()
local humanoid = char:FindFirstChildOfClass("Humanoid")
if humanoid then
    pcall(function() humanoid:UnequipTools() end)
    task.wait(0.3)
end

log("Placing via CFrame into folder...")
local before = #folder:GetChildren()
log("Folder children before:", tostring(before))

local ok, err = pcall(function()
    tool.Parent = folder
    local handle = tool:FindFirstChild("Handle")
    local printerD = tool:FindFirstChild("Printer_d")
    local targetCF = CFrame.new(clampedPos) * (existingCF - existingCF.Position)
    if handle and handle:IsA("BasePart") then
        handle.CFrame = targetCF
        handle.Anchored = true
        handle.CanCollide = true
        log("Handle set to:", tostring(handle.CFrame))
    end
    if printerD and printerD:IsA("BasePart") then
        printerD.CFrame = targetCF
        printerD.Anchored = true
        printerD.CanCollide = true
        log("Printer_d set to:", tostring(printerD.CFrame))
    end
end)

if not ok then
    log("ERROR during placement:", tostring(err))
    copy()
    return
end

log("Waiting 15s for server conversion...")
local converted = false
local newPrinter = nil
for i = 1, 15 do
    task.wait(1)
    -- Check if the tool acquired MoneyPrinterId or became a Model
    if tool.Parent == folder then
        local id = tool:GetAttribute("MoneyPrinterId")
        if id then
            log("t+", tostring(i), "Tool got MoneyPrinterId:", tostring(id))
            converted = true
            break
        end
        -- Check if any new Model appeared in folder
        for _, c in ipairs(folder:GetChildren()) do
            if c ~= tool and (c.Name:lower():find("print") or c:HasTag("MoneyPrinter")) then
                if c:GetAttribute("MoneyPrinterId") then
                    log("t+", tostring(i), "New model with MoneyPrinterId:", c.Name)
                    converted = true
                    newPrinter = c
                    break
                end
            end
        end
        if converted then break end
    else
        log("t+", tostring(i), "Tool parent:", tool.Parent and tool.Parent:GetFullName() or "nil")
    end
end

if converted then
    log("*** CFRAME PLACEMENT IN REGION WORKED! ***")
else
    log("No conversion detected. Tool parent:", tool.Parent and tool.Parent:GetFullName() or "nil")
    -- Try to return tool to backpack
    pcall(function() tool.Parent = backpack end)
end

log("\n========== END ==========")
copy()
