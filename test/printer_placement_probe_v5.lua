--[[
    San Diego Agent — Probe: printer placement v5
    =====================================================
    Перебирает способы установки принтера и проверяет,
    какой из них реально создаёт объект в Workspace.
    Запусти в executor'е и скопируй JSON-сводку.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")

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
        pcall(function() setclipboard(text) end)
    end
    if writefile then
        pcall(function() writefile("printer_probe_v5_log.txt", text) end)
    end
end

local function getPrinterInBackpack()
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return nil end
    for _, child in ipairs(backpack:GetChildren()) do
        if child:IsA("Tool") and child.Name:lower():find("print") then
            return child
        end
    end
    return nil
end

local function getEquippedPrinter()
    local char = player.Character
    if not char then return nil end
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") and child.Name:lower():find("print") then
            return child
        end
    end
    return nil
end

local function findPlacedPrinter()
    for _, child in ipairs(Workspace:GetChildren()) do
        if child:IsA("Model") or child:IsA("Part") or child:IsA("MeshPart") then
            local name = child.Name:lower()
            if name:find("money printer") or name:find("printer") then
                return child
            end
        end
    end
    -- deeper search
    local function deep(parent)
        for _, c in ipairs(parent:GetChildren()) do
            if c:IsA("Model") or c:IsA("Part") or c:IsA("MeshPart") then
                local name = c.Name:lower()
                if name:find("money printer") or name:find("printer") then
                    return c
                end
            end
            if not c:IsA("BasePart") then
                local found = deep(c)
                if found then return found end
            end
        end
        return nil
    end
    return deep(Workspace)
end

local function countPrinters()
    local count = 0
    local function scan(parent)
        for _, c in ipairs(parent:GetChildren()) do
            if c:IsA("Model") or c:IsA("Part") or c:IsA("MeshPart") then
                local name = c.Name:lower()
                if name:find("money printer") or name:find("printer") then
                    count += 1
                end
            end
            if not c:IsA("BasePart") then
                scan(c)
            end
        end
    end
    scan(Workspace)
    return count
end

local function reset(printer)
    -- Возвращаем принтер в Backpack
    local char = player.Character
    if not char then
        char = player.CharacterAdded:Wait()
        task.wait(0.5)
    end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        pcall(function() humanoid:UnequipTools() end)
    end
    if printer then
        printer.Parent = player.Backpack
    end
    -- Убираем экипированные инструменты
    for _, c in ipairs(char:GetChildren()) do
        if c:IsA("Tool") then
            c.Parent = player.Backpack
        end
    end
    task.wait(0.5)
end

local function equipPrinter(printer)
    local char = player.Character
    if not char then
        char = player.CharacterAdded:Wait()
        task.wait(0.5)
    end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        pcall(function() humanoid:UnequipTools() end)
    end
    printer.Parent = char
    task.wait(0.5)
end

log("========== PRINTER PLACEMENT TEST v5 ==========")
log("Player:", player.Name)
log("Time:", tostring(tick()))

local printer = getPrinterInBackpack()
if not printer then
    printer = getEquippedPrinter()
end
if not printer then
    log("ERROR: No printer found in Backpack or Character")
    copyLogs()
    return
end

log("Selected printer:", printer.Name)
local backpack = player.Backpack
local char = player.Character or player.CharacterAdded:Wait()
local humanoid = char:WaitForChild("Humanoid", 5)

local results = {}

-- Метод 1: Tool:Activate()
log("\n--- Method 1: tool:Activate() ---")
reset(printer)
equipPrinter(printer)
local before = countPrinters()
log("Printers in workspace before:", tostring(before))
local ok, err = pcall(function() printer:Activate() end)
log("Activate result:", ok and "OK" or "ERR", ok and "" or tostring(err))
task.wait(1)
local after = countPrinters()
log("Printers in workspace after:", tostring(after))
table.insert(results, { method = "Activate", before = before, after = after, ok = ok, err = ok and nil or tostring(err), toolParent = printer.Parent and printer.Parent.Name or "nil" })

-- Метод 2: Parent = workspace (прямой дроп)
log("\n--- Method 2: tool.Parent = workspace ---")
reset(printer)
equipPrinter(printer)
before = countPrinters()
log("Printers in workspace before:", tostring(before))
ok, err = pcall(function() printer.Parent = workspace end)
log("Parent set result:", ok and "OK" or "ERR", ok and "" or tostring(err))
task.wait(1)
after = countPrinters()
log("Printers in workspace after:", tostring(after))
log("Tool parent:", printer.Parent and printer.Parent.Name or "nil")
table.insert(results, { method = "ParentToWorkspace", before = before, after = after, ok = ok, err = ok and nil or tostring(err), toolParent = printer.Parent and printer.Parent.Name or "nil" })

-- Метод 3: Unequip, затем Parent = workspace
log("\n--- Method 3: UnequipTools then Parent = workspace ---")
reset(printer)
equipPrinter(printer)
before = countPrinters()
log("Printers in workspace before:", tostring(before))
ok, err = pcall(function()
    humanoid:UnequipTools()
    task.wait(0.3)
    printer.Parent = workspace
end)
log("Unequip+drop result:", ok and "OK" or "ERR", ok and "" or tostring(err))
task.wait(1)
after = countPrinters()
log("Printers in workspace after:", tostring(after))
log("Tool parent:", printer.Parent and printer.Parent.Name or "nil")
table.insert(results, { method = "UnequipThenDrop", before = before, after = after, ok = ok, err = ok and nil or tostring(err), toolParent = printer.Parent and printer.Parent.Name or "nil" })

-- Метод 4: Симуляция Backspace через VirtualInputManager
log("\n--- Method 4: VirtualInputManager Backspace ---")
reset(printer)
equipPrinter(printer)
before = countPrinters()
log("Printers in workspace before:", tostring(before))
ok, err = pcall(function()
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Backspace, false, nil)
    task.wait(0.1)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Backspace, false, nil)
end)
log("VIM Backspace result:", ok and "OK" or "ERR", ok and "" or tostring(err))
task.wait(1.5)
after = countPrinters()
log("Printers in workspace after:", tostring(after))
log("Tool parent:", printer.Parent and printer.Parent.Name or "nil")
table.insert(results, { method = "VIM_Backspace", before = before, after = after, ok = ok, err = ok and nil or tostring(err), toolParent = printer.Parent and printer.Parent.Name or "nil" })

-- Метод 5: Используем keypress/keytap, если доступен
log("\n--- Method 5: Executor keypress Backspace ---")
reset(printer)
equipPrinter(printer)
before = countPrinters()
log("Printers in workspace before:", tostring(before))
ok, err = pcall(function()
    if keypress and keyrelease then
        keypress(0x08) -- Backspace VK
        task.wait(0.1)
        keyrelease(0x08)
    elseif keytap then
        keytap(0x08)
    else
        error("no keypress/keytap")
    end
end)
log("keypress Backspace result:", ok and "OK" or "ERR", ok and "" or tostring(err))
task.wait(1.5)
after = countPrinters()
log("Printers in workspace after:", tostring(after))
log("Tool parent:", printer.Parent and printer.Parent.Name or "nil")
table.insert(results, { method = "Keypress_Backspace", before = before, after = after, ok = ok, err = ok and nil or tostring(err), toolParent = printer.Parent and printer.Parent.Name or "nil" })

-- Метод 6: Simulate left mouse click while equipped
log("\n--- Method 6: Simulate mouse click while equipped ---")
reset(printer)
equipPrinter(printer)
before = countPrinters()
log("Printers in workspace before:", tostring(before))
ok, err = pcall(function()
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then error("no hrp") end
    local targetPos = hrp.Position - Vector3.new(0, 3, 0)
    -- Aim camera at floor
    local camera = workspace.CurrentCamera
    if camera then
        camera.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 5, 0), targetPos)
    end
    task.wait(0.2)
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, nil, 0)
    task.wait(0.1)
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, nil, 0)
end)
log("VIM mouse click result:", ok and "OK" or "ERR", ok and "" or tostring(err))
task.wait(1)
after = countPrinters()
log("Printers in workspace after:", tostring(after))
log("Tool parent:", printer.Parent and printer.Parent.Name or "nil")
table.insert(results, { method = "VIM_MouseClick", before = before, after = after, ok = ok, err = ok and nil or tostring(err), toolParent = printer.Parent and printer.Parent.Name or "nil" })

-- Метод 7: fireclickdetector на Handle, если есть
log("\n--- Method 7: fire click on tool parts ---")
reset(printer)
equipPrinter(printer)
before = countPrinters()
log("Printers in workspace before:", tostring(before))
ok, err = pcall(function()
    for _, part in ipairs(printer:GetDescendants()) do
        if part:IsA("ClickDetector") and fireclickdetector then
            log("  Firing ClickDetector:", part.Name)
            fireclickdetector(part)
        elseif part:IsA("ProximityPrompt") and fireproximityprompt then
            log("  Firing ProximityPrompt:", part.Name)
            fireproximityprompt(part)
        end
    end
end)
log("fireclickdetector result:", ok and "OK" or "ERR", ok and "" or tostring(err))
task.wait(1)
after = countPrinters()
log("Printers in workspace after:", tostring(after))
table.insert(results, { method = "FireToolDetectors", before = before, after = after, ok = ok, err = ok and nil or tostring(err), toolParent = printer.Parent and printer.Parent.Name or "nil" })

-- Восстановление
reset(printer)

-- JSON summary
log("\n========== RESULTS ==========")
for _, r in ipairs(results) do
    log(r.method .. ": before=" .. tostring(r.before) .. " after=" .. tostring(r.after) .. " toolParent=" .. r.toolParent .. " ok=" .. tostring(r.ok) .. " err=" .. (r.err or "nil"))
end

local summary = {
    player = player.Name,
    userId = player.UserId,
    printerName = printer.Name,
    results = results,
}

local ok, json = pcall(function() return HttpService:JSONEncode(summary) end)
if ok then
    log("\n========== JSON SUMMARY ==========")
    log(json)
    if setclipboard then
        pcall(function() setclipboard(json) end)
    end
else
    log("JSON error:", tostring(json))
end

log("========== END PROBE v5 ==========")
copyLogs()
