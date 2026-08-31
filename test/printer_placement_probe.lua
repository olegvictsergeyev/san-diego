--[[
    San Diego Agent — Probe: printer placement
    =====================================================
    Исследует инвентарь и принтеры: ищет инструменты-принтеры,
    изучает их структуру, пробует экипировать/активировать и
    записывает, что происходит. Запусти в executor'е и скопируй
    сюда полный вывод (уже будет в консоли и буфере обмена).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local lines = {}
local function log(...)
    local msg = table.concat({ ... }, " ")
    table.insert(lines, msg)
    print(msg)
end

local function dumpToClipboard()
    local text = table.concat(lines, "\n")
    if setclipboard then
        pcall(function()
            setclipboard(text)
            log("[Clipboard] Output copied to clipboard")
        end)
    else
        log("[Clipboard] setclipboard not available")
    end
end

local function describeInstance(inst, depth)
    if not inst then
        return string.rep("  ", depth or 0) .. "nil"
    end
    local indent = string.rep("  ", depth or 0)
    local info = indent .. inst.Name .. " (" .. inst.ClassName .. ")"
    if inst:IsA("ValueBase") then
        info = info .. " = " .. tostring(inst.Value) .. " (" .. typeof(inst.Value) .. ")"
    elseif inst:IsA("BasePart") then
        info = info .. " pos=" .. tostring(inst.Position) .. " size=" .. tostring(inst.Size)
    elseif inst:IsA("Humanoid") then
        info = info .. " health=" .. tostring(inst.Health)
    end
    return info
end

local function dumpChildren(parent, depth, maxDepth, filter)
    if not parent then
        return
    end
    if depth > maxDepth then
        return
    end
    for _, child in ipairs(parent:GetChildren()) do
        if not filter or filter(child) then
            log(describeInstance(child, depth))
            dumpChildren(child, depth + 1, maxDepth, filter)
        end
    end
end

local function isPrinterLike(inst)
    local name = inst.Name:lower()
    return name:find("print") or name:find("press") or name:find("money") or name:find("cash")
end

-- ============================================================
-- 1. Поиск принтеров в Backpack / StarterGear / PlayerGui
-- ============================================================
log("========== PRINTER PLACEMENT PROBE ==========")
log("Player:", player.Name, "UserId:", tostring(player.UserId))
log("Time:", tostring(tick()))

local backpacks = {}
for _, p in ipairs(Players:GetPlayers()) do
    if p:FindFirstChild("Backpack") then
        table.insert(backpacks, p.Backpack)
    end
end
if player:FindFirstChild("StarterGear") then
    table.insert(backpacks, player.StarterGear)
end

local printerTools = {}
for _, container in ipairs(backpacks) do
    log("\n-- scanning", container:GetFullName(), "--")
    for _, child in ipairs(container:GetChildren()) do
        log(describeInstance(child, 0))
        if isPrinterLike(child) then
            table.insert(printerTools, child)
            log("  -> matched as printer-like")
        end
    end
end

log("\n-- found", tostring(#printerTools), "printer-like tool(s) --")
for _, tool in ipairs(printerTools) do
    log("  *", tool:GetFullName())
end

-- ============================================================
-- 2. Детальная информация по каждому принтеру
-- ============================================================
for i, tool in ipairs(printerTools) do
    log("\n========== PRINTER #" .. tostring(i) .. ": " .. tool.Name .. " ==========")
    log("Path:", tool:GetFullName())
    log("Class:", tool.ClassName)
    if tool:IsA("Tool") then
        log("Tool properties:")
        log("  CanBeDropped:", tostring(tool.CanBeDropped))
        log("  RequiresHandle:", tostring(tool.RequiresHandle))
        log("  ToolTip:", tostring(tool.ToolTip))
        log("  GripPos:", tostring(tool.GripPos))
        log("  GripForward:", tostring(tool.GripForward))
        log("  GripRight:", tostring(tool.GripRight))
        log("  GripUp:", tostring(tool.GripUp))
        log("  ManualActivationOnly:", tostring(tool.ManualActivationOnly))
        log("  ActivationAllowed:", tostring(tool.ActivationAllowed))
    end

    log("Children (3 levels):")
    dumpChildren(tool, 0, 3)

    -- Собираем дочерние RemoteEvent/RemoteFunction/ClickDetector/ProximityPrompt
    local interesting = {}
    local function collectInteresting(inst)
        if inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") or inst:IsA("ClickDetector") or inst:IsA("ProximityPrompt") or inst:IsA("BindableEvent") or inst:IsA("BindableFunction") then
            table.insert(interesting, inst)
        end
        for _, c in ipairs(inst:GetChildren()) do
            collectInteresting(c)
        end
    end
    collectInteresting(tool)

    log("Interesting children count:", tostring(#interesting))
    for _, c in ipairs(interesting) do
        log("  ", c.ClassName, c.Name, "path:", c:GetFullName())
    end
end

-- ============================================================
-- 3. Поиск placement-ремотов в ReplicatedStorage
-- ============================================================
log("\n========== REMOTES RELATED TO PLACING/BUILDING/PRINTERS ==========")
local placementKeywords = { "place", "deploy", "build", "buildmode", "printer", "print", "drop", "spawn", "furniture", "item" }
local matchedRemotes = {}
local function scanRemotes(parent, path)
    for _, child in ipairs(parent:GetChildren()) do
        local lowerName = child.Name:lower()
        local isRemote = child:IsA("RemoteEvent") or child:IsA("RemoteFunction") or child:IsA("BindableEvent") or child:IsA("BindableFunction")
        local isFolder = child:IsA("Folder") or child:IsA("Model") or child:IsA("Configuration")

        if isRemote then
            local match = false
            for _, kw in ipairs(placementKeywords) do
                if lowerName:find(kw) then
                    match = true
                    break
                end
            end
            if match then
                log("  ", child.ClassName, child:GetFullName())
                table.insert(matchedRemotes, child)
            end
        elseif isFolder then
            scanRemotes(child, path .. "." .. child.Name)
        end
    end
end
scanRemotes(ReplicatedStorage, "ReplicatedStorage")
log("Matched remotes:", tostring(#matchedRemotes))

-- ============================================================
-- 4. Уже размещённые принтеры в Workspace
-- ============================================================
log("\n========== EXISTING PRINTERS IN WORKSPACE ==========")
local existingPrinters = {}
local function findPlacedPrinters(parent, depth)
    if depth > 4 then
        return
    end
    for _, child in ipairs(parent:GetChildren()) do
        if isPrinterLike(child) then
            log("  found placed:", child:GetFullName(), "pos=", tostring(child:IsA("BasePart") and child.Position or "N/A"))
            table.insert(existingPrinters, child)
        end
        if not child:IsA("BasePart") then
            findPlacedPrinters(child, depth + 1)
        end
    end
end
findPlacedPrinters(Workspace, 0)
log("Total placed printers:", tostring(#existingPrinters))

-- ============================================================
-- 5. Пробуем экипировать первый принтер и активировать
-- ============================================================
log("\n========== EQUIP & ACTIVATE TEST ==========")
if #printerTools == 0 then
    log("No printer tools found; skipping equip test.")
else
    local tool = printerTools[1]
    local char = player.Character or player.CharacterAdded:Wait()
    local humanoid = char:WaitForChild("Humanoid")

    -- Drop current tool if any
    if humanoid and humanoid.Health > 0 then
        local currentTool = char:FindFirstChildOfClass("Tool")
        if currentTool then
            log("Unequipping current tool:", currentTool.Name)
            currentTool.Parent = player.Backpack
        end
    end

    task.wait(0.3)

    -- Equip the printer
    log("Equipping tool:", tool.Name)
    tool.Parent = char
    task.wait(0.5)

    -- Dump character state after equip
    log("Character children after equip:")
    dumpChildren(char, 0, 2, function(c)
        return c.ClassName ~= "BasePart" and c.ClassName ~= "Decal" and c.ClassName ~= "Texture" and c.ClassName ~= "MeshPart"
    end)

    -- Dump PlayerGui after equip
    log("\nPlayerGui children after equip:")
    if player:FindFirstChild("PlayerGui") then
        dumpChildren(player.PlayerGui, 0, 1)
    end

    -- Dump workspace around player after equip
    log("\nWorkspace new children near player after equip:")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then
        local pos = hrp.Position
        for _, child in ipairs(Workspace:GetChildren()) do
            if child:IsA("BasePart") then
                local d = (child.Position - pos).Magnitude
                if d < 30 then
                    log("  ", child.Name, "(", child.ClassName, ") dist=", tostring(math.round(d * 10) / 10), "pos=", tostring(child.Position))
                end
            end
        end
    end

    -- Try Activate
    log("\nTrying tool:Activate() on", tool.Name)
    local oldCount = #player.Backpack:GetChildren()
    local ok, err = pcall(function()
        tool:Activate()
    end)
    log("Activate result:", ok and "OK" or "ERR", ok and "" or tostring(err))
    task.wait(0.5)

    -- Check if tool was consumed / unequipped / ghost appeared
    log("Tool parent after Activate:", tool.Parent and tool.Parent.Name or "nil")
    log("Backpack count before/after:", tostring(oldCount), "/", tostring(#player.Backpack:GetChildren()))

    -- Try mouse click if target exists
    log("\nMouse state after Activate:")
    log("  Target:", mouse.Target and mouse.Target:GetFullName() or "nil")
    log("  Hit:", tostring(mouse.Hit))
    log("  Hit.p:", tostring(mouse.Hit and mouse.Hit.p))

    -- Try dequip and equip again
    task.wait(0.3)
    if tool.Parent == char then
        log("Unequipping", tool.Name)
        tool.Parent = player.Backpack
    end
end

-- ============================================================
-- 6. Поиск UI связанного с расстановкой (Placement UI)
-- ============================================================
log("\n========== PLACEMENT UI SEARCH ==========")
if player:FindFirstChild("PlayerGui") then
    local placementUiKeywords = { "place", "build", "deploy", "printer", "furniture", "item", "rotation", "confirm" }
    for _, gui in ipairs(player.PlayerGui:GetChildren()) do
        local lowerName = gui.Name:lower()
        local isUi = gui:IsA("ScreenGui") or gui:IsA("BillboardGui") or gui:IsA("SurfaceGui")
        if isUi then
            local matched = false
            for _, kw in ipairs(placementUiKeywords) do
                if lowerName:find(kw) then
                    matched = true
                    break
                end
            end
            if matched then
                log("UI matched:", gui.Name, "(", gui.ClassName, ")")
                dumpChildren(gui, 1, 2)
            end
        end
    end
end

-- ============================================================
-- 7. JSON-дамп найденных принтеров и ремотов
-- ============================================================
log("\n========== JSON SUMMARY ==========")
local summary = {
    player = player.Name,
    userId = player.UserId,
    printerTools = {},
    matchedRemotes = {},
    existingPrinters = {},
}

for _, tool in ipairs(printerTools) do
    table.insert(summary.printerTools, {
        name = tool.Name,
        class = tool.ClassName,
        path = tool:GetFullName(),
    })
end
for _, r in ipairs(matchedRemotes) do
    table.insert(summary.matchedRemotes, {
        name = r.Name,
        class = r.ClassName,
        path = r:GetFullName(),
    })
end
for _, p in ipairs(existingPrinters) do
    table.insert(summary.existingPrinters, {
        name = p.Name,
        class = p.ClassName,
        path = p:GetFullName(),
        position = p:IsA("BasePart") and tostring(p.Position) or nil,
    })
end

local ok, json = pcall(function()
    return HttpService:JSONEncode(summary)
end)
if ok then
    log(json)
    if setclipboard then
        pcall(function()
            setclipboard(json)
            log("[Clipboard] JSON summary copied")
        end)
    end
else
    log("JSON encode error:", tostring(json))
end

log("========== END PROBE ==========")
dumpToClipboard()
