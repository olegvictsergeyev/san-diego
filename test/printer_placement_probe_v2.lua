--[[
    San Diego Agent — Probe: printer placement v2
    =====================================================
    Сокращённый исследовательский скрипт. Только локальный игрок,
    только первый принтер, подробный лог экипировки/активации.
    Запусти в executor'е и скопируй сюда полный вывод.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local logs = {}
local function log(...)
    local msg = table.concat({ ... }, " ")
    table.insert(logs, msg)
    print(msg)
end

local function copyLogs()
    local text = table.concat(logs, "\n")
    if setclipboard then
        pcall(function()
            setclipboard(text)
        end)
    end
end

local function safeProp(inst, prop)
    local ok, v = pcall(function()
        return inst[prop]
    end)
    return ok and tostring(v) or "ERR"
end

local function describeChildren(parent, maxDepth, depth)
    depth = depth or 0
    if depth > maxDepth then
        return
    end
    for _, child in ipairs(parent:GetChildren()) do
        local line = string.rep("  ", depth) .. child.Name .. " (" .. child.ClassName .. ")"
        if child:IsA("BasePart") then
            line = line .. " pos=" .. tostring(child.Position)
        elseif child:IsA("ValueBase") then
            line = line .. " value=" .. tostring(child.Value)
        end
        log(line)
        if not child:IsA("BasePart") then
            describeChildren(child, maxDepth, depth + 1)
        end
    end
end

local function getConnections(obj, eventName)
    local results = {}
    local ok, event = pcall(function()
        return obj[eventName]
    end)
    if not ok or not event then
        return results
    end
    if typeof(event) == "RBXScriptSignal" and getconnections then
        local conns = getconnections(event)
        for _, c in ipairs(conns) do
            table.insert(results, {
                enabled = c.Enabled,
                func = tostring(c.Function),
            })
        end
    end
    return results
end

log("========== PRINTER PLACEMENT PROBE v2 ==========")
log("Player:", player.Name, "UserId:", tostring(player.UserId))
log("Time:", tostring(tick()))

-- Находим первый принтер локального игрока
local backpack = player:FindFirstChild("Backpack")
if not backpack then
    log("ERROR: Backpack not found")
    copyLogs()
    return
end

local printer = nil
for _, child in ipairs(backpack:GetChildren()) do
    if child:IsA("Tool") and child.Name:lower():find("print") then
        printer = child
        break
    end
end

if not printer then
    log("ERROR: No printer tool found in local Backpack")
    copyLogs()
    return
end

log("Selected printer:", printer.Name, "path:", printer:GetFullName())
log("Class:", printer.ClassName)
log("Properties:")
log("  CanBeDropped:", tostring(printer.CanBeDropped))
log("  RequiresHandle:", tostring(printer.RequiresHandle))
log("  ManualActivationOnly:", tostring(printer.ManualActivationOnly))
log("  ToolTip:", tostring(printer.ToolTip))
log("  ActivationAllowed:", tostring(printer.ActivationAllowed))
log("  GripPos:", tostring(printer.GripPos))
log("  GripForward:", tostring(printer.GripForward))
log("  GripUp:", tostring(printer.GripUp))
log("  GripRight:", tostring(printer.GripRight))

log("\nChildren of printer (2 levels):")
describeChildren(printer, 2)

log("\nConnections on printer:")
local eventsToCheck = { "Activated", "Deactivated", "Equipped", "Unequipped" }
for _, eventName in ipairs(eventsToCheck) do
    local conns = getConnections(printer, eventName)
    log("  " .. eventName .. ": " .. tostring(#conns) .. " connection(s)")
    for i, c in ipairs(conns) do
        log("    [" .. tostring(i) .. "] enabled=" .. tostring(c.enabled) .. " func=" .. c.func)
    end
end

log("\nConnections on Workspace/players (placement events):")
local placementKeywords = { "place", "deploy", "build", "printer", "spawn", "furniture" }
local function scanRemotes(parent, depth)
    if depth > 3 then
        return
    end
    for _, child in ipairs(parent:GetChildren()) do
        local lower = child.Name:lower()
        local isRemote = child:IsA("RemoteEvent") or child:IsA("RemoteFunction")
        local isFolder = child:IsA("Folder") or child:IsA("Configuration") or child:IsA("Model")
        if isRemote then
            for _, kw in ipairs(placementKeywords) do
                if lower:find(kw) then
                    log("  REMOTE", child.ClassName, child:GetFullName())
                    break
                end
            end
        elseif isFolder then
            scanRemotes(child, depth + 1)
        end
    end
end
scanRemotes(ReplicatedStorage, 0)

log("\n========== EQUIP TEST ==========")
local char = player.Character
if not char then
    char = player.CharacterAdded:Wait()
    log("Waited for Character")
end

local humanoid = char:WaitForChild("Humanoid", 5)
if not humanoid then
    log("ERROR: Humanoid not found")
    copyLogs()
    return
end

-- Unequip current tool
local currentTool = char:FindFirstChildOfClass("Tool")
if currentTool then
    log("Unequipping current tool:", currentTool.Name)
    currentTool.Parent = backpack
    task.wait(0.3)
end

log("Equipping printer:", printer.Name)
local beforeWorkspace = {}
for _, c in ipairs(Workspace:GetChildren()) do
    beforeWorkspace[c] = true
end
local beforePlayerGui = {}
if player:FindFirstChild("PlayerGui") then
    for _, c in ipairs(player.PlayerGui:GetChildren()) do
        beforePlayerGui[c] = true
    end
end

printer.Parent = char
task.wait(0.5)

log("Printer parent after equip:", printer.Parent and printer.Parent.Name or "nil")
log("Humanoid state:", tostring(humanoid:GetState()))

log("\nCharacter children after equip (only non-parts):")
for _, c in ipairs(char:GetChildren()) do
    if not c:IsA("BasePart") and not c:IsA("Decal") and not c:IsA("Texture") then
        log("  ", c.Name, "(", c.ClassName, ")")
        if c:IsA("Tool") then
            for _, cc in ipairs(c:GetChildren()) do
                log("    ", cc.Name, "(", cc.ClassName, ")")
            end
        end
    end
end

log("\nNew objects in Workspace after equip:")
for _, c in ipairs(Workspace:GetChildren()) do
    if not beforeWorkspace[c] then
        log("  NEW", c.Name, "(", c.ClassName, ")")
        if c:IsA("BasePart") then
            log("    pos=", tostring(c.Position), "size=", tostring(c.Size))
        end
    end
end

log("\nNew objects in PlayerGui after equip:")
if player:FindFirstChild("PlayerGui") then
    for _, c in ipairs(player.PlayerGui:GetChildren()) do
        if not beforePlayerGui[c] then
            log("  NEW GUI", c.Name, "(", c.ClassName, ")")
            describeChildren(c, 1, 1)
        end
    end
end

log("\nMouse state after equip:")
log("  Target:", mouse.Target and mouse.Target:GetFullName() or "nil")
log("  Hit:", tostring(mouse.Hit))
log("  Hit.p:", tostring(mouse.Hit and mouse.Hit.p))

log("\n========== ACTIVATE TEST ==========")
log("Trying tool:Activate()...")
local ok, err = pcall(function()
    printer:Activate()
end)
log("Activate pcall result:", ok and "OK" or "ERR", ok and "" or tostring(err))
task.wait(0.5)

log("Printer parent after Activate:", printer.Parent and printer.Parent.Name or "nil")
log("Backpack child count:", tostring(#backpack:GetChildren()))

log("\nNew objects in Workspace after Activate:")
for _, c in ipairs(Workspace:GetChildren()) do
    if not beforeWorkspace[c] then
        log("  NEW", c.Name, "(", c.ClassName, ")")
        if c:IsA("BasePart") then
            log("    pos=", tostring(c.Position), "size=", tostring(c.Size))
        end
    end
end

log("\nMouse state after Activate:")
log("  Target:", mouse.Target and mouse.Target:GetFullName() or "nil")
log("  Hit:", tostring(mouse.Hit))
log("  Hit.p:", tostring(mouse.Hit and mouse.Hit.p))

log("\n========== CLICK TEST ==========")
-- Пытаемся имитировать клик в текущую позицию мыши
if mouse.Target then
    log("Trying to fire click on mouse target:", mouse.Target:GetFullName())
    local cd = mouse.Target:FindFirstChildOfClass("ClickDetector")
    if cd and fireclickdetector then
        log("Found ClickDetector, firing...")
        pcall(function()
            fireclickdetector(cd)
        end)
    else
        log("No ClickDetector or fireclickdetector unavailable")
    end

    local pp = mouse.Target:FindFirstChildOfClass("ProximityPrompt")
    if pp and fireproximityprompt then
        log("Found ProximityPrompt, firing...")
        pcall(function()
            fireproximityprompt(pp)
        end)
    else
        log("No ProximityPrompt or fireproximityprompt unavailable")
    end
else
    log("No mouse target for click test")
end

log("\n========== JSON SUMMARY ==========")
local summary = {
    player = player.Name,
    userId = player.UserId,
    printerName = printer.Name,
    printerPath = printer:GetFullName(),
    properties = {
        CanBeDropped = printer.CanBeDropped,
        RequiresHandle = printer.RequiresHandle,
        ManualActivationOnly = printer.ManualActivationOnly,
        ToolTip = printer.ToolTip,
        ActivationAllowed = printer.ActivationAllowed,
    },
}

local ok, json = pcall(function()
    return HttpService:JSONEncode(summary)
end)
if ok then
    log(json)
    if setclipboard then
        pcall(function()
            setclipboard(json)
            log("[Clipboard] JSON copied")
        end)
    end
else
    log("JSON error:", tostring(json))
end

log("========== END PROBE v2 ==========")
copyLogs()
