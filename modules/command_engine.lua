local Players = game:GetService("Players")

local CommandEngine = {}
CommandEngine.__index = CommandEngine

function CommandEngine.new()
	local self = setmetatable({}, CommandEngine)
	self.cancelled = false
	self.currentCommandId = nil
	return self
end

function CommandEngine:_getPlayer()
	return Players.LocalPlayer
end

function CommandEngine:_getCharacter()
	local player = self:_getPlayer()
	if not player then return nil end
	local character = player.Character
	if not character then
		-- Дадим персонажу небольшое время на загрузку.
		local ok, char = pcall(function()
			return player.CharacterAdded:Wait()
		end)
		if ok then
			character = char
		end
	end
	return character
end

function CommandEngine:_getHrp()
	local character = self:_getCharacter()
	if not character then return nil end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return hrp
	end
	-- Подождём, если HRP ещё не создан.
	local ok, found = pcall(function()
		return character:WaitForChild("HumanoidRootPart", 5)
	end)
	if ok and found and found:IsA("BasePart") then
		return found
	end
	return nil
end

function CommandEngine:_getHumanoid()
	local character = self:_getCharacter()
	if not character then return nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then return humanoid end
	local ok, found = pcall(function()
		return character:WaitForChild("Humanoid", 5)
	end)
	if ok and found and found:IsA("Humanoid") then
		return found
	end
	return nil
end

function CommandEngine:_isCancelled()
	return self.cancelled
end

function CommandEngine:resetCancel()
	self.cancelled = false
end

function CommandEngine:requestCancel()
	self.cancelled = true
end

function CommandEngine:getCommandsSpec()
	return {
		{
			name = "get_commands",
			description = "Вернуть список доступных команд",
			params = {},
		},
		{
			name = "move_x",
			description = "Сместить персонажа по оси X",
			params = {
				value = {
					type = "integer",
					required = true,
					min = -7000,
					max = 7000,
					description = "Смещение по оси X в студиях",
				},
			},
		},
		{
			name = "move_y",
			description = "Сместить персонажа по оси Y",
			params = {
				value = {
					type = "integer",
					required = true,
					min = -7000,
					max = 7000,
					description = "Смещение по оси Y в студиях",
				},
			},
		},
		{
			name = "move_z",
			description = "Сместить персонажа по оси Z",
			params = {
				value = {
					type = "integer",
					required = true,
					min = -7000,
					max = 7000,
					description = "Смещение по оси Z в студиях",
				},
			},
		},
		{
			name = "pause",
			description = "Подождать N секунд",
			params = {
				duration = {
					type = "integer",
					required = true,
					min = 0,
					max = 86400,
					description = "Длительность паузы в секундах",
				},
			},
		},
		{
			name = "respawn",
			description = "Умереть и возродиться",
			params = {},
		},
		{
			name = "cancel",
			description = "Отменить текущую команду",
			params = {},
		},
	}
end

function CommandEngine:_validateMove(payload, axis)
	-- Поддерживаем как payload.value, так и payload.x / payload.y / payload.z.
	local value = payload and (payload.value or (axis and payload[axis]))
	if typeof(value) ~= "number" then
		return false, "param 'value' must be an integer"
	end
	if value % 1 ~= 0 then
		return false, "param 'value' must be an integer"
	end
	if value < -7000 or value > 7000 then
		return false, "param 'value' out of range [-7000, 7000]"
	end
	return true, value
end

function CommandEngine:_moveAxis(axis, payload)
	local ok, value = self:_validateMove(payload, axis)
	if not ok then
		return { success = false, error = value }
	end

	local hrp = self:_getHrp()
	if not hrp then
		return { success = false, error = "HumanoidRootPart not found" }
	end

	if self:_isCancelled() then
		return { success = false, error = "cancelled" }
	end

	local pos = hrp.Position
	local startValue = pos[axis]
	local sign = value >= 0 and 1 or -1

	-- Шаги взяты из реального поведения игры San Diego:
	-- X/Z: 20 студий за шаг, пауза 0.1 с.
	-- Y: 100 студий за шаг, пауза 0.5 с.
	local stepSize, waitTime
	if axis == "y" then
		stepSize = 100 * sign
		waitTime = 0.5
	else
		stepSize = 20 * sign
		waitTime = 0.1
	end

	local steps = math.floor(math.abs(value) / math.abs(stepSize))
	local current = startValue

	for _ = 1, steps do
		if self:_isCancelled() then
			return { success = false, error = "cancelled" }
		end

		current = current + stepSize
		local newPos
		if axis == "x" then
			newPos = Vector3.new(current, pos.Y, pos.Z)
		elseif axis == "y" then
			newPos = Vector3.new(pos.X, current, pos.Z)
		else
			newPos = Vector3.new(pos.X, pos.Y, current)
		end
		hrp.CFrame = CFrame.new(newPos)
		task.wait(waitTime)
	end

	if self:_isCancelled() then
		return { success = false, error = "cancelled" }
	end

	local finalValue = startValue + value
	local finalPos
	if axis == "x" then
		finalPos = Vector3.new(finalValue, pos.Y, pos.Z)
	elseif axis == "y" then
		finalPos = Vector3.new(pos.X, finalValue, pos.Z)
	else
		finalPos = Vector3.new(pos.X, pos.Y, finalValue)
	end
	hrp.CFrame = CFrame.new(finalPos)

	return {
		success = true,
		data = {
			newPosition = {
				x = math.round(hrp.Position.X * 10) / 10,
				y = math.round(hrp.Position.Y * 10) / 10,
				z = math.round(hrp.Position.Z * 10) / 10,
			},
		},
	}
end

function CommandEngine:_pause(payload)
	local duration = payload and payload.duration
	if typeof(duration) ~= "number" then
		return { success = false, error = "param 'duration' must be an integer" }
	end
	if duration % 1 ~= 0 then
		return { success = false, error = "param 'duration' must be an integer" }
	end
	if duration < 0 or duration > 86400 then
		return { success = false, error = "param 'duration' out of range [0, 86400]" }
	end

	local elapsed = 0
	while elapsed < duration do
		if self:_isCancelled() then
			return { success = false, error = "cancelled" }
		end
		task.wait(0.1)
		elapsed = elapsed + 0.1
	end

	return { success = true, data = { elapsed = math.round(elapsed * 10) / 10 } }
end

function CommandEngine:_respawn()
	local humanoid = self:_getHumanoid()
	if not humanoid then
		return { success = false, error = "Humanoid not found" }
	end
	if self:_isCancelled() then
		return { success = false, error = "cancelled" }
	end
	humanoid.Health = 0
	return { success = true, data = { respawned = true } }
end

function CommandEngine:_cancelCurrent()
	self:requestCancel()
	return { success = true, data = { cancelledCommandId = self.currentCommandId } }
end

function CommandEngine:execute(command)
	local name = command.name
	local payload = command.payload or {}
	self.currentCommandId = command.id
	self:resetCancel()

	local result
	if name == "get_commands" then
		result = { success = true, data = { commands = self:getCommandsSpec() } }
	elseif name == "move_x" then
		result = self:_moveAxis("x", payload)
	elseif name == "move_y" then
		result = self:_moveAxis("y", payload)
	elseif name == "move_z" then
		result = self:_moveAxis("z", payload)
	elseif name == "pause" then
		result = self:_pause(payload)
	elseif name == "respawn" then
		result = self:_respawn()
	elseif name == "cancel" then
		result = self:_cancelCurrent()
	else
		result = { success = false, error = "unknown command: " .. tostring(name) }
	end

	self.currentCommandId = nil
	return result
end

return CommandEngine
