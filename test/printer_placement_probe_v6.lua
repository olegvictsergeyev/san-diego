--[[
    San Diego Agent — Probe: printer placement v6
    =====================================================
    Упрощённый и ускоренный тест. Только 3 основных способа.
    Выводит результат каждого шага сразу.
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
    if writefile then pcall(function() writefile("printer_probe_v6_log.txt", text) end) end
end

local function countPrinters()
    local count = 0
    local function scan(parent)
        for _, c in ipairs(parent:GetChildren()) do
            local name = c.Name:lower()
            if (c:IsA("Model") or c:IsA("Part") or c:IsA("MeshPart")) and (name:find("money printer") or name:find("printer")) then
                count += 1
            end
            if not c:IsA("BasePart") then scan(c) end
        end
    end
    scan(Workspace)
    return count
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

local function reset(printer)
    local char = player.Character
    if char then
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then pcall(function() humanoid:UnequipTools() end) end
        for _, c in ipairs(char:GetChildren()) do
            if c:IsA("Tool") then c.Parent = player.Backpack end
        end
    end
    if printer then printer.Parent = player.Backpack end
    task.wait(0.3)
end

local function equip(printer)
    local char = player.Character or player.CharacterAdded:Wait()
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid then pcall(function() humanoid:UnequipTools() end) end
    printer.Parent = char
    task.wait(0.3)
end

log("========== PRINTER PLACEMENT TEST v6 ==========")
log("Player:", player.Name)

local printer = findPrinter()
if not printer then
    log("ERROR: No printer found")
    copy()
    return
end
log("Printer:", printer.Name)

local char = player.Character or player.CharacterAdded:Wait()
local humanoid = char:WaitForChild("Humanoid", 5)
local results = {}

-- Метод 1: Activate
log("\n--- 1. tool:Activate() ---")
reset(printer)
equip(printer)
local before = countPrinters()
log("Printers before:", before)
pcall(function() printer:Activate() end)
task.wait(1)
local after = countPrinters()
log("Printers after:", after, "tool parent:", printer.Parent and printer.Parent.Name or "nil")
table.insert(results, { method = "Activate", before = before, after = after, parent = printer.Parent and printer.Parent.Name or "nil" })

-- Метод 2: Parent = workspace
log("\n--- 2. tool.Parent = workspace ---")
reset(printer)
equip(printer)
before = countPrinters()
log("Printers before:", before)
pcall(function() printer.Parent = workspace end)
task.wait(1)
after = countPrinters()
log("Printers after:", after, "tool parent:", printer.Parent and printer.Parent.Name or "nil")
table.insert(results, { method = "ParentToWorkspace", before = before, after = after, parent = printer.Parent and printer.Parent.Name or "nil" })

-- Метод 3: UnequipTools then drop
log("\n--- 3. UnequipTools then tool.Parent = workspace ---")
reset(printer)
equip(printer)
before = countPrinters()
log("Printers before:", before)
pcall(function()
    humanoid:UnequipTools()
    task.wait(0.2)
    printer.Parent = workspace
end)
task.wait(1)
after = countPrinters()
log("Printers after:", after, "tool parent:", printer.Parent and printer.Parent.Name or "nil")
table.insert(results, { method = "UnequipThenDrop", before = before, after = after, parent = printer.Parent and printer.Parent.Name or "nil" })

reset(printer)

log("\n========== RESULTS ==========")
for _, r in ipairs(results) do
    local placed = r.after > r.before
    log(r.method .. ": " .. r.before .. " -> " .. r.after .. " placed=" .. tostring(placed) .. " parent=" .. r.parent)
end

local summary = { player = player.Name, userId = player.UserId, printer = printer.Name, results = results }
local ok, json = pcall(function() return HttpService:JSONEncode(summary) end)
if ok then
    log("\nJSON:")
    log(json)
    if setclipboard then pcall(function() setclipboard(json) end) end
else
    log("JSON error:", tostring(json))
end

log("========== END v6 ==========")
copy()
