-- San Diego Agent — монитор античита/модерации ИГРЫ.
--
-- ВАЖНО: игра сообщает о срабатываниях античита НАПРЯМУЮ, через
-- GUI-уведомления (PlayerGui.WarningGui — moderation warning,
-- PlayerGui.AccountResetNoticeGui — "account data was reset for using
-- exploits", "N more infractions will result in ... permanently banned").
-- Это каноничный канал сигнала: видимое уведомление = игра уже зафиксировала
-- нарушение.
--
-- Детектить «античит» по отклонению позиции после шага НЕЛЬЗЯ: откат
-- шагового телепорта — это почти всегда физика/границы карты
-- (PlayerBoundary на горах, canQuery=false, рейкасты их не видят), а не
-- срабатывание детектора. Смешивать эти сигналы — ошибка диагностики.
--
-- Поведение:
--  * При старте фиксирует уже существующие уведомления как «preexisting»
--    (докладываются через getPreexisting(), движение НЕ блокируют — это
--    прошлые события, например варн от модератора месячной давности).
--  * После старта: любое уведомление, которое стало Enabled (или новый
--    GUI с маркерным текстом) → flagged=true (sticky) + getNotice().
--    Пешие/транспортные команды движения отказываются работать, пока
--    флаг поднят; после исчезновения уведомления флаг держится cooldownSec.
local Players = game:GetService("Players")

local AnticheatGuard = {}
AnticheatGuard.__index = AnticheatGuard

local NOTICE_GUI_NAMES = {
	"WarningGui",
	"AccountResetNoticeGui",
}

-- Текстовые маркеры: срабатывание фиксируем только если в уведомлении
-- есть что-то из этого (защита от ложных срабатываний на одноимённых GUI).
local TEXT_MARKERS = {
	"permanently banned",
	"moderation warning",
	"reset for using exploits",
	"infraction",
	"account data was reset",
}

local function readNoticeText(gui)
	local parts = {}
	for _, d in ipairs(gui:GetDescendants()) do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			local t = tostring(d.Text or "")
			t = t:gsub("%s+", " ")
			t = t:gsub("^%s+", ""):gsub("%s+$", "")
			if #t > 2 then
				parts[#parts + 1] = t
			end
		end
	end
	return table.concat(parts, " | ")
end

local function textLooksLikeNotice(text)
	local lower = string.lower(text or "")
	for _, marker in ipairs(TEXT_MARKERS) do
		if lower:find(marker, 1, true) then
			return true
		end
	end
	return false
end

function AnticheatGuard.new(opts)
	opts = opts or {}
	local self = setmetatable({}, AnticheatGuard)
	self._cooldownSec = tonumber(opts.cooldownSec) or 900
	self._pollSec = tonumber(opts.pollSec) or 1
	self._flagged = false
	self._notice = nil
	self._flaggedAt = nil
	self._clearedAt = nil
	self._preexisting = nil
	self._preexistingReported = false
	self._started = false
	self._conn = nil
	return self
end

function AnticheatGuard:_playerGui()
	local player = Players.LocalPlayer
	return player and player:FindFirstChild("PlayerGui") or nil
end

-- Сканирует PlayerGui; возвращает enabled-уведомление (gui, text) или nil.
function AnticheatGuard:_findActiveNotice()
	local playerGui = self:_playerGui()
	if not playerGui then
		return nil
	end
	for _, name in ipairs(NOTICE_GUI_NAMES) do
		local gui = playerGui:FindFirstChild(name)
		if gui and gui.Enabled then
			local text = readNoticeText(gui)
			if textLooksLikeNotice(text) then
				return gui, text
			end
		end
	end
	-- запасной вариант: любой GUI с маркерным текстом
	for _, gui in ipairs(playerGui:GetChildren()) do
		if gui:IsA("ScreenGui") and gui.Enabled then
			local ok, text = pcall(readNoticeText, gui)
			if ok and textLooksLikeNotice(text) then
				return gui, text
			end
		end
	end
	return nil
end

-- Тихий скан уже существующих (в т.ч. скрытых) уведомлений при старте.
function AnticheatGuard:_snapshotPreexisting()
	local playerGui = self:_playerGui()
	if not playerGui then
		return
	end
	for _, name in ipairs(NOTICE_GUI_NAMES) do
		local gui = playerGui:FindFirstChild(name)
		if gui then
			local text = readNoticeText(gui)
			if textLooksLikeNotice(text) then
				self._preexisting = string.format("%s: %s", name, text)
				return
			end
		end
	end
end

function AnticheatGuard:start()
	if self._started then
		return
	end
	self._started = true
	self:_snapshotPreexisting()
	task.spawn(function()
		while self._started do
			local gui, text = self:_findActiveNotice()
			if gui then
				if not self._flagged then
					warn("[SanDiegoAgent][AnticheatGuard] NOTICE SHOWN:", gui.Name, "|", text)
				end
				self._flagged = true
				self._notice = string.format("%s: %s", gui.Name, text)
				self._flaggedAt = self._flaggedAt or tick()
				self._clearedAt = nil
			elseif self._flagged then
				-- уведомление исчезло: держим флаг ещё cooldownSec
				if not self._clearedAt then
					self._clearedAt = tick()
				elseif tick() - self._clearedAt >= self._cooldownSec then
					self._flagged = false
					self._notice = nil
					warn("[SanDiegoAgent][AnticheatGuard] cooldown expired, movement resumed")
				end
			end
			task.wait(self._pollSec)
		end
	end)
end

function AnticheatGuard:stop()
	self._started = false
	if self._conn then
		pcall(function()
			self._conn:Disconnect()
		end)
		self._conn = nil
	end
end

-- true = игра показала античит/модерацию после старта агента: движение
-- должно быть остановлено.
function AnticheatGuard:isFlagged()
	return self._flagged == true
end

function AnticheatGuard:getNotice()
	return self._notice
end

-- Уведомление, существовавшее ДО старта агента (прошлые события).
-- Возвращает текст один раз, затем считается «доложенным».
function AnticheatGuard:consumePreexisting()
	if self._preexisting and not self._preexistingReported then
		self._preexistingReported = true
		return self._preexisting
	end
	return nil
end

return AnticheatGuard
