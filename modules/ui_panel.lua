--[[
    San Diego Agent — UI Panel
    ==========================
    Модуль управления агентом через Orion UI.
    Содержит CONFIG и логику запуска/остановки.
    Запускается из final/agent.lua.
]]

local Players = game:GetService("Players")

local CONFIG = {
    -- Версия агента (major.minor.patch). Сейчас ранняя альфа.
    version = "1.3.0",

    -- URL существующего сервиса
    baseUrl = "http://195.161.68.193:5173/api",

    -- Идентификатор игры
    gameSlug = "san-diego",

    -- Как часто отправлять статус (секунды)
    statusInterval = 7,

    -- Long-poll таймаут при получении команд (секунды)
    commandPollTimeout = 30,

    -- Пауза перед повторным запросом при ошибке (секунды)
    commandRetryDelay = 3,

    -- Путь к балансу в иерархии LocalPlayer
    balancePath = "leaderstats.Cash",

    -- Дополнительные кастомные поля
    customData = {},

    -- URL модулей
    moduleUrls = (function()
        local base = getgenv().SanDiegoAgentBaseUrl or "https://raw.githubusercontent.com/olegvictsergeyev/san-diego/main"
        return {
            http_client = base .. "/modules/http_client.lua",
            state_collector = base .. "/modules/state_collector.lua",
            command_engine = base .. "/modules/command_engine.lua",
            agent = base .. "/modules/agent.lua",
            private_server = base .. "/modules/private_server.lua",
            popup_closer = base .. "/modules/popup_closer.lua",
            compat = base .. "/modules/compat.lua",
            disconnect_watcher = base .. "/modules/disconnect_watcher.lua",
            ui_toggle = base .. "/modules/ui_toggle.lua",
            autoexec = base .. "/modules/autoexec.lua",
            server_state = base .. "/modules/server_state.lua",
            afk = base .. "/modules/afk.lua",
        }
    end)(),

    -- URL загрузчика для перезапуска после телепорта
    agentLoaderUrl = (getgenv().SanDiegoAgentBaseUrl or "https://raw.githubusercontent.com/olegvictsergeyev/san-diego/main") .. "/final/agent.lua",

    -- true при запуске через loadstring (script == nil), иначе false
    useRemoteModules = (script == nil),

    -- true — показать панель Orion; false — запустить агента сразу
    showUI = true,

    -- true — автоматически нажимать Reconnect при ошибке 277
    autoReconnectOnDisconnect = true,

    -- AFK-режим: периодическое незаметное действие, чтобы не выкидывало из игры
    afkEnabled = true,
    afkInterval = 600,
}

local function loadModule(name)
    if CONFIG.useRemoteModules or not script or typeof(script) ~= "Instance" or not script.Parent then
        local url = CONFIG.moduleUrls[name]
        if not url then
            error("module URL not configured: " .. tostring(name))
        end
        -- Обходим кэш raw.githubusercontent.com
        url = url .. "?nocache=" .. tostring(tick())
        local source = game:HttpGet(url)
        local fn, err = loadstring(source, name)
        if not fn then
            error("failed to load module " .. name .. ": " .. tostring(err))
        end
        return fn()
    else
        return require(script.Parent:WaitForChild(name))
    end
end

local HttpClient = loadModule("http_client")
local StateCollector = loadModule("state_collector")
local PrivateServer = loadModule("private_server")
local PopupCloser = loadModule("popup_closer")
local Compat = loadModule("compat")
local DisconnectWatcher = loadModule("disconnect_watcher")
local ToggleUI = loadModule("ui_toggle")
local Autoexec = loadModule("autoexec")
local ServerState = loadModule("server_state")
local CommandEngine = loadModule("command_engine")
local Agent = loadModule("agent")
local Afk = loadModule("afk")

local serverState = ServerState.new(Compat, Players.LocalPlayer and Players.LocalPlayer.Name)

local privateServer = PrivateServer.new({
    loaderUrl = CONFIG.agentLoaderUrl,
    compat = Compat,
    serverState = serverState,
})

local currentAgent = nil
local currentMainGui = nil
local autoexec = Autoexec.new()
local stateReader = StateCollector.new(CONFIG.balancePath, CONFIG.version)
local popupCloser = PopupCloser.new(Compat)

local coreStarted = false
local runCore

local function ensureCorrectServer()
	local saved = serverState:load()
	if not saved then
		return true
	end

	-- Телепорт/reconnect делаем только если был зафиксирован дисконнект.
	if not saved.reconnectPending then
		serverState:clear()
		return true
	end

	local currentJobId = tostring(game.JobId)

	-- Уже на нужном сервере — сбрасываем сохранение.
	if saved.jobId and saved.jobId == currentJobId then
		serverState:clear()
		return true
	end

	-- Игнорируем устаревшее сохранение (старше 3 минут).
	local savedAt = tonumber(saved.savedAt) or 0
	if tick() - savedAt > 180 then
		serverState:clear()
		return true
	end

	-- Только что зашли по коду — сохраняем текущий JobId.
	if saved.code and not saved.jobId then
		serverState:save(game.PlaceId, currentJobId)
		return true
	end

	-- Переподключаемся по коду, если он есть.
	if saved.code then
		warn("[SanDiegoAgent][ServerGuard] current server does not match saved " .. currentJobId .. ", reconnecting by private server code")
		local ok, err = pcall(function()
			privateServer:reconnectByCode(saved.code)
		end)
		if ok then
			return false
		end
		warn("[SanDiegoAgent][ServerGuard] reconnect by code failed: " .. tostring(err))
	end

	-- Fallback: телепорт по placeId/jobId.
	local placeId = tonumber(saved.placeId) or game.PlaceId
	local jobId = tostring(saved.jobId)
	warn("[SanDiegoAgent][ServerGuard] current server does not match saved " .. currentJobId .. ", teleporting to " .. jobId)

	local loaderCode = 'getgenv().SanDiegoAgentBaseUrl = "' .. (getgenv().SanDiegoAgentBaseUrl or "https://raw.githubusercontent.com/olegvictsergeyev/san-diego/main") .. '"\nloadstring(game:HttpGet("' .. CONFIG.agentLoaderUrl .. '?nocache=" .. tostring(tick())))()'
	Compat.queueOnTeleport(loaderCode)

	local TeleportService = game:GetService("TeleportService")
	local player = Players.LocalPlayer
	local ok, err = pcall(function()
		TeleportService:TeleportToPlaceInstance(placeId, jobId, player)
	end)
	if not ok then
		warn("[SanDiegoAgent][ServerGuard] teleport failed: " .. tostring(err))
		serverState:clear()
		hideTeleportErrorPrompt()
		return true
	end

	return false
end

local function makeAgent()
    local http = HttpClient.new(CONFIG.baseUrl)
    local state = StateCollector.new(CONFIG.balancePath, CONFIG.version)
    local afk = Afk.new(CONFIG)
    local engine = CommandEngine.new(privateServer, afk)
    return Agent.new(CONFIG, http, state, engine, afk)
end

local function startWatcher()
    if not currentAgent then
        return
    end
    local watcher = DisconnectWatcher.new(currentAgent, Compat, {
        autoReconnect = CONFIG.autoReconnectOnDisconnect,
        loaderUrl = CONFIG.agentLoaderUrl,
        serverState = serverState,
    })
    watcher:start()
end

local function installAutoexec()
    local ok, path = pcall(function()
        return autoexec:install(CONFIG.agentLoaderUrl)
    end)
    if not ok then
        warn("[SanDiegoAgent][Autoexec] install error:", tostring(path))
    end
end

local function startAgent()
    if currentAgent then
        currentAgent:stop()
        currentAgent = nil
        getgenv().SanDiegoAgentRunning = nil
    end
    currentAgent = makeAgent()
    currentAgent:start()
    startWatcher()
    installAutoexec()
end

local function stopAgent()
    if currentAgent then
        currentAgent:stop()
        currentAgent = nil
    end
    getgenv().SanDiegoAgentRunning = nil
end

local function getPosition()
    local player = Players.LocalPlayer
    if not player then return Vector3.new(0, 0, 0) end
    local character = player.Character
    if not character then return Vector3.new(0, 0, 0) end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if hrp and hrp:IsA("BasePart") then
        return hrp.Position
    end
    return Vector3.new(0, 0, 0)
end

local function getCoord(axis)
    local pos = getPosition()
    if axis == "X" then return pos.X end
    if axis == "Y" then return pos.Y end
    if axis == "Z" then return pos.Z end
    return 0
end

local function getUiParent()
    local hui = Compat.gethui()
    if typeof(hui) == "Instance" and hui:IsA("CoreGui") then
        return hui
    end
    return game.CoreGui
end

local function copyToClipboard(text)
    Compat.setClipboard(text)
    print("[SanDiegoAgent][UI] Скопировано:", text)
end

local function loadOrion()
    local ok, Orion = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/OrionLibrary/Orion/main/source.lua"))()
    end)
    if not ok then
        warn("[SanDiegoAgent][UI] Failed to load Orion:", tostring(Orion))
        return nil
    end
    return Orion
end

local function findMainPage(gui)
    if not gui then return nil end
    for _, desc in ipairs(gui:GetDescendants()) do
        if desc.Name == "newPageГлавное" then
            return desc
        end
    end
    return nil
end

local function findOrionGui(preExisting)
    local function searchRoot(root)
        if preExisting then
            for _, sg in ipairs(root:GetChildren()) do
                if sg:IsA("ScreenGui") and not preExisting[sg] then
                    return sg
                end
            end
        end
        for _, sg in ipairs(root:GetChildren()) do
            if sg:IsA("ScreenGui") then
                if sg.Name == "San Diego Agent" then
                    return sg
                end
                for _, desc in ipairs(sg:GetDescendants()) do
                    if (desc:IsA("TextLabel") or desc:IsA("TextButton") or desc:IsA("TextBox")) and desc.Text == "San Diego Agent" then
                        return sg
                    end
                end
            end
        end
        return nil
    end

    local found = searchRoot(game.CoreGui)
    if found then
        return found
    end
    found = searchRoot(Compat.gethui())
    if found then
        return found
    end
    warn("[SanDiegoAgent][UI] Orion ScreenGui not found")
    return nil
end

local function updateInfoLabels()
    local gui = currentMainGui
    if not gui then return end
    local page = findMainPage(gui)
    if not page then return end

    local pos = getPosition()
    local bal = stateReader:getBalance()

    for _, child in ipairs(page:GetChildren()) do
        if child.Name == "labelFrame" then
            local txt = child:FindFirstChild("txtLabel")
            if txt and txt:IsA("TextLabel") then
                if txt.Text:sub(1, 2) == "X:" then
                    txt.Text = string.format("X: %.2f", pos.X)
                elseif txt.Text:sub(1, 2) == "Y:" then
                    txt.Text = string.format("Y: %.2f", pos.Y)
                elseif txt.Text:sub(1, 2) == "Z:" then
                    txt.Text = string.format("Z: %.2f", pos.Z)
                elseif txt.Text:sub(1, 8) == "Balance:" then
                    txt.Text = "Balance: " .. tostring(bal)
                end
            end
        end
    end
end

local function buildUI()
    local Orion = loadOrion()
    if not Orion then
        warn("[SanDiegoAgent][UI] buildUI aborted: Orion not loaded")
        return
    end

    local hui = Compat.gethui()
    local existingGuis = {}
    for _, sg in ipairs(game.CoreGui:GetChildren()) do
        if sg:IsA("ScreenGui") then
            existingGuis[sg] = true
        end
    end
    for _, sg in ipairs(hui:GetChildren()) do
        if sg:IsA("ScreenGui") then
            existingGuis[sg] = true
        end
    end

    local window = Orion:CreateOrion("San Diego Agent")
    task.wait(0.1)
    currentMainGui = findOrionGui(existingGuis)

    if currentMainGui then
        local ok, err = pcall(function()
            ToggleUI.new(currentMainGui, {
                parent = getUiParent(),
                initialVisible = false,
            })
        end)
        if not ok then
            warn("[SanDiegoAgent][UI] ToggleUI failed:", tostring(err))
        end
    else
        warn("[SanDiegoAgent][UI] Orion ScreenGui not found, toggle will not be created")
    end

    local tabMain = window:CreateSection("Главное")

    local pos = getPosition()
    local bal = stateReader:getBalance()

    tabMain:TextLabel(string.format("X: %.2f", pos.X))
    tabMain:TextButton("Copy X", "Copy X coordinate", function()
        copyToClipboard(string.format("%.2f", getCoord("X")))
    end)

    tabMain:TextLabel(string.format("Y: %.2f", pos.Y))
    tabMain:TextButton("Copy Y", "Copy Y coordinate", function()
        copyToClipboard(string.format("%.2f", getCoord("Y")))
    end)

    tabMain:TextLabel(string.format("Z: %.2f", pos.Z))
    tabMain:TextButton("Copy Z", "Copy Z coordinate", function()
        copyToClipboard(string.format("%.2f", getCoord("Z")))
    end)

    tabMain:TextLabel("Balance: " .. tostring(bal))

    -- Автозапуск агента
    startAgent()

    -- Автозакрытие стартовых попапов (StarterPack и др.)
    popupCloser:start()

    -- Обновление координат и баланса в UI
    task.spawn(function()
        while true do
            updateInfoLabels()
            task.wait(0.5)
        end
    end)
end

local function hideTeleportErrorPrompt()
	local ok, coreGui = pcall(function()
		return game:GetService("CoreGui")
	end)
	if not ok then
		return
	end
	local promptGui = coreGui:FindFirstChild("RobloxPromptGui")
	if not promptGui then
		return
	end
	local overlay = promptGui:FindFirstChild("promptOverlay")
	if not overlay then
		return
	end
	local prompt = overlay:FindFirstChild("ErrorPrompt")
	if prompt and typeof(prompt) == "Instance" then
		prompt.Visible = false
	end
end

local function runCore()
	if coreStarted then
		return
	end
	coreStarted = true

	if CONFIG.showUI then
		buildUI()
	else
		startAgent()
		popupCloser:start()
		installAutoexec()
	end

	-- Фоновый поток для обработки флага остановки
	task.spawn(function()
		while not getgenv().StopSanDiegoAgent do
			task.wait(1)
		end
		stopAgent()
		print("[SanDiegoAgent] stopped")
	end)
end

local UIPanel = {}

function UIPanel.run()
	getgenv().StopSanDiegoAgent = false

	if not ensureCorrectServer() then
		print("[SanDiegoAgent][ServerGuard] waiting for teleport to previous server, agent not started")

		local TeleportService = game:GetService("TeleportService")
		local conn
		conn = TeleportService.TeleportInitFailed:Connect(function(player, result, msg)
			if player == Players.LocalPlayer then
				warn("[SanDiegoAgent][ServerGuard] teleport failed:", tostring(result), tostring(msg))
				serverState:clear()
				hideTeleportErrorPrompt()
				runCore()
				if conn then
					conn:Disconnect()
				end
			end
		end)

		task.delay(10, function()
			if conn then
				conn:Disconnect()
			end
			if not coreStarted then
				warn("[SanDiegoAgent][ServerGuard] teleport timeout, starting agent on current server")
				serverState:clear()
				hideTeleportErrorPrompt()
				runCore()
			end
		end)

		return
	end

	runCore()
end

return UIPanel
