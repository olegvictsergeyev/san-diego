--[[
    San Diego Agent — Test: compare placed printers
    ================================================
    Выводит атрибуты и информацию о всех принтерах в папке MoneyPrinters,
    чтобы понять, почему автоматически поставленные не печатают деньги.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

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
    if writefile then pcall(function() writefile("compare_printers_test_log.txt", text) end) end
end

local function findMoneyPrintersFolder()
    local char = player.Character or player.CharacterAdded:Wait()
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local playerPos = hrp and hrp.Position or Vector3.new(0, 0, 0)
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
    return best, bestDist
end

local function dumpAttributes(obj)
    local attrs = {}
    for name, value in pairs(obj:GetAttributes()) do
        table.insert(attrs, name .. "=" .. tostring(value))
    end
    return attrs
end

log("========== COMPARE PRINTERS TEST ==========")
log("Player:", player.Name)

local folder, dist = findMoneyPrintersFolder()
if not folder then
    log("ERROR: No MoneyPrinters folder found")
    copy()
    return
end
log("Folder:", folder:GetFullName(), "dist:", tostring(math.round(dist * 10) / 10))

local printers = {}
for _, c in ipairs(folder:GetChildren()) do
    if c.Name:lower():find("print") or c:HasTag("MoneyPrinter") then
        table.insert(printers, c)
    end
end
log("Printers in folder:", tostring(#printers))

for i, p in ipairs(printers) do
    log("\n--- Printer #" .. tostring(i) .. " ---")
    log("  Name:", p.Name)
    log("  Class:", p.ClassName)
    log("  FullName:", p:GetFullName())
    log("  HasTag MoneyPrinter:", tostring(p:HasTag("MoneyPrinter")))
    log("  Attributes:")
    for _, a in ipairs(dumpAttributes(p)) do
        log("    " .. a)
    end
    local part = p:FindFirstChild("Printer_d") or p:FindFirstChild("Handle")
    if part and part:IsA("BasePart") then
        log("  Part position:", tostring(part.Position))
        log("  Part CFrame:", tostring(part.CFrame))
        log("  Part Size:", tostring(part.Size))
        log("  Part Anchored:", tostring(part.Anchored))
        log("  Part CanCollide:", tostring(part.CanCollide))
    else
        log("  No Printer_d/Handle BasePart")
    end
    -- Check for scripts or values
    if #p:GetChildren() > 0 then
        log("  Children:")
        for _, ch in ipairs(p:GetChildren()) do
            log("    -", ch.ClassName, ch.Name)
        end
    end
end

log("\n========== END ==========")
copy()
