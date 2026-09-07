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
	local deadline = tick() + self.CONFIRM_TIMEOUT
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
				},
			}
		end
		task.wait(0.25)
	end

	return {
		success = false,
		error = "purchase was not confirmed by the server (team must be Civilian, door must be unowned, enough cash)",
		data = {
			apartment_id = doorAptId,
			door_distance = math.floor(dist * 10) / 10,
			purchase_result = tostring(callResult),
		},
	}
end

return Apartments
