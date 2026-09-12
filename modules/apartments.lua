local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Apartments = {}
Apartments.__index = Apartments

-- Аренда номера отеля тем же серверным вызовом, что и ProximityPrompt
-- «Purchase Apartment» на парадной двери (только без нажатия E):
--   require(ReplicatedStorage.SharedModules.Pronghorn.Remotes).Client
--     .ApartmentService:PurchaseApartment(door)
-- Двери ищутся по тегу CollectionService "ApartmentDoor"; арендуемая —
-- ApartmentDoorKind == "Front" и без атрибута ApartmentOwnerUserId.
-- Статус аренды игрока — атрибут OwnedApartmentId
-- (ApartmentUtil.ATTR_PLAYER_APARTMENT_ID): number = номер арендован.
Apartments.DOOR_TAG = "ApartmentDoor"
Apartments.DOOR_KIND_ATTR = "ApartmentDoorKind"
Apartments.DOOR_KIND_FRONT = "Front"
Apartments.DOOR_KIND_INTERIOR = "Interior"
Apartments.DOOR_OPEN_ATTR = "ApartmentDoorOpen"
Apartments.DOOR_BUSY_ATTR = "ApartmentDoorBusy"
Apartments.OWNER_ATTR = "ApartmentOwnerUserId"
Apartments.APARTMENT_ID_ATTR = "ApartmentId"
Apartments.PLAYER_APARTMENT_ATTR = "OwnedApartmentId"
-- Промпт активен на 12 ст; запас на неточность подхода.
Apartments.MAX_DOOR_DISTANCE = 20
Apartments.CONFIRM_TIMEOUT = 6

function Apartments.new()
	local self = setmetatable({}, Apartments)
	return self
end

function Apartments:_client()
	local ok, client = pcall(function()
		return require(game.ReplicatedStorage.SharedModules.Pronghorn.Remotes).Client
	end)
	if not ok or not client or not client.ApartmentService then
		return nil, "apartment remotes unavailable: " .. tostring(client)
	end
	return client
end

-- Number — арендован (значение = ApartmentId), иначе nil.
function Apartments:rentedApartmentId()
	local player = Players.LocalPlayer
	if not player then
		return nil
	end
	local id = player:GetAttribute(self.PLAYER_APARTMENT_ATTR)
	if type(id) == "number" then
		return id
	end
	return nil
end

function Apartments:_doors()
	local ok, doors = pcall(function()
		return CollectionService:GetTagged(self.DOOR_TAG)
	end)
	if ok and doors then
		return doors
	end
	-- фолбэк: обход Units/*/Door
	local result = {}
	local gameplay = workspace:FindFirstChild("Gameplay")
	local units = gameplay and gameplay:FindFirstChild("Apartments") and gameplay.Apartments:FindFirstChild("Units")
	if units then
		for _, unit in ipairs(units:GetChildren()) do
			local door = unit:FindFirstChild("Door", true)
			if door then
				table.insert(result, door)
			end
		end
	end
	return result
end

-- Ближайшая неарендованная парадная дверь. apartmentId (optional) —
-- арендовать конкретный номер. Возвращает door, distance, error.
function Apartments:findRentableDoor(hrp, apartmentId)
	local best, bestDist = nil, math.huge
	for _, door in ipairs(self:_doors()) do
		if door:GetAttribute(self.DOOR_KIND_ATTR) == self.DOOR_KIND_FRONT
			and type(door:GetAttribute(self.OWNER_ATTR)) ~= "number"
		then
			if apartmentId == nil or door:GetAttribute(self.APARTMENT_ID_ATTR) == apartmentId then
				local okP, pos = pcall(function()
					return door:GetPivot().Position
				end)
				if okP and pos then
					local dist = (pos - hrp.Position).Magnitude
					if dist < bestDist then
						best, bestDist = door, dist
					end
				end
			end
		end
	end
	if not best then
		if apartmentId ~= nil then
			return nil, nil, "no unowned front door found for apartment_id=" .. tostring(apartmentId)
		end
		return nil, nil, "no unowned front door found on this server"
	end
	return best, bestDist, nil
end

-- Арендует номер. Если уже арендован — не покупает, возвращает
-- already_rented. isCancelled — кооперативная отмена (ожидание подтверждения).
function Apartments:rent(apartmentId, isCancelled)
	local player = Players.LocalPlayer
	if not player then
		return { success = false, error = "local player not found" }
	end

	local existing = self:rentedApartmentId()
	if existing then
		return { success = true, data = { already_rented = true, rented = true, apartment_id = existing } }
	end

	-- Кнопка Purchase видна только гражданским — сервер тоже отклонит.
	local okTeam, isCivilian = pcall(function()
		return player.Team == game.Teams.Civilian
	end)
	if okTeam and not isCivilian then
		return { success = false, error = "team must be Civilian to rent an apartment" }
	end

	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return { success = false, error = "HumanoidRootPart not found" }
	end

	local client, clientErr = self:_client()
	if not client then
		return { success = false, error = clientErr }
	end

	local door, dist, findErr = self:findRentableDoor(hrp, apartmentId)
	if not door then
		return { success = false, error = findErr }
	end
	if dist > self.MAX_DOOR_DISTANCE then
		return {
			success = false,
			error = string.format("rentable door is %.1f studs away (stand at the door, max %d)", dist, self.MAX_DOOR_DISTANCE),
			data = { apartment_id = door:GetAttribute(self.APARTMENT_ID_ATTR), door_distance = math.floor(dist * 10) / 10 },
		}
	end

	local doorAptId = door:GetAttribute(self.APARTMENT_ID_ATTR)
	-- МОБИЛЬНАЯ РЕПЛИКАЦИЯ: сервер может ещё видеть персонажа вдали
	-- и молча отклонить PurchaseApartment. Settle 1 с + до 3 ретраев;
	-- повторный вызов безопасен (аренда идемпотентна — уже своя вернётся
	-- через ownedApartmentId на верификации).
	task.wait(1.0)
	local attempts = {}
	for attempt = 1, 3 do
		if isCancelled and isCancelled() then
			return { success = false, error = "cancelled" }
		end
		local callResult = nil
		local okCall, callErr = pcall(function()
			callResult = client.ApartmentService:PurchaseApartment(door)
		end)
		if not okCall then
			return {
				success = false,
				error = "purchase call failed: " .. tostring(callErr),
				data = { apartment_id = doorAptId, door_distance = math.floor(dist * 10) / 10 },
			}
		end

		-- Верификация: сервер ставит OwnedApartmentId на игрока.
		local deadline = tick() + 4
		while tick() < deadline do
			if isCancelled and isCancelled() then
				return { success = false, error = "cancelled" }
			end
			local now = self:rentedApartmentId()
			if now then
				return {
					success = true,
					data = {
						rented = true,
						already_rented = false,
						apartment_id = now,
						door_distance = math.floor(dist * 10) / 10,
						attempts = attempt,
					},
				}
			end
			task.wait(0.25)
		end
		table.insert(attempts, string.format("attempt %d: not confirmed in 4s (purchase_result=%s)", attempt, tostring(callResult)))
		task.wait(1.0)
	end

	return {
		success = false,
		error = "purchase was not confirmed by the server (team must be Civilian, door must be unowned, enough cash)",
		data = {
			apartment_id = doorAptId,
			door_distance = math.floor(dist * 10) / 10,
			attempts_log = attempts,
		},
	}
end

-- Ближайшая дверь, которую игрок имеет право открывать/закрывать:
-- своя парадная (ApartmentOwnerUserId == UserId) или любая Interior
-- (совпадает с клиентским GetPromptMode). Возвращает door, distance, error.
-- Возвращает дверь для переключения. Приоритет: своя парадная дверь
-- (Front + владелец — мы), затем ближайшая интерьерная. Иначе сценарий
-- у коридора соседнего номера может цеплять чужую interior-дверь.
function Apartments:findToggleableDoor(hrp)
	local player = Players.LocalPlayer
	local bestOwn, bestOwnDist = nil, math.huge
	local bestInterior, bestInteriorDist = nil, math.huge
	for _, door in ipairs(self:_doors()) do
		local okP, pos = pcall(function()
			return door:GetPivot().Position
		end)
		if okP and pos then
			local dist = (pos - hrp.Position).Magnitude
			local isOwnFront = door:GetAttribute(self.DOOR_KIND_ATTR) == self.DOOR_KIND_FRONT
				and player ~= nil
				and door:GetAttribute(self.OWNER_ATTR) == player.UserId
			if isOwnFront and dist < bestOwnDist then
				bestOwn, bestOwnDist = door, dist
			elseif door:GetAttribute(self.DOOR_KIND_ATTR) == self.DOOR_KIND_INTERIOR and dist < bestInteriorDist then
				bestInterior, bestInteriorDist = door, dist
			end
		end
	end
	local best, bestDist = bestOwn, bestOwnDist
	if not best then
		best, bestDist = bestInterior, bestInteriorDist
	end
	-- фолбэк: любая своя дверь (на случай нестандартного kind)
	if not best and player then
		for _, door in ipairs(self:_doors()) do
			if door:GetAttribute(self.OWNER_ATTR) == player.UserId then
				local okP, pos = pcall(function()
					return door:GetPivot().Position
				end)
				if okP and pos then
					local dist = (pos - hrp.Position).Magnitude
					if dist < bestDist then
						best, bestDist = door, dist
					end
				end
			end
		end
	end
	if not best then
		return nil, nil, "no toggleable door found nearby (own front door or any interior door)"
	end
	return best, bestDist, nil
end

-- Открывает (targetOpen=true) или закрывает ближайшую доступную дверь тем
-- же вызовом, что промпт Open/Close Door (без нажатия E):
--   Client.ApartmentService:ToggleApartmentDoor(door)
-- Доступные двери — своя парадная (ApartmentOwnerUserId == UserId) или
-- любая Interior (как в клиентском GetPromptMode). Если дверь уже в
-- целевом состоянии — вызов не делается, возвращается успех (no-op).
-- Возвращает open — итоговое состояние двери.
-- Переключает дверь в целевое состояние. Надёжность — главное: сценарий
-- фермы прерывался на close_door, поэтому:
-- 1. ApartmentDoorBusy ждём перед КАЖДОЙ попыткой (анимация открытия
--    после open_door длится дольше старого однократного ожидания, и
--    toggle по занятой двери сервер молча отклоняет).
-- 2. Окно верификации 5 с — мобильная репликация атрибутов двери
--    доходит с заметной задержкой (старое 2.5 с не дожидалось).
-- 3. Перед закрытием персонаж в проёме отшагивает на 3 ст — дверь,
--    закрывающаяся «по нему», откатывается или не закрывается вовсе.
-- 4. После исчерпания попыток — финальная пауза 3 с: состояние может
--    дойти с опозданием, это не ошибка.
local function doorBusyWait(door, busyAttr, timeout, isCancelled)
	local deadline = tick() + timeout
	while door:GetAttribute(busyAttr) == true and tick() < deadline do
		if isCancelled and isCancelled() then
			return false
		end
		task.wait(0.2)
	end
	return door:GetAttribute(busyAttr) ~= true
end

function Apartments:setDoorOpen(targetOpen, isCancelled)
	local player = Players.LocalPlayer
	if not player then
		return { success = false, error = "local player not found" }
	end
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return { success = false, error = "HumanoidRootPart not found" }
	end

	local client, clientErr = self:_client()
	if not client then
		return { success = false, error = clientErr }
	end

	local door, dist, findErr = self:findToggleableDoor(hrp)
	if not door then
		return { success = false, error = findErr }
	end

	local data = {
		apartment_id = door:GetAttribute(self.APARTMENT_ID_ATTR),
		door_kind = door:GetAttribute(self.DOOR_KIND_ATTR),
		door_distance = math.floor(dist * 10) / 10,
	}

	local function doorOpen()
		return door:GetAttribute(self.DOOR_OPEN_ATTR) == true
	end
	local function doorPos()
		local okP, pos = pcall(function()
			return door:GetPivot().Position
		end)
		if okP then
			return pos
		end
		return nil
	end
	local function refreshDistance()
		local pos = doorPos()
		if pos then
			dist = (pos - hrp.Position).Magnitude
			data.door_distance = math.floor(dist * 10) / 10
		end
		return dist
	end

	-- уже в целевом состоянии — успех без вызова
	if doorOpen() == targetOpen then
		data.open = targetOpen
		data.toggled = false
		return { success = true, data = data }
	end

	-- перед закрытием убираем персонажа из проёма: стоим в дверях —
	-- дверь физически не закроется или сразу откроется обратно.
	-- Отшагиваем малыми шагами (как _moveTo), античит не триггерим.
	if not targetOpen then
		refreshDistance()
		if dist < 2.5 then
			local pos = doorPos()
			if pos then
				local away = hrp.Position - pos
				away = Vector3.new(away.X, 0, away.Z)
				if away.Magnitude < 0.5 then
					local okL, look = pcall(function()
						return door:GetPivot().LookVector
					end)
					away = (okL and look) and Vector3.new(look.X, 0, look.Z) or Vector3.new(1, 0, 0)
				end
				away = away.Unit
				local target = hrp.Position + away * 3
				for step = 1, 3 do
					if isCancelled and isCancelled() then
						return { success = false, error = "cancelled", data = data }
					end
					local cf = CFrame.new(Vector3.new(
						hrp.Position.X + away.X,
						hrp.Position.Y,
						hrp.Position.Z + away.Z
					)) * CFrame.Angles(0, select(2, hrp.CFrame:ToEulerAnglesYXZ()), 0)
					pcall(function()
						hrp.CFrame = cf
						hrp.AssemblyLinearVelocity = Vector3.zero
					end)
					task.wait(0.2)
					if refreshDistance() >= 2.5 then
						break
					end
					if (Vector3.new(target.X - hrp.Position.X, 0, target.Z - hrp.Position.Z)).Magnitude < 0.3 then
						break
					end
				end
			end
		end
	end

	-- МОБИЛЬНАЯ РЕПЛИКАЦИЯ: после подхода к двери сервер ещё ~1-2 с видит
	-- персонажа на старом месте и МОЛЧА отклоняет ToggleApartmentDoor.
	-- Ретраим вызов до 6 раз: пока дверь не перешла в целевое состояние,
	-- серверный вызов безопасен (no-op или очередной reject — атрибут
	-- двери меняет только сервер).
	task.wait(1.0)
	local attempts = {}
	for attempt = 1, 6 do
		if isCancelled and isCancelled() then
			return { success = false, error = "cancelled", data = data }
		end
		-- позиция могла откатиться (boundary) или дверь уже дошла до цели
		if refreshDistance() > self.MAX_DOOR_DISTANCE then
			data.open = doorOpen()
			return { success = false, error = string.format("door is %.1f studs away (max %d)", dist, self.MAX_DOOR_DISTANCE), data = data }
		end
		if doorOpen() == targetOpen then
			data.open = targetOpen
			data.toggled = attempt > 1 or nil
			data.attempts = attempt
			return { success = true, data = data }
		end
		-- занятая дверь отклоняет toggle молча — ждём освобождения
		-- именно здесь, а не один раз перед циклом (анимация чужого
		-- переключения может начаться между попытками).
		if not doorBusyWait(door, self.DOOR_BUSY_ATTR, 6, isCancelled) then
			if isCancelled and isCancelled() then
				return { success = false, error = "cancelled", data = data }
			end
			table.insert(attempts, string.format("attempt %d: door busy > 6s", attempt))
		end
		if doorOpen() == targetOpen then
			data.open = targetOpen
			data.toggled = attempt > 1 or nil
			data.attempts = attempt
			return { success = true, data = data }
		end
		local okCall, callErr = pcall(function()
			client.ApartmentService:ToggleApartmentDoor(door)
		end)
		if not okCall then
			data.open = doorOpen()
			return { success = false, error = "toggle call failed: " .. tostring(callErr), data = data }
		end
		-- верификация: атрибут должен дойти до целевого состояния
		local deadline = tick() + 5
		while tick() < deadline do
			if isCancelled and isCancelled() then
				return { success = false, error = "cancelled", data = data }
			end
			if doorOpen() == targetOpen then
				data.open = targetOpen
				data.toggled = true
				data.attempts = attempt
				return { success = true, data = data }
			end
			task.wait(0.2)
		end
		table.insert(attempts, string.format("attempt %d: no state change in 5s (server rejected or slow replication)", attempt))
		task.wait(0.5)
	end

	-- финальная пауза: состояние может дойти с опозданием после
	-- последнего вызова — это не ошибка, а медленная репликация.
	local graceDeadline = tick() + 3
	while tick() < graceDeadline do
		if isCancelled and isCancelled() then
			return { success = false, error = "cancelled", data = data }
		end
		if doorOpen() == targetOpen then
			data.open = targetOpen
			data.toggled = true
			data.attempts = 7
			return { success = true, data = data }
		end
		task.wait(0.2)
	end

	data.open = doorOpen()
	data.attempts_log = attempts
	return { success = false, error = "door did not reach target state (server rejected?)", data = data }
end

return Apartments
