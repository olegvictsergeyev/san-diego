local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PrivateServer = {}
PrivateServer.__index = PrivateServer

function PrivateServer.new(opts)
	local self = setmetatable({}, PrivateServer)
	self.loaderUrl = opts and opts.loaderUrl or "https://raw.githubusercontent.com/olegvictsergeyev/san-diego/main/final/agent.lua"
	self.compat = opts and opts.compat or nil
	self.commandEngine = opts and opts.commandEngine or nil
	return self
end

function PrivateServer:setCommandEngine(commandEngine)
	self.commandEngine = commandEngine
end

function PrivateServer:_queueReload()
    local baseUrl = tostring(self.loaderUrl):match("(.+)/final/agent%.lua$") or self.loaderUrl
    local code = 'local baseUrl = "' .. baseUrl .. '"\ngetgenv().SanDiegoAgentBaseUrl = baseUrl\ntask.wait(0.5)\nprint("[SanDiegoAgent][QueueOnTeleport] reloading loader after teleport")\nlocal ok, err = pcall(function()\n    loadstring(game:HttpGet(baseUrl .. "/final/agent.lua?nocache=" .. tostring(tick())))()\nend)\nif not ok then\n    warn("[SanDiegoAgent][QueueOnTeleport] reload failed: " .. tostring(err))\nend'
    if self.compat and self.compat.queueOnTeleport then
        local ok = self.compat.queueOnTeleport(code)
        print("[SanDiegoAgent][QueueOnTeleport] compat queue_on_teleport:", tostring(ok))
        return ok
    end
    local q = queue_on_teleport
    if typeof(q) ~= "function" then
        warn("[SanDiegoAgent][QueueOnTeleport] queue_on_teleport is not available")
        return false
    end
    local ok = pcall(q, code)
    print("[SanDiegoAgent][QueueOnTeleport] queue_on_teleport result:", tostring(ok))
    return ok
end

function PrivateServer:_getRemotesFolder()
    local remotes = ReplicatedStorage:FindFirstChild("__remotes")
    if not remotes then
        warn("[SanDiegoAgent][PrivateServer] ReplicatedStorage.__remotes not found")
        return nil, "ReplicatedStorage.__remotes not found"
    end
    local service = remotes:FindFirstChild("CustomServerService")
    if not service then
        warn("[SanDiegoAgent][PrivateServer] CustomServerService remotes not found")
        return nil, "CustomServerService remotes not found"
    end
    return service
end

function PrivateServer:_getRemote(name)
    local folder = self:_getRemotesFolder()
    if not folder then
        return nil, "CustomServerService folder not found"
    end
    local remote = folder:FindFirstChild(name)
    if not remote then
        warn("[SanDiegoAgent][PrivateServer] Remote not found: " .. tostring(name))
        return nil, "Remote " .. name .. " not found"
    end
    if not (remote:IsA("RemoteFunction") or remote:IsA("RemoteEvent")) then
        warn("[SanDiegoAgent][PrivateServer] " .. tostring(name) .. " is not a remote")
        return nil, "Instance " .. name .. " is not a remote"
    end
    print("[SanDiegoAgent][PrivateServer] found remote: " .. tostring(name))
    return remote
end

function PrivateServer:joinByCode(code)
    if typeof(code) ~= "string" or code:gsub("%s+", "") == "" then
        return { success = false, error = "private server code must be a non-empty string" }
    end

    print("[SanDiegoAgent][PrivateServer] joinByCode requested with code:", code)

    local canJoin, err = self:_getRemote("CanJoinServerByCode")
    if not canJoin then
        return { success = false, error = err }
    end

    local ok, checkResult = pcall(function()
        return canJoin:InvokeServer(code)
    end)
    if not ok then
        warn("[SanDiegoAgent][PrivateServer] CanJoinServerByCode failed:", tostring(checkResult))
        return { success = false, error = "CanJoinServerByCode failed: " .. tostring(checkResult) }
    end
    print("[SanDiegoAgent][PrivateServer] CanJoinServerByCode result:", tostring(checkResult), typeof(checkResult) == "table" and "(table)" or "")
    if typeof(checkResult) == "table" and checkResult.Success == false then
        return { success = false, error = checkResult.Message or "server rejected join by code" }
    end

    local joinRemote, joinErr = self:_getRemote("JoinServerByCode")
    if not joinRemote then
        return { success = false, error = joinErr }
    end

    -- Запускаем в отдельном потоке, потому что успешный телепорт
    -- может прервать выполнение текущего скрипта.
    task.spawn(function()
        -- Отключаем захват камеры перед телепортом, чтобы избежать вылетов.
        if self.commandEngine and typeof(self.commandEngine.releaseCamera) == "function" then
            pcall(function()
                self.commandEngine:releaseCamera()
            end)
        end
        local queued = self:_queueReload()
        if not queued then
            warn("[SanDiegoAgent][PrivateServer] failed to queue reload; agent may not restart after teleport")
        end
        local joinOk, joinResult = pcall(function()
            return joinRemote:InvokeServer(code)
        end)
        if not joinOk then
            warn("[SanDiegoAgent][PrivateServer] JoinServerByCode failed:", tostring(joinResult))
        elseif typeof(joinResult) == "table" and joinResult.Success == false then
            warn("[SanDiegoAgent][PrivateServer] JoinServerByCode rejected:", tostring(joinResult.Message))
        else
            print("[SanDiegoAgent][PrivateServer] JoinServerByCode invoked, teleport should start")
        end
    end)

    return {
        success = true,
        data = {
            code = code,
            action = "teleport_requested",
        },
    }
end

return PrivateServer
