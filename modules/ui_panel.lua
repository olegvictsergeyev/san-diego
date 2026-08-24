--[[
    San Diego Agent — UI Panel
    ==========================
    Модуль управления агентом через Orion UI.
    Содержит CONFIG и логику запуска/остановки.
    Запускается из final/agent.lua.
]]

local CONFIG = {
    -- URL существующего сервиса
    baseUrl = "http://195.161.68.193:5173/api",

    -- Идентификатор игры
    gameSlug = "san-diego",

    -- Как часто отправлять статус (секунды)
    statusInterval = 7,

    -- Long-poll таймаут при получении команд (секунды)
    commandPollTimeout = 55,

    -- Пауза перед повторным запросом при ошибке (секунды)
    commandRetryDelay = 2,

    -- Путь к балансу в иерархии LocalPlayer
    balancePath = "leaderstats.Cash",

    -- Дополнительные кастомные поля
    customData = {},

    -- URL модулей
    moduleUrls = {
        http_client = "https://raw.githubusercontent.com/olegvictsergeyev/san-diego/main/modules/http_client.lua",
        state_collector = "https://raw.githubusercontent.com/olegvictsergeyev/san-diego/main/modules/state_collector.lua",
        command_engine = "https://raw.githubusercontent.com/olegvictsergeyev/san-diego/main/modules/command_engine.lua",
        agent = "https://raw.githubusercontent.com/olegvictsergeyev/san-diego/main/modules/agent.lua",
    },

    -- true при запуске через loadstring (script == nil), иначе false
    useRemoteModules = (script == nil),

    -- true — показать панель Orion; false — запустить агента сразу
    showUI = true,
}

local function loadModule(name)
    if CONFIG.useRemoteModules then
        local url = CONFIG.moduleUrls[name]
        if not url then
            error("module URL not configured: " .. tostring(name))
        end
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
local CommandEngine = loadModule("command_engine")
local Agent = loadModule("agent")

local currentAgent = nil

local function makeAgent()
    local http = HttpClient.new(CONFIG.baseUrl)
    local state = StateCollector.new(CONFIG.balancePath)
    local engine = CommandEngine.new()
    return Agent.new(CONFIG, http, state, engine)
end

local function startAgent()
    if currentAgent then
        currentAgent:stop()
        task.wait(0.2)
    end
    currentAgent = makeAgent()
    currentAgent:start()
end

local function stopAgent()
    if currentAgent then
        currentAgent:stop()
        currentAgent = nil
    end
end

local function sendStatusNow()
    if currentAgent and currentAgent._sendStatus then
        currentAgent:_sendStatus()
    end
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

local function buildUI()
    local Orion = loadOrion()
    if not Orion then
        return
    end

    local window = Orion:CreateOrion("San Diego Agent")

    local tabMain = window:CreateSection("Main")

    tabMain:TextLabel("baseUrl: " .. tostring(CONFIG.baseUrl))
    tabMain:TextLabel("gameSlug: " .. tostring(CONFIG.gameSlug))
    tabMain:TextLabel("balancePath: " .. tostring(CONFIG.balancePath))
    tabMain:TextLabel("statusInterval: " .. tostring(CONFIG.statusInterval))

    tabMain:TextButton("Start Agent", "Launch the agent", function()
        startAgent()
    end)

    tabMain:TextButton("Stop Agent", "Stop the agent", function()
        stopAgent()
    end)

    tabMain:TextButton("Send Status Now", "Send status manually", function()
        sendStatusNow()
    end)

    print("[SanDiegoAgent][UI] Panel built")
end

local UIPanel = {}

function UIPanel.run()
    getgenv().StopSanDiegoAgent = false

    if CONFIG.showUI then
        buildUI()
    else
        startAgent()
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

return UIPanel
