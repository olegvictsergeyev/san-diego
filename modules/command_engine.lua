local Players = game:GetService("Players")

local CommandEngine = {}
CommandEngine.__index = CommandEngine

function CommandEngine.new()
	local self = setmetatable({}, CommandEngine)
	self.cancelled = false
	self.currentCommandId = nil
	return self
end

function CommandEngine:_getHrp()
	local player = Players.LocalPlayer
	if not player then return nil end
	local character = player.Character
	if not character then return nil end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return hrp
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
			name = "cancel",
			description = "Отменить текущую команду",
			params = {},
		},
	}
end

function CommandEngine:_validateMove(payload)
	local value = payload and payload.value
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
	local ok, value = self:_validateMove(payload)
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

	local offset = Vector3.zero
	if axis == "x" then
		offset = Vector3.new(value, 0, 0)
	elseif axis == "y" then
		offset = Vector3.new(0, value, 0)
	elseif axis == "z" then
		offset = Vector3.new(0, 0, value)
	end

	hrp.CFrame = hrp.CFrame + offset

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
	elseif name == "cancel" then
		result = self:_cancelCurrent()
	else
		result = { success = false, error = "unknown command: " .. tostring(name) }
	end

	self.currentCommandId = nil
	return result
end

return CommandEngine
