--[[
    San Diego Agent — Test: try different placement methods
    ======================================================
    Пробует разные способы "выставить" принтер из Tool:
    1. Humanoid:DropTool()
    2. Симуляция Backspace/keypress.
    3. Tool.Parent = Workspace (ещё раз).
    4. Проверяет, появился ли Model в MoneyPrinters.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

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
    if writefile then pcall(function() writefile("printer_placement_methods_test_log.txt", text) end) end
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

local function countFolder(folder)
    if not folder then return 0 end
    local count = 0
    for _, c in ipairs(folder:GetChildren()) do
        if c:HasTag("MoneyPrinter") or c.Name:lower():find("print") then
            count += 1
        end
    end
    return count
end

log("========== PRINTER PLACEMENT METHODS TEST ==========")
log("Player:", player.Name)
log("Stand in apartment with at least 1 printer in backpack")

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

local function tryMethod(name, action)
    log("\n--- Trying method:", name, "---")

    -- Make sure tool is in backpack
    if tool.Parent ~= backpack then
        log("  returning tool to backpack first")
        pcall(function() tool.Parent = backpack end)
        task.wait(0.5)
    end

    local before = countFolder(folder)
    log("  folder count before:", tostring(before))

    -- Equip
    local ok, err = pcall(function() humanoid:EquipTool(tool) end)
    if not ok then
        log("  equip failed:", tostring(err))
        return
    end
    task.wait(0.5)
    log("  tool parent after equip:", tool.Parent and tool.Parent.Name or "nil")

    -- Run action
    local aok, aerr = pcall(action)
    if not aok then
        log("  action failed:", tostring(aerr))
    end

    -- Wait
    task.wait(3)
    local after = countFolder(folder)
    log("  folder count after 3s:", tostring(after))

    -- Return tool if possible
    pcall(function()
        humanoid:UnequipTools()
        if tool.Parent ~= backpack then
            tool.Parent = backpack
        end
    end)
    task.wait(0.5)

    if after > before then
        log("  *** METHOD WORKED! ***")
    else
        log("  method did not place printer")
    end
end

-- Method 1: Humanoid:DropTool()
tryMethod("Humanoid:DropTool(tool)", function()
    if humanoid.DropTool then
        humanoid:DropTool(tool)
    else
        log("  DropTool method not available")
    end
end)

-- Method 2: keypress simulation (Backspace)
tryMethod("keypress Backspace", function()
    if keypress then
        keypress(0x08) -- Backspace VK
        task.wait(0.1)
        keyrelease(0x08)
    else
        log("  keypress not available")
    end
end)

-- Method 3: Drop tool with Parent = Workspace
tryMethod("tool.Parent = Workspace", function()
    tool.Parent = Workspace
end)

-- Method 4: Set CanBeDropped and use DropTool
tryMethod("CanBeDropped + DropTool", function()
    tool.CanBeDropped = true
    task.wait(0.1)
    if humanoid.DropTool then
        humanoid:DropTool(tool)
    else
        tool.Parent = Workspace
    end
end)

log("\n========== END TEST ==========")
copy()
