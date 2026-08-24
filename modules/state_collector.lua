local Players = game:GetService("Players")

local StateCollector = {}
StateCollector.__index = StateCollector

function StateCollector.new(balancePath)
	local self = setmetatable({}, StateCollector)
	self.balancePath = balancePath or "leaderstats.Cash"
	return self
end

function StateCollector:_safeGet(object, path)
	if not object then return nil end
	local current = object
	for part in path:gmatch("[^%.]+") do
		if typeof(current) == "Instance" then
			current = current:FindFirstChild(part)
		elseif typeof(current) == "table" then
			current = current[part]
		else
			return nil
		end
		if current == nil then return nil end
	end
	if typeof(current) == "Instance" and current:IsA("ValueBase") then
		return current.Value
	end
	return current
end

function StateCollector:_getLocalPlayer()
	return Players.LocalPlayer
end

function StateCollector:_getCharacter()
	local player = self:_getLocalPlayer()
	if not player then return nil end
	return player.Character
end

function StateCollector:_getHumanoidRootPart()
	local character = self:_getCharacter()
	if not character then return nil end
	return character:FindFirstChild("HumanoidRootPart")
end

function StateCollector:getLocation()
	local hrp = self:_getHumanoidRootPart()
	if hrp and hrp:IsA("BasePart") then
		local pos = hrp.Position
		return string.format("%.1f, %.1f, %.1f", pos.X, pos.Y, pos.Z)
	end
	return "unknown"
end

function StateCollector:getTeam()
	local player = self:_getLocalPlayer()
	if not player then return "unknown" end
	if player.Team then
		return tostring(player.Team.Name)
	end
	return "Neutral"
end

function StateCollector:getBalance()
	local player = self:_getLocalPlayer()
	if not player then return 0 end
	local value = self:_safeGet(player, self.balancePath)
	if typeof(value) == "number" then
		return value
	end
	return 0
end

function StateCollector:getStatus()
	local player = self:_getLocalPlayer()
	if not player then return "offline" end
	return "online"
end

function StateCollector:getNickname()
	local player = self:_getLocalPlayer()
	if not player then return "unknown" end
	return player.DisplayName or player.Name
end

function StateCollector:getServerId()
	return game.JobId or "unknown"
end

function StateCollector:getPlaceId()
	return tostring(game.PlaceId or 0)
end

function StateCollector:getAll(custom)
	local customData = {
		location = self:getLocation(),
		team = self:getTeam(),
	}
	if typeof(custom) == "table" then
		for k, v in pairs(custom) do
			customData[k] = v
		end
	end

	return {
		nickname = self:getNickname(),
		status = self:getStatus(),
		balance = self:getBalance(),
		server_id = self:getServerId(),
		place_id = self:getPlaceId(),
		custom_data = customData,
	}
end

return StateCollector
