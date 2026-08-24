--[[
    San Diego Agent - Standalone Test Version
    ===========================================
    Все модули встроены в один файл. Не требует readfile/require.
    Для остановки:
        getgenv().StopSanDiegoAgent = true
]]

print("[TEST] Loading standalone agent...")

-- ======================== КОНФИГУРАЦИЯ ========================
local CONFIG = {
    baseUrl = "http://195.161.68.193:5173/api",
    gameSlug = "san-diego",
    statusInterval = 7,
    balancePath = "leaderstats.Cash",
    customData = {},
    useMockHttp = true,
}
-- ==============================================================

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

-- ======================== HTTP CLIENT ========================
local function urlEncode(str)
    if not str then return "" end
    local result = {}
    str = tostring(str)
    for i = 1, #str do
        local c = str:sub(i, i)
        local b = c:byte()
        if (b >= 48 and b <= 57) or (b >= 65 and b <= 90) or (b >= 97 and b <= 122) or c == "-" or c == "_" or c == "." or c == "~" then
            table.insert(result, c)
        else
            table.insert(result, string.format("%%%02X", b))
        end
    end
    return table.concat(result)
end

local HttpClient = {}
HttpClient.__index = HttpClient

function HttpClient.new(baseUrl)
    local self = setmetatable({}, HttpClient)
    self.baseUrl = baseUrl
    return self
end

function HttpClient:_getRequestFunction()
    if syn and syn.request then
        return syn.request
    elseif http and http.request then
        return http.request
    elseif fluxus and fluxus.request then
        return fluxus.request
    elseif getgenv().request then
        return getgenv().request
    elseif getgenv().http_request then
        return getgenv().http_request
    else
        return nil
    end
end

function HttpClient:_makeUrl(path)
    local url = self.baseUrl
    if url:sub(-1) == "/" then url = url:sub(1, -2) end
    if path:sub(1, 1) ~= "/" then path = "/" .. path end
    return url .. path
end

function HttpClient:request(method, path, body, headers, query)
    local requestFunc = self:_getRequestFunction()
    local url = self:_makeUrl(path)

    if query then
        local parts = {}
        for k, v in pairs(query) do
            table.insert(parts, urlEncode(k) .. "=" .. urlEncode(tostring(v)))
        end
        if #parts > 0 then
            url = url .. "?" .. table.concat(parts, "&")
        end
    end

    headers = headers or {}
    headers["Content-Type"] = headers["Content-Type"] or "application/json"

    local ok, res = pcall(function()
        local opts = { Url = url, Method = method, Headers = headers }
        if body then
            opts.Body = typeof(body) == "string" and body or HttpService:JSONEncode(body)
        end
        if requestFunc then
            return requestFunc(opts)
        else
            return HttpService:RequestAsync(opts)
        end
    end)

    if not ok then return false, tostring(res) end

    local parsedBody
    if res.Body and res.Body ~= "" then
        local parseOk, parsed = pcall(function() return HttpService:JSONDecode(res.Body) end)
        if parseOk then parsedBody = parsed else parsedBody = res.Body end
    end

    return true, { statusCode = res.StatusCode, body = parsedBody, rawBody = res.Body }
end

function HttpClient:post(path, body, headers)
    return self:request("POST", path, body, headers)
end

function HttpClient:get(path, query, headers)
    return self:request("GET", path, nil, headers, query)
end

-- ======================== STATE COLLECTOR ========================
local StateCollector = {}
StateCollector.__index = StateCollector

function StateCollector.new(balancePath)
    local self = setmetatable({}, StateCollector)
    self.balancePath = balancePath or "leaderstats.Cash"
    return self
end

function StateCollector:_safeGet(object, path)
    if not object then return nil end
    local current = object
    for part in path:gmatch("[^%.]+") do
        if typeof(current) == "Instance" then
            current = current:FindFirstChild(part)
        elseif typeof(current) == "table" then
            current = current[part]
        else
            return nil
        end
        if current == nil then return nil end
    end
    if typeof(current) == "Instance" and current:IsA("ValueBase") then
        return current.Value
    end
    return current
end

function StateCollector:_getLocalPlayer()
    return Players.LocalPlayer
end

function StateCollector:_getCharacter()
    local player = self:_getLocalPlayer()
    if not player then return nil end
    return player.Character
end

function StateCollector:_getHumanoidRootPart()
    local character = self:_getCharacter()
    if not character then return nil end
    return character:FindFirstChild("HumanoidRootPart")
end

function StateCollector:getLocation()
    local hrp = self:_getHumanoidRootPart()
    if hrp and hrp:IsA("BasePart") then
        local pos = hrp.Position
        return string.format("%.1f, %.1f, %.1f", pos.X, pos.Y, pos.Z)
    end
    return "unknown"
end

function StateCollector:getTeam()
    local player = self:_getLocalPlayer()
    if not player then return "unknown" end
    if player.Team then return tostring(player.Team.Name) end
    return "Neutral"
end

function StateCollector:getBalance()
    local player = self:_getLocalPlayer()
    if not player then return 0 end
    local value = self:_safeGet(player, self.balancePath)
    if typeof(value) == "number" then return value end
    return 0
end

function StateCollector:getStatus()
    local player = self:_getLocalPlayer()
    if not player then return "offline" end
    return "online"
end

function StateCollector:getNickname()
    local player = self:_getLocalPlayer()
    if not player then return "unknown" end
    return player.DisplayName or player.Name
end

function StateCollector:getServerId()
    return game.JobId or "unknown"
end

function StateCollector:getPlaceId()
    return tostring(game.PlaceId or 0)
end

function StateCollector:getAll(custom)
    local customData = {
        location = self:getLocation(),
        team = self:getTeam(),
    }
    if typeof(custom) == "table" then
        for k, v in pairs(custom) do
            customData[k] = v
        end
    end

    return {
        nickname = self:getNickname(),
        status = self:getStatus(),
        balance = self:getBalance(),
        server_id = self:getServerId(),
        place_id = self:getPlaceId(),
        custom_data = customData,
    }
end

-- ======================== COMMAND ENGINE ========================
local CommandEngine = {}
CommandEngine.__index = CommandEngine

function CommandEngine.new()
    local self = setmetatable({}, CommandEngine)
    self.cancelled = false
    self.currentCommandId = nil
    return self
end

function CommandEngine:_getHrp()
    local player = Players.LocalPlayer
    if not player then return nil end
    local character = player.Character
    if not character then return nil end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if hrp and hrp:IsA("BasePart") then return hrp end
    return nil
end

function CommandEngine:_isCancelled() return self.cancelled end
function CommandEngine:resetCancel() self.cancelled = false end
function CommandEngine:requestCancel() self.cancelled = true end

function CommandEngine:getCommandsSpec()
    return {
        { name = "get_commands", description = "Вернуть список доступных команд", params = {} },
        { name = "move_x", description = "Сместить персонажа по оси X", params = { value = { type = "number", required = true, min = -10000, max = 10000, description = "Смещение по оси X в студиях" } } },
        { name = "move_y", description = "Сместить персонажа по оси Y", params = { value = { type = "number", required = true, min = -10000, max = 10000, description = "Смещение по оси Y в студиях" } } },
        { name = "move_z", description = "Сместить персонажа по оси Z", params = { value = { type = "number", required = true, min = -10000, max = 10000, description = "Смещение по оси Z в студиях" } } },
        { name = "pause", description = "Подождать N секунд", params = { duration = { type = "number", required = true, min = 0, max = 300, description = "Длительность паузы в секундах" } } },
        { name = "cancel", description = "Отменить текущую команду", params = {} },
    }
end

function CommandEngine:_validateMove(payload)
    local value = payload and payload.value
    if typeof(value) ~= "number" then return false, "param 'value' must be a number" end
    if value < -10000 or value > 10000 then return false, "param 'value' out of range [-10000, 10000]" end
    return true, value
end

function CommandEngine:_moveAxis(axis, payload)
    local ok, value = self:_validateMove(payload)
    if not ok then return { success = false, error = value } end

    local hrp = self:_getHrp()
    if not hrp then return { success = false, error = "HumanoidRootPart not found" } end
    if self:_isCancelled() then return { success = false, error = "cancelled" } end

    local offset = Vector3.zero
    if axis == "x" then offset = Vector3.new(value, 0, 0)
    elseif axis == "y" then offset = Vector3.new(0, value, 0)
    elseif axis == "z" then offset = Vector3.new(0, 0, value) end

    hrp.CFrame = hrp.CFrame + offset
    return { success = true, data = { newPosition = { x = math.round(hrp.Position.X * 10) / 10, y = math.round(hrp.Position.Y * 10) / 10, z = math.round(hrp.Position.Z * 10) / 10 } } }
end

function CommandEngine:_pause(payload)
    local duration = payload and payload.duration
    if typeof(duration) ~= "number" then return { success = false, error = "param 'duration' must be a number" } end
    if duration < 0 or duration > 300 then return { success = false, error = "param 'duration' out of range [0, 300]" } end

    local elapsed = 0
    while elapsed < duration do
        if self:_isCancelled() then return { success = false, error = "cancelled" } end
        task.wait(0.1)
        elapsed = elapsed + 0.1
    end
    return { success = true, data = { elapsed = math.round(elapsed * 10) / 10 } }
end

function CommandEngine:_cancelCurrent()
    self:requestCancel()
    local data = {}
    if self.currentCommandId then data.cancelledCommandId = self.currentCommandId end
    return { success = true, data = data }
end

function CommandEngine:execute(command)
    local name = command.name
    local payload = command.payload or {}
    self.currentCommandId = command.id
    self:resetCancel()

    local result
    if name == "get_commands" then
        result = { success = true, data = { commands = self:getCommandsSpec() } }
    elseif name == "move_x" then result = self:_moveAxis("x", payload)
    elseif name == "move_y" then result = self:_moveAxis("y", payload)
    elseif name == "move_z" then result = self:_moveAxis("z", payload)
    elseif name == "pause" then result = self:_pause(payload)
    elseif name == "cancel" then result = self:_cancelCurrent()
    else result = { success = false, error = "unknown command: " .. tostring(name) }
    end

    self.currentCommandId = nil
    return result
end

-- ======================== AGENT ========================
local Agent = {}
Agent.__index = Agent

function Agent.new(config, httpClient, stateCollector, commandEngine)
    local self = setmetatable({}, Agent)
    self.config = {
        baseUrl = config.baseUrl,
        gameSlug = config.gameSlug,
        statusInterval = config.statusInterval or 5,
    }
    self.http = httpClient
    self.state = stateCollector
    self.engine = commandEngine
    self.running = false
    self.lastCommandId = nil
    self.lastCommandStatus = nil
    self.lastCommandMessage = nil
    self.lastCommandResult = nil
    self.currentCommand = nil
    self.commandQueue = {}
    return self
end

function Agent:_log(level, ...)
    local msg = table.concat({ ... }, " ")
    print(string.format("[SanDiegoAgent][%s] %s", level, msg))
end

function Agent:_sendStatus()
    local data = self.state:getAll(self.config.customData)
    data.game_slug = self.config.gameSlug
    local ok, res = self.http:post("/game/update", data)
    if ok then self:_log("INFO", "status sent", res.statusCode) else self:_log("ERROR", "status send failed:", tostring(res)) end
end

function Agent:_updateCommandStatus(commandId, status, message)
    if not commandId then return end
    local body = { status = status }
    if message then body.message = message end
    local ok, res = self.http:post("/commands/" .. tostring(commandId) .. "/status", body)
    if ok then self:_log("INFO", "command status updated", commandId, status, res.statusCode) else self:_log("ERROR", "command status update failed:", commandId, tostring(res)) end
end

function Agent:_sendCommandResult(commandId, result)
    if not commandId then return end
    local ok, res = self.http:post("/commands/" .. tostring(commandId) .. "/result", result)
    if ok then self:_log("INFO", "command result sent", commandId, res.statusCode) else self:_log("ERROR", "command result send failed:", commandId, tostring(res)) end
end

function Agent:_finishCommand(commandId, status, result)
    self.lastCommandId = commandId
    self.lastCommandStatus = status
    self.lastCommandMessage = result.error or result.message
    self.lastCommandResult = result

    self:_sendCommandResult(commandId, result)
    self:_updateCommandStatus(commandId, status, self.lastCommandMessage)
end

function Agent:_reportLastCommandAndClear()
    if self.lastCommandId and self.lastCommandStatus and self.lastCommandResult then
        self:_finishCommand(self.lastCommandId, self.lastCommandStatus, self.lastCommandResult)
        self.lastCommandId = nil
        self.lastCommandStatus = nil
        self.lastCommandMessage = nil
        self.lastCommandResult = nil
    end
end

function Agent:_fetchNextCommand()
    local nickname = self.state:getNickname()
    local query = { nickname = nickname, game_slug = self.config.gameSlug }
    if self.lastCommandId and self.lastCommandStatus then
        query.last_id = self.lastCommandId
        query.last_status = self.lastCommandStatus
    end

    local ok, res = self.http:get("/commands/next", query)
    if not ok then
        self:_log("ERROR", "command fetch failed:", tostring(res))
        return nil
    end
    if res.statusCode == 204 or not res.body then return nil end
    if typeof(res.body) ~= "table" then return nil end

    local command = res.body.command or res.body
    if not command or not command.id then return nil end
    return command
end

function Agent:_handleCommand(command)
    self.currentCommand = command
    self:_updateCommandStatus(command.id, "in_progress")

    local ok, result = pcall(function() return self.engine:execute(command) end)
    if not ok then result = { success = false, error = tostring(result) } end

    local status = "completed"
    if not result.success then status = "error" end
    if result.error == "cancelled" then status = "cancelled" end

    if status == "cancelled" then
        self.lastCommandId = command.id
        self.lastCommandStatus = "cancelled"
        self.lastCommandMessage = result.error
        self.lastCommandResult = result
        self:_sendCommandResult(command.id, result)
    else
        self:_finishCommand(command.id, status, result)
    end

    self.currentCommand = nil
    self:_log("INFO", "command finished", command.id, command.name, status)
end

function Agent:_handleCancel(command)
    local cancelledId = self.currentCommand and self.currentCommand.id
    self:_log("INFO", "received cancel command", command.id, "cancelling", cancelledId or "none")
    self.engine:requestCancel()
    if cancelledId then
        self:_updateCommandStatus(cancelledId, "cancelled", "cancelled by user")
    end
    local resultData = {}
    if cancelledId then resultData.cancelledCommandId = cancelledId end
    self:_finishCommand(command.id, "completed", { success = true, data = resultData })
end

function Agent:_fetcherLoop()
    while self.running do
        local command = self:_fetchNextCommand()
        if command then
            self:_log("INFO", "fetched command", command.id, command.name)
            if command.name == "cancel" then
                self:_handleCancel(command)
            else
                table.insert(self.commandQueue, command)
            end
        else
            task.wait(1)
        end
    end
end

function Agent:_workerLoop()
    while self.running do
        if #self.commandQueue > 0 then
            local command = table.remove(self.commandQueue, 1)
            self:_handleCommand(command)
        else
            task.wait(0.1)
        end
    end
end

function Agent:_statusLoop()
    while self.running do
        task.wait(self.config.statusInterval)
        if self.running then
            self:_sendStatus()
        end
    end
end

function Agent:start()
    if self.running then
        self:_log("WARN", "agent already running")
        return
    end

    self.running = true
    self:_log("INFO", "starting agent for game", self.config.gameSlug)

    self:_reportLastCommandAndClear()
    self:_sendStatus()

    task.spawn(function() self:_statusLoop() end)
    task.spawn(function() self:_fetcherLoop() end)
    task.spawn(function() self:_workerLoop() end)
end

function Agent:stop()
    self.running = false
    self.engine:requestCancel()
    self:_log("INFO", "agent stopped")
end

-- ======================== MOCK HTTP CLIENT ========================
local MockHttpClient = {}
MockHttpClient.__index = MockHttpClient

function MockHttpClient.new(baseUrl)
    local self = setmetatable({}, MockHttpClient)
    self.baseUrl = baseUrl
    self.commandQueue = {}
    self.commandIndex = 0
    return self
end

function MockHttpClient:enqueueCommand(name, payload)
    self.commandIndex = self.commandIndex + 1
    table.insert(self.commandQueue, {
        id = "mock-cmd-" .. tostring(self.commandIndex),
        game_slug = CONFIG.gameSlug,
        nickname = Players.LocalPlayer and Players.LocalPlayer.Name or "TestPlayer",
        name = name,
        payload = payload or {},
        status = "pending",
        created_at = "2026-08-24T12:00:00Z",
        updated_at = "2026-08-24T12:00:00Z",
    })
end

function MockHttpClient:post(path, body)
    print("[MOCK HTTP POST]", path, HttpService:JSONEncode(body))
    return true, { statusCode = 200, body = { success = true } }
end

function MockHttpClient:get(path, query)
    print("[MOCK HTTP GET]", path, HttpService:JSONEncode(query))
    if path == "/commands/next" then
        if #self.commandQueue > 0 then
            local cmd = table.remove(self.commandQueue, 1)
            cmd.status = "in_progress"
            return true, { statusCode = 200, body = { command = cmd } }
        end
        return true, { statusCode = 204, body = nil }
    end
    return true, { statusCode = 200, body = {} }
end

-- ======================== MAIN ========================
local localPlayer = Players.LocalPlayer
if not localPlayer then
    print("[TEST] CRITICAL: Players.LocalPlayer not available")
    return
end
print("[TEST] LocalPlayer:", localPlayer.Name)

local function waitForCharacter()
    if localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") then return true end
    print("[TEST] Waiting for Character/HumanoidRootPart...")
    local waited = 0
    while waited < 10 do
        if localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") then return true end
        task.wait(0.5)
        waited = waited + 0.5
    end
    return false
end

if not waitForCharacter() then
    print("[TEST] WARNING: Character not loaded. Movement commands will fail.")
end

getgenv().StopSanDiegoAgent = false

local http = CONFIG.useMockHttp and MockHttpClient.new(CONFIG.baseUrl) or HttpClient.new(CONFIG.baseUrl)
local state = StateCollector.new(CONFIG.balancePath)
local engine = CommandEngine.new()
local agent = Agent.new(CONFIG, http, state, engine)

if CONFIG.useMockHttp then
    http:enqueueCommand("get_commands", {})
    http:enqueueCommand("pause", { duration = 10 })
    http:enqueueCommand("move_x", { value = 10 })
    http:enqueueCommand("move_z", { value = -5 })
    print("[TEST] Mock commands enqueued")

    -- cancel придёт через 2 секунды после старта, когда pause уже выполняется
    task.delay(2, function()
        http:enqueueCommand("cancel", {})
        print("[TEST] cancel command enqueued with delay")
    end)
end

print("[TEST] Starting agent...")
agent:start()
print("[TEST] Agent started")

while not getgenv().StopSanDiegoAgent do
    task.wait(1)
end

agent:stop()
print("[SanDiegoAgent] stopped")
