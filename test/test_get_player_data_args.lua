local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local getPlayerData = ReplicatedStorage.__remotes.PlayerDataService.GetPlayerData

local function tryInvoke(label, ...)
	local ok, res = pcall(function(...)
		return getPlayerData:InvokeServer(...)
	end, ...)
	print("=== " .. label .. " ===")
	if not ok then
		print("ERROR:", tostring(res))
		return
	end
	if res == nil then
		print("nil")
		return
	end
	if typeof(res) ~= "table" then
		print("type:", typeof(res))
		print(tostring(res))
		return
	end
	-- выводим только ключи, чтобы не засорять лог
	local keys = {}
	for k, _ in pairs(res) do
		table.insert(keys, k)
	end
	print("keys:", table.concat(keys, ", "))
	-- и список OwnedVehicles / OwnedBeachHouses / MoneyPrinters
	print("Currency.Money:", tostring(res.Currency and res.Currency.Money))
	print("OwnedVehicles:", HttpService:JSONEncode(res.OwnedVehicles or {}))
	print("PurchasedVehicles:", HttpService:JSONEncode(res.PurchasedVehicles or {}))
	print("OwnedBeachHouses:", HttpService:JSONEncode(res.OwnedBeachHouses or {}))
	print("BeachHouseGardens:", HttpService:JSONEncode(res.BeachHouseGardens or {}))
	print("ApartmentPurchaseExpiresAt:", tostring(res.ApartmentPurchaseExpiresAt))
	local mpCount = 0
	if typeof(res.MoneyPrinters) == "table" then
		for _ in pairs(res.MoneyPrinters) do mpCount += 1 end
	end
	print("MoneyPrinters count:", mpCount)
end

-- для себя (LocalPlayer)
tryInvoke("no args")
tryInvoke("LocalPlayer", Players.LocalPlayer)
tryInvoke("LocalPlayer.UserId", Players.LocalPlayer.UserId)

-- для каждого игрока на сервере
for _, p in ipairs(Players:GetPlayers()) do
	if p ~= Players.LocalPlayer then
		tryInvoke("player " .. p.Name, p)
		tryInvoke("UserId " .. p.UserId, p.UserId)
	end
end

print("=== done ===")
