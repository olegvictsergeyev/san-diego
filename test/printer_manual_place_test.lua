--[[
    San Diego Agent — Test: place one printer at known good position/orientation
    ============================================================================
    Берёт один Money Printer из backpack и ставит его на позицию/ориентацию
    оригинального реального принтера (вычислено из региона). Если конвертнется —
    значит, Tool'ы в backpack рабочие, и дело в сетке/ориентации.
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
    if writefile then pcall(function() writefile("printer_manual_place_test_log.txt", text) end) end
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

local function getRegionFromPart(folder)
    if not folder or not folder.Parent then return nil, nil end
    local regionPart = folder.Parent:FindFirstChild("Region")
    if regionPart and regionPart:IsA("BasePart") then
        return regionPart.CFrame, regionPart.Size
    end
    return nil, nil
end

log("========== MANUAL PRINTER PLACE TEST ==========")
log("Player:", player.Name)

local folder = findMoneyPrintersFolder()
if not folder then
    log("ERROR: No MoneyPrinters folder found")
    copy()
    return
end
log("Folder:", folder:GetFullName())

local regionCF, regionSize = getRegionFromPart(folder)
if not regionCF then
    log("ERROR: No Region part found in unit")
    copy()
    return
end
log("Region CFrame:", tostring(regionCF))
log("Region Size:", tostring(regionSize))

-- Original real printer local position from earlier inspect: (20.85, -3.34, -17.27)
-- Use exact values from the earlier log for UnitNew
local originalLocal = Vector3.new(20.85, -3.34, -17.27)
local originalPos = regionCF:PointToWorldSpace(originalLocal)
log("Original printer world pos (approx):", tostring(originalPos))

-- Original orientation from earlier inspect: CFrame(0,0,1; 0,1,0; -1,0,0)
local originalOrientation = CFrame.new(0, 0, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)
log("Original orientation CFrame:", tostring(originalOrientation))

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

-- Clean fake Tools from folder
for _, c in ipairs(folder:GetChildren()) do
    if c:IsA("Tool") and c.Name:lower():find("print") then
        log("Moving fake Tool from folder to backpack:", c.Name)
        pcall(function() c.Parent = backpack end)
    end
end
task.wait(0.3)

log("Placing tool at original position with original orientation...")
local ok, err = pcall(function()
    tool.Parent = folder
    local handle = tool:FindFirstChild("Handle")
    local printerD = tool:FindFirstChild("Printer_d")
    local targetCF = CFrame.new(originalPos) * originalOrientation
    if handle and handle:IsA("BasePart") then
        handle.CFrame = targetCF
        handle.Anchored = true
        handle.CanCollide = true
        log("Handle placed at:", tostring(handle.CFrame))
    end
    if printerD and printerD:IsA("BasePart") then
        printerD.CFrame = targetCF
        printerD.Anchored = true
        printerD.CanCollide = true
    end
end)

if not ok then
    log("ERROR during placement:", tostring(err))
    copy()
    return
end

log("Waiting 15s for server conversion...")
local converted = false
for i = 1, 15 do
    task.wait(1)
    if tool.Parent ~= folder then
        log("t+", tostring(i), "Tool parent changed:", tool.Parent and tool.Parent:GetFullName() or "nil")
        converted = true
        break
    end
    if tool:GetAttribute("MoneyPrinterId") then
        log("t+", tostring(i), "Tool got MoneyPrinterId")
        converted = true
        break
    end
    local newModel = nil
    for _, c in ipairs(folder:GetChildren()) do
        if c ~= tool and (c.Name:lower():find("print") or c:HasTag("MoneyPrinter")) then
            if c:GetAttribute("MoneyPrinterId") then
                newModel = c
                break
            end
        end
    end
    if newModel then
        log("t+", tostring(i), "New model with MoneyPrinterId:", newModel.Name)
        converted = true
        break
    end
end

if converted then
    log("*** MANUAL PLACE AT ORIGINAL POSITION WORKED! ***")
else
    log("No conversion at original position. The Tool in backpack is likely fake/invalid.")
    pcall(function() tool.Parent = backpack end)
end

log("\n========== END ==========")
copy()
