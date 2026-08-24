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
    },

    -- Если true, модули загружаются из moduleUrls.
    -- Если false, используется локальный require (для теста в Roblox Studio / local script).
    -- По умолчанию: true при запуске через loadstring (script == nil), иначе false.
    useRemoteModules = (script == nil),
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

getgenv().StopSanDiegoAgent = false

local http = HttpClient.new(CONFIG.baseUrl)
local state = StateCollector.new(CONFIG.balancePath)
local engine = CommandEngine.new()
local agent = Agent.new(CONFIG, http, state, engine)

agent:start()

-- Фоновый поток для обработки флага остановки
while not getgenv().StopSanDiegoAgent do
    task.wait(1)
end

agent:stop()
print("[SanDiegoAgent] stopped")
