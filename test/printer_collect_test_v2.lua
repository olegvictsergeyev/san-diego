--[[
    San Diego Agent — Test: collect all printers v2 (using MoneyPrinterService remote)
    =================================================================================
    Собирает принтеры через RemoteFunction MoneyPrinterService.PickupMoneyPrinter.
    Если remote не срабатывает — пробует забрать обычным Parent=Backpack.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
    if writefile then pcall(function() writefile("printer_collect_test_v2_log.txt", text) end) end
end

local RAYCAST_DOWN_DISTANCE = 50

local function getCharacter()
    local char = player.Character
    if char then return char end
    return player.CharacterAdded:Wait()
end

local function getPlayerPos()
    local char = getCharacter()
    local hrp = char:FindFirstChild("HumanoidRootPart")
    return hrp and hrp.Position
end

local function findMoneyPrintersFolders()
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
    return folders
end

local function raycastDownFromPlayer()
    local playerPos = getPlayerPos()
    if not playerPos then return nil end
    local char = getCharacter()
    local params = nil
    local ok, res = pcall(function()
        local p = RaycastParams.new()
        p.FilterType = Enum.RaycastFilterType.Blacklist
        p.FilterDescendantsInstances = { char }
        return p
    end)
    if not ok or not res then return nil end
    local result = nil
    pcall(function()
        result = Workspace:Raycast(playerPos + Vector3.new(0, 5, 0), Vector3.new(0, -RAYCAST_DOWN_DISTANCE, 0), res)
    end)
    return result and result.Instance
end

local function findMoneyPrintersFolderInUnit(unit)
    if not unit then return nil end
    local function scan(parent, depth)
        if depth > 8 then return nil end
        for _, c in ipairs(parent:GetChildren()) do
            if c.Name == "MoneyPrinters" and (c:IsA("Folder") or c:IsA("Model") or c:IsA("Configuration")) then
                return c
            end
            if not c:IsA("BasePart") then
                local found = scan(c, depth + 1)
                if found then return found end
            end
        end
        return nil
    end
    return scan(unit, 0)
end

local function chooseTargetFolder()
    local hitPart = raycastDownFromPlayer()
    if hitPart then
        local unit = hitPart.Parent
        local depth = 0
        while unit and depth < 10 do
            local mp = findMoneyPrintersFolderInUnit(unit)
            if mp then return mp end
            unit = unit.Parent
            depth = depth + 1
        end
    end
    local folders = findMoneyPrintersFolders()
    return folders[1]
end

log("========== PRINTER COLLECT TEST v2 ==========")
log("Player:", player.Name)

local pickupRemote = ReplicatedStorage:FindFirstChild("__remotes", true)
if pickupRemote then
    pickupRemote = pickupRemote:FindFirstChild("MoneyPrinterService")
    if pickupRemote then
        pickupRemote = pickupRemote:FindFirstChild("PickupMoneyPrinter")
    end
end

if not pickupRemote then
    log("WARNING: PickupMoneyPrinter remote not found")
else
    log("Found remote:", pickupRemote:GetFullName(), "Class:", pickupRemote.ClassName)
end

local folder = chooseTargetFolder()
if not folder then
    log("ERROR: No MoneyPrinters folder found")
    copy()
    return
end
log("Target folder:", folder:GetFullName())

local backpack = player:FindFirstChild("Backpack")
if not backpack then
    log("ERROR: No backpack")
    copy()
    return
end

local collected = 0
local remoteCollected = 0
local failed = 0

for _, c in ipairs(folder:GetChildren()) do
    if c.Name:lower():find("print") then
        log("Collecting:", c.Name, "->", c:GetFullName(), "Class:", c.ClassName)

        local remoteOk = false
        if pickupRemote and pickupRemote:IsA("RemoteFunction") then
            -- Пробуем разные варианты вызова remote.
            local argsToTry = {
                { c },
                { c, player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character.HumanoidRootPart.Position },
                { folder, c },
                {},
            }
            for i, args in ipairs(argsToTry) do
                log("  trying remote call variant #", tostring(i))
                local ok, result = pcall(function()
                    return pickupRemote:InvokeServer(unpack(args))
                end)
                if ok then
                    log("  remote success, result=", tostring(result))
                    remoteOk = true
                    remoteCollected += 1
                    break
                else
                    log("  remote failed:", tostring(result))
                end
            end
        end

        if not remoteOk then
            log("  falling back to Parent=Backpack")
            local ok, err = pcall(function()
                c.Parent = backpack
            end)
            if ok then
                collected += 1
                log("  Parent=Backpack success")
            else
                failed += 1
                log("  Parent=Backpack FAILED:", tostring(err))
            end
        end

        task.wait(0.3)
    end
end

log("\n--- Results ---")
log("Remote collected:", tostring(remoteCollected))
log("Parent collected:", tostring(collected))
log("Failed:", tostring(failed))
log("Total in backpack after:", tostring(#backpack:GetChildren()))
log("========== END ==========")
copy()
