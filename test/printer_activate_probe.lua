--[[
    San Diego Agent — Probe: trigger printer placement and catch remotes
    ======================================================================
    Экипирует Money Printer, хукает ВСЕ remote-вызовы, затем активирует Tool
    (imitating click) и смотрит, какой remote ушёл на сервер.
    Также ищет локальные скрипты, связанные с MoneyPrinter.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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
    if writefile then pcall(function() writefile("printer_activate_probe_log.txt", text) end) end
end

local function dumpValue(v, depth)
    if depth == nil then depth = 0 end
    if depth > 2 then return "..." end
    if typeof(v) == "Instance" then
        return v:GetFullName()
    elseif typeof(v) == "CFrame" or typeof(v) == "Vector3" then
        return tostring(v)
    elseif typeof(v) == "table" then
        local parts = {}
        local count = 0
        for k, val in pairs(v) do
            count += 1
            if count <= 10 then
                table.insert(parts, tostring(k) .. "=" .. dumpValue(val, depth + 1))
            end
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    else
        return tostring(v)
    end
end

log("========== PRINTER ACTIVATE PROBE ==========")
log("Player:", player.Name)

-- Find printer tool in backpack
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
    log("ERROR: No Money Printer in backpack. Put one there and rerun.")
    copy()
    return
end
log("Tool found:", tool.Name)

-- Hook all remotes
local captured = {}
local hooked = {}
local function hookRemote(r)
    if hooked[r] then return end
    hooked[r] = true
    if r:IsA("RemoteEvent") then
        local old = r.FireServer
        r.FireServer = function(self, ...)
            local args = {...}
            log("[REMOTE FIRE]", r:GetFullName(), dumpValue(args))
            table.insert(captured, { event = r:GetFullName(), method = "FireServer", args = args, time = tick() })
            return old(self, ...)
        end
    elseif r:IsA("RemoteFunction") then
        local old = r.InvokeServer
        r.InvokeServer = function(self, ...)
            local args = {...}
            log("[REMOTE INVOKE]", r:GetFullName(), dumpValue(args))
            table.insert(captured, { event = r:GetFullName(), method = "InvokeServer", args = args, time = tick() })
            return old(self, ...)
        end
    end
end

local function scanRemotes(parent, depth)
    if depth > 5 then return end
    for _, c in ipairs(parent:GetChildren()) do
        if c:IsA("RemoteEvent") or c:IsA("RemoteFunction") then
            hookRemote(c)
        end
        scanRemotes(c, depth + 1)
    end
end
scanRemotes(ReplicatedStorage, 0)
scanRemotes(Workspace, 0)
log("Hooked", tostring(#hooked), "remotes")

-- Find local scripts that mention MoneyPrinter
log("\n--- Searching scripts for MoneyPrinter/Place keywords ---")
local function scanScripts(parent, depth)
    if depth > 5 then return end
    for _, c in ipairs(parent:GetChildren()) do
        if c:IsA("LocalScript") or c:IsA("Script") or c:IsA("ModuleScript") then
            local source = nil
            pcall(function()
                if decompile then
                    source = decompile(c)
                else
                    source = c.Source
                end
            end)
            if source and (source:lower():find("moneyprinter") or source:lower():find("money printer") or source:lower():find("place")) then
                log("Found script:", c:GetFullName(), "keyword match")
                log("  source first 300 chars:\n", string.sub(source, 1, 300))
            end
        end
        scanScripts(c, depth + 1)
    end
end
scanScripts(player.PlayerScripts, 0)
scanScripts(ReplicatedStorage, 0)

-- Equip
local char = player.Character or player.CharacterAdded:Wait()
local humanoid = char:FindFirstChildOfClass("Humanoid")
if not humanoid then
    log("ERROR: No humanoid")
    copy()
    return
end

log("\nEquipping tool...")
pcall(function()
    humanoid:EquipTool(tool)
end)
task.wait(1)
log("Tool parent after equip:", tool.Parent and tool.Parent.Name or "nil")

-- Check connections now
if getconnections then
    log("\n--- Connections on tool.Activated after equip ---")
    local ok, conns = pcall(function() return getconnections(tool.Activated) end)
    if ok and conns and #conns > 0 then
        for i, conn in ipairs(conns) do
            log("  ", tostring(i), tostring(conn.Function))
            if conn.Function and decompile then
                local src = nil
                pcall(function() src = decompile(conn.Function) end)
                if src then log("    source:\n", string.sub(src, 1, 300)) end
            end
        end
    else
        log("  none")
    end

    log("\n--- Connections on tool.Equipped ---")
    ok, conns = pcall(function() return getconnections(tool.Equipped) end)
    if ok and conns and #conns > 0 then
        for i, conn in ipairs(conns) do
            log("  ", tostring(i), tostring(conn.Function))
        end
    end
end

-- Activate tool (simulate click)
log("\nCalling tool:Activate()...")
local ok, err = pcall(function()
    tool:Activate()
end)
log("Activate result:", ok and "ok" or "failed", tostring(err))

log("\nWaiting 3 seconds for any remote calls...")
task.wait(3)

-- Also try mouse click simulation
local mouse = player:GetMouse()
if mouse then
    log("\nMouse position:", tostring(mouse.Hit.Position))
    -- Try to activate at mouse position
    pcall(function()
        if tool.Activated then
            log("Firing Activated event with mouse position...")
            tool.Activated:Fire(mouse.Hit.Position, mouse.Hit)
        end
    end)
    task.wait(2)
end

log("\n--- Captured remote calls ---")
if #captured == 0 then
    log("No remote calls captured")
else
    for _, call in ipairs(captured) do
        log(call.method, call.event, "time=", call.time, "args=", dumpValue(call.args))
    end
end

-- Cleanup: unequip
pcall(function()
    if humanoid then humanoid:UnequipTools() end
end)

log("\n========== END PROBE ==========")
copy()
