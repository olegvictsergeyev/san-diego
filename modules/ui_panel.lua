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
    version = "0.2.1",

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
        private_server = "https://raw.githubusercontent.com/olegvictsergeyev/san-diego/main/modules/private_server.lua",
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
local CommandEngine = loadModule("command_engine")
local Agent = loadModule("agent")

local currentAgent = nil
local stateReader = StateCollector.new(CONFIG.balancePath, CONFIG.version)

local function makeAgent()
    local http = HttpClient.new(CONFIG.baseUrl)
    local state = StateCollector.new(CONFIG.balancePath, CONFIG.version)
    local privateServer = PrivateServer.new()
    local engine = CommandEngine.new(privateServer)
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

local function copyToClipboard(text)
    local ok = pcall(function()
        setclipboard(tostring(text))
    end)
    if ok then
        print("[SanDiegoAgent][UI] Скопировано:", text)
    else
        print("[SanDiegoAgent][UI] Clipboard недоступен. Значение:", text)
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

local function findMainPage(gui)
    for _, desc in ipairs(gui:GetDescendants()) do
        if desc.Name == "newPageГлавное" then
            return desc
        end
    end
    return nil
end

local function updateInfoLabels()
    local gui = game.CoreGui:FindFirstChild("San Diego Agent")
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
        return
    end

    local window = Orion:CreateOrion("San Diego Agent")
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

    -- Обновление координат и баланса в UI
    task.spawn(function()
        while true do
            updateInfoLabels()
            task.wait(0.5)
        end
    end)

    print("[SanDiegoAgent][UI] Panel built and agent started")
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
