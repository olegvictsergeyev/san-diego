--[[
    San Diego Agent — Probe: printer placement v4
    =====================================================
    Компактный зонд. Полный лог пишется в файл и в буфер обмена.
    В консоль выводится только краткая JSON-сводка.
    Запусти в executor'е, затем найди файл printer_probe_v4_log.txt
    (или вставь сюда JSON из консоли/буфера).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local logs = {}
local function log(...)
    local msg = table.concat({ ... }, " ")
    table.insert(logs, msg)
end

local function printAndCopy()
    local text = table.concat(logs, "\n")
    print(text)
    if setclipboard then
        pcall(function() setclipboard(text) end)
    end
    if writefile then
        pcall(function() writefile("printer_probe_v4_log.txt", text) end)
    end
end

local summary = {
    player = player.Name,
    userId = player.UserId,
    printer = nil,
    properties = {},
    children = {},
    connections = {},
    workspaceBefore = 0,
    workspaceAfterEquip = {},
    workspaceAfterActivate = {},
    playerGuiAfterEquip = {},
    activateResult = nil,
    clickTest = {},
    matchedRemotes = {},
    errors = {},
}

local function addError(section, err)
    log("[ERROR] " .. section .. ": " .. tostring(err))
    summary.errors[section] = tostring(err)
end

log("========== PRINTER PLACEMENT PROBE v4 ==========")
log("Player: " .. player.Name .. " UserId: " .. tostring(player.UserId))

-- Backpack + printer
local backpack = player:FindFirstChild("Backpack")
if not backpack then
    addError("find backpack", "Backpack not found")
    printAndCopy()
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
    addError("find printer", "No printer tool in local Backpack")
    printAndCopy()
    return
end

summary.printer = {
    name = printer.Name,
    path = printer:GetFullName(),
}
log("Selected printer: " .. printer.Name)

-- Properties
local props = { "CanBeDropped", "RequiresHandle", "ManualActivationOnly", "ToolTip", "ActivationAllowed", "GripPos" }
for _, prop in ipairs(props) do
    local ok, v = pcall(function() return printer[prop] end)
    summary.properties[prop] = ok and tostring(v) or "ERR"
    log("  " .. prop .. " = " .. summary.properties[prop])
end

-- Children (1 level)
for _, child in ipairs(printer:GetChildren()) do
    table.insert(summary.children, { name = child.Name, class = child.ClassName })
    log("  child: " .. child.Name .. " (" .. child.ClassName .. ")")
    if child:IsA("BasePart") then
        log("    pos=" .. tostring(child.Position))
    end
end

-- Connections
for _, eventName in ipairs({ "Activated", "Deactivated", "Equipped", "Unequipped" }) do
    local count = 0
    local ok, event = pcall(function() return printer[eventName] end)
    if ok and event and typeof(event) == "RBXScriptSignal" and getconnections then
        local ok2, conns = pcall(function() return getconnections(event) end)
        if ok2 then
            count = #conns
        end
    end
    summary.connections[eventName] = count
    log("  " .. eventName .. " connections: " .. tostring(count))
end

-- Equip test
log("\n========== EQUIP TEST ==========")
local ok, err = pcall(function()
    local char = player.Character or player.CharacterAdded:Wait()
    local humanoid = char:WaitForChild("Humanoid", 5)

    local currentTool = char:FindFirstChildOfClass("Tool")
    if currentTool then
        currentTool.Parent = backpack
        task.wait(0.3)
    end

    summary.workspaceBefore = #Workspace:GetChildren()
    printer.Parent = char
    task.wait(0.5)

    log("Printer parent after equip: " .. (printer.Parent and printer.Parent.Name or "nil"))
    log("Humanoid state: " .. tostring(humanoid:GetState()))

    for _, c in ipairs(Workspace:GetChildren()) do
        table.insert(summary.workspaceAfterEquip, { name = c.Name, class = c.ClassName })
    end

    if player:FindFirstChild("PlayerGui") then
        for _, c in ipairs(player.PlayerGui:GetChildren()) do
            table.insert(summary.playerGuiAfterEquip, { name = c.Name, class = c.ClassName })
        end
    end

    log("Mouse target: " .. (mouse.Target and mouse.Target:GetFullName() or "nil"))
    log("Mouse Hit.p: " .. tostring(mouse.Hit and mouse.Hit.p))
end)
if not ok then
    addError("equip test", err)
end

-- Activate test
log("\n========== ACTIVATE TEST ==========")
local ok, err = pcall(function()
    local ok2, err2 = pcall(function() printer:Activate() end)
    summary.activateResult = { ok = ok2, err = ok2 and nil or tostring(err2) }
    log("Activate result: " .. (ok2 and "OK" or "ERR") .. " " .. (ok2 and "" or tostring(err2)))
    task.wait(0.5)
    log("Printer parent after Activate: " .. (printer.Parent and printer.Parent.Name or "nil"))

    for _, c in ipairs(Workspace:GetChildren()) do
        table.insert(summary.workspaceAfterActivate, { name = c.Name, class = c.ClassName })
    end
end)
if not ok then
    addError("activate test", err)
end

-- Click test
log("\n========== CLICK TEST ==========")
if mouse.Target then
    log("Mouse target: " .. mouse.Target:GetFullName())
    local cd = mouse.Target:FindFirstChildOfClass("ClickDetector")
    if cd and fireclickdetector then
        local ok2 = pcall(function() fireclickdetector(cd) end)
        summary.clickTest.fireclickdetector = ok2
        log("fireclickdetector: " .. (ok2 and "OK" or "ERR"))
    else
        summary.clickTest.fireclickdetector = "not found or unavailable"
        log("No ClickDetector or fireclickdetector unavailable")
    end
    local pp = mouse.Target:FindFirstChildOfClass("ProximityPrompt")
    if pp and fireproximityprompt then
        local ok2 = pcall(function() fireproximityprompt(pp) end)
        summary.clickTest.fireproximityprompt = ok2
        log("fireproximityprompt: " .. (ok2 and "OK" or "ERR"))
    else
        summary.clickTest.fireproximityprompt = "not found or unavailable"
        log("No ProximityPrompt or fireproximityprompt unavailable")
    end
else
    summary.clickTest.mouseTarget = "nil"
    log("No mouse target")
end

-- Remotes
log("\n========== REMOTES RELATED TO PLACING/PRINTERS ==========")
local placementKeywords = { "place", "deploy", "build", "printer", "spawn", "furniture" }
local function scanRemotes(parent, depth)
    if depth > 3 then return end
    for _, child in ipairs(parent:GetChildren()) do
        local lower = child.Name:lower()
        local isRemote = child:IsA("RemoteEvent") or child:IsA("RemoteFunction")
        local isFolder = child:IsA("Folder") or child:IsA("Configuration") or child:IsA("Model")
        if isRemote then
            for _, kw in ipairs(placementKeywords) do
                if lower:find(kw) then
                    table.insert(summary.matchedRemotes, { name = child.Name, class = child.ClassName, path = child:GetFullName() })
                    log("  REMOTE " .. child.ClassName .. " " .. child:GetFullName())
                    break
                end
            end
        elseif isFolder then
            scanRemotes(child, depth + 1)
        end
    end
end
scanRemotes(ReplicatedStorage, 0)

-- Final JSON
log("\n========== JSON SUMMARY ==========")
local ok, json = pcall(function() return HttpService:JSONEncode(summary) end)
if ok then
    log(json)
    if setclipboard then
        pcall(function() setclipboard(json) end)
    end
else
    addError("json encode", json)
end

log("========== END PROBE v4 ==========")
printAndCopy()
