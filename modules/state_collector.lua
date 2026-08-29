local Players = game:GetService("Players")

local StateCollector = {}
StateCollector.__index = StateCollector

local BALANCE_CANDIDATES = {
	"Cash", "Money", "Balance", "Credits", "Gold", "Coins",
	"Tokens", "Points", "Gems", "Bucks", "Dollars", "Bank",
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

function StateCollector.new(balancePath, version)
	local self = setmetatable({}, StateCollector)
	self.balancePath = balancePath or ""
	self.version = version or "0.0.0"
	self._cachedBalancePath = nil
	self._action = ""
	self._actionExcept = {}
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
	return current
end

function StateCollector:_findBalanceValue(instance)
	if not instance then return nil end
	local found = {}
	local function scan(obj)
		for _, child in ipairs(obj:GetChildren()) do
			if child:IsA("ValueBase") then
				local name = child.Name
				for _, candidate in ipairs(BALANCE_CANDIDATES) do
					if name:lower() == candidate:lower() then
						table.insert(found, { child, candidate })
					end
				end
			end
			scan(child)
		end
	end
	scan(instance)

	-- Приоритет отдаём NumberValue / IntValue / DoubleConstrainedValue
	table.sort(found, function(a, b)
		local priority = { NumberValue = 1, IntValue = 2, DoubleConstrainedValue = 3 }
		local pa = priority[a[1].ClassName] or 10
		local pb = priority[b[1].ClassName] or 10
		return pa < pb
	end)

	if #found > 0 then
		return found[1][1]
	end
	return nil
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

	-- 1. Если задан путь и он работает — используем его.
	if self.balancePath and self.balancePath ~= "" then
		local obj = self:_safeGet(player, self.balancePath)
		if typeof(obj) == "Instance" then
			local raw = obj:GetAttribute("RawValue")
			if typeof(raw) == "number" then
				return raw
			end
			local parsed = parseFormattedNumber(obj.Value)
			if parsed then
				return parsed
			end
		else
			local parsed = parseFormattedNumber(obj)
			if parsed then
				return parsed
			end
		end
	end

	-- 2. Используем закэшированный найденный путь.
	if self._cachedBalancePath then
		local obj = self:_safeGet(player, self._cachedBalancePath)
		if typeof(obj) == "Instance" then
			local raw = obj:GetAttribute("RawValue")
			if typeof(raw) == "number" then
				return raw
			end
			local parsed = parseFormattedNumber(obj.Value)
			if parsed then
				return parsed
			end
		else
			local parsed = parseFormattedNumber(obj)
			if parsed then
				return parsed
			end
		end
		self._cachedBalancePath = nil
	end

	-- 3. Ищем среди leaderstats, ReplicatedStats, PlayerGui, Backpack.
	local roots = {
		{ "leaderstats", player:FindFirstChild("leaderstats") },
		{ "ReplicatedStats", player:FindFirstChild("ReplicatedStats") },
		{ "PlayerGui", player:FindFirstChild("PlayerGui") },
		{ "Backpack", player:FindFirstChild("Backpack") },
	}

	for _, rootInfo in ipairs(roots) do
		local rootName, root = rootInfo[1], rootInfo[2]
		if root then
			local value = self:_findBalanceValue(root)
			if value then
				self._cachedBalancePath = rootName .. "." .. value.Name
				local raw = value:GetAttribute("RawValue")
				if typeof(raw) == "number" then
					return raw
				end
				local parsed = parseFormattedNumber(value.Value)
				return parsed or 0
			end
		end
	end

	return 0
end

function StateCollector:getBalancePath()
	return self._cachedBalancePath or self.balancePath or ""
end

function StateCollector:setStatusOverride(value)
	self._statusOverride = value
end

function StateCollector:setCommandState(status, commandName, startedAt)
	self._commandStatus = status
	self._commandName = commandName
	self._commandStartedAt = startedAt
end

function StateCollector:setAction(value)
	self._action = tostring(value or "")
end

function StateCollector:clearAction()
	self._action = ""
end

function StateCollector:setActionExcept(commaList)
	self._actionExcept = {}
	if typeof(commaList) ~= "string" then
		return
	end
	for part in commaList:gmatch("[^,]+") do
		local name = part:gsub("%s+", "")
		if name ~= "" then
			self._actionExcept[name] = true
		end
	end
end

function StateCollector:shouldResetAction(commandName)
	if commandName == "set_action" then
		return false
	end
	if self._actionExcept and self._actionExcept[commandName] then
		return false
	end
	return true
end

function StateCollector:setTimer(name, value)
	if not self._timers then
		self._timers = {}
	end
	self._timers[name] = tonumber(value) or os.time()
end

function StateCollector:getTimerElapsed(name)
	local t = self._timers and self._timers[name]
	if not t then
		return 0
	end
	return os.time() - t
end

function StateCollector:resetTimers()
	self._timers = {
		time_1 = os.time(),
	}
end

function StateCollector:getTimerNameOrDefault(name)
	return self:getTimerElapsed(name)
end

function StateCollector:_formatMskTime(timestamp)
	if not timestamp then return nil end
	local t = os.date("!*t", timestamp + 3 * 3600)
	return string.format("%04d-%02d-%02dT%02d:%02d:%02d+03:00", t.year, t.month, t.day, t.hour, t.min, t.sec)
end

function StateCollector:getStatus()
	if self._statusOverride then
		return self._statusOverride
	end
	if self._commandStatus then
		return self._commandStatus
	end
	local player = self:_getLocalPlayer()
	if not player then return "offline" end
	return "idle"
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
	local hrp = self:_getHumanoidRootPart()
	local pos = hrp and hrp:IsA("BasePart") and hrp.Position or nil

	local customData = {
		position_x = pos and math.round(pos.X * 10) / 10 or 0,
		position_y = pos and math.round(pos.Y * 10) / 10 or 0,
		position_z = pos and math.round(pos.Z * 10) / 10 or 0,
		team = self:getTeam(),
		balance = self:getBalance(),
		action = self._action or "",
		time_1 = self:getTimerElapsed("time_1"),
		time_2 = self:getTimerElapsed("time_2"),
		time_3 = self:getTimerElapsed("time_3"),
		time_4 = self:getTimerElapsed("time_4"),
		time_5 = self:getTimerElapsed("time_5"),
	}

	if self._commandName then
		customData.current_command = self._commandName
		if self._commandStartedAt then
			customData.command_started_at = self:_formatMskTime(self._commandStartedAt)
		end
	else
		customData.current_command = ""
	end

	if typeof(custom) == "table" then
		for k, v in pairs(custom) do
			customData[k] = v
		end
	end

	return {
		nickname = self:getNickname(),
		status = self:getStatus(),
		version = self.version,
		server_id = self:getServerId(),
		place_id = self:getPlaceId(),
		custom_data = customData,
	}
end

return StateCollector
