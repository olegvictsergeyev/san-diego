--[[
    San Diego Agent — Test: drop Money Printer at current position
    ==============================================================
    Стоя на нужном месте в квартире, запусти этот скрипт.
    Он берёт один Money Printer из рюкзака, экипирует и имитирует Backspace.
    Затем 20 секунд ждёт и смотрит, появился ли новый принтер в папке MoneyPrinters.
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
    if writefile then pcall(function() writefile("printer_drop_here_test_log.txt", text) end) end
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
        -- пустые папки — по центру родителя
        if dist == math.huge then
            local pPos
            local function findPart(p)
                for _, cc in ipairs(p:GetChildren()) do
                    if cc:IsA("BasePart") then pPos = cc.Position return end
                    findPart(cc)
                    if pPos then return end
                end
            end
            findPart(f.Parent)
            if pPos then dist = (pPos - playerPos).Magnitude end
        end
        if dist < bestDist then
            bestDist = dist
            best = f
        end
    end
    return best, bestDist
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

log("========== DROP AT CURRENT POSITION TEST ==========")
log("Player:", player.Name)
log("Stand still in the apartment where printers should be placed.")

local folder, folderDist = findMoneyPrintersFolder()
if not folder then
    log("ERROR: No MoneyPrinters folder found")
    copy()
    return
end
log("Target folder:", folder:GetFullName(), "distance:", tostring(math.round(folderDist * 10) / 10))

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

-- Unequip current tool
for _, c in ipairs(char:GetChildren()) do
    if c:IsA("Tool") then
        pcall(function() c.Parent = backpack end)
    end
end
pcall(function() humanoid:UnequipTools() end)
task.wait(0.5)

-- Equip
log("Equipping tool...")
local ok, err = pcall(function() humanoid:EquipTool(tool) end)
if not ok then log("Equip error:", tostring(err)) end
log("Tool parent after equip:", tool.Parent and tool.Parent.Name or "nil")

task.wait(0.5)

-- Drop via VIM Backspace
log("Dropping tool with VirtualInputManager Backspace...")
pcall(function()
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Backspace, false, game)
    task.wait(0.1)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Backspace, false, game)
end)

log("Tool parent after drop:", tool.Parent and tool.Parent:GetFullName() or "nil")

log("Waiting up to 20 seconds for server to convert...")
local converted = false
for i = 1, 20 do
    task.wait(1)
    local now = countPrinters(folder)
    log("t+", tostring(i), "printers:", tostring(now))
    if now > before then
        converted = true
        break
    end
end

if converted then
    log("*** PLACEMENT WORKED AT CURRENT POSITION! ***")
else
    log("No placement detected at current position")
    -- Check workspace for dropped tool
    local dropped = false
    for _, c in ipairs(Workspace:GetChildren()) do
        if c:IsA("Tool") and c.Name:lower():find("print") then
            log("Found dropped tool in Workspace:", c:GetFullName())
            dropped = true
        end
    end
    if not dropped then
        log("No dropped tool in Workspace either")
    end
end

log("\n========== END ==========")
copy()
