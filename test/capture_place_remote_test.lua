--[[
    San Diego Agent — Test: capture placement remote
    =================================================
    Хук всех RemoteEvent/RemoteFunction на 30 секунд. В течение этого времени
    вручную поставь один Money Printer через игровой интерфейс.
    Скрипт запишет, какие remote'ы вызывались и с какими аргументами.
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
    if writefile then pcall(function() writefile("capture_place_remote_log.txt", text) end) end
end

local function formatArg(arg)
    local t = typeof(arg)
    if t == "Instance" then
        return arg.ClassName .. " " .. arg.Name
    elseif t == "CFrame" then
        return "CFrame(" .. tostring(arg) .. ")"
    elseif t == "Vector3" then
        return "Vector3(" .. tostring(arg) .. ")"
    elseif t == "table" then
        local parts = {}
        for k, v in pairs(arg) do
            table.insert(parts, tostring(k) .. "=" .. tostring(v))
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    else
        return tostring(arg) .. " (" .. t .. ")"
    end
end

log("========== CAPTURE PLACE REMOTE TEST ==========")
log("Player:", player.Name)
log("В течение 30 секунд вручную поставь Money Printer через игру.")

local captured = {}
local connections = {}
local function hookRemote(remote)
    if remote:IsA("RemoteEvent") then
        local con = remote.OnClientEvent:Connect(function(...)
            local args = {...}
            local s = remote:GetFullName() .. ":FireClient -> " .. #args .. " args"
            for i, a in ipairs(args) do
                s = s .. "\n    [" .. i .. "] " .. formatArg(a)
            end
            table.insert(captured, s)
            log("FIRED CLIENT", remote:GetFullName())
        end)
        table.insert(connections, con)
        -- hook FireServer by replacing the function
        local old = remote.FireServer
        remote.FireServer = function(self, ...)
            local args = {...}
            local s = remote:GetFullName() .. ":FireServer -> " .. #args .. " args"
            for i, a in ipairs(args) do
                s = s .. "\n    [" .. i .. "] " .. formatArg(a)
            end
            table.insert(captured, s)
            log("FIRED SERVER", remote:GetFullName())
            return old(self, ...)
        end
    elseif remote:IsA("RemoteFunction") then
        local old = remote.InvokeServer
        remote.InvokeServer = function(self, ...)
            local args = {...}
            local s = remote:GetFullName() .. ":InvokeServer -> " .. #args .. " args"
            for i, a in ipairs(args) do
                s = s .. "\n    [" .. i .. "] " .. formatArg(a)
            end
            table.insert(captured, s)
            log("INVOKED SERVER", remote:GetFullName())
            return old(self, ...)
        end
    end
end

local function scanRemotes(parent, depth)
    if depth > 8 then return end
    for _, c in ipairs(parent:GetChildren()) do
        if c:IsA("RemoteEvent") or c:IsA("RemoteFunction") then
            hookRemote(c)
        end
        scanRemotes(c, depth + 1)
    end
end

scanRemotes(game, 0)
log("Hooked", tostring(#connections), "remotes. Waiting 30s...")

for i = 1, 30 do
    task.wait(1)
    log("t+", tostring(i))
end

for _, con in ipairs(connections) do
    pcall(function() con:Disconnect() end)
end

log("\n--- Captured events ---")
for _, s in ipairs(captured) do
    log(s)
end

log("\n========== END ==========")
copy()
