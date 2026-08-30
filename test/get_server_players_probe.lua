--[[
    San Diego Agent — Probe: get_server_players
    =====================================================
    Тестовый скрипт. Запусти в executor'е на сервере San Diego.
    Он соберёт данные обо всех игроках и выведет JSON в консоль.
    После проверки вывода логика будет перенесена в command_engine.lua.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local BALANCE_CANDIDATES = {
	"Cash", "Money", "Balance", "Credits", "Gold", "Coins",
	"Tokens", "Points", "Gems", "Bucks", "Dollars", "Bank",
}

local PROPERTY_CONTAINER_NAMES = {
	"Properties", "Houses", "Homes", "Property", "House", "Home",
	"Apartments", "Estate", "RealEstate", "OwnedProperties",
}

local VEHICLE_CONTAINER_NAMES = {
	"Vehicles", "Cars", "Garage", "OwnedVehicles", "Cars", "Bikes",
	"Vehicle", "Car", "Boats", "Air", "Planes", "Helicopters",
}

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

local function findBalanceIn(instance)
	if not instance then return nil end
	for _, child in ipairs(instance:GetChildren()) do
		if child:IsA("ValueBase") then
			local name = child.Name:lower()
			for _, candidate in ipairs(BALANCE_CANDIDATES) do
				if name == candidate:lower() then
					local raw = child:GetAttribute("RawValue")
					if typeof(raw) == "number" then return raw end
					local parsed = parseFormattedNumber(child.Value)
					if parsed then return parsed end
				end
			end
		end
	end
	return nil
end

local function getPlayerBalance(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local bal = findBalanceIn(leaderstats)
		if bal then return bal end
	end
	local reps = player:FindFirstChild("ReplicatedStats")
	if reps then
		local bal = findBalanceIn(reps)
		if bal then return bal end
	end
	return nil
end

local function scanContainer(container, result)
	if not container then return end
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("ValueBase") then
			local val = child.Value
			local include = false
			if typeof(val) == "boolean" then
				include = val
			elseif typeof(val) == "number" then
				include = val > 0
			elseif typeof(val) == "string" then
				include = val ~= "" and val:lower() ~= "none" and val:lower() ~= "false"
			end
			if include then
				table.insert(result, child.Name)
			end
		elseif child:IsA("Folder") or child:IsA("Model") or child:IsA("Configuration") then
			-- если это папка с детьми — считаем, что каждый ребёнок — отдельный объект
			for _, grand in ipairs(child:GetChildren()) do
				table.insert(result, grand.Name)
			end
		end
	end
end

local function getPlayerProperties(player)
	local found = {}
	for _, name in ipairs(PROPERTY_CONTAINER_NAMES) do
		local container = player:FindFirstChild(name)
		if not container then
			local leaderstats = player:FindFirstChild("leaderstats")
			if leaderstats then container = leaderstats:FindFirstChild(name) end
		end
		if container then
			scanContainer(container, found)
		end
	end
	return found
end

local function getPlayerVehicles(player)
	local found = {}
	for _, name in ipairs(VEHICLE_CONTAINER_NAMES) do
		local container = player:FindFirstChild(name)
		if not container then
			local leaderstats = player:FindFirstChild("leaderstats")
			if leaderstats then container = leaderstats:FindFirstChild(name) end
		end
		if container then
			scanContainer(container, found)
		end
	end
	return found
end

local function collectServerPlayers()
	local result = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local entry = {
			roblox_name = player.Name,
			display_name = player.DisplayName,
			user_id = player.UserId,
			team = player.Team and tostring(player.Team.Name) or "Neutral",
			balance = getPlayerBalance(player),
			properties = getPlayerProperties(player),
			vehicles = getPlayerVehicles(player),
		}
		table.insert(result, entry)
	end
	return result
end

local function printSnapshot(label)
	local data = collectServerPlayers()
	local ok, json = pcall(function()
		return HttpService:JSONEncode(data)
	end)
	print("=== get_server_players probe [" .. tostring(label) .. "] ===")
	if ok then
		print(json)
	else
		print("JSON encode error:", tostring(json))
	end
	print("=== end probe ===")
	return data
end

-- Первый снимок сразу.
printSnapshot("initial")

-- Если игроки присоединяются/уходят — можно перезапустить вручную или раскомментировать:
-- task.spawn(function()
--     while true do
--         task.wait(10)
--         printSnapshot("tick")
--     end
-- end)
