--[[
    San Diego Agent — Probe: printer placement v8
    =====================================================
    Пробуем разместить принтер в папке MoneyPrinters ближайшей
    квартиры. Отслеживаем Tool и следим, появится ли он в нужном
    месте и будет ли он функциональным.
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
    if writefile then pcall(function() writefile("printer_probe_v8_log.txt", text) end) end
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

local function getPlayerPosition()
    local char = player.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then return hrp.Position end
    local root = char:FindFirstChild("HumanoidRootPart")
    return nil
end

local function findClosestMoneyPrintersFolder()
    local playerPos = getPlayerPosition()
    if not playerPos then return nil end

    local closest = nil
    local closestDist = math.huge

    local function scan(parent)
        for _, c in ipairs(parent:GetChildren()) do
            if c.Name == "MoneyPrinters" and (c:IsA("Folder") or c:IsA("Model")) then
                -- Определяем позицию папки по ближайшему BasePart или по имени родителя
                local pos = nil
                local function findPart(p)
                    for _, cc in ipairs(p:GetChildren()) do
                        if cc:IsA("BasePart") then return cc.Position end
                        local found = findPart(cc)
                        if found then return found end
                    end
                    return nil
                end
                pos = findPart(c.Parent)
                if not pos then
                    -- Попробуем найти в Workspace.Position по имени
                    local unitName = c.Parent and c.Parent.Name or ""
                    for _, cc in ipairs(Workspace:GetDescendants()) do
                        if cc.Name == unitName and cc:IsA("BasePart") then
                            pos = cc.Position
                            break
                        end
                    end
                end
                if pos then
                    local dist = (pos - playerPos).Magnitude
                    if dist < closestDist then
                        closestDist = dist
                        closest = c
                    end
                end
            end
            if not c:IsA("BasePart") then
                scan(c)
            end
        end
    end
    scan(Workspace)
    return closest, closestDist
end

local function findPlacedPrinterModel(tool)
    local playerPos = getPlayerPosition()
    if not playerPos then return nil end
    local best = nil
    local bestDist = math.huge
    local function scan(parent)
        for _, c in ipairs(parent:GetChildren()) do
            if c:IsA("Model") or c:IsA("Tool") then
                if c.Name:lower() == "money printer" then
                    local part = c:FindFirstChild("Printer_d") or c:FindFirstChild("Handle")
                    if part and part:IsA("BasePart") then
                        local dist = (part.Position - playerPos).Magnitude
                        if dist < bestDist then
                            bestDist = dist
                            best = c
                        end
                    end
                end
            end
            if not c:IsA("BasePart") then
                scan(c)
            end
        end
    end
    scan(Workspace)
    return best, bestDist
end

log("========== PRINTER PLACEMENT PROBE v8 ==========")
log("Player:", player.Name)

local printer = findPrinter()
if not printer then
    log("ERROR: No printer found")
    copy()
    return
end
log("Selected printer:", printer.Name)

local char = player.Character or player.CharacterAdded:Wait()
local humanoid = char:WaitForChild("Humanoid", 5)

-- Ищем папку MoneyPrinters
log("\n--- Finding closest MoneyPrinters folder ---")
local folder, dist = findClosestMoneyPrintersFolder()
if folder then
    log("Found:", folder:GetFullName(), "dist=", tostring(math.round(dist * 10) / 10))
else
    log("No MoneyPrinters folder found nearby")
end

-- Экипируем
log("\n--- Equipping ---")
local current = char:FindFirstChildOfClass("Tool")
if current then
    current.Parent = player.Backpack
    task.wait(0.3)
end
printer.Parent = char
task.wait(0.5)
log("Printer parent:", printer.Parent and printer.Parent.Name or "nil")

-- Находим ближайший размещённый принтер до
log("\n--- Closest placed printer before ---")
local beforePrinter, beforeDist = findPlacedPrinterModel(printer)
if beforePrinter then
    log("  ", beforePrinter:GetFullName(), "dist=", tostring(math.round(beforeDist * 10) / 10))
else
    log("  none")
end

-- Пробуем разместить
log("\n--- Attempt: parent to MoneyPrinters folder ---")
if folder then
    local ok, err = pcall(function()
        -- Сначала unequip
        humanoid:UnequipTools()
        task.wait(0.3)
        -- Перемещаем в папку
        printer.Parent = folder
        -- Устанавливаем позицию рядом с игроком, на высоте пола
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local handle = printer:FindFirstChild("Handle")
            local printerD = printer:FindFirstChild("Printer_d")
            if handle and handle:IsA("BasePart") then
                handle.CFrame = CFrame.new(hrp.Position - Vector3.new(0, 3, 0))
                handle.Anchored = true
                handle.CanCollide = true
            end
            if printerD and printerD:IsA("BasePart") then
                printerD.CFrame = CFrame.new(hrp.Position - Vector3.new(0, 3, 0))
                printerD.Anchored = true
                printerD.CanCollide = true
            end
        end
    end)
    log("Placement result:", ok and "OK" or "ERR", ok and "" or tostring(err))
    task.wait(2)
    log("After 2s printer parent:", printer.Parent and printer.Parent.Name or "nil")
else
    log("Skipping: no folder")
end

-- Находим ближайший размещённый принтер после
log("\n--- Closest placed printer after ---")
local afterPrinter, afterDist = findPlacedPrinterModel(printer)
if afterPrinter then
    log("  ", afterPrinter:GetFullName(), "dist=", tostring(math.round(afterDist * 10) / 10))
    local part = afterPrinter:FindFirstChild("Printer_d") or afterPrinter:FindFirstChild("Handle")
    if part and part:IsA("BasePart") then
        log("  pos:", tostring(part.Position), "parent:", afterPrinter.Parent and afterPrinter.Parent.Name or "nil")
    end
else
    log("  none")
end

-- Попробуем Activate после размещения
if printer.Parent then
    log("\n--- Attempt: Activate after placement ---")
    pcall(function() printer:Activate() end)
    task.wait(1)
    log("After Activate parent:", printer.Parent and printer.Parent.Name or "nil")
end

-- JSON
log("\n========== JSON SUMMARY ==========")
local summary = {
    player = player.Name,
    userId = player.UserId,
    printerName = printer.Name,
    moneyPrintersFolder = folder and folder:GetFullName() or nil,
    folderDistance = dist and math.round(dist * 10) / 10 or nil,
    printerParent = printer.Parent and printer.Parent.Name or "nil",
    beforePrinter = beforePrinter and beforePrinter:GetFullName() or nil,
    afterPrinter = afterPrinter and afterPrinter:GetFullName() or nil,
    afterPrinterDist = afterDist and math.round(afterDist * 10) / 10 or nil,
}
local ok, json = pcall(function() return HttpService:JSONEncode(summary) end)
if ok then
    log(json)
    if setclipboard then pcall(function() setclipboard(json) end) end
else
    log("JSON error:", tostring(json))
end

log("========== END PROBE v8 ==========")
copy()
