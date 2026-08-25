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
    version = "0.4.10",

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
        popup_closer = "https://raw.githubusercontent.com/olegvictsergeyev/san-diego/main/modules/popup_closer.lua",
        compat = "https://raw.githubusercontent.com/olegvictsergeyev/san-diego/main/modules/compat.lua",
        disconnect_watcher = "https://raw.githubusercontent.com/olegvictsergeyev/san-diego/main/modules/disconnect_watcher.lua",
        ui_toggle = "https://raw.githubusercontent.com/olegvictsergeyev/san-diego/main/modules/ui_toggle.lua",
    },

    -- URL загрузчика для перезапуска после телепорта
    agentLoaderUrl = "https://raw.githubusercontent.com/olegvictsergeyev/san-diego/main/final/agent.lua",

    -- true при запуске через loadstring (script == nil), иначе false
    useRemoteModules = (script == nil),

    -- true — показать панель Orion; false — запустить агента сразу
    showUI = true,

    -- true — автоматически нажимать Reconnect при ошибке 277
    autoReconnectOnDisconnect = true,
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
local CommandEngine = loadModule("command_engine")
local Agent = loadModule("agent")

print("[SanDiegoAgent][UI] modules loaded, version", CONFIG.version)

local currentAgent = nil
local currentMainGui = nil
local stateReader = StateCollector.new(CONFIG.balancePath, CONFIG.version)
local popupCloser = PopupCloser.new(Compat)

local function makeAgent()
    local http = HttpClient.new(CONFIG.baseUrl)
    local state = StateCollector.new(CONFIG.balancePath, CONFIG.version)
    local privateServer = PrivateServer.new({
        loaderUrl = CONFIG.agentLoaderUrl,
        compat = Compat,
    })
    local engine = CommandEngine.new(privateServer)
    return Agent.new(CONFIG, http, state, engine)
end

local function startWatcher()
    if not currentAgent then
        return
    end
    local watcher = DisconnectWatcher.new(currentAgent, Compat, {
        autoReconnect = CONFIG.autoReconnectOnDisconnect,
    })
    watcher:start()
end

local function startAgent()
    if currentAgent then
        currentAgent:stop()
        task.wait(0.2)
    end
    currentAgent = makeAgent()
    currentAgent:start()
    startWatcher()
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
    print("[SanDiegoAgent][UI] buildUI started")
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
        print("[SanDiegoAgent][UI] Orion ScreenGui found:", currentMainGui.Name)
        ToggleUI.new(currentMainGui, {
            parent = getUiParent(),
            initialVisible = false,
        })
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

    print("[SanDiegoAgent][UI] Panel built and agent started")
end

local UIPanel = {}

function UIPanel.run()
    print("[SanDiegoAgent][UI] UIPanel.run started")
    getgenv().StopSanDiegoAgent = false

    if CONFIG.showUI then
        buildUI()
    else
        startAgent()
        popupCloser:start()
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
