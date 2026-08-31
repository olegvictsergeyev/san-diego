--[[
    San Diego Agent — Test: click on equipped printer to place it
    =============================================================
    Пользователь кликает по принтеру в руке. Этот скрипт:
    1. Экипирует принтер.
    2. Ищет на нём ClickDetector / ProximityPrompt / другие интерактивные элементы.
    3. Пробует их активировать.
    4. Наблюдает, появится ли Model в MoneyPrinters.
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
    if writefile then pcall(function() writefile("printer_click_on_tool_test_log.txt", text) end) end
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

log("========== PRINTER CLICK ON TOOL TEST ==========")
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

-- Equip
log("Equipping tool...")
local ok, err = pcall(function() humanoid:EquipTool(tool) end)
if not ok then
    log("Equip failed:", tostring(err))
    copy()
    return
end
task.wait(0.5)
log("Tool parent:", tool.Parent and tool.Parent.Name or "nil")

-- Inspect tool parts for interactive elements
log("\n--- Inspecting equipped tool ---")
local interactives = {}
for _, desc in ipairs(tool:GetDescendants()) do
    if desc:IsA("ClickDetector") or desc:IsA("ProximityPrompt") or desc:IsA("TouchTransmitter") then
        log("Found interactive:", desc.ClassName, desc.Name, "on", desc.Parent and desc.Parent.Name or "nil")
        table.insert(interactives, desc)
    end
end

if #interactives == 0 then
    log("No ClickDetector/ProximityPrompt/TouchTransmitter found on tool")
end

-- Find Handle/Printer_d parts
local handle = tool:FindFirstChild("Handle")
local printerD = tool:FindFirstChild("Printer_d")
if handle then log("Handle found:", handle.Name, "Pos:", tostring(handle.Position)) end
if printerD then log("Printer_d found:", printerD.Name, "Pos:", tostring(printerD.Position)) end

-- Try to click on tool parts
if handle and fireclickdetector then
    for _, desc in ipairs(handle:GetDescendants()) do
        if desc:IsA("ClickDetector") then
            log("Firing ClickDetector on Handle...")
            pcall(function() fireclickdetector(desc) end)
            task.wait(0.5)
        end
    end
end

if handle and fireproximityprompt then
    for _, desc in ipairs(handle:GetDescendants()) do
        if desc:IsA("ProximityPrompt") then
            log("Firing ProximityPrompt on Handle...")
            pcall(function() fireproximityprompt(desc) end)
            task.wait(0.5)
        end
    end
end

if handle and firetouchinterest then
    log("Firing touch interest on Handle...")
    pcall(function()
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            firetouchinterest(hrp, handle, 0)
            task.wait(0.1)
            firetouchinterest(hrp, handle, 1)
        end
    end)
end

-- Try clicking on Printer_d
if printerD then
    if fireclickdetector then
        for _, desc in ipairs(printerD:GetDescendants()) do
            if desc:IsA("ClickDetector") then
                log("Firing ClickDetector on Printer_d...")
                pcall(function() fireclickdetector(desc) end)
                task.wait(0.5)
            end
        end
    end
    if fireproximityprompt then
        for _, desc in ipairs(printerD:GetDescendants()) do
            if desc:IsA("ProximityPrompt") then
                log("Firing ProximityPrompt on Printer_d...")
                pcall(function() fireproximityprompt(desc) end)
                task.wait(0.5)
            end
        end
    end
    if firetouchinterest then
        log("Firing touch interest on Printer_d...")
        pcall(function()
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                firetouchinterest(hrp, printerD, 0)
                task.wait(0.1)
                firetouchinterest(hrp, printerD, 1)
            end
        end)
    end
end

log("\nWaiting 3 seconds...")
task.wait(3)
local after = countPrinters(folder)
log("Printers in folder after:", tostring(after))

if after > before then
    log("*** PLACEMENT WORKED! ***")
else
    log("Placement did not work")
end

-- Unequip
pcall(function()
    humanoid:UnequipTools()
    if tool.Parent ~= backpack then
        tool.Parent = backpack
    end
end)

log("\n========== END TEST ==========")
copy()
