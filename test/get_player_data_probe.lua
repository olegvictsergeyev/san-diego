local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local function safeInvoke(remote, ...)
	if not remote or not remote:IsA("RemoteFunction") then
		return false, "not a RemoteFunction"
	end
	local ok, res = pcall(function(...)
		return remote:InvokeServer(...)
	end, ...)
	if ok then
		return true, res
	else
		return false, tostring(res)
	end
end

local function safePrint(label, success, data)
	print("=== " .. label .. " ===")
	if not success then
		print("ERROR:", tostring(data))
		return
	end
	if data == nil then
		print("nil response")
		return
	end
	local ok, json = pcall(function()
		return HttpService:JSONEncode(data)
	end)
	if ok then
		print(json)
	else
		print("response (not JSON):", tostring(data))
	end
end

local playerDataService = ReplicatedStorage.__remotes.PlayerDataService
local vehicleSpawnerService = ReplicatedStorage.__remotes.VehicleSpawnerService
local beachHouseService = ReplicatedStorage.__remotes.BeachHouseService
local apartmentService = ReplicatedStorage.__remotes.ApartmentService

-- 1. GetPlayerData для себя (без аргументов и с LocalPlayer)
safePrint("PlayerDataService.GetPlayerData()", safeInvoke(playerDataService.GetPlayerData))
safePrint("PlayerDataService.GetPlayerData(LocalPlayer)", safeInvoke(playerDataService.GetPlayerData, Players.LocalPlayer))

-- 2. Попытка получить данные по другим игрокам
for _, other in ipairs(Players:GetPlayers()) do
	if other ~= Players.LocalPlayer then
		safePrint("PlayerDataService.GetPlayerData(" .. other.Name .. ")", safeInvoke(playerDataService.GetPlayerData, other))
		safePrint("PlayerDataService.GetPlayerData(" .. tostring(other.UserId) .. ")", safeInvoke(playerDataService.GetPlayerData, other.UserId))
	end
end

-- 3. GetLimitedVehicleCount — возможно, возвращает купленные/лимитированные машины
safePrint("VehicleSpawnerService.GetLimitedVehicleCount()", safeInvoke(vehicleSpawnerService.GetLimitedVehicleCount))

-- 4. BeachHouseService.SelectHouse / RemoveHouse — пробуем получить данные, если есть методы
-- У сервиса нет явного Get, но можно посмотреть на возврат SelectHouse(nil)
safePrint("BeachHouseService.SelectHouse(nil)", safeInvoke(beachHouseService.SelectHouse, nil))

-- 5. ApartmentService remote'ы в основном управленческие, пробуем GetApartmentCircleTeleportDestination
safePrint("ApartmentService.GetApartmentCircleTeleportDestination()", safeInvoke(apartmentService.GetApartmentCircleTeleportDestination))

print("=== probe finished ===")
