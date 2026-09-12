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

function PrivateServer:setResultStore(resultStore)
	self.resultStore = resultStore
end

-- Флаг перехода храним и в genv (для текущего сервера), и файлом (getgenv
-- НЕ переживает телепорт — новый инстанс агента восстановит флаг из файла).
function PrivateServer:_setTeleporting(value, extra)
	if value then
		getgenv().SanDiegoAgentTeleporting = true
		getgenv().SanDiegoAgentTeleportFailed = nil
		getgenv().SanDiegoAgentTeleportJobId = tostring(game.JobId or "")
	else
		getgenv().SanDiegoAgentTeleporting = nil
	end
	if extra and extra.failed then
		getgenv().SanDiegoAgentTeleportFailed = tostring(extra.failed)
	end
	if self.resultStore then
		local state = {
			teleporting = value == true,
			jobId = tostring(game.JobId or ""),
			savedAt = tick(),
		}
		if extra then
			for k, v in pairs(extra) do
				state[k] = v
			end
		end
		pcall(function()
			self.resultStore:saveTeleportState(state)
		end)
	end
end

-- Ошибка доводится до CommandEngine/Agent: результат join_private_server
-- может быть уже персистнут как "completed", его нужно перезаписать ошибкой.
function PrivateServer:_notifyTeleportFailed(err)
	if self.commandEngine and typeof(self.commandEngine.onTeleportFailed) == "function" then
		pcall(function()
			self.commandEngine:onTeleportFailed(err)
		end)
	end
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
        -- «Уже в этом сервере» — это ЦЕЛЕВОЕ состояние команды, а не
        -- ошибка: ферма шлёт join каждый цикл, и RBT-сценарий прерывался
        -- на этом ответе. Считаем успехом, чтобы цикл шёл дальше.
        local msg = typeof(checkResult.Message) == "string" and checkResult.Message or ""
        if msg:lower():find("already in this server", 1, true) then
            return { success = true, data = { joined = true, already = true, message = msg } }
        end
        return { success = false, error = checkResult.Message or "server rejected join by code" }
    end

	local joinRemote, joinErr = self:_getRemote("JoinServerByCode")
	if not joinRemote then
		return { success = false, error = joinErr }
	end

	-- Флаг телепорта ставится ДО вызова remote: старый агент на текущем
	-- сервере перестаёт забирать новые команды и слать результаты, чтобы
	-- бэкендная команда не выполнилась на старом сервере, пока идёт
	-- переход. Результат join_private_server доставляет агент, стартовавший
	-- УЖЕ на новом сервере (result_store переживает телепорт через файл).
	self:_setTeleporting(true)

	-- Сторож: если через 90 секунд мы всё ещё на том же JobId, телепорт так
	-- и не начался — снимаем флаг, чтобы агент не завис навсегда.
	local watchedJobId = tostring(game.JobId or "")
	task.delay(90, function()
		if getgenv().SanDiegoAgentTeleporting
			and getgenv().SanDiegoAgentTeleportJobId == watchedJobId
			and tostring(game.JobId or "") == watchedJobId then
			warn("[SanDiegoAgent][PrivateServer] teleport did not start within 90s, releasing teleport flag")
			self:_setTeleporting(false, { failed = "teleport did not start within 90s" })
		end
	end)

	-- Запускаем в отдельном потоке, потому что успешный телепорт
	-- может прервать выполнение текущего скрипта. Перезапуск агента на
	-- новом сервере обеспечивает сам загрузчик (self-arm queue_on_teleport).
	task.spawn(function()
		-- Отключаем захват камеры перед телепортом, чтобы избежать вылетов.
		if self.commandEngine and typeof(self.commandEngine.releaseCamera) == "function" then
			pcall(function()
				self.commandEngine:releaseCamera()
			end)
		end
		local joinOk, joinResult = pcall(function()
			return joinRemote:InvokeServer(code)
		end)
		if not joinOk then
			warn("[SanDiegoAgent][PrivateServer] JoinServerByCode failed:", tostring(joinResult))
			self:_setTeleporting(false, { failed = tostring(joinResult) })
			self:_notifyTeleportFailed(tostring(joinResult))
		elseif typeof(joinResult) == "table" and joinResult.Success == false then
			warn("[SanDiegoAgent][PrivateServer] JoinServerByCode rejected:", tostring(joinResult.Message))
			self:_setTeleporting(false, { failed = tostring(joinResult.Message or "join rejected") })
			self:_notifyTeleportFailed(tostring(joinResult.Message or "join rejected"))
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
