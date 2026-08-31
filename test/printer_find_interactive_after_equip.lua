--[[
    San Diego Agent — Test: find interactive elements after equipping printer
    ========================================================================
    Экипирует принтер, ждёт, затем ищет ClickDetector / ProximityPrompt
    на всём персонаже и вокруг, пытается их активировать.
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
    if writefile then pcall(function() writefile("printer_find_interactive_log.txt", text) end) end
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

log("========== FIND INTERACTIVE AFTER EQUIP ==========")
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
pcall(function() humanoid:EquipTool(tool) end)

task.wait(3)
log("Tool parent after 3s:", tool.Parent and tool.Parent.Name or "nil")

-- Search character and tool for interactive elements
log("\n--- Searching for ClickDetectors/ProximityPrompts ---")
local interactives = {}
local function scan(parent, depth)
    if depth > 5 then return end
    for _, c in ipairs(parent:GetChildren()) do
        if c:IsA("ClickDetector") or c:IsA("ProximityPrompt") then
            log("Found", c.ClassName, c.Name, "on", c.Parent and c.Parent:GetFullName() or "nil")
            table.insert(interactives, c)
        end
        scan(c, depth + 1)
    end
end

scan(char, 0)
scan(tool, 0)

-- Also search nearby area around character
local hrp = char:FindFirstChild("HumanoidRootPart")
if hrp then
    log("\n--- Searching nearby workspace parts for interactives ---")
    local region = Region3.new(hrp.Position - Vector3.new(10, 10, 10), hrp.Position + Vector3.new(10, 10, 10))
    local parts = Workspace:FindPartsInRegion3(region, char, 100)
    local seen = {}
    for _, part in ipairs(parts) do
        for _, c in ipairs(part:GetChildren()) do
            if (c:IsA("ClickDetector") or c:IsA("ProximityPrompt")) and not seen[c] then
                seen[c] = true
                log("Nearby", c.ClassName, c.Name, "on", part:GetFullName())
                table.insert(interactives, c)
            end
        end
    end
end

if #interactives == 0 then
    log("No interactive elements found")
end

-- Try firing each
for _, interactive in ipairs(interactives) do
    log("\nFiring", interactive.ClassName, interactive.Name)
    if interactive:IsA("ClickDetector") and fireclickdetector then
        pcall(function() fireclickdetector(interactive) end)
    elseif interactive:IsA("ProximityPrompt") and fireproximityprompt then
        pcall(function() fireproximityprompt(interactive) end)
    end
    task.wait(1)
end

task.wait(3)
local after = countPrinters(folder)
log("\nPrinters in folder after:", tostring(after))

if after > before then
    log("*** PLACEMENT WORKED! ***")
else
    log("No placement detected")
end

pcall(function()
    humanoid:UnequipTools()
    if tool.Parent ~= backpack then
        tool.Parent = backpack
    end
end)

log("\n========== END ==========")
copy()
