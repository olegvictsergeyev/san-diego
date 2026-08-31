--[[
    San Diego Agent — Test: simulate Backspace drop
    ================================================
    Экипирует Money Printer и имитирует нажатие Backspace через VirtualInputManager.
    Проверяет, превратится ли Tool в Model.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

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
    if writefile then pcall(function() writefile("backspace_drop_test_log.txt", text) end) end
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

log("========== BACKSPACE DROP TEST ==========")
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

log("Equipping tool...")
local ok, err = pcall(function() humanoid:EquipTool(tool) end)
if not ok then log("Equip error:", tostring(err)) end
log("Tool parent after equip:", tool.Parent and tool.Parent.Name or "nil")

task.wait(1)

-- Try ContextActionService first
local CAS = game:GetService("ContextActionService")
log("Trying ContextActionService...")
local casOk, casErr = pcall(function()
    -- Some executors support firing bound actions
    if CAS.FireAction then
        CAS:FireAction("Drop", Enum.UserInputState.Begin, {})
    else
        log("CAS.FireAction not available")
    end
end)
if not casOk then log("CAS error:", tostring(casErr)) end

task.wait(0.5)

-- Try VirtualInputManager
local VIM = game:GetService("VirtualInputManager")
log("Trying VirtualInputManager Backspace...")
local vimOk, vimErr = pcall(function()
    VIM:SendKeyEvent(true, Enum.KeyCode.Backspace, false, game)
    task.wait(0.1)
    VIM:SendKeyEvent(false, Enum.KeyCode.Backspace, false, game)
end)
if not vimOk then log("VIM error:", tostring(vimErr)) end

task.wait(0.5)

-- Try InputBegan on UserInputService with fake input
log("Trying UserInputService.InputBegan...")
local inputOk, inputErr = pcall(function()
    -- Create a fake input object (may not work)
    local fakeInput = {
        KeyCode = Enum.KeyCode.Backspace,
        UserInputType = Enum.UserInputType.Keyboard,
        UserInputState = Enum.UserInputState.Begin,
        Position = Vector3.new(0, 0, 0),
        Delta = Vector3.new(0, 0, 0),
    }
    UserInputService.InputBegan:Fire(fakeInput)
end)
if not inputOk then log("InputBegan fire error:", tostring(inputErr)) end

task.wait(0.5)

log("Tool parent after simulated inputs:", tool.Parent and tool.Parent:GetFullName() or "nil")

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

log("\n========== END ==========")
copy()
