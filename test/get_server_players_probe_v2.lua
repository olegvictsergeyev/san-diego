local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local getPlayerData = ReplicatedStorage.__remotes.PlayerDataService.GetPlayerData

local function parseFormattedNumber(text)
	if typeof(text) == "number" then return text end
	local s = tostring(text):gsub("[ ,]", "")
	if s == "" then return nil end
	local num, suffix = s:match("^([%d%.]+)([KkMmBbTt]?)$")
	if num then
		local n = tonumber(num)
		if n then
			local lower = suffix:lower()
			if lower == "k" then n = n * 1e3
			elseif lower == "m" then n = n * 1e6
			elseif lower == "b" then n = n * 1e9
			elseif lower == "t" then n = n * 1e12
			end
			return n
		end
	end
	return tonumber(s)
end

local function getBalanceFromReplicatedStats(player)
	local folder = player:FindFirstChild("ReplicatedStats")
	if not folder then return nil end
	local money = folder:FindFirstChild("Money")
	if money and money:IsA("StringValue") then
		return parseFormattedNumber(money.Value)
	end
	return nil
end

local function getLocalPlayerData()
	local ok, res = pcall(function()
		return getPlayerData:InvokeServer()
	end)
	if not ok or typeof(res) ~= "table" then
		return nil, tostring(res)
	end
	return res, nil
end

local function extractVehicleNames(data)
	local names = {}
	local seen = {}
	local sources = { data.OwnedVehicles, data.PurchasedVehicles, data.FavoriteVehicles, data.ClaimedBeachHouseVehicles }
	for _, src in ipairs(sources) do
		if typeof(src) == "table" then
			for _, v in ipairs(src) do
				local name = typeof(v) == "string" and v or (typeof(v) == "table" and (v.Name or v.name)) or tostring(v)
				if name and name ~= "" and not seen[name] then
					seen[name] = true
					table.insert(names, name)
				end
			end
		end
	end
	return names
end

local function extractPropertyNames(userId)
	local props = {}
	local gameplay = Workspace:FindFirstChild("Gameplay")
	local beachPlots = gameplay and gameplay:FindFirstChild("BeachHousePlots")
	if beachPlots then
		for _, plot in ipairs(beachPlots:GetChildren()) do
			local ownerId = plot:GetAttribute("BeachHouseOwnerUserId")
			if ownerId and ownerId == userId then
				local plotType = plot:GetAttribute("BeachHouseType") or "BeachHouse"
				table.insert(props, plotType .. " " .. plot.Name)
			end
		end
	end
	local apartments = gameplay and gameplay:FindFirstChild("Apartments")
	if apartments then
		local units = apartments:FindFirstChild("Units")
		if units then
			for _, unit in ipairs(units:GetChildren()) do
				local ownerId = unit:GetAttribute("OwnerUserId") or unit:GetAttribute("ApartmentOwnerUserId") or unit:GetAttribute("OccupantUserId")
				if ownerId and ownerId == userId then
					table.insert(props, "Apartment " .. unit.Name)
				end
			end
		end
	end
	return props
end

local function collectServerPlayers()
	local localPlayer = Players.LocalPlayer
	local localUserId = localPlayer and localPlayer.UserId
	local localData = nil
	if localPlayer then
		localData = getLocalPlayerData()
	end

	local result = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local entry = {
			roblox_name = player.Name,
			display_name = player.DisplayName,
			user_id = player.UserId,
			team = player.Team and tostring(player.Team.Name) or "Neutral",
		}

		if player == localPlayer and localData then
			entry.balance = localData.Currency and localData.Currency.Money
			entry.properties = extractPropertyNames(player.UserId)
			-- добавляем beach houses из данных, если их нет в workspace
			for _, house in ipairs(localData.OwnedBeachHouses or {}) do
				local name = typeof(house) == "string" and house or (typeof(house) == "table" and (house.Name or house.name)) or tostring(house)
				local found = false
				for _, p in ipairs(entry.properties) do
					if p == name then found = true; break end
				end
				if not found then
					table.insert(entry.properties, name)
				end
			end
			entry.vehicles = extractVehicleNames(localData)
			entry.money_printers = 0
			if typeof(localData.MoneyPrinters) == "table" then
				for _ in pairs(localData.MoneyPrinters) do entry.money_printers += 1 end
			end
			entry.apartment_expires_at = localData.ApartmentPurchaseExpiresAt
		else
			entry.balance = getBalanceFromReplicatedStats(player)
			entry.properties = extractPropertyNames(player.UserId)
			entry.vehicles = {}
			entry.money_printers = nil
			entry.apartment_expires_at = nil
		end

		table.insert(result, entry)
	end
	return result
end

local data = collectServerPlayers()
local ok, json = pcall(function()
	return HttpService:JSONEncode(data)
end)
print("=== get_server_players probe v2 ===")
if ok then
	print(json)
else
	print("encode error:", tostring(json))
end
print("=== end ===")
