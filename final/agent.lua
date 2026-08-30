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

local MARKER_FILE = "san-diego-agent-running.json"
local MARKER_TTL = 30

local function readMarker()
    if typeof(readfile) ~= "function" then
        return nil
    end
    local ok, content = pcall(readfile, MARKER_FILE)
    if not ok or not content or content == "" then
        return nil
    end
    local hs = game:GetService("HttpService")
    local parseOk, data = pcall(function()
        return hs:JSONDecode(content)
    end)
    if parseOk and typeof(data) == "table" then
        return data
    end
    return nil
end

local function writeMarker(data)
    if typeof(writefile) ~= "function" then
        return false
    end
    local hs = game:GetService("HttpService")
    local ok, content = pcall(function()
        return hs:JSONEncode(data)
    end)
    if not ok then
        return false
    end
    return pcall(writefile, MARKER_FILE, content)
end

local function isAlreadyRunning()
    if getgenv().SanDiegoAgentRunning and getgenv().SanDiegoAgentRunningJobId == currentJobId then
        print("[SanDiegoAgent] skipping start: getgenv flag matches JobId", currentJobId)
        return true
    end
    local marker = readMarker()
    if marker and marker.running and marker.timestamp then
        local age = tick() - marker.timestamp
        if marker.jobId == currentJobId and currentJobId ~= "" and age < MARKER_TTL then
            print("[SanDiegoAgent] skipping start: marker matches JobId", currentJobId, "age", age)
            return true
        end
        if currentJobId == "" and age < 3 then
            print("[SanDiegoAgent] skipping start: empty JobId, marker age", age)
            return true
        end
    end
    return false
end

local function setRunning()
    getgenv().SanDiegoAgentRunning = true
    getgenv().SanDiegoAgentRunningJobId = currentJobId
    writeMarker({ running = true, jobId = currentJobId, timestamp = tick() })
end

local function clearRunning()
    getgenv().SanDiegoAgentRunning = nil
    getgenv().SanDiegoAgentRunningJobId = nil
    if typeof(delfile) == "function" then
        pcall(delfile, MARKER_FILE)
    end
end

if isAlreadyRunning() then
    warn("[SanDiegoAgent] already running or queued, skipping duplicate start")
    return
end

print("[SanDiegoAgent] guard passed, starting agent")

setRunning()

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
    clearRunning()
end
