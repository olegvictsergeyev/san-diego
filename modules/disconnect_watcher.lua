local CoreGui = game:GetService("CoreGui")

local DisconnectWatcher = {}
DisconnectWatcher.__index = DisconnectWatcher

function DisconnectWatcher.new(agent, compat, opts)
	return setmetatable({
		agent = agent,
		compat = compat,
		opts = opts or {},
		watching = false,
		handled = false,
	}, DisconnectWatcher)
end

function DisconnectWatcher:_log(...)
	print("[SanDiegoAgent][DisconnectWatcher]", table.concat({ ... }, " "))
end

function DisconnectWatcher:_getErrorPrompt()
	local promptGui = CoreGui:FindFirstChild("RobloxPromptGui")
	if not promptGui then
		return nil
	end
	local overlay = promptGui:FindFirstChild("promptOverlay")
	if not overlay then
		return nil
	end
	return overlay:FindFirstChild("ErrorPrompt")
end

function DisconnectWatcher:_readText(root, path)
	local current = root
	for _, name in ipairs(path) do
		current = current:FindFirstChild(name)
		if not current then
			return nil
		end
	end
	if current:IsA("TextLabel") or current:IsA("TextButton") then
		return current.Text
	end
	return nil
end

function DisconnectWatcher:_readErrorInfo()
	local prompt = self:_getErrorPrompt()
	if not prompt then
		return nil
	end
	local title = self:_readText(prompt, { "TitleFrame", "ErrorTitle" })
	local message = self:_readText(prompt, { "MessageArea", "ErrorFrame", "ErrorMessage" })
	local code = nil
	if message then
		-- Case-insensitive: встречались варианты написания "Error code:".
		code = message:lower():match("%(error code:%s*(%d+)%)")
	end
	return {
		title = title,
		message = message,
		code = code,
	}
end

function DisconnectWatcher:_onPromptShown()
	if self.handled then
		return
	end

	-- Во время намеренного телепорта (join_private_server) Roblox может
	-- кратко показать ErrorPrompt — это НЕ дисконнект, бэкенду не шлём.
	local teleporting = getgenv().SanDiegoAgentTeleporting == true
		or (self.agent and self.agent.teleporting == true)
	if teleporting then
		self:_log("teleport in progress, ignoring ErrorPrompt")
		return
	end

	self.handled = true

	-- Текст промпта может отрисоваться позже самого инстанса: если сразу
	-- не прочиталось — повторяем, а не сдаёмся. Ранний return с
	-- handled=true навсегда отключал и репорт, и авто-переподключение.
	local info
	for attempt = 1, 10 do
		info = self:_readErrorInfo()
		if info and (info.title or info.message) then
			break
		end
		task.wait(0.5)
	end
	if not info or not (info.title or info.message) then
		self:_log("could not read ErrorPrompt content after retries")
		return
	end

	self:_log("error/disconnect prompt shown", tostring(info.title), tostring(info.code))

	if self.agent and self.agent.reportError then
		pcall(function()
			self.agent:reportError(info)
		end)
	end

	-- Авто-переподключение при 277/278: это сетевой обрыв/idle-кик, а не
	-- управляемый бэкендом переход. Ждём внешних команд бессмысленно —
	-- клиент сидит на ErrorPrompt, и пока его не перезапустят, фарм мёртв.
	-- Лестница восстановления: ReconnectButton (реджойн на тот же инстанс,
	-- повторы с бэкофом на случай 773) → Teleport(placeId) на любой
	-- инстанс как последний шаг — оживляет клиента, бэкенд затем шлёт
	-- join_private_server и возвращает на ферму.
	if info.code == "277" or info.code == "278" then
		self:_scheduleReconnect(info)
	elseif info.code == "288" then
		-- Сервер закрыт: реджойн на тот же инстанс невозможен в принципе —
		-- сразу оживляем клиент телепортом на любой инстанс.
		self:_scheduleRevive(info)
	end
end

-- Оживление при 288 «The server has shut down» (проверено: 10 персонажей
-- потеряли сервер s1 одновременно 11.09.2026). ReconnectButton бесполезен
-- (целевого инстанса нет), работает только Teleport(placeId) — дальше
-- бэкенд штатной командой join_private_server возвращает на ферму.
function DisconnectWatcher:_scheduleRevive(info)
	task.spawn(function()
		local Players = game:GetService("Players")
		for _, delay in ipairs({10, 60}) do
			task.wait(delay)
			if self.agent and self.agent.running == false then
				self:_log("agent stopped by user, revive cancelled")
				return
			end
			if not self:_getErrorPrompt() then
				self:_log("ErrorPrompt gone, revive not needed")
				return
			end
			local ok, err = pcall(function()
				local TeleportService = game:GetService("TeleportService")
				self:_log("revive attempt: teleporting to place", tostring(game.PlaceId))
				TeleportService:Teleport(game.PlaceId, Players.LocalPlayer)
			end)
			if not ok then
				self:_log("revive teleport failed:", tostring(err))
			end
		end
		self:_log("revive attempts exhausted; leaving prompt for backend/user")
	end)
end

-- Лестница восстановления (все шаги проверены на живом клиенте
-- 09.09.2026, pid 22488, кик 278):
-- 1) ReconnectButton (через getconnections Activated) — реально инициирует
--    реджойн на тот же инстанс, но сервер может ответить 773 «Reconnect was
--    unsuccessful» (инстанс мёртв/полон/сессия призрак) — повторяем с бэкофом.
-- 2) Teleport(placeId) на любой инстанс — срабатывает даже с повисшего
--    ErrorPrompt и оживляет клиента; дальше бэкенд штатной командой
--    join_private_server возвращает его на ферму.
-- ВАЖНО: TeleportToPlaceInstance на ТОТ ЖЕ jobId из состояния дисконнекта —
-- тихий no-op (3 попытки подряд, промпт остался): НЕ использовать.
function DisconnectWatcher:_scheduleReconnect(info)
	task.spawn(function()
		local Players = game:GetService("Players")
		local steps = {
			{ delay = 10, action = "reconnect_button" },
			{ delay = 30, action = "reconnect_button" },
			{ delay = 60, action = "reconnect_button" },
			{ delay = 30, action = "teleport_place" },
		}
		for i, step in ipairs(steps) do
			task.wait(step.delay)
			if self.agent and self.agent.running == false then
				self:_log("agent stopped by user, reconnect cancelled")
				return
			end
			local prompt = self:_getErrorPrompt()
			if not prompt then
				self:_log("ErrorPrompt gone, reconnect not needed")
				return
			end
			local current = self:_readErrorInfo()
			if step.action == "reconnect_button" then
				self:_log("auto-reconnect step", i, "firing ReconnectButton, prompt code", tostring(current and current.code))
				self:_fireReconnectButton(prompt)
			else
				local ok, err = pcall(function()
					local TeleportService = game:GetService("TeleportService")
					self:_log("auto-reconnect step", i, "teleporting to place", tostring(game.PlaceId))
					TeleportService:Teleport(game.PlaceId, Players.LocalPlayer)
				end)
				if not ok then
					self:_log("teleport to place failed:", tostring(err))
				end
			end
		end
		self:_log("reconnect ladder exhausted; leaving prompt for backend/user")
	end)
end

-- Клик по системной кнопке Reconnect: через getconnections + pcall, обработчик
-- — в task.spawn (правило §4 AGENTS.md). Кнопка — ImageButton (Text нет).
function DisconnectWatcher:_fireReconnectButton(prompt)
	local ok, err = pcall(function()
		local area = prompt:FindFirstChild("MessageArea")
		local frame = area and area:FindFirstChild("ErrorFrame")
		local buttons = frame and frame:FindFirstChild("ButtonArea")
		local btn = buttons and buttons:FindFirstChild("ReconnectButton")
		if not btn then
			error("ReconnectButton not found")
		end
		local conns = {}
		local okConns, res = pcall(function()
			return getconnections(btn.Activated)
		end)
		if okConns and typeof(res) == "table" then
			conns = res
		end
		if #conns == 0 then
			error("no getconnections for ReconnectButton.Activated")
		end
		task.spawn(function()
			for _, c in ipairs(conns) do
				pcall(function()
					c:Fire()
				end)
			end
		end)
	end)
	if not ok then
		self:_log("fire ReconnectButton failed:", tostring(err))
	end
end

function DisconnectWatcher:_watchExisting()
	local prompt = self:_getErrorPrompt()
	if prompt then
		self:_log("ErrorPrompt already visible at start")
		self:_onPromptShown()
	end
end

function DisconnectWatcher:_watchPromptAdded()
	local promptGui = CoreGui:FindFirstChild("RobloxPromptGui")
	if not promptGui then
		self:_log("RobloxPromptGui not found")
		return
	end
	local overlay = promptGui:FindFirstChild("promptOverlay")
	if not overlay then
		self:_log("promptOverlay not found")
		return
	end
	overlay.ChildAdded:Connect(function(child)
		if child.Name == "ErrorPrompt" then
			self:_log("ErrorPrompt added")
			task.wait(0.1)
			self:_onPromptShown()
		end
	end)
end

function DisconnectWatcher:start()
	if self.watching then
		return
	end
	self.watching = true
	self:_log("starting")
	self:_watchExisting()
	self:_watchPromptAdded()
end

return DisconnectWatcher
