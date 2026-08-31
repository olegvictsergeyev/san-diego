--[[
    San Diego Agent — Probe v3: activate without remote hooks
    ==========================================================
    Без хуков remote'ов. Экипирует, активирует Tool и логирует изменения.
    Смотрит, появился ли новый принтер в MoneyPrinters, изменился ли Tool,
    появились ли скрипты/атрибуты.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
    if writefile then pcall(function() writefile("printer_activate_probe_v3_log.txt", text) end) end
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

local function inspectTool(tool, label)
    log("\n--- Tool state:", label, "---")
    log("  FullName:", tool:GetFullName())
    log("  Parent:", tool.Parent and tool.Parent.Name or "nil")
    log("  CanBeDropped:", tostring(tool.CanBeDropped))
    log("  Enabled:", tostring(tool.Enabled))
    log("  ManualActivationOnly:", tostring(tool.ManualActivationOnly))
    log("  GripPos:", tostring(tool.GripPos))

    -- Attributes
    local ok, attrs = pcall(function() return tool:GetAttributes() end)
    if ok and attrs and next(attrs) then
        log("  Attributes:")
        for k, v in pairs(attrs) do
            log("    ", k, "=", tostring(v))
        end
    end

    -- Children
    log("  Children:")
    for _, c in ipairs(tool:GetDescendants()) do
        log("    ", c.ClassName, c.Name, "Parent:", c.Parent.Name)
        if c:IsA("BasePart") then
            log("      Pos=", tostring(c.Position), "Anchored=", tostring(c.Anchored), "CanCollide=", tostring(c.CanCollide))
        end
    end

    -- Connections
    if getconnections then
        log("  Connections on Activated:")
        local ok2, conns = pcall(function() return getconnections(tool.Activated) end)
        if ok2 and conns then
            for i, conn in ipairs(conns) do
                log("    ", tostring(i), tostring(conn.Function))
            end
        else
            log("    none")
        end
    end
end

log("========== PRINTER ACTIVATE PROBE v3 ==========")
log("Player:", player.Name)

local folder = findMoneyPrintersFolder()
if not folder then
    log("WARNING: No MoneyPrinters folder found")
else
    log("Target folder:", folder:GetFullName())
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
    log("ERROR: No Money Printer in backpack")
    copy()
    return
end
log("Tool found:", tool.Name)

local beforeCount = folder and #folder:GetChildren() or 0
log("Printers in folder before:", tostring(beforeCount))

inspectTool(tool, "BEFORE equip")

-- Equip
log("\nEquipping tool...")
local char = player.Character or player.CharacterAdded:Wait()
local humanoid = char:FindFirstChildOfClass("Humanoid")
if not humanoid then
    log("ERROR: No humanoid")
    copy()
    return
end

local ok, err = pcall(function()
    humanoid:EquipTool(tool)
end)
if not ok then
    log("Equip failed:", tostring(err))
    copy()
    return
end
task.wait(1)
log("Tool parent after equip:", tool.Parent and tool.Parent.Name or "nil")
inspectTool(tool, "AFTER equip")

-- Activate
log("\nCalling tool:Activate()...")
local ok2, err2 = pcall(function()
    tool:Activate()
end)
log("Activate result:", ok2 and "ok" or "failed", tostring(err2))

log("\nWaiting 5 seconds...")
task.wait(5)
inspectTool(tool, "AFTER activate + 5s")

if folder then
    local afterCount = #folder:GetChildren()
    log("Printers in folder after activate:", tostring(afterCount))
    if afterCount > beforeCount then
        log("  -> NEW printer appeared in folder!")
        -- Show newest child
        for _, c in ipairs(folder:GetChildren()) do
            log("    child:", c.Name, "Class:", c.ClassName, "Full:", c:GetFullName())
        end
    else
        log("  -> No new printer in folder")
    end
end

-- Try manual fire
local mouse = player:GetMouse()
if mouse then
    log("\nMouse position:", tostring(mouse.Hit.Position))
    log("Firing tool.Activated manually...")
    pcall(function()
        if tool.Activated then
            tool.Activated:Fire(mouse.Hit.Position, mouse.Hit)
        end
    end)
    task.wait(3)
    inspectTool(tool, "AFTER manual Activated fire")
    if folder then
        log("Printers in folder after manual fire:", tostring(#folder:GetChildren()))
    end
end

-- Unequip
pcall(function()
    if humanoid then humanoid:UnequipTools() end
end)
task.wait(0.5)
inspectTool(tool, "AFTER unequip")

log("\n========== END PROBE ==========")
copy()
