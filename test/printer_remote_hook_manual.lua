--[[
    San Diego Agent — Probe: hook remotes during manual printer placement
    ======================================================================
    Подключается к FireServer/InvokeServer ВСЕХ RemoteEvent/RemoteFunction
    и логирует вызовы. Просит вручную поставить принтер, чтобы поймать remote.
    
    ВАЖНО: использует hookfunction (безопаснее __namecall). 
    После теста перезапусти клиент, чтобы снять хуки.
]]

local Players = game:GetService("Players")
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
    if writefile then pcall(function() writefile("printer_remote_hook_log.txt", text) end) end
end

log("========== HOOK REMOTES DURING MANUAL PLACE ==========")
log("Player:", player.Name)
log("Hooking RemoteEvent.FireServer and RemoteFunction.InvokeServer...")
log("Возьми в руки Money Printer и поставь его вручную.")
log("Логирую все remote-вызовы в течение 20 секунд.\n")

local hooked = false

local function safeToString(obj)
    local ok, res = pcall(function()
        if typeof(obj) == "Instance" then
            return obj.ClassName .. ":" .. obj.Name .. " (" .. obj:GetFullName() .. ")"
        elseif typeof(obj) == "CFrame" then
            return tostring(obj)
        elseif typeof(obj) == "Vector3" then
            return tostring(obj)
        elseif typeof(obj) == "Color3" then
            return tostring(obj)
        elseif type(obj) == "table" then
            local parts = {}
            for k, v in pairs(obj) do
                table.insert(parts, tostring(k) .. "=" .. safeToString(v))
            end
            return "{" .. table.concat(parts, ", ") .. "}"
        elseif type(obj) == "string" then
            return '"' .. obj .. '"'
        elseif type(obj) == "number" or type(obj) == "boolean" then
            return tostring(obj)
        elseif type(obj) == "function" then
            return "function"
        elseif obj == nil then
            return "nil"
        else
            return typeof(obj) .. ":" .. tostring(obj)
        end
    end)
    if ok then return res else return "[ERR:" .. tostring(res) .. "]" end
end

local function logCall(remote, method, args)
    local parts = {}
    for i, arg in ipairs(args) do
        parts[i] = safeToString(arg)
    end
    log("REMOTE CALL:", remote.ClassName .. "[\"" .. remote.Name .. "\"]", method, table.concat(parts, " | "))
    -- Also log remote location
    local ok, fullName = pcall(function() return remote:GetFullName() end)
    if ok then log("  path:", fullName) end
end

-- Hook RemoteEvent.FireServer
pcall(function()
    local oldFireServer
    oldFireServer = hookfunction(Instance.new("RemoteEvent").FireServer, function(self, ...)
        local args = {...}
        pcall(function() logCall(self, "FireServer", args) end)
        return oldFireServer(self, ...)
    end)
    hooked = true
    log("RemoteEvent.FireServer hooked")
end)

-- Hook RemoteFunction.InvokeServer
pcall(function()
    local oldInvokeServer
    oldInvokeServer = hookfunction(Instance.new("RemoteFunction").InvokeServer, function(self, ...)
        local args = {...}
        pcall(function() logCall(self, "InvokeServer", args) end)
        return oldInvokeServer(self, ...)
    end)
    hooked = true
    log("RemoteFunction.InvokeServer hooked")
end)

if not hooked then
    log("ERROR: Failed to hook any remote")
    copy()
    return
end

-- Listen for 20 seconds
log("Listening for 20 seconds...")
for i = 1, 20 do
    task.wait(1)
    log("t+", tostring(i))
end

log("\n========== END ==========")
log("Total hooks active. Rejoin to remove hooks.")
copy()
