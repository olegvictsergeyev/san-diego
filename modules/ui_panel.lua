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
    version = "1.17.11",

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
            ui_toggle = base .. "/modules/ui_toggle.lua",
            autoexec = base .. "/modules/autoexec.lua",
            afk = base .. "/modules/afk.lua",
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

    -- true — показать панель Orion; false — запустить агента сразу
    showUI = true,

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
local ToggleUI = loadModule("ui_toggle")
local Autoexec = loadModule("autoexec")
local CommandEngine = loadModule("command_engine")
local ResultStore = loadModule("result_store")
local Agent = loadModule("agent")
local Afk = loadModule("afk")

local privateServer = PrivateServer.new({
    loaderUrl = CONFIG.agentLoaderUrl,
    compat = Compat,
})

local currentAgent = nil
local currentMainGui = nil
local autoexec = Autoexec.new()
local stateReader = StateCollector.new(CONFIG.balancePath, CONFIG.version)
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
    local engine = CommandEngine.new(privateServer, afk, state)
    privateServer:setCommandEngine(engine)
    local resultStore = ResultStore.new(Compat, state:getNickname())
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
    warn("[SanDiegoAgent][UI] loading Orion")
    local ok, Orion = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/OrionLibrary/Orion/main/source.lua"))()
    end)
    if not ok then
        warn("[SanDiegoAgent][UI] Failed to load Orion:", tostring(Orion))
        return nil
    end
    warn("[SanDiegoAgent][UI] Orion loaded")
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

local function cleanupExistingUi()
    local hui = Compat.gethui()
    for _, root in ipairs({ game.CoreGui, hui }) do
        for _, sg in ipairs(root:GetChildren()) do
            if sg:IsA("ScreenGui") then
                local name = sg.Name
                if name == "San Diego Agent" or name:find("SanDiegoAgentToggle") then
                    pcall(function()
                        sg:Destroy()
                    end)
                end
            end
        end
    end
end

local function buildUI()
    warn("[SanDiegoAgent][UI] buildUI() start")
    local Orion = loadOrion()
    if not Orion then
        warn("[SanDiegoAgent][UI] buildUI aborted: Orion not loaded")
        return
    end

    warn("[SanDiegoAgent][UI] cleaning up existing UI")
    cleanupExistingUi()

    warn("[SanDiegoAgent][UI] collecting existing ScreenGuis")
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

    warn("[SanDiegoAgent][UI] creating Orion window")
    local window = Orion:CreateOrion("San Diego Agent")
    warn("[SanDiegoAgent][UI] Orion window created")

    task.wait(0.1)
    currentMainGui = findOrionGui(existingGuis)

    if currentMainGui then
        warn("[SanDiegoAgent][UI] main gui found:", currentMainGui:GetFullName())
        local ok, err = pcall(function()
            ToggleUI.new(currentMainGui, {
                parent = getUiParent(),
                initialVisible = true,
            })
        end)
        if not ok then
            warn("[SanDiegoAgent][UI] ToggleUI failed:", tostring(err))
        end
    else
        warn("[SanDiegoAgent][UI] Orion ScreenGui not found, toggle will not be created")
    end

    warn("[SanDiegoAgent][UI] creating main tab")
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
    warn("[SanDiegoAgent][UI] starting agent from buildUI")
    startAgent()

    -- Автозакрытие стартовых попапов (StarterPack и др.)
    warn("[SanDiegoAgent][UI] starting popup closer")
    popupCloser:start()

    -- Обновление координат и баланса в UI
    warn("[SanDiegoAgent][UI] starting UI update loop")
    task.spawn(function()
        while true do
            updateInfoLabels()
            task.wait(0.5)
        end
    end)
    warn("[SanDiegoAgent][UI] buildUI() finished")
end

local function runCore()
	warn("[SanDiegoAgent][UI] runCore() called, coreStarted=" .. tostring(coreStarted))
	if coreStarted then
		warn("[SanDiegoAgent][UI] runCore() already started, returning")
		return
	end
	coreStarted = true

	if CONFIG.showUI then
		warn("[SanDiegoAgent][UI] showUI=true, building UI")
		buildUI()
	else
		warn("[SanDiegoAgent][UI] showUI=false, starting agent directly")
		startAgent()
		popupCloser:start()
		installAutoexec()
	end

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
