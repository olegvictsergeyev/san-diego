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
-- бы все разом (буря рестартов). Постановка в очередь дедуплицируется
-- через SanDiegoAgentTeleportQueuedJobId (только первая копия в «окне»
-- загрузки агента), а первый стартующий лоадер помечается
-- SanDiegoAgentStartingJobId, чтобы остальные копии выходили сразу, не
-- грузя модули повторно. Первая исполнившаяся очередная копия «захватывает»
-- JobId через SanDiegoAgentTeleportHandledJobId — при бурсте работает ровно
-- одна. Сценарий «уже на новом сервере, агент ещё не стартовал» покрывает
-- autoexec/ручной запуск.
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
	-- Дедупликация бурста: если из очереди исполняется сразу несколько
	-- копий (например, скопившиеся до фикса), работает только первая.
	-- Между проверкой и записью нет приостановок, так что в Luau это
	-- атомарно: остальные копии завершаются сразу.
		"	if getgenv().SanDiegoAgentTeleportHandledJobId == jobId then return end",
		"	getgenv().SanDiegoAgentTeleportHandledJobId = jobId",
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
	-- Ставим в очередь только при реальной смене сервера: перезапуск
	-- лоадера на том же JobId не должен плодить копии в очереди.
	-- Дедуп через SanDiegoAgentTeleportQueuedJobId: при бурсте очередных
	-- копий в «окне» загрузки агента очередь пополняет только первая
	-- (проверка+запись без приостановок — атомарны в Luau).
	if typeof(q) == "function"
		and getgenv().SanDiegoAgentLastStartJobId ~= currentJobId
		and getgenv().SanDiegoAgentTeleportQueuedJobId ~= currentJobId then
		getgenv().SanDiegoAgentTeleportQueuedJobId = currentJobId
		local ok = pcall(q, reloadCode)
		print("[SanDiegoAgent] queue_on_teleport armed:", tostring(ok))
	elseif typeof(q) ~= "function" then
		warn("[SanDiegoAgent] queue_on_teleport unavailable; relying on autoexec")
	else
		print("[SanDiegoAgent] queue_on_teleport skipped: already on this server")
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

-- Первый лоадер на новом сервере уже занял слот старта и грузит модули:
-- пропускаем остальные копии, не дожидаясь Instance-метки. Проверяем ещё и
-- Running: после остановки агента слот StartingJobId мог остаться просроченным.
if getgenv().SanDiegoAgentStartingJobId == currentJobId and getgenv().SanDiegoAgentRunning then
    print("[SanDiegoAgent] skipping start: another loader is starting the agent")
    return
end

if existingMarker then
    print("[SanDiegoAgent] skipping start: running marker found")
    return
end

getgenv().SanDiegoAgentRunning = true
getgenv().SanDiegoAgentRunningJobId = currentJobId
-- Метка ставится ДО длительной загрузки модулей: это единственный защитный
-- барьер от бурста queue_on_teleport (все копии кроме первой видят метку и
-- выходят). JobId «последнего старта» намеренно НЕ выставляем здесь —
-- иначе очередные копии решили бы, что сервер тот же, и не стартовали бы
-- агент на новом сервере (агент реально стартует асинхронно в UIPanel.run,
-- и сигнал LastStartJobId выставляется ниже, после возврата из run()).
getgenv().SanDiegoAgentStartingJobId = currentJobId

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
    getgenv().SanDiegoAgentStartingJobId = nil
    if marker then
        pcall(function() marker:Destroy() end)
    end
    return
end

-- Сигнал для queue_on_teleport: агент реально стартовал на этом сервере.
getgenv().SanDiegoAgentLastStartJobId = currentJobId
