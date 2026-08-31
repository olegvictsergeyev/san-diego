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

-- Verbose logging helper
local function log(level, ...)
    local msg = table.concat({"[SanDiegoAgent]", "[" .. level .. "]", ...}, " ")
    print(msg)
    if level == "WARN" or level == "ERROR" then
        warn(msg)
    end
end

log("INFO", "step 1/5: checking for existing marker")

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

if existingMarker then
    log("WARN", "skipping start: running marker found")
    return
end

log("INFO", "step 2/5: setting guard flags")
getgenv().SanDiegoAgentRunning = true
getgenv().SanDiegoAgentRunningJobId = currentJobId

log("INFO", "step 3/5: creating CoreGui marker")
local markerOk, markerErr = pcall(function()
    local marker = Instance.new("BoolValue")
    marker.Name = "SanDiegoAgentRunningMarker"
    marker.Value = true
    local hui = nil
    if typeof(gethui) == "function" then
        local ok, h = pcall(gethui)
        if ok and typeof(h) == "Instance" then
            hui = h
        end
    end
    marker.Parent = hui or game:GetService("CoreGui")
    return marker
end)

if not markerOk then
    log("ERROR", "failed to create marker:", tostring(markerErr))
    getgenv().SanDiegoAgentRunning = nil
    getgenv().SanDiegoAgentRunningJobId = nil
    return
end

local marker = markerErr
log("INFO", "step 4/5: loading ui_panel from", UI_PANEL_URL)

local function loadUiPanel()
    if script and typeof(script) == "Instance" and script.Parent then
        log("INFO", "local mode: requiring ui_panel from script.Parent")
        return require(script.Parent:WaitForChild("modules"):WaitForChild("ui_panel"))
    else
        log("INFO", "remote mode: fetching ui_panel")
        local ok, source = pcall(function()
            return game:HttpGet(UI_PANEL_URL)
        end)
        if not ok then
            error("HttpGet failed: " .. tostring(source))
        end
        if typeof(source) ~= "string" or #source == 0 then
            error("HttpGet returned empty source")
        end
        log("INFO", "ui_panel source length:", tostring(#source))
        local fn, err = loadstring(source, "ui_panel")
        if not fn then
            error("loadstring failed: " .. tostring(err))
        end
        log("INFO", "ui_panel loaded, executing")
        return fn()
    end
end

log("INFO", "step 5/5: running ui_panel")
local ok, result = pcall(function()
    local UIPanel = loadUiPanel()
    log("INFO", "ui_panel returned, calling UIPanel.run()")
    UIPanel.run()
    log("INFO", "UIPanel.run() completed")
end)

if not ok then
    log("ERROR", "failed to start:", tostring(result))
    getgenv().SanDiegoAgentRunning = nil
    getgenv().SanDiegoAgentRunningJobId = nil
    if marker then
        pcall(function() marker:Destroy() end)
    end
    return
end

log("INFO", "loader finished successfully")
