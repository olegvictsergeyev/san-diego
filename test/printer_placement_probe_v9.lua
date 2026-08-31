--[[
    San Diego Agent — Probe: printer placement v9
    =====================================================
    Минимальный тест: берём Tool, перемещаем в MoneyPrinters
    ближайшей квартиры, устанавливаем позицию.
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
    if writefile then pcall(function() writefile("printer_probe_v9_log.txt", text) end) end
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

local function getPlayerPos()
    local char = player.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    return hrp and hrp.Position or nil
end

local function findMoneyPrintersFolder()
    local playerPos = getPlayerPos()
    if not playerPos then return nil end
    local closest = nil
    local closestDist = math.huge
    local function scan(parent)
        for _, c in ipairs(parent:GetChildren()) do
            if c.Name == "MoneyPrinters" and (c:IsA("Folder") or c:IsA("Model")) then
                local pos = nil
                local function findPart(p)
                    for _, cc in ipairs(p:GetChildren()) do
                        if cc:IsA("BasePart") then return cc.Position end
                        local f = findPart(cc)
                        if f then return f end
                    end
                    return nil
                end
                pos = findPart(c.Parent)
                if pos then
                    local dist = (pos - playerPos).Magnitude
                    if dist < closestDist then
                        closestDist = dist
                        closest = c
                    end
                end
            end
            if not c:IsA("BasePart") then scan(c) end
        end
    end
    scan(Workspace)
    return closest, closestDist
end

log("========== PRINTER PLACEMENT v9 ==========")
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

log("\n--- Looking for MoneyPrinters folder ---")
local folder, dist = findMoneyPrintersFolder()
if folder then
    log("Found:", folder:GetFullName(), "dist=", tostring(math.round(dist * 10) / 10))
else
    log("No MoneyPrinters folder found")
    copy()
    return
end

log("\n--- Equipping printer ---")
local current = char:FindFirstChildOfClass("Tool")
if current then
    current.Parent = player.Backpack
    task.wait(0.3)
end
printer.Parent = char
task.wait(0.5)
log("Equipped, parent:", printer.Parent and printer.Parent.Name or "nil")

log("\n--- Placing into MoneyPrinters folder ---")
local ok, err = pcall(function()
    humanoid:UnequipTools()
    task.wait(0.3)
    printer.Parent = folder
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then
        local handle = printer:FindFirstChild("Handle")
        local printerD = printer:FindFirstChild("Printer_d")
        local targetPos = hrp.Position - Vector3.new(0, 3, 0)
        if handle and handle:IsA("BasePart") then
            handle.CFrame = CFrame.new(targetPos)
            handle.Anchored = true
            handle.CanCollide = true
        end
        if printerD and printerD:IsA("BasePart") then
            printerD.CFrame = CFrame.new(targetPos)
            printerD.Anchored = true
            printerD.CanCollide = true
        end
    end
end)
log("Place result:", ok and "OK" or "ERR", ok and "" or tostring(err))

task.wait(2)
log("After 2s parent:", printer.Parent and printer.Parent.Name or "nil")
log("Full path:", printer.Parent and printer:GetFullName() or "destroyed")

local handle = printer:FindFirstChild("Handle")
if handle and handle:IsA("BasePart") then
    log("Handle pos:", tostring(handle.Position), "Anchored:", tostring(handle.Anchored))
end

log("\n--- JSON SUMMARY ---")
local summary = {
    player = player.Name,
    userId = player.UserId,
    printerName = printer.Name,
    folder = folder:GetFullName(),
    folderDist = math.round(dist * 10) / 10,
    placeOk = ok,
    placeErr = ok and nil or tostring(err),
    parentAfter = printer.Parent and printer.Parent.Name or "nil",
    fullPath = printer.Parent and printer:GetFullName() or "destroyed",
}
local ok2, json = pcall(function() return HttpService:JSONEncode(summary) end)
if ok2 then
    log(json)
    if setclipboard then pcall(function() setclipboard(json) end) end
else
    log("JSON error:", tostring(json))
end

log("========== END v9 ==========")
copy()
