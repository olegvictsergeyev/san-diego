--[[
    San Diego Agent — Test: fake MoneyPrinter Model placement
    ==========================================================
    Создаёт Model с теми же атрибутами, что и рабочий ручной принтер,
    и помещает его в папку MoneyPrinters. Проверяет, начнёт ли он
    печатать деньги без вызова remote'а.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

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
    if writefile then pcall(function() writefile("printer_fake_model_test_log.txt", text) end) end
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

local function findWorkingPrinter(folder)
    for _, c in ipairs(folder:GetChildren()) do
        if c:IsA("Model") and c:HasTag("MoneyPrinter") then
            return c
        end
    end
    for _, c in ipairs(folder:GetChildren()) do
        if c.Name:lower():find("print") then
            return c
        end
    end
    return nil
end

local function cloneParts(original, newModel)
    for _, c in ipairs(original:GetChildren()) do
        if c:IsA("BasePart") then
            local clone = c:Clone()
            clone.Parent = newModel
        elseif c:IsA("Weld") or c:IsA("WeldConstraint") or c:IsA("Motor6D") then
            local clone = c:Clone()
            clone.Parent = newModel
        elseif not c:IsA("Script") and not c:IsA("LocalScript") and not c:IsA("ModuleScript") then
            local clone = c:Clone()
            clone.Parent = newModel
        end
    end
end

log("========== FAKE MONEYPRINTER MODEL TEST ==========")
log("Player:", player.Name)

local folder = findMoneyPrintersFolder()
if not folder then
    log("ERROR: No MoneyPrinters folder found")
    copy()
    return
end
log("Target folder:", folder:GetFullName())

local workingPrinter = findWorkingPrinter(folder)
if not workingPrinter then
    log("ERROR: No working printer found in folder. Place one manually first.")
    copy()
    return
end
log("Working printer:", workingPrinter:GetFullName(), "Class:", workingPrinter.ClassName)

-- Copy attributes
local attrs = {}
local ok, attrsList = pcall(function() return workingPrinter:GetAttributes() end)
if ok and attrsList then
    log("\nWorking printer attributes:")
    for k, v in pairs(attrsList) do
        attrs[k] = v
        log("  ", k, "=", tostring(v), "(", typeof(v), ")")
    end
else
    log("ERROR: Could not read attributes")
    copy()
    return
end

local before = #folder:GetChildren()
log("\nPrinters in folder before:", tostring(before))

-- Create fake model
log("\nCreating fake model...")
local fake = Instance.new("Model")
fake.Name = "Money Printer"
for k, v in pairs(attrs) do
    fake:SetAttribute(k, v)
end

-- Modify ID to be unique
local newId = HttpService:GenerateGUID(false)
fake:SetAttribute("MoneyPrinterId", newId)
log("Generated new MoneyPrinterId:", newId)

-- Clone parts from working printer
cloneParts(workingPrinter, fake)

-- Reposition parts
local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
local placePos = hrp and (hrp.Position + Vector3.new(2, 0, 0)) or Vector3.new(0, 0, 0)
local cf = CFrame.new(placePos)

local primary = fake:FindFirstChild("Handle") or fake:FindFirstChild("Printer_d") or fake:FindFirstChildWhichIsA("BasePart")
if primary then
    fake.PrimaryPart = primary
    for _, part in ipairs(fake:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CFrame = cf * CFrame.new(part.Position - primary.Position)
            part.Anchored = true
            part.CanCollide = false
        end
    end
    log("Placed fake model at", tostring(placePos))
end

-- Add tag
if fake:HasTag("MoneyPrinter") then
    log("Already has tag MoneyPrinter")
else
    pcall(function()
        local collectionService = game:GetService("CollectionService")
        collectionService:AddTag(fake, "MoneyPrinter")
    end)
    log("Added tag MoneyPrinter")
end

fake.Parent = folder

log("\nWaiting 10 seconds to see if fake printer prints money...")
for i = 1, 10 do
    log("t+", tostring(i))
    task.wait(1)
end

local after = #folder:GetChildren()
log("\nPrinters in folder after:", tostring(after))

if after > before then
    log("Fake printer was added successfully")
else
    log("Fake printer was removed by server")
end

log("\n--- Fake model final state ---")
local ok2, finalAttrs = pcall(function() return fake:GetAttributes() end)
if ok2 and finalAttrs then
    for k, v in pairs(finalAttrs) do
        log("  ", k, "=", tostring(v))
    end
end

log("\n========== END TEST ==========")
copy()
