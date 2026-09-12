--[[
    San Diego Agent — UI Panel
    ==========================
    Содержит CONFIG и логику запуска/остановки агента.
    Вместо полноценного UI (Orion) показывает только компактный
    бейдж с номером версии в левом нижнем углу.
    Запускается из final/agent.lua.
]]

local CONFIG = {
    -- Версия агента (major.minor.patch). Сейчас ранняя альфа.
	version = "2.12.33",

    -- URL существующего сервиса
    baseUrl = "http://195.161.68.193:5173/api",

    -- Идентификатор игры
    gameSlug = "san-diego",

    -- Как часто отправлять статус (секунды)
    statusInterval = 7,

    -- Long-poll таймаут при получении команд (секунды).
    -- Потолок ~50с: nginx перед бэкендом рвёт соединения на 60с (504).
    commandPollTimeout = 45,

    -- Пауза перед повторным запросом при ошибке (секунды)
    commandRetryDelay = 3,

    -- Путь к балансу в иерархии LocalPlayer
    balancePath = "leaderstats.Cash",

    -- Дополнительные кастомные поля
    customData = {},

    -- URL модулей
    moduleUrls = (function()
        local base
        if typeof(getgenv) == "function" then
            local ok, genv = pcall(getgenv)
            if ok and genv and typeof(genv.SanDiegoAgentBaseUrl) == "string" then
                base = genv.SanDiegoAgentBaseUrl
            end
        end
        if not base and typeof(_G) == "table" and typeof(_G.SanDiegoAgentBaseUrl) == "string" then
            base = _G.SanDiegoAgentBaseUrl
        end
        if not base and typeof(shared) == "table" and typeof(shared.SanDiegoAgentBaseUrl) == "string" then
            base = shared.SanDiegoAgentBaseUrl
        end
        base = base or "https://raw.githubusercontent.com/olegvictsergeyev/san-diego/main"
        return {
            http_client = base .. "/modules/http_client.lua",
            state_collector = base .. "/modules/state_collector.lua",
            command_engine = base .. "/modules/command_engine.lua",
            result_store = base .. "/modules/result_store.lua",
            agent = base .. "/modules/agent.lua",
            private_server = base .. "/modules/private_server.lua",
            popup_closer = base .. "/modules/popup_closer.lua",
            compat = base .. "/modules/compat.lua",
            disconnect_watcher = base .. "/modules/disconnect_watcher.lua",
            autoexec = base .. "/modules/autoexec.lua",
            afk = base .. "/modules/afk.lua",
            anticheat_guard = base .. "/modules/anticheat_guard.lua",
            printers = base .. "/modules/printers.lua",
            vehicles = base .. "/modules/vehicles.lua",
            apartments = base .. "/modules/apartments.lua",
        }
    end)(),

    -- URL загрузчика для перезапуска после телепорта
    agentLoaderUrl = (function()
        local base
        if typeof(getgenv) == "function" then
            local ok, genv = pcall(getgenv)
            if ok and genv and typeof(genv.SanDiegoAgentBaseUrl) == "string" then
                base = genv.SanDiegoAgentBaseUrl
            end
        end
        if not base and typeof(_G) == "table" and typeof(_G.SanDiegoAgentBaseUrl) == "string" then
            base = _G.SanDiegoAgentBaseUrl
        end
        if not base and typeof(shared) == "table" and typeof(shared.SanDiegoAgentBaseUrl) == "string" then
            base = shared.SanDiegoAgentBaseUrl
        end
        return (base or "https://raw.githubusercontent.com/olegvictsergeyev/san-diego/main") .. "/final/agent.lua"
    end)(),

    -- true при запуске через loadstring (script == nil), иначе false
    useRemoteModules = (script == nil),

    -- AFK-режим: периодическое незаметное действие, чтобы не выкидывало из игры
    afkEnabled = true,
    afkInterval = 300,
}

local function loadModule(name)
    warn("[SanDiegoAgent][UI] loadModule(" .. tostring(name) .. ")")
    if CONFIG.useRemoteModules or not script or typeof(script) ~= "Instance" or not script.Parent then
        local url = CONFIG.moduleUrls[name]
        if not url then
            error("module URL not configured: " .. tostring(name))
        end
        url = url .. "?nocache=" .. tostring(tick())
        warn("[SanDiegoAgent][UI] fetching " .. tostring(name) .. " from " .. url)
        local ok, source = pcall(function() return game:HttpGet(url) end)
        if not ok then
            error("HttpGet failed for " .. name .. ": " .. tostring(source))
        end
        if typeof(source) ~= "string" or #source == 0 then
            error("empty source for " .. name)
        end
        warn("[SanDiegoAgent][UI] " .. name .. " source length " .. tostring(#source))
        local fn, err = loadstring(source, name)
        if not fn then
            error("loadstring failed for " .. name .. ": " .. tostring(err))
        end
        warn("[SanDiegoAgent][UI] executing " .. name)
        return fn()
    else
        warn("[SanDiegoAgent][UI] local require " .. name)
        return require(script.Parent:WaitForChild(name))
    end
end

local HttpClient = loadModule("http_client")
local StateCollector = loadModule("state_collector")
local PrivateServer = loadModule("private_server")
local PopupCloser = loadModule("popup_closer")
local Compat = loadModule("compat")
local DisconnectWatcher = loadModule("disconnect_watcher")
local Autoexec = loadModule("autoexec")
local CommandEngine = loadModule("command_engine")
local ResultStore = loadModule("result_store")
local Agent = loadModule("agent")
local Afk = loadModule("afk")
local AnticheatGuard = loadModule("anticheat_guard")
local Printers = loadModule("printers")
local Vehicles = loadModule("vehicles")
local Apartments = loadModule("apartments")

local privateServer = PrivateServer.new({
    loaderUrl = CONFIG.agentLoaderUrl,
    compat = Compat,
})

local currentAgent = nil
local autoexec = Autoexec.new()
local popupCloser = PopupCloser.new(Compat)

local coreStarted = false
local runCore

local function ensureCorrectServer()
	-- Агент больше не переподключается самостоятельно.
	-- Переходы между серверами управляются бэкендом через команды.
	return true
end

local function makeAgent()
    local http = HttpClient.new(CONFIG.baseUrl)
    local state = StateCollector.new(CONFIG.balancePath, CONFIG.version)
    local afk = Afk.new(CONFIG)
    local printers = Printers.new()
    local vehicles = Vehicles.new()
    local apartments = Apartments.new()
    local anticheatGuard = AnticheatGuard.new()
    anticheatGuard:start()
    local engine = CommandEngine.new(privateServer, afk, state, printers, vehicles, apartments, anticheatGuard)
    privateServer:setCommandEngine(engine)
    local resultStore = ResultStore.new(Compat, state:getNickname())
    privateServer:setResultStore(resultStore)
    return Agent.new(CONFIG, http, state, engine, afk, resultStore)
end

local function startWatcher()
    if not currentAgent then
        return
    end
    local watcher = DisconnectWatcher.new(currentAgent, Compat, {
        loaderUrl = CONFIG.agentLoaderUrl,
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
    warn("[SanDiegoAgent][UI] startAgent() called")
    if currentAgent then
        warn("[SanDiegoAgent][UI] stopping existing agent")
        currentAgent:stop()
        currentAgent = nil
        getgenv().SanDiegoAgentRunning = nil
        getgenv().SanDiegoAgentStartingJobId = nil
    end
    currentAgent = makeAgent()
    warn("[SanDiegoAgent][UI] agent instance created")
    currentAgent:start()
    warn("[SanDiegoAgent][UI] agent started")
    startWatcher()
    installAutoexec()
    warn("[SanDiegoAgent][UI] startAgent() finished")
end

local function stopAgent()
    if currentAgent then
        local eng = rawget(currentAgent, "engine")
        currentAgent:stop()
        currentAgent = nil
        if eng and eng.releaseCamera then
            pcall(function()
                eng:releaseCamera()
            end)
        end
    end
    getgenv().SanDiegoAgentRunning = nil
    getgenv().SanDiegoAgentRunningJobId = nil
    -- Слот «старт занят» тоже освобождаем: иначе после ручного рестарта
    -- (стоп/старт) лоадер будет вечно видеть просроченный StartingJobId и
    -- отказываться запускать агент.
    getgenv().SanDiegoAgentStartingJobId = nil
    getgenv().StopSanDiegoAgent = false
    pcall(function()
        for _, root in ipairs({ game.CoreGui, Compat.gethui() }) do
            if typeof(root) == "Instance" then
                local marker = root:FindFirstChild("SanDiegoAgentRunningMarker")
                if marker then
                    marker:Destroy()
                end
            end
        end
    end)
end

local function getUiParent()
    local hui = Compat.gethui()
    if typeof(hui) == "Instance" and hui:IsA("CoreGui") then
        return hui
    end
    return game.CoreGui
end

local function cleanupExistingUi()
    local hui = Compat.gethui()
    for _, root in ipairs({ game.CoreGui, hui }) do
        for _, sg in ipairs(root:GetChildren()) do
            if sg:IsA("ScreenGui") then
                local name = sg.Name
                if name == "San Diego Agent" or name:find("SanDiegoAgent") then
                    pcall(function()
                        sg:Destroy()
                    end)
                end
            end
        end
    end
end

-- Компактный бейдж с версией в левом нижнем углу (вместо Orion-панели).
local function buildVersionBadge()
    warn("[SanDiegoAgent][UI] buildVersionBadge() start")
    cleanupExistingUi()

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "SanDiegoAgentVersion"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = getUiParent()

    local frame = Instance.new("Frame")
    frame.Name = "VersionBadge"
    frame.Size = UDim2.new(0, 110, 0, 44)
    frame.Position = UDim2.new(0, 12, 1, -56)
    frame.AnchorPoint = Vector2.new(0, 1)
    frame.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 0
    frame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Transparency = 0.6
    stroke.Thickness = 1
    stroke.Parent = frame

    local label = Instance.new("TextLabel")
    label.Name = "Version"
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "v" .. tostring(CONFIG.version)
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 16
    label.Font = Enum.Font.GothamBold
    label.Parent = frame

    warn("[SanDiegoAgent][UI] version badge built: " .. label.Text)
end

local function runCore()
	warn("[SanDiegoAgent][UI] runCore() called, coreStarted=" .. tostring(coreStarted))
	if coreStarted then
		warn("[SanDiegoAgent][UI] runCore() already started, returning")
		return
	end
	coreStarted = true

	warn("[SanDiegoAgent][UI] building version badge and starting agent")
	buildVersionBadge()
	startAgent()
	popupCloser:start()
	installAutoexec()

	-- Фоновый поток для обработки флага остановки
	warn("[SanDiegoAgent][UI] starting stop-flag watcher")
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
	warn("[SanDiegoAgent] UIPanel.run() called")
	getgenv().StopSanDiegoAgent = false

	ensureCorrectServer()
	runCore()
end

return UIPanel
