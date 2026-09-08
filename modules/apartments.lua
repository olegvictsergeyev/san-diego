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
function Apartments:findToggleableDoor(hrp)
	local player = Players.LocalPlayer
	local best, bestDist = nil, math.huge
	for _, door in ipairs(self:_doors()) do
		local allowed = door:GetAttribute(self.DOOR_KIND_ATTR) == self.DOOR_KIND_INTERIOR
		if not allowed and player then
			allowed = door:GetAttribute(self.OWNER_ATTR) == player.UserId
		end
		if allowed then
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

	if dist > self.MAX_DOOR_DISTANCE then
		data.open = door:GetAttribute(self.DOOR_OPEN_ATTR) == true
		return { success = false, error = string.format("door is %.1f studs away (max %d)", dist, self.MAX_DOOR_DISTANCE), data = data }
	end

	local function doorOpen()
		return door:GetAttribute(self.DOOR_OPEN_ATTR) == true
	end

	-- уже в целевом состоянии — успех без вызова
	if doorOpen() == targetOpen then
		data.open = targetOpen
		data.toggled = false
		return { success = true, data = data }
	end

	-- ждём, пока дверь освободится (анимация предыдущего переключения)
	local busyDeadline = tick() + 4
	while door:GetAttribute(self.DOOR_BUSY_ATTR) == true and tick() < busyDeadline do
		if isCancelled and isCancelled() then
			return { success = false, error = "cancelled", data = data }
		end
		task.wait(0.1)
	end

	-- МОБИЛЬНАЯ РЕПЛИКАЦИЯ: после подхода к двери сервер ещё ~1 с видит
	-- персонажа на старом месте и МОЛЧА отклоняет ToggleApartmentDoor
	-- (клиентская дистанция 18.4 < max 20, серверная — уже нет). Даём
	-- позиции доехать до сервера и ретраим вызов до 4 раз: пока дверь
	-- не перешла в целевое состояние, серверный вызов безопасен (no-op
	-- или очередной reject — атрибут двери меняет только сервер).
	task.wait(1.0)
	local attempts = {}
	for attempt = 1, 4 do
		if isCancelled and isCancelled() then
			return { success = false, error = "cancelled", data = data }
		end
		-- позиция могла откатиться (boundary) или дверь уже дошла до цели
		local okPos, doorPos = pcall(function()
			return door:GetPivot().Position
		end)
		if okPos and doorPos then
			dist = (doorPos - hrp.Position).Magnitude
			data.door_distance = math.floor(dist * 10) / 10
			if dist > self.MAX_DOOR_DISTANCE then
				data.open = doorOpen()
				return { success = false, error = string.format("door is %.1f studs away (max %d)", dist, self.MAX_DOOR_DISTANCE), data = data }
			end
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
		local deadline = tick() + 2.5
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
			task.wait(0.1)
		end
		table.insert(attempts, string.format("attempt %d: no state change in 2.5s (server rejected?)", attempt))
		task.wait(1.0)
	end

	data.open = doorOpen()
	data.attempts_log = attempts
	return { success = false, error = "door did not reach target state (server rejected?)", data = data }
end

return Apartments
