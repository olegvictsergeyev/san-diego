local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PrivateServer = {}
PrivateServer.__index = PrivateServer

function PrivateServer.new(opts)
	local self = setmetatable({}, PrivateServer)
	self.loaderUrl = opts and opts.loaderUrl or "https://raw.githubusercontent.com/olegvictsergeyev/san-diego/main/final/agent.lua"
	self.compat = opts and opts.compat or nil
	return self
end

function PrivateServer:_queueReload()
	local baseUrl = tostring(self.loaderUrl):match("(.+)/final/agent%.lua$") or self.loaderUrl
	local code = 'local baseUrl = "' .. baseUrl .. '"\ngetgenv().SanDiegoAgentBaseUrl = baseUrl\ngetgenv().SanDiegoAgentRunning = nil\ngetgenv().SanDiegoAgentRunningJobId = nil\ntask.wait(0.5)\nprint("[SanDiegoAgent][QueueOnTeleport] reloading loader after teleport")\nlocal ok, err = pcall(function()\n    loadstring(game:HttpGet(baseUrl .. "/final/agent.lua?nocache=" .. tostring(tick())))()\nend)\nif not ok then\n    warn("[SanDiegoAgent][QueueOnTeleport] reload failed: " .. tostring(err))\nend'
	if self.compat and self.compat.queueOnTeleport then
		return self.compat.queueOnTeleport(code)
	end
	local q = queue_on_teleport
	if typeof(q) ~= "function" then
		return false
	end
	local ok = pcall(q, code)
	return ok
end

function PrivateServer:_getRemotesFolder()
	local remotes = ReplicatedStorage:FindFirstChild("__remotes")
	if not remotes then
		return nil, "ReplicatedStorage.__remotes not found"
	end
	local service = remotes:FindFirstChild("CustomServerService")
	if not service then
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
		return nil, "Remote " .. name .. " not found"
	end
	if not (remote:IsA("RemoteFunction") or remote:IsA("RemoteEvent")) then
		return nil, "Instance " .. name .. " is not a remote"
	end
	return remote
end

function PrivateServer:joinByCode(code)
	if typeof(code) ~= "string" or code:gsub("%s+", "") == "" then
		return { success = false, error = "private server code must be a non-empty string" }
	end

	local canJoin, err = self:_getRemote("CanJoinServerByCode")
	if not canJoin then
		return { success = false, error = err }
	end

	local ok, checkResult = pcall(function()
		return canJoin:InvokeServer(code)
	end)
	if not ok then
		return { success = false, error = "CanJoinServerByCode failed: " .. tostring(checkResult) }
	end
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
		self:_queueReload()
		pcall(function()
			joinRemote:InvokeServer(code)
		end)
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
