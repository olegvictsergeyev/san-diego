--[[
    San Diego Agent — Probe: compare working vs non-working printers
    ================================================================
    Запускать, когда в комнате есть:
    - хотя бы один принтер, установленный вручную (печатает деньги)
    - хотя бы один принтер, установленный скриптом (не печатает)
    Скрипт сравнивает их свойства, атрибуты, иерархию и разницу.
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
    if writefile then pcall(function() writefile("printer_compare_probe_log.txt", text) end) end
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
    -- pick nearest by distance to player or first
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

local function inspectPrinter(printer, label)
    log("\n--- Inspecting", label, "---")
    log("FullName:", printer:GetFullName())
    log("ClassName:", printer.ClassName)
    log("Name:", printer.Name)
    log("Parent:", printer.Parent and printer.Parent:GetFullName() or "nil")

    -- Attributes
    log("\nAttributes:")
    local ok, attrs = pcall(function() return printer:GetAttributes() end)
    if ok and attrs then
        for k, v in pairs(attrs) do
            log("  ", k, "=", tostring(v), "(", typeof(v), ")")
        end
    else
        log("  error:", tostring(attrs))
    end

    -- Tags
    log("\nTags:")
    local ok2, tags = pcall(function() return printer:GetTags() end)
    if ok2 and tags then
        for _, tag in ipairs(tags) do
            log("  ", tag)
        end
    else
        log("  error or none:", tostring(tags))
    end

    -- Properties
    log("\nKey properties:")
    local propsToCheck = {
        "Archivable", "CanBeDropped", "Enabled", "ManualActivationOnly",
        "ToolTip", "Grip", "GripPos", "GripForward", "GripUp", "GripRight"
    }
    for _, prop in ipairs(propsToCheck) do
        local ok, val = pcall(function() return printer[prop] end)
        if ok then
            log("  ", prop, "=", tostring(val))
        end
    end

    -- Children parts
    log("\nChildren parts:")
    for _, c in ipairs(printer:GetDescendants()) do
        if c:IsA("BasePart") then
            log("  ", c.Name, "Class=", c.ClassName, "Size=", tostring(c.Size),
                "Pos=", tostring(c.Position), "Anchored=", tostring(c.Anchored),
                "CanCollide=", tostring(c.CanCollide), "CFrame=", tostring(c.CFrame))
            -- attributes on part
            local ok3, attrs3 = pcall(function() return c:GetAttributes() end)
            if ok3 and attrs3 then
                for k, v in pairs(attrs3) do
                    log("    attr", k, "=", tostring(v))
                end
            end
        elseif c:IsA("Script") or c:IsA("LocalScript") or c:IsA("ModuleScript") then
            log("  script:", c.Name, "(", c.ClassName, ") in", c.Parent.Name)
        elseif c:IsA("Sound") or c:IsA("ParticleEmitter") or c:IsA("BillboardGui") then
            log("  effect:", c.Name, "(", c.ClassName, ")")
        end
    end
end

log("========== PRINTER COMPARE PROBE ==========")
log("Player:", player.Name)

local folder = findMoneyPrintersFolder()
if not folder then
    log("ERROR: No MoneyPrinters folder found")
    copy()
    return
end
log("Folder:", folder:GetFullName())

local printers = {}
for _, c in ipairs(folder:GetChildren()) do
    if c.Name:lower():find("print") and c:IsA("Tool") then
        table.insert(printers, c)
    end
end
log("Found printers:", tostring(#printers))

if #printers < 2 then
    log("ERROR: Need at least 2 printers to compare")
    copy()
    return
end

-- Inspect first two
inspectPrinter(printers[1], "Printer #1")
inspectPrinter(printers[2], "Printer #2")

-- If more, just list names and positions
if #printers > 2 then
    log("\n--- Other printers ---")
    for i = 3, math.min(10, #printers) do
        local p = printers[i]
        local part = p:FindFirstChild("Printer_d") or p:FindFirstChild("Handle")
        local pos = part and tostring(part.Position) or "no part"
        log("  #", tostring(i), p.Name, "pos=", pos)
    end
end

log("\n========== END PROBE ==========")
copy()
