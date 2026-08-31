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

-- Robust guard: prevent double start across different executor environments.
local function findRunningMarker()
    local function search(root)
        if typeof(root) ~= "Instance" then return nil end
        local marker = root:FindFirstChild("SanDiegoAgentRunningMarker")
        if marker and marker:IsA("BoolValue") and marker.Value then
            return marker
        end
        return nil
    end
    local marker = search(game:GetService("CoreGui"))
    if marker then return marker end
    local hui = (gethui and typeof(gethui) == "function") and gethui() or nil
    if typeof(hui) == "Instance" then
        return search(hui)
    end
    return nil
end

local existingMarker = findRunningMarker()

if getgenv().SanDiegoAgentRunning and getgenv().SanDiegoAgentRunningJobId == currentJobId and existingMarker then
    print("[SanDiegoAgent] skipping start: already running on this server")
    return
end

if existingMarker then
    print("[SanDiegoAgent] skipping start: running marker found")
    return
end

getgenv().SanDiegoAgentRunning = true
getgenv().SanDiegoAgentRunningJobId = currentJobId

local marker = Instance.new("BoolValue")
marker.Name = "SanDiegoAgentRunningMarker"
marker.Value = true
marker.Parent = (gethui and typeof(gethui) == "function" and typeof(gethui()) == "Instance") and gethui() or game:GetService("CoreGui")

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
    if marker then
        pcall(function() marker:Destroy() end)
    end
end
