--[[
    San Diego Agent — Probe: printer placement v7
    =====================================================
    Тестирует дроп принтера и отслеживает конкретный инстанс,
    а не считает по имени. Смотрим, куда девается Tool после
    каждого действия, и что появляется рядом с персонажем.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer

local logs = {}
local function log(...)
    local msg = table.concat({ ... }, " ")
    table.insert(logs, msg)
    print(msg)
    warn(msg)
end

local function copy()
    local text = table.concat(logs, "\n")
    if setclipboard then pcall(function() setclipboard(text) end) end
    if writefile then pcall(function() writefile("printer_probe_v7_log.txt", text) end) end
end

local function findPrinter()
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        for _, c in ipairs(backpack:GetChildren()) do
            if c:IsA("Tool") and c.Name:lower():find("print") then return c end
        end
    end
    local char = player.Character
    if char then
        for _, c in ipairs(char:GetChildren()) do
            if c:IsA("Tool") and c.Name:lower():find("print") then return c end
        end
    end
    return nil
end

local function getHrp()
    local char = player.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function snapshotNearPlayer(radius)
    local hrp = getHrp()
    if not hrp then return {} end
    local pos = hrp.Position
    local list = {}
    local function scan(parent)
        for _, c in ipairs(parent:GetChildren()) do
            if c:IsA("BasePart") then
                local d = (c.Position - pos).Magnitude
                if d <= radius then
                    table.insert(list, { name = c.Name, class = c.ClassName, path = c:GetFullName(), dist = math.round(d * 10) / 10 })
                end
            end
            if not c:IsA("BasePart") then
                scan(c)
            end
        end
    end
    scan(Workspace)
    return list
end

local function scanWorkspaceByName(nameSub)
    local found = {}
    local function scan(parent)
        for _, c in ipairs(parent:GetChildren()) do
            if c.Name:lower():find(nameSub:lower()) then
                table.insert(found, { name = c.Name, class = c.ClassName, path = c:GetFullName() })
            end
            if not c:IsA("BasePart") then
                scan(c)
            end
        end
    end
    scan(Workspace)
    return found
end

local function describeTool(tool)
    if not tool then return "nil" end
    return tool.Name .. " (" .. tool.ClassName .. ") id=" .. tostring(tool) .. " parent=" .. (tool.Parent and tool.Parent.Name or "nil")
end

log("========== PRINTER PLACEMENT PROBE v7 ==========")
log("Player:", player.Name)

local printer = findPrinter()
if not printer then
    log("ERROR: No printer found")
    copy()
    return
end
log("Selected printer:", describeTool(printer))
for _, c in ipairs(printer:GetChildren()) do
    log("  child:", c.Name, "(", c.ClassName, ")")
end

local char = player.Character or player.CharacterAdded:Wait()
local humanoid = char:WaitForChild("Humanoid", 5)

-- Экипируем
log("\n--- Equipping ---")
local current = char:FindFirstChildOfClass("Tool")
if current then
    current.Parent = player.Backpack
    task.wait(0.3)
end
printer.Parent = char
task.wait(0.5)
log("After equip:", describeTool(printer))

-- Проверяем, есть ли уже размещённые принтеры рядом
log("\n--- Nearby printers before drop (radius 15) ---")
local nearBefore = snapshotNearPlayer(15)
local printedBefore = 0
for _, item in ipairs(nearBefore) do
    if item.name:lower():find("print") then
        log("  ", item.path, "dist=", item.dist)
        printedBefore += 1
    end
end
log("Total printer-like parts near player before:", tostring(printedBefore))

-- Пробуем Parent = workspace
log("\n--- Attempt: tool.Parent = workspace ---")
local beforeAll = scanWorkspaceByName("Money Printer")
log("Money Printer objects in workspace before:", tostring(#beforeAll))
local ok, err = pcall(function() printer.Parent = workspace end)
log("Set parent result:", ok and "OK" or "ERR", ok and "" or tostring(err))
task.wait(2)
log("After 2s:", describeTool(printer))
if printer.Parent then
    log("IsDescendantOf Workspace:", tostring(printer:IsDescendantOf(Workspace)))
end

local afterAll = scanWorkspaceByName("Money Printer")
log("Money Printer objects in workspace after:", tostring(#afterAll))
if #afterAll > #beforeAll then
    log("  -> new object appeared")
    for i = #beforeAll + 1, #afterAll do
        log("    new:", afterAll[i].path, "(", afterAll[i].class, ")")
    end
elseif #afterAll < #beforeAll then
    log("  -> some objects removed")
end

log("\n--- Nearby objects after drop (radius 15) ---")
local nearAfter = snapshotNearPlayer(15)
local printedAfter = 0
for _, item in ipairs(nearAfter) do
    if item.name:lower():find("print") then
        log("  ", item.path, "dist=", item.dist)
        printedAfter += 1
    end
end
log("Total printer-like parts near player after:", tostring(printedAfter))

-- Если принтер исчез, ищем что-то похожее по детям
log("\n--- Searching for tool children in workspace ---")
local printerChildNames = {}
for _, c in ipairs(printer:GetChildren()) do
    table.insert(printerChildNames, c.Name)
end
for _, childName in ipairs(printerChildNames) do
    local matches = scanWorkspaceByName(childName)
    if #matches > 0 then
        log("  found", tostring(#matches), "matches for", childName)
        for _, m in ipairs(matches) do
            log("    ", m.path, "(", m.class, ")")
        end
    end
end

-- Если tool всё ещё в workspace, посмотрим его положение
if printer:IsDescendantOf(Workspace) then
    local handle = printer:FindFirstChild("Handle")
    if handle and handle:IsA("BasePart") then
        log("\nDropped tool Handle position:", tostring(handle.Position))
    end
    local printerD = printer:FindFirstChild("Printer_d")
    if printerD and printerD:IsA("BasePart") then
        log("Dropped tool Printer_d position:", tostring(printerD.Position))
    end
end

-- Попробуем Activate после дропа
if printer:IsDescendantOf(Workspace) or printer.Parent == char then
    log("\n--- Attempt: Activate after drop/equip ---")
    pcall(function() printer:Activate() end)
    task.wait(1)
    log("After Activate:", describeTool(printer))
end

log("\n========== JSON SUMMARY ==========")
local summary = {
    player = player.Name,
    userId = player.UserId,
    printerName = printer.Name,
    printerId = tostring(printer),
    printerChildren = printerChildNames,
    afterDropParent = printer.Parent and printer.Parent.Name or "nil",
    isInWorkspace = printer:IsDescendantOf(Workspace),
    nearPlayerBefore = printedBefore,
    nearPlayerAfter = printedAfter,
    moneyPrinterCountBefore = #beforeAll,
    moneyPrinterCountAfter = #afterAll,
}
local ok, json = pcall(function() return HttpService:JSONEncode(summary) end)
if ok then
    log(json)
    if setclipboard then pcall(function() setclipboard(json) end) end
else
    log("JSON error:", tostring(json))
end

log("========== END PROBE v7 ==========")
copy()
