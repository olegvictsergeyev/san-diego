--[[
    San Diego Agent
    ===============
    Тонкий загрузчик для UI-модуля агента.
    Конфигурация теперь находится в modules/ui_panel.lua.

    Для остановки выполните в консоли executor'а:
        getgenv().StopSanDiegoAgent = true
]]

local currentJobId = tostring(game.JobId or "")
print("[SanDiegoAgent] loader started, JobId:", currentJobId)

if getgenv().SanDiegoAgentRunning and getgenv().SanDiegoAgentRunningJobId == currentJobId then
    print("[SanDiegoAgent] skipping start: already running on this server")
    return
end

getgenv().SanDiegoAgentRunning = true
getgenv().SanDiegoAgentRunningJobId = currentJobId
print("[SanDiegoAgent] guard passed, starting agent")

local BASE_URL = getgenv().SanDiegoAgentBaseUrl or "https://raw.githubusercontent.com/olegvictsergeyev/san-diego/main"
local UI_PANEL_URL = BASE_URL .. "/modules/ui_panel.lua?nocache=" .. tostring(tick())

local function loadUiPanel()
    if script and typeof(script) == "Instance" and script.Parent then
        return require(script.Parent:WaitForChild("modules"):WaitForChild("ui_panel"))
    else
        local source = game:HttpGet(UI_PANEL_URL)
        local fn, err = loadstring(source, "ui_panel")
        if not fn then
            error("failed to load ui_panel: " .. tostring(err))
        end
        return fn()
    end
end

local ok, result = pcall(function()
    local UIPanel = loadUiPanel()
    UIPanel.run()
end)

if not ok then
    warn("[SanDiegoAgent] failed to start: " .. tostring(result))
    getgenv().SanDiegoAgentRunning = nil
    getgenv().SanDiegoAgentRunningJobId = nil
end
