--[[
    San Diego Agent — Probe: inspect printer tool and placement mechanism
    =====================================================================
    Запускать в комнате с 1+ принтером в руке/инвентаре.
    Скрипт пытается понять, как работает ручная установка:
    - какие скрипты внутри Tool
    - какие RemoteEvents/RemoteFunctions используются
    - какие соединения есть на Activated/Equipped
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
    if writefile then pcall(function() writefile("printer_manual_placement_probe_log.txt", text) end) end
end

local function dump(obj, depth)
    if depth == nil then depth = 0 end
    if depth > 3 then return "..." end
    if typeof(obj) == "Instance" then
        return obj:GetFullName()
    elseif typeof(obj) == "CFrame" then
        return tostring(obj.Position)
    elseif typeof(obj) == "Vector3" then
        return tostring(obj)
    elseif typeof(obj) == "table" then
        local parts = {}
        for k, v in pairs(obj) do
            table.insert(parts, tostring(k) .. "=" .. dump(v, depth + 1))
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    else
        return tostring(obj)
    end
end

local function listRemotes()
    log("\n--- Remote events/functions in ReplicatedStorage ---")
    local function scan(parent, depth)
        if depth > 5 then return end
        for _, c in ipairs(parent:GetChildren()) do
            if c:IsA("RemoteEvent") or c:IsA("RemoteFunction") or c:IsA("BindableEvent") or c:IsA("BindableFunction") then
                log("  ", c.ClassName, c:GetFullName())
            end
            scan(c, depth + 1)
        end
    end
    scan(ReplicatedStorage, 0)
end

local function inspectTool(tool)
    log("\n--- Inspecting tool:", tool.Name, "---")
    log("FullName:", tool:GetFullName())
    log("Parent:", tool.Parent and tool.Parent.Name or "nil")
    log("ClassName:", tool.ClassName)

    -- Properties
    local props = { "CanBeDropped", "Grip", "GripPos", "GripForward", "GripUp", "GripRight", "ToolTip", "ManualActivationOnly" }
    for _, prop in ipairs(props) do
        local ok, val = pcall(function() return tool[prop] end)
        if ok then
            log("  ", prop, "=", dump(val))
        end
    end

    -- Children
    log("\nChildren:")
    for _, c in ipairs(tool:GetDescendants()) do
        log("  ", c.ClassName, c.Name, "Parent:", c.Parent.Name)
        if c:IsA("Script") or c:IsA("LocalScript") or c:IsA("ModuleScript") then
            local source = nil
            local ok, err = pcall(function()
                if decompile then
                    source = decompile(c)
                else
                    source = c.Source
                end
            end)
            if ok and source then
                log("    SOURCE (first 500 chars):\n", string.sub(source, 1, 500))
            else
                log("    could not get source:", tostring(err))
            end
        end
    end

    -- Connections
    if getconnections then
        log("\nConnections on Activated:")
        local ok, conns = pcall(function() return getconnections(tool.Activated) end)
        if ok and conns then
            for _, conn in ipairs(conns) do
                log("  connection:", tostring(conn.Function))
                if conn.Function and islclosure then
                    local isL = islclosure(conn.Function)
                    log("    islclosure=", tostring(isL))
                end
            end
        else
            log("  none or error:", tostring(conns))
        end

        log("\nConnections on Equipped:")
        ok, conns = pcall(function() return getconnections(tool.Equipped) end)
        if ok and conns then
            for _, conn in ipairs(conns) do
                log("  connection:", tostring(conn.Function))
            end
        end

        log("\nConnections on Unequipped:")
        ok, conns = pcall(function() return getconnections(tool.Unequipped) end)
        if ok and conns then
            for _, conn in ipairs(conns) do
                log("  connection:", tostring(conn.Function))
            end
        end
    end
end

local function monitorRemotes(duration)
    log("\n--- Monitoring remote traffic for", tostring(duration), "seconds ---")
    local originalFireServer = {}
    local originalInvokeServer = {}
    local calls = {}

    local function hookRemote(remote)
        if remote:IsA("RemoteEvent") and remote.FireServer then
            originalFireServer[remote] = remote.FireServer
            remote.FireServer = function(self, ...)
                local args = {...}
                log("[REMOTE] FireServer", self:GetFullName(), "args=", dump(args))
                table.insert(calls, { remote = self:GetFullName(), method = "FireServer", args = args, time = tick() })
                return originalFireServer[remote](self, ...)
            end
        elseif remote:IsA("RemoteFunction") and remote.InvokeServer then
            originalInvokeServer[remote] = remote.InvokeServer
            remote.InvokeServer = function(self, ...)
                local args = {...}
                log("[REMOTE] InvokeServer", self:GetFullName(), "args=", dump(args))
                table.insert(calls, { remote = self:GetFullName(), method = "InvokeServer", args = args, time = tick() })
                return originalInvokeServer[remote](self, ...)
            end
        end
    end

    local function scan(parent, depth)
        if depth > 4 then return end
        for _, c in ipairs(parent:GetChildren()) do
            if c:IsA("RemoteEvent") or c:IsA("RemoteFunction") then
                hookRemote(c)
            end
            scan(c, depth + 1)
        end
    end
    scan(ReplicatedStorage, 0)

    task.wait(duration)

    -- restore
    for remote, fn in pairs(originalFireServer) do
        remote.FireServer = fn
    end
    for remote, fn in pairs(originalInvokeServer) do
        remote.InvokeServer = fn
    end

    log("\n--- Remote calls captured ---")
    for _, call in ipairs(calls) do
        log(call.method, call.remote, "time=", call.time, "args=", dump(call.args))
    end
end

log("========== PRINTER MANUAL PLACEMENT PROBE ==========")
log("Player:", player.Name)

listRemotes()

-- Find tool in hand/backpack/workspace
local tool = nil
local char = player.Character
if char then
    for _, c in ipairs(char:GetChildren()) do
        if c:IsA("Tool") and c.Name:lower():find("print") then
            tool = c
            break
        end
    end
end
if not tool then
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        for _, c in ipairs(backpack:GetChildren()) do
            if c:IsA("Tool") and c.Name:lower():find("print") then
                tool = c
                break
            end
        end
    end
end
if not tool then
    local function scan(parent)
        for _, c in ipairs(parent:GetChildren()) do
            if c:IsA("Tool") and c.Name:lower():find("print") then
                tool = c
                return true
            end
            if not c:IsA("BasePart") then
                if scan(c) then return true end
            end
        end
        return false
    end
    scan(Workspace)
end

if not tool then
    log("ERROR: No printer tool found. Equip or have one in backpack.")
    copy()
    return
end

inspectTool(tool)

log("\n!!! Now manually place 1 printer within the next 10 seconds !!!")
monitorRemotes(10)

log("\n========== END PROBE ==========")
copy()
