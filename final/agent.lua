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

local BASE_URL = getgenv().SanDiegoAgentBaseUrl or "https://raw.githubusercontent.com/olegvictsergeyev/san-diego/main"

-- Переживаем телепорт: при смене JobId (т.е. ТОЛЬКО при реальном
-- телепорте, а не при каждом запуске лоадера) ставим в очередь перезапуск
-- этого же загрузчика на новом сервере. Очередной код дожидается полной
-- загрузки игры, повторяет попытки с бэкофом (2/4/8… с, потолок 300 с,
-- до 12 попыток) и проверяет, что агент реально стартовал
-- (getgenv().SanDiegoAgentLastStartJobId). Без фильтра JobId каждый запуск
-- лоадера ставил бы ещё одну копию в очередь, и при телепорте исполнились
-- бы все разом (буря рестартов). Сценарий «уже на новом сервере, агент ещё
-- не стартовал» покрывает autoexec/ручной запуск.
do
	-- ПЕРЕЖИВАЕМ ТЕЛЕПОРТ: ставим в очередь перезапуск ТОЛЬКО при смене
	-- JobId. Сценарий «уже на новом сервере, агент ещё не стартовал»
	-- покрывает autoexec/ручной запуск — без повторных перезапусков.
	-- Без фильтра каждый вызов лоадера ставил бы ещё одну копию в
	-- очередь: они складываются и при первом же телепорте исполняются
	-- все разом (буря из сотен рестартов, рассинхрон консоли).
	local reloadCode = table.concat({
		'getgenv().SanDiegoAgentBaseUrl = "' .. BASE_URL .. '"',
		"task.spawn(function()",
		"	local jobId = tostring(game.JobId or \"\")",
		"	if getgenv().SanDiegoAgentLastStartJobId == jobId then return end",
		"	local function reloadAttempt(n)",
		"		if getgenv().SanDiegoAgentLastStartJobId == jobId then return true end",
		"		local ok, err = pcall(function()",
		"			loadstring(game:HttpGet(\"" .. BASE_URL .. "/final/agent.lua?nocache=\" .. tostring(tick())))()",
		"		end)",
		"		local started = getgenv().SanDiegoAgentLastStartJobId == jobId",
		"		print(\"[SanDiegoAgent][QueueOnTeleport] reload attempt \" .. n .. \" ok=\" .. tostring(ok) .. \" err=\" .. tostring(err) .. \" started=\" .. tostring(started))",
		"		return ok and started",
		"	end",
		-- Ранняя стадия после телепорта ненадёжна (чёрный экран, игра ещё
		-- грузится): ждём полной загрузки, иначе HttpGet может упасть.
		"	pcall(function() if not game:IsLoaded() then game.Loaded:Wait() end end)",
		"	task.wait(1)",
		"	for i = 1, 12 do",
		"		if reloadAttempt(i) then return end",
		"		local backoff = math.min(2 ^ i, 300)",
		"		print(\"[SanDiegoAgent][QueueOnTeleport] waiting \" .. backoff .. \"s before retry\")",
		"		task.wait(backoff)",
		"	end",
		"	warn(\"[SanDiegoAgent][QueueOnTeleport] all reload attempts failed; agent NOT running after teleport\")",
		"end)",
	}, "\n")
	local q = queue_on_teleport
	if typeof(q) == "function" then
		local ok = pcall(q, reloadCode)
		print("[SanDiegoAgent] queue_on_teleport armed:", tostring(ok))
	else
		warn("[SanDiegoAgent] queue_on_teleport unavailable; relying on autoexec")
	end
end

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
    return
end

-- Сигнал для queue_on_teleport: агент реально стартовал на этом сервере.
getgenv().SanDiegoAgentLastStartJobId = currentJobId
