--[[
    San Diego Agent — Probe v2: light version
    ======================================
    Хукает только MoneyPrinterService remote'ы, экипирует принтер
    и активирует. Минимум сканирования, чтобы не зависать.
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
    if writefile then pcall(function() writefile("printer_activate_probe_v2_log.txt", text) end) end
end

local function dumpValue(v)
    if typeof(v) == "Instance" then
        return v:GetFullName()
    elseif typeof(v) == "CFrame" or typeof(v) == "Vector3" then
        return tostring(v)
    elseif typeof(v) == "table" then
        local parts = {}
        for k, val in pairs(v) do
            table.insert(parts, tostring(k) .. "=" .. dumpValue(val))
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    else
        return tostring(v)
    end
end

log("========== PRINTER ACTIVATE PROBE v2 ==========")
log("Player:", player.Name)

local backpack = player:FindFirstChild("Backpack")
local tool = nil
if backpack then
    for _, c in ipairs(backpack:GetChildren()) do
        if c:IsA("Tool") and c.Name:lower():find("print") then
            tool = c
            break
        end
    end
end

if not tool then
    log("ERROR: No Money Printer in backpack")
    copy()
    return
end
log("Tool found:", tool.Name)

-- Hook only MoneyPrinterService remotes
log("Hooking MoneyPrinterService remotes...")
local captured = {}
local function hookRemote(r)
    if r:IsA("RemoteEvent") and r.FireServer then
        local old = r.FireServer
        r.FireServer = function(self, ...)
            local args = {...}
            log("[REMOTE FIRE]", r:GetFullName(), dumpValue(args))
            table.insert(captured, { name = r:GetFullName(), method = "FireServer", args = args, time = tick() })
            return old(self, ...)
        end
    elseif r:IsA("RemoteFunction") and r.InvokeServer then
        local old = r.InvokeServer
        r.InvokeServer = function(self, ...)
            local args = {...}
            log("[REMOTE INVOKE]", r:GetFullName(), dumpValue(args))
            table.insert(captured, { name = r:GetFullName(), method = "InvokeServer", args = args, time = tick() })
            return old(self, ...)
        end
    end
end

local mpService = ReplicatedStorage:WaitForChild("__remotes", 2):WaitForChild("MoneyPrinterService", 2)
if mpService then
    log("MoneyPrinterService found:", mpService:GetFullName())
    for _, c in ipairs(mpService:GetChildren()) do
        if c:IsA("RemoteEvent") or c:IsA("RemoteFunction") then
            log("  hooking", c.Name)
            hookRemote(c)
        end
    end
else
    log("MoneyPrinterService not found")
end

-- Equip
log("\nEquipping tool...")
local char = player.Character or player.CharacterAdded:Wait()
local humanoid = char:FindFirstChildOfClass("Humanoid")
if not humanoid then
    log("ERROR: No humanoid")
    copy()
    return
end

local ok, err = pcall(function()
    humanoid:EquipTool(tool)
end)
if not ok then
    log("Equip failed:", tostring(err))
    copy()
    return
end
task.wait(1)
log("Tool parent after equip:", tool.Parent and tool.Parent.Name or "nil")

-- Check Activated connections
if getconnections then
    log("\nConnections on Activated:")
    local ok2, conns = pcall(function() return getconnections(tool.Activated) end)
    if ok2 and conns then
        for i, conn in ipairs(conns) do
            log("  ", tostring(i), tostring(conn.Function))
        end
    else
        log("  none or error:", tostring(conns))
    end
end

-- Activate
log("\nCalling tool:Activate()...")
local ok3, err3 = pcall(function()
    tool:Activate()
end)
log("Activate result:", ok3 and "ok" or "failed", tostring(err3))

log("\nWaiting 5 seconds for remote calls...")
task.wait(5)

-- Try mouse fire
local mouse = player:GetMouse()
if mouse then
    log("\nMouse position:", tostring(mouse.Hit.Position))
    log("Firing tool.Activated manually...")
    pcall(function()
        if tool.Activated then
            tool.Activated:Fire(mouse.Hit.Position, mouse.Hit)
        end
    end)
    task.wait(3)
end

log("\n--- Captured remote calls ---")
if #captured == 0 then
    log("No remote calls captured")
else
    for _, call in ipairs(captured) do
        log(call.method, call.name, "args=", dumpValue(call.args))
    end
end

-- Unequip
pcall(function()
    if humanoid then humanoid:UnequipTools() end
end)

log("\n========== END PROBE ==========")
copy()
