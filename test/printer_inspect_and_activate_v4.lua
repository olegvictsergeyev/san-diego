--[[
    San Diego Agent — Probe v4: inspect folder + manual printer + try Activate
    ==========================================================================
    Один скрипт на всё:
    1. Показывает, что сейчас лежит в папке MoneyPrinters.
    2. Подробно описывает ручной принтер (если есть).
    3. Берёт 1 принтер из Backpack, экипирует, активирует.
    4. Наблюдает, появится ли новый принтер в папке.
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
    if writefile then pcall(function() writefile("printer_inspect_and_activate_v4_log.txt", text) end) end
end

local function getPlayerPos()
    local char = player.Character or player.CharacterAdded:Wait()
    local hrp = char:FindFirstChild("HumanoidRootPart")
    return hrp and hrp.Position
end

local function findNearestMoneyPrintersFolder()
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

local function inspectObject(obj, depth)
    if depth == nil then depth = 0 end
    if depth > 2 then return end
    log(string.rep("  ", depth) .. "Object:", obj.Name, "Class:", obj.ClassName, "Full:", obj:GetFullName())

    -- Attributes
    local ok, attrs = pcall(function() return obj:GetAttributes() end)
    if ok and attrs and next(attrs) then
        for k, v in pairs(attrs) do
            log(string.rep("  ", depth + 1) .. "attr:", k, "=", tostring(v), "(", typeof(v), ")")
        end
    end

    -- Tags
    local ok2, tags = pcall(function() return obj:GetTags() end)
    if ok2 and tags and #tags > 0 then
        for _, tag in ipairs(tags) do
            log(string.rep("  ", depth + 1) .. "tag:", tag)
        end
    end

    -- Properties for Tools/Parts
    if obj:IsA("Tool") then
        local props = { "CanBeDropped", "Enabled", "ManualActivationOnly", "GripPos", "GripForward", "GripUp", "GripRight" }
        for _, prop in ipairs(props) do
            local ok3, val = pcall(function() return obj[prop] end)
            if ok3 then
                log(string.rep("  ", depth + 1) .. prop .. ":", tostring(val))
            end
        end
    end

    -- Children
    for _, child in ipairs(obj:GetChildren()) do
        if child:IsA("BasePart") then
            log(string.rep("  ", depth + 1) .. "Part:", child.Name, "Class:", child.ClassName,
                "Size:", tostring(child.Size), "Pos:", tostring(child.Position),
                "Anchored:", tostring(child.Anchored), "CanCollide:", tostring(child.CanCollide),
                "CFrame:", tostring(child.CFrame))
            local ok3, attrs3 = pcall(function() return child:GetAttributes() end)
            if ok3 and attrs3 and next(attrs3) then
                for k, v in pairs(attrs3) do
                    log(string.rep("  ", depth + 2) .. "attr:", k, "=", tostring(v))
                end
            end
        elseif child:IsA("Weld") or child:IsA("WeldConstraint") or child:IsA("Motor6D") then
            log(string.rep("  ", depth + 1) .. "Joint:", child.Name, "Class:", child.ClassName,
                "Part0:", child.Part0 and child.Part0.Name or "nil",
                "Part1:", child.Part1 and child.Part1.Name or "nil")
        else
            inspectObject(child, depth + 1)
        end
    end
end

log("========== PRINTER INSPECT & ACTIVATE v4 ==========")
log("Player:", player.Name)

local folder = findNearestMoneyPrintersFolder()
if not folder then
    log("ERROR: No MoneyPrinters folder found")
    copy()
    return
end
log("Folder:", folder:GetFullName())

log("\n--- Folder contents ---")
for _, c in ipairs(folder:GetChildren()) do
    inspectObject(c, 0)
end

-- Take tool from backpack
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
    log("\nERROR: No Money Printer in backpack")
    copy()
    return
end
log("\nTool from backpack:", tool.Name)

-- Equip
local char = player.Character or player.CharacterAdded:Wait()
local humanoid = char:FindFirstChildOfClass("Humanoid")
if not humanoid then
    log("ERROR: No humanoid")
    copy()
    return
end

local beforeCount = #folder:GetChildren()
log("Printers in folder before activate:", tostring(beforeCount))

log("\nEquipping tool...")
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

if getconnections then
    log("Connections on Activated after equip:")
    local ok2, conns = pcall(function() return getconnections(tool.Activated) end)
    if ok2 and conns and #conns > 0 then
        for i, conn in ipairs(conns) do
            log("  ", tostring(i), tostring(conn.Function))
        end
    else
        log("  none")
    end
end

-- Activate
log("\nCalling tool:Activate()...")
local ok2, err2 = pcall(function()
    tool:Activate()
end)
log("Activate result:", ok2 and "ok" or "failed", tostring(err2))

log("\nWaiting 5 seconds...")
for i = 1, 5 do
    local currentCount = #folder:GetChildren()
    log("t+", tostring(i), "folder count:", tostring(currentCount))
    if currentCount > beforeCount then
        log("  -> NEW printer appeared")
        break
    end
    task.wait(1)
end

-- Inspect folder again
log("\n--- Folder contents after activate ---")
for _, c in ipairs(folder:GetChildren()) do
    inspectObject(c, 0)
end

-- Try manual Activated fire
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
    log("Folder count after manual fire:", tostring(#folder:GetChildren()))
end

-- Unequip
pcall(function()
    if humanoid then humanoid:UnequipTools() end
end)

log("\n========== END PROBE ==========")
copy()
