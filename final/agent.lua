--[[
    San Diego Agent
    ===============
    Конфигурация расположена в секции ниже.
    Скрипт загружает переиспользуемые модули по raw-URL (GitHub) и запускает агента.
    Для остановки выполните в консоли executor'а:
        getgenv().StopSanDiegoAgent = true
]]

-- ======================== КОНФИГУРАЦИЯ ========================
local CONFIG = {
    -- URL существующего сервиса
    baseUrl = "http://195.161.68.193:5173/api",

    -- Идентификатор игры
    gameSlug = "san-diego",

    -- Как часто отправлять статус (секунды, рекомендуется 5-10)
    statusInterval = 7,

    -- Long-poll таймаут при получении команд (секунды)
    commandPollTimeout = 55,

    -- Пауза перед повторным запросом при ошибке (секунды)
    commandRetryDelay = 2,

    -- Путь к балансу в иерархии LocalPlayer, например "leaderstats.Cash"
    balancePath = "leaderstats.Cash",

    -- Дополнительные кастомные поля, если нужны
    customData = {},

    -- URL модулей на raw.githubusercontent.com.
    -- Замените на свои после публикации в git.
    moduleUrls = {
        http_client = "https://raw.githubusercontent.com/olegvictsergeyev/san-diego/main/modules/http_client.lua",
        state_collector = "https://raw.githubusercontent.com/olegvictsergeyev/san-diego/main/modules/state_collector.lua",
        command_engine = "https://raw.githubusercontent.com/olegvictsergeyev/san-diego/main/modules/command_engine.lua",
        agent = "https://raw.githubusercontent.com/olegvictsergeyev/san-diego/main/modules/agent.lua",
        ui_panel = "https://raw.githubusercontent.com/olegvictsergeyev/san-diego/main/modules/ui_panel.lua",
    },

    -- Если true, модули загружаются из moduleUrls.
    -- Если false, используется локальный require (для теста в Roblox Studio / local script).
    -- По умолчанию: true при запуске через loadstring (script == nil), иначе false.
    useRemoteModules = (script == nil),

    -- Если true, отображается панель управления (Orion UI).
    -- Если false, агент запускается сразу без UI.
    showUI = true,
}
-- ==============================================================

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
        return require(script.Parent:WaitForChild("modules"):WaitForChild(name))
    end
end

local HttpClient = loadModule("http_client")
local StateCollector = loadModule("state_collector")
local CommandEngine = loadModule("command_engine")
local Agent = loadModule("agent")

local HttpClient = loadModule("http_client")
local StateCollector = loadModule("state_collector")
local CommandEngine = loadModule("command_engine")
local Agent = loadModule("agent")

getgenv().StopSanDiegoAgent = false

local currentAgent = nil

local function makeAgent(cfg)
    local http = HttpClient.new(cfg.baseUrl)
    local state = StateCollector.new(cfg.balancePath)
    local engine = CommandEngine.new()
    local agent = Agent.new(cfg, http, state, engine)
    return agent
end

local function startAgent(cfg)
    if currentAgent then
        currentAgent:stop()
        task.wait(0.2)
    end
    currentAgent = makeAgent(cfg)
    currentAgent:start()
end

local function stopAgent()
    if currentAgent then
        currentAgent:stop()
        currentAgent = nil
    end
end

if CONFIG.showUI then
    local UIPanel = loadModule("ui_panel")
    local panel = UIPanel.new(CONFIG, {
        start = function(cfg)
            startAgent(cfg)
        end,
        stop = function()
            stopAgent()
        end,
        sendStatus = function()
            if currentAgent and currentAgent._sendStatus then
                currentAgent:_sendStatus()
            end
        end,
        getCommandSpec = function()
            local engine = CommandEngine.new()
            return engine:getCommandsSpec()
        end,
    })
    panel:build()
else
    startAgent(CONFIG)
end

-- Фоновый поток для обработки флага остановки
while not getgenv().StopSanDiegoAgent do
    task.wait(1)
end

stopAgent()
print("[SanDiegoAgent] stopped")
