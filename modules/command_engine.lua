local Players = game:GetService("Players")

local CommandEngine = {}
CommandEngine.__index = CommandEngine

function CommandEngine.new(privateServer, afk, state)
	local self = setmetatable({}, CommandEngine)
	self.cancelled = false
	self.currentCommandId = nil
	self.afk = afk
	self.state = state
	if privateServer then
		self.privateServer = privateServer
	else
		local ok, PrivateServer = pcall(function()
			return require(script.Parent:WaitForChild("private_server"))
		end)
		if ok and PrivateServer then
			self.privateServer = PrivateServer.new()
		end
	end
	return self
end

function CommandEngine:setAfk(afk)
	self.afk = afk
end

function CommandEngine:setState(state)
	self.state = state
end

function CommandEngine:isBusy()
	return self.currentCommandId ~= nil
end

function CommandEngine:_getPlayer()
	return Players.LocalPlayer
end

function CommandEngine:_getCharacter(timeout)
	timeout = tonumber(timeout) or 5
	local player = self:_getPlayer()
	if not player then
		return nil
	end
	local character = player.Character
	if character then
		return character
	end

	-- Ждём появления персонажа с таймаутом, чтобы не зависнуть навечно.
	local start = tick()
	local connection
	local newCharacter = nil

	connection = player.CharacterAdded:Connect(function(char)
		newCharacter = char
		if connection then
			connection:Disconnect()
			connection = nil
		end
	end)

	while not newCharacter and tick() - start < timeout do
		task.wait(0.05)
	end

	if connection then
		connection:Disconnect()
		connection = nil
	end

	return newCharacter
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

function CommandEngine:_getPlayerHrp(player)
	if not player then
		return nil
	end
	local character = player.Character
	if not character then
		return nil
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return hrp
	end
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
				speed = {
					type = "integer",
					required = false,
					min = 1,
					max = 10,
					description = "Скорость перемещения: 10 — максимальная (по умолчанию), 1 — в 10 раз медленнее",
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
				speed = {
					type = "integer",
					required = false,
					min = 1,
					max = 10,
					description = "Скорость перемещения: 10 — максимальная (по умолчанию), 1 — в 10 раз медленнее",
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
				speed = {
					type = "integer",
					required = false,
					min = 1,
					max = 10,
					description = "Скорость перемещения: 10 — максимальная (по умолчанию), 1 — в 10 раз медленнее",
				},
			},
		},
		{
			name = "move_to",
			description = "Переместить персонажа к целевым координатам X и Z",
			params = {
				x = {
					type = "integer",
					required = true,
					min = -7000,
					max = 7000,
					description = "Целевая координата X",
				},
				z = {
					type = "integer",
					required = true,
					min = -7000,
					max = 7000,
					description = "Целевая координата Z",
				},
				speed = {
					type = "integer",
					required = false,
					min = 1,
					max = 10,
					description = "Скорость перемещения: 10 — максимальная (по умолчанию), 1 — в 10 раз медленнее",
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
			name = "transfer_money_via_respawn",
			description = "Передавать деньги целевому игроку через respawn, пока его баланс не достигнет заданной суммы",
			params = {
				identifier = {
					type = "string",
					required = true,
					min = 1,
					max = 64,
					description = "Имя аккаунта, display name или user_id целевого игрока",
				},
				amount = {
					type = "integer",
					required = true,
					min = 0,
					max = 1000000000,
					description = "Целевой баланс, которого нужно достичь",
				},
				max_attempts = {
					type = "integer",
					required = false,
					min = 1,
					max = 500,
					description = "Максимальное число respawn'ов (по умолчанию 100)",
				},
				wait_seconds = {
					type = "integer",
					required = false,
					min = 0,
					max = 60,
					description = "Секунд между проверками после respawn (по умолчанию 5, минимум 0 — возможна переплата)",
				},
			},
		},
		{
			name = "respawn_for_money",
			description = "Одна итерация передачи денег целевому игроку: проверка, подход, respawn, повторная проверка",
			params = {
				identifier = {
					type = "string",
					required = true,
					min = 1,
					max = 64,
					description = "Имя аккаунта, display name или user_id целевого игрока",
				},
				amount = {
					type = "integer",
					required = true,
					min = 0,
					max = 1000000000,
					description = "Целевой баланс, которого нужно достичь",
				},
				wait_seconds = {
					type = "integer",
					required = false,
					min = 0,
					max = 60,
					description = "Секунд после respawn перед финальной проверкой (по умолчанию 5, минимум 0 — возможна переплата)",
				},
			},
		},
		{
			name = "place_all_printers",
			description = "Убрать все уже стоящие Money Printer в квартире и разложить их заново плотной сеткой внутри комнаты. Использует встроенные координаты комнаты (замер уже выполнен, измерять повторно не нужно). Вмещает до 50 принтеров; если Tool'ов меньше — выкладывает все.",
			params = {
				max_total = {
					type = "integer",
					required = false,
					min = 1,
					max = 50,
					description = "Максимальное суммарное число принтеров в квартире (по умолчанию 50)",
				},
				max_distance = {
					type = "integer",
					required = false,
					min = 10,
					max = 500,
					description = "Максимальное расстояние до ближайшего существующего принтера в папке (по умолчанию 200)",
				},
			},
		},
		{
			name = "jump",
			description = "Подпрыгнуть",
			params = {},
		},
		{
			name = "hold_key",
			description = "Нажать и удерживать клавишу на указанное время",
			params = {
				key = {
					type = "string",
					required = true,
					min = 1,
					max = 32,
					description = "Имя клавиши, например 'E', 'Space', 'LeftShift'",
				},
				duration = {
					type = "integer",
					required = true,
					min = 0,
					max = 60000,
					description = "Время удержания клавиши в миллисекундах (0 — просто нажать и сразу отпустить)",
				},
			},
		},
		{
			name = "cancel",
			description = "Отменить текущую команду",
			params = {},
		},
		{
			name = "afk",
			description = "Управление AFK-режимом: включить/выключить или задать интервал",
			params = {
				enabled = {
					type = "string",
					required = false,
					min = 2,
					max = 5,
					description = "Включить/выключить AFK: 'on' или 'off'",
				},
				interval = {
					type = "integer",
					required = false,
					min = 60,
					max = 3600,
					description = "Интервал незаметного действия в секундах (по умолчанию 600)",
				},
			},
		},
		{
			name = "set_action",
			description = "Установить произвольный статус действия (action) без выполнения",
			params = {
				action = {
					type = "string",
					required = true,
					min = 0,
					max = 32,
					description = "Значение action, например 'farm'. Пустая строка — сбросить.",
				},
				except = {
					type = "string",
					required = false,
					min = 0,
					max = 256,
					description = "Список команд через запятую, которые не сбрасывают action (например 'respawn, jump')",
				},
			},
		},
		{
			name = "set_team",
			description = "Сменить команду (team) персонажа",
			params = {
				team = {
					type = "string",
					required = true,
					min = 1,
					max = 32,
					description = "Имя команды, например 'Police' или 'Civilian'",
				},
			},
		},
		{
			name = "turn",
			description = "Повернуть персонажа на указанный абсолютный угол (0..360)",
			params = {
				degrees = {
					type = "integer",
					required = true,
					min = 0,
					max = 360,
					description = "Абсолютный угол в градусах",
				},
				speed = {
					type = "integer",
					required = false,
					min = 1,
					max = 10,
					description = "Скорость поворота: 10 — быстро (по умолчанию), 1 — медленно",
				},
			},
		},
		{
			name = "turn_with_camera",
			description = "Повернуть персонажа и камеру на указанный абсолютный угол (0..360)",
			params = {
				degrees = {
					type = "integer",
					required = true,
					min = 0,
					max = 360,
					description = "Абсолютный угол в градусах",
				},
				speed = {
					type = "integer",
					required = false,
					min = 1,
					max = 10,
					description = "Скорость поворота: 10 — быстро (по умолчанию), 1 — медленно",
				},
			},
		},
		{
			name = "tilt_camera",
			description = "Наклонить камеру по вертикали (без поворота персонажа)",
			params = {
				degrees = {
					type = "integer",
					required = true,
					min = -80,
					max = 80,
					description = "Вертикальный угол в градусах: положительные — вверх, отрицательные — вниз (0 — горизонт)",
				},
				speed = {
					type = "integer",
					required = false,
					min = 1,
					max = 10,
					description = "Скорость наклона: 10 — быстро (по умолчанию), 1 — медленно",
				},
			},
		},
		{
			name = "set_time",
			description = "Установить один из таймеров time_1..time_5 в текущее время или указанный timestamp",
			params = {
				name = {
					type = "string",
					required = true,
					min = 1,
					max = 6,
					description = "Имя таймера: time_1, time_2, time_3, time_4 или time_5",
				},
				value = {
					type = "integer",
					required = false,
					min = 0,
					max = 9999999999,
					description = "Unix timestamp (опционально). Если не передан — используется текущее время.",
				},
			},
		},
		{
			name = "get_custom_field",
			description = "Получить, сколько секунд прошло с момента установки указанного таймера",
			params = {
				name = {
					type = "string",
					required = true,
					min = 1,
					max = 6,
					description = "Имя таймера: time_1, time_2, time_3, time_4 или time_5",
				},
			},
		},
		{
			name = "get_server_players",
			description = "Вернуть массив объектов со всеми игроками на текущем сервере (roblox_name, display_name, user_id, team, balance, properties, money_printers)",
			params = {},
		},
		{
			name = "get_player",
			description = "Вернуть объект с данными об одном игроке по имени, display_name или user_id",
			params = {
				identifier = {
					type = "string",
					required = true,
					min = 1,
					max = 64,
					description = "Имя игрока, display name или user_id",
				},
			},
		},
		{
			name = "join_private_server",
			description = "Перейти на приватный сервер по коду",
			params = {
				code = {
					type = "string",
					required = true,
					min = 1,
					max = 64,
					description = "Код приватного сервера",
				},
			},
		},
	}
end

function CommandEngine:_mapCommandSpec(cmd)
	local params = {}
	for paramName, paramInfo in pairs(cmd.params or {}) do
		local pType = paramInfo.type
		if pType == "integer" then
			pType = "number"
		end
		local mappedParam = { type = pType }
		if paramInfo.min ~= nil then
			mappedParam.min = paramInfo.min
		end
		if paramInfo.max ~= nil then
			mappedParam.max = paramInfo.max
		end
		params[paramName] = mappedParam
	end
	return {
		name = cmd.name,
		params = params,
	}
end

function CommandEngine:getCommandsResponse()
	local spec = self:getCommandsSpec()
	local response = {}
	for _, cmd in ipairs(spec) do
		if cmd.name ~= "get_commands" then
			table.insert(response, self:_mapCommandSpec(cmd))
		end
	end
	return { commands = response }
end

function CommandEngine:_encodeGetCommandsResult()
	local response = self:getCommandsResponse()
	if not response or typeof(response.commands) ~= "table" or #response.commands == 0 then
		warn("[SanDiegoAgent][CommandEngine] get_commands response is empty, refusing to send")
		return nil
	end

	local version = "0.0.0"
	if self.state and self.state.getVersion then
		version = self.state:getVersion()
	end
	response.version = version

	local HttpService = game:GetService("HttpService")
	local ok, json = pcall(function()
		return HttpService:JSONEncode(response)
	end)
	if not ok then
		warn("[SanDiegoAgent][CommandEngine] failed to encode get_commands response:", tostring(json))
		return nil
	end
	-- Roblox HttpService кодирует пустую таблицу как [], а бэкенд требует {}.
	json = json:gsub('"params":%[%]', '"params":{}')
	return json
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

	local speed = payload and payload.speed
	if speed == nil then
		speed = 10
	elseif typeof(speed) ~= "number" or speed % 1 ~= 0 then
		return false, "param 'speed' must be an integer"
	elseif speed < 1 or speed > 10 then
		return false, "param 'speed' out of range [1, 10]"
	end

	return true, value, speed
end

function CommandEngine:_validateMoveTo(payload)
	local x = payload and payload.x
	local z = payload and payload.z
	if typeof(x) ~= "number" or x % 1 ~= 0 then
		return false, "param 'x' must be an integer"
	end
	if x < -7000 or x > 7000 then
		return false, "param 'x' out of range [-7000, 7000]"
	end
	if typeof(z) ~= "number" or z % 1 ~= 0 then
		return false, "param 'z' must be an integer"
	end
	if z < -7000 or z > 7000 then
		return false, "param 'z' out of range [-7000, 7000]"
	end

	local speed = payload and payload.speed
	if speed == nil then
		speed = 10
	elseif typeof(speed) ~= "number" or speed % 1 ~= 0 then
		return false, "param 'speed' must be an integer"
	elseif speed < 1 or speed > 10 then
		return false, "param 'speed' out of range [1, 10]"
	end

	return true, x, z, speed
end

function CommandEngine:_moveAxis(axis, payload)
	local ok, value, speed = self:_validateMove(payload, axis)
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
	local _, startYaw = hrp.CFrame:ToEulerAnglesYXZ()

	-- Базовые шаги подобраны для плавности (max speed = прежняя скорость):
	-- X/Z: 4 студии за шаг, пауза 0.02 с.
	-- Y: 20 студий за шаг, пауза 0.1 с.
	-- speed 1..10 масштабирует только длину шага, поэтому min в 10 раз медленнее.
	local baseStep, baseWait
	if axis == "y" then
		baseStep = 20
		baseWait = 0.1
	else
		baseStep = 4
		baseWait = 0.02
	end

	local stepSize = baseStep * sign * (speed / 10)
	local waitTime = baseWait

	local steps = math.floor(math.abs(value) / math.abs(stepSize))
	local current = startValue

	local function setHrpCFrame(cf)
		if hrp and hrp.Parent then
			local ok = pcall(function()
				hrp.CFrame = cf
				hrp.AssemblyLinearVelocity = Vector3.zero
			end)
			if ok then
				return true
			end
		end
		-- Если HRP пропал (например, респавн), попробуем получить новый.
		hrp = self:_getHrp()
		if hrp then
			local ok = pcall(function()
				hrp.CFrame = cf
				hrp.AssemblyLinearVelocity = Vector3.zero
			end)
			return ok
		end
		return false
	end

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
		if not setHrpCFrame(CFrame.new(newPos) * CFrame.Angles(0, startYaw, 0)) then
			return { success = false, error = "HumanoidRootPart lost during movement" }
		end
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
	if not setHrpCFrame(CFrame.new(finalPos) * CFrame.Angles(0, startYaw, 0)) then
		return { success = false, error = "HumanoidRootPart lost during movement" }
	end

	local finalHrp = self:_getHrp()
	return {
		success = true,
		data = {
			newPosition = {
				x = math.round((finalHrp and finalHrp.Position.X or finalPos.X) * 10) / 10,
				y = math.round((finalHrp and finalHrp.Position.Y or finalPos.Y) * 10) / 10,
				z = math.round((finalHrp and finalHrp.Position.Z or finalPos.Z) * 10) / 10,
			},
		},
	}
end

function CommandEngine:_moveTo(payload)
	local ok, x, z, speed = self:_validateMoveTo(payload)
	if not ok then
		return { success = false, error = x }
	end

	local hrp = self:_getHrp()
	if not hrp then
		return { success = false, error = "HumanoidRootPart not found" }
	end

	if self:_isCancelled() then
		return { success = false, error = "cancelled" }
	end

	local pos = hrp.Position
	local startX = pos.X
	local startZ = pos.Z
	local _, startYaw = hrp.CFrame:ToEulerAnglesYXZ()

	local dx = x - startX
	local dz = z - startZ
	local dist = math.sqrt(dx * dx + dz * dz)

	local function setHrpCFrame(cf)
		if hrp and hrp.Parent then
			local ok = pcall(function()
				hrp.CFrame = cf
				hrp.AssemblyLinearVelocity = Vector3.zero
			end)
			if ok then
				return true
			end
		end
		hrp = self:_getHrp()
		if hrp then
			local ok = pcall(function()
				hrp.CFrame = cf
				hrp.AssemblyLinearVelocity = Vector3.zero
			end)
			return ok
		end
		return false
	end

	if dist < 0.1 then
		if not setHrpCFrame(CFrame.new(Vector3.new(x, pos.Y, z)) * CFrame.Angles(0, startYaw, 0)) then
			return { success = false, error = "HumanoidRootPart lost" }
		end
		local finalHrp = self:_getHrp()
		return {
			success = true,
			data = {
				newPosition = {
					x = math.round((finalHrp and finalHrp.Position.X or x) * 10) / 10,
					y = math.round((finalHrp and finalHrp.Position.Y or pos.Y) * 10) / 10,
					z = math.round((finalHrp and finalHrp.Position.Z or z) * 10) / 10,
				},
			},
		}
	end

	local baseStep = 4
	local baseWait = 0.02
	local stepSize = baseStep * (speed / 10)
	local waitTime = baseWait
	local steps = math.max(1, math.floor(dist / stepSize))
	local stepX = dx / steps
	local stepZ = dz / steps

	for i = 1, steps do
		if self:_isCancelled() then
			return { success = false, error = "cancelled" }
		end

		local newX = startX + stepX * i
		local newZ = startZ + stepZ * i
		local newPos = Vector3.new(newX, pos.Y, newZ)
		if not setHrpCFrame(CFrame.new(newPos) * CFrame.Angles(0, startYaw, 0)) then
			return { success = false, error = "HumanoidRootPart lost during movement" }
		end
		task.wait(waitTime)
	end

	if self:_isCancelled() then
		return { success = false, error = "cancelled" }
	end

	if not setHrpCFrame(CFrame.new(Vector3.new(x, pos.Y, z)) * CFrame.Angles(0, startYaw, 0)) then
		return { success = false, error = "HumanoidRootPart lost during movement" }
	end

	local finalHrp = self:_getHrp()
	return {
		success = true,
		data = {
			newPosition = {
				x = math.round((finalHrp and finalHrp.Position.X or x) * 10) / 10,
				y = math.round((finalHrp and finalHrp.Position.Y or pos.Y) * 10) / 10,
				z = math.round((finalHrp and finalHrp.Position.Z or z) * 10) / 10,
			},
		},
	}
end

function CommandEngine:_chasePlayer(player, options)
    options = options or {}
    local timeout = tonumber(options.timeout) or 30
    local threshold = tonumber(options.threshold) or 10
    local heightThreshold = tonumber(options.heightThreshold) or 5
    local maxStep = tonumber(options.maxStep) or 100

    local function tryTeleportToTarget(targetHrp)
        local hrp = self:_getHrp()
        if not hrp then
            return false
        end
        local ok = pcall(function()
            -- Не меняем высоту при близком телепорте, чтобы персонаж не оказался
            -- в воздухе и не разбился при падении с крыши/возвышенности.
            -- Выравниваем только по X/Z, высоту подбираем отдельно.
            local currentY = hrp.Position.Y
            local targetPos = targetHrp.Position
            local _, yaw = hrp.CFrame:ToEulerAnglesYXZ()
            hrp.CFrame = CFrame.new(Vector3.new(targetPos.X, currentY, targetPos.Z)) * CFrame.Angles(0, yaw, 0)
            hrp.AssemblyLinearVelocity = Vector3.zero
        end)
        return ok
    end

    local start = tick()
    while tick() - start < timeout do
        if self:_isCancelled() then
            return { success = false, error = "cancelled" }
        end

        local targetHrp = self:_getPlayerHrp(player)
        local localHrp = self:_getHrp()
        if not targetHrp or not localHrp then
            warn("[SanDiegoAgent][CommandEngine] HRP lost during chase, retrying...")
            task.wait(0.1)
        else
            local tPos = targetHrp.Position
            local lPos = localHrp.Position
            local dist2d = math.sqrt((tPos.X - lPos.X) ^ 2 + (tPos.Z - lPos.Z) ^ 2)
            local dy = math.abs(tPos.Y - lPos.Y)

            if dist2d < threshold and dy < heightThreshold then
                return { success = true, data = { distance = dist2d, heightDiff = dy } }
            end

            -- Если уже близко — телепортируемся горизонтально к цели, сохраняя высоту.
            if dist2d < 25 and dy < 15 then
                if not tryTeleportToTarget(targetHrp) then
                    warn("[SanDiegoAgent][CommandEngine] close teleport failed")
                end
            else
                -- Двигаемся к цели короткими сегментами, чтобы успевать за убегающими и не тратить минуты на дальние дистанции.
                local dx2d = tPos.X - lPos.X
                local dz2d = tPos.Z - lPos.Z
                local stepRatio = dist2d > 0 and math.min(1, maxStep / dist2d) or 0
                local destX = math.round(lPos.X + dx2d * stepRatio)
                local destZ = math.round(lPos.Z + dz2d * stepRatio)

                local moveResult = self:_moveTo({ x = destX, z = destZ, speed = 10 })
                if not moveResult.success then
                    warn("[SanDiegoAgent][CommandEngine] chase horizontal move failed:", tostring(moveResult.error))
                    return { success = false, error = "chase horizontal move failed: " .. tostring(moveResult.error) }
                end
            end

            -- Корректируем высоту (крыши, этажи), но не более чем на maxStep за раз.
            -- Используем актуальную позицию цели, так как она могла смениться.
            local newHrp = self:_getHrp()
            local newTargetHrp = self:_getPlayerHrp(player)
            if newHrp and newTargetHrp then
                local newY = newHrp.Position.Y
                local targetY = newTargetHrp.Position.Y
                local dyNow = targetY - newY
                if math.abs(dyNow) > 0.5 then
                    local yValue = math.clamp(math.round(dyNow), -maxStep, maxStep)
                    local yResult = self:_moveAxis("y", { value = yValue, speed = 10 })
                    if not yResult.success then
                        warn("[SanDiegoAgent][CommandEngine] chase vertical move failed:", tostring(yResult.error))
                        return { success = false, error = "chase vertical move failed: " .. tostring(yResult.error) }
                    end
                end
            end

            task.wait(0.03)
        end
    end

    return { success = false, error = "chase timeout" }
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

	-- После возрождения сбрасываем time_2.
	local player = self:_getPlayer()
	if player and self.state and self.state.setTimer then
		local state = self.state
		local connection
		connection = player.CharacterAdded:Connect(function()
			state:setTimer("time_2")
			if connection then
				connection:Disconnect()
				connection = nil
			end
		end)
		task.delay(10, function()
			if connection then
				connection:Disconnect()
				connection = nil
			end
		end)
	end

	return { success = true, data = { respawned = true } }
end

function CommandEngine:_transferMoneyViaRespawn(payload)
	local identifier = payload and payload.identifier
	if identifier == nil or (typeof(identifier) ~= "string" and typeof(identifier) ~= "number") then
		return { success = false, error = "param 'identifier' is required (string or number)" }
	end

	local amount = payload and payload.amount
	if typeof(amount) ~= "number" or amount % 1 ~= 0 then
		return { success = false, error = "param 'amount' must be an integer" }
	end
	if amount < 0 or amount > 1000000000 then
		return { success = false, error = "param 'amount' out of range [0, 1000000000]" }
	end

	local maxAttempts = payload and payload.max_attempts
	if maxAttempts == nil then
		maxAttempts = 100
	elseif typeof(maxAttempts) ~= "number" or maxAttempts % 1 ~= 0 then
		return { success = false, error = "param 'max_attempts' must be an integer" }
	else
		maxAttempts = math.clamp(maxAttempts, 1, 500)
	end

	local waitSeconds = payload and payload.wait_seconds
	if waitSeconds == nil then
		waitSeconds = 5
	elseif typeof(waitSeconds) ~= "number" or waitSeconds % 1 ~= 0 then
		return { success = false, error = "param 'wait_seconds' must be an integer" }
	else
		waitSeconds = math.clamp(waitSeconds, 0, 60)
	end

	local targetPlayer, err = self:_resolvePlayer(identifier)
	if not targetPlayer then
		return { success = false, error = err or "target player not found" }
	end

	local player = self:_getPlayer()
	if not player then
		return { success = false, error = "LocalPlayer not found" }
	end

	local attempts = 0
	local lastBalance = nil
	while attempts < maxAttempts do
		if self:_isCancelled() then
			return { success = false, error = "cancelled" }
		end

		local balance = self:_getPlayerBalanceFromReplicatedStats(targetPlayer)
		lastBalance = balance
		warn("[SanDiegoAgent][CommandEngine] transfer attempt", attempts, "target balance", tostring(balance), "target amount", tostring(amount))
		if balance and balance >= amount then
			return {
				success = true,
				data = {
					target_user_id = targetPlayer.UserId,
					target_name = targetPlayer.Name,
					attempts = attempts,
					final_balance = balance,
					target_amount = amount,
				},
			}
		end

		-- Перед смертью всегда подбегаем к цели, чтобы деньги упали рядом.
		local chaseResult = self:_chasePlayer(targetPlayer, { timeout = 10, threshold = 1, heightThreshold = 1 })
		if not chaseResult.success then
			warn("[SanDiegoAgent][CommandEngine] failed to reach target before respawn:", tostring(chaseResult.error))
		end

		-- Ещё раз проверяем баланс после подхода: может, цель уже достигнута.
		balance = self:_getPlayerBalanceFromReplicatedStats(targetPlayer)
		lastBalance = balance
		if balance and balance >= amount then
			return {
				success = true,
				data = {
					target_user_id = targetPlayer.UserId,
					target_name = targetPlayer.Name,
					attempts = attempts,
					final_balance = balance,
					target_amount = amount,
				},
			}
		end

		-- Убиваем локального персонажа, чтобы он дропнул деньги.
		local humanoid = self:_getHumanoid()
		if humanoid and humanoid.Health > 0 then
			if self:_isCancelled() then
				return { success = false, error = "cancelled" }
			end
			humanoid.Health = 0
		end

		attempts += 1

		-- Ждём возрождения и немного дополнительного времени.
		local character = player.Character
		local added = false
		local conn
		conn = player.CharacterAdded:Connect(function()
			added = true
			if conn then
				conn:Disconnect()
				conn = nil
			end
		end)

		-- Таймаут на случай, если CharacterAdded не сработает.
		task.delay(15, function()
			if conn then
				conn:Disconnect()
				conn = nil
			end
		end)

		local waited = 0
		while not added and waited < 15 do
			if self:_isCancelled() then
				if conn then
					conn:Disconnect()
					conn = nil
				end
				return { success = false, error = "cancelled" }
			end
			task.wait(0.05)
			waited += 0.05
		end

		-- Даём время игре обновить баланс цели.
		task.wait(waitSeconds)
	end

	return {
		success = false,
		error = "max attempts reached",
		data = {
			target_user_id = targetPlayer.UserId,
			target_name = targetPlayer.Name,
			attempts = attempts,
			final_balance = lastBalance,
			target_amount = amount,
		},
	}
end

function CommandEngine:_respawnForMoney(payload)
	local identifier = payload and payload.identifier
	if identifier == nil or (typeof(identifier) ~= "string" and typeof(identifier) ~= "number") then
		return { success = false, error = "param 'identifier' is required (string or number)" }
	end

	local amount = payload and payload.amount
	if typeof(amount) ~= "number" or amount % 1 ~= 0 then
		return { success = false, error = "param 'amount' must be an integer" }
	end
	if amount < 0 or amount > 1000000000 then
		return { success = false, error = "param 'amount' out of range [0, 1000000000]" }
	end

	local waitSeconds = payload and payload.wait_seconds
	if waitSeconds == nil then
		waitSeconds = 5
	elseif typeof(waitSeconds) ~= "number" or waitSeconds % 1 ~= 0 then
		return { success = false, error = "param 'wait_seconds' must be an integer" }
	else
		waitSeconds = math.clamp(waitSeconds, 0, 60)
	end

	local targetPlayer, err = self:_resolvePlayer(identifier)
	if not targetPlayer then
		return { success = false, error = err or "target player not found" }
	end

	local player = self:_getPlayer()
	if not player then
		return { success = false, error = "LocalPlayer not found" }
	end

	if self:_isCancelled() then
		return { success = false, error = "cancelled" }
	end

	local beforeBalance = self:_getPlayerBalanceFromReplicatedStats(targetPlayer)
	warn("[SanDiegoAgent][CommandEngine] respawn_for_money start: target balance", tostring(beforeBalance), "target amount", tostring(amount))

	if beforeBalance and beforeBalance >= amount then
		return {
			success = true,
			data = {
				target_user_id = targetPlayer.UserId,
				target_name = targetPlayer.Name,
				respawned = false,
				reached = true,
				before_balance = beforeBalance,
				after_balance = beforeBalance,
				target_amount = amount,
			},
		}
	end

	-- Всегда подбегаем к цели перед смертью.
	local chaseResult = self:_chasePlayer(targetPlayer, { timeout = 10, threshold = 1, heightThreshold = 1 })
	if not chaseResult.success then
		warn("[SanDiegoAgent][CommandEngine] failed to reach target before respawn:", tostring(chaseResult.error))
	end

	local afterMoveBalance = self:_getPlayerBalanceFromReplicatedStats(targetPlayer)
	if afterMoveBalance and afterMoveBalance >= amount then
		return {
			success = true,
			data = {
				target_user_id = targetPlayer.UserId,
				target_name = targetPlayer.Name,
				respawned = false,
				reached = true,
				before_balance = beforeBalance,
				after_balance = afterMoveBalance,
				target_amount = amount,
			},
		}
	end

	local humanoid = self:_getHumanoid()
	if humanoid and humanoid.Health > 0 then
		if self:_isCancelled() then
			return { success = false, error = "cancelled" }
		end
		humanoid.Health = 0
	end

	local added = false
	local conn
	conn = player.CharacterAdded:Connect(function()
		added = true
		if conn then
			conn:Disconnect()
			conn = nil
		end
	end)
	task.delay(15, function()
		if conn then
			conn:Disconnect()
			conn = nil
		end
	end)

	local waited = 0
	while not added and waited < 15 do
		if self:_isCancelled() then
			if conn then
				conn:Disconnect()
				conn = nil
			end
			return { success = false, error = "cancelled" }
		end
		task.wait(0.05)
		waited += 0.05
	end

	task.wait(waitSeconds)

	local afterBalance = self:_getPlayerBalanceFromReplicatedStats(targetPlayer)
	local reached = afterBalance and afterBalance >= amount
	warn("[SanDiegoAgent][CommandEngine] respawn_for_money end: target balance", tostring(afterBalance), "reached", tostring(reached))

	return {
		success = true,
		data = {
			target_user_id = targetPlayer.UserId,
			target_name = targetPlayer.Name,
			respawned = true,
			reached = reached,
			before_balance = beforeBalance,
			after_balance = afterBalance,
			target_amount = amount,
		},
	}
end

function CommandEngine:_placePrinterCommand(payload)
	local player = self:_getPlayer()
	if not player then
		return { success = false, error = "LocalPlayer not found" }
	end

	local character = self:_getCharacter()
	if not character then
		return { success = false, error = "Character not found" }
	end

	local humanoid = self:_getHumanoid()
	if not humanoid then
		return { success = false, error = "Humanoid not found" }
	end

	if self:_isCancelled() then
		return { success = false, error = "cancelled" }
	end

	-- Ищем Tool-принтер в Backpack или Character.
	local printer = nil
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, child in ipairs(backpack:GetChildren()) do
			if child:IsA("Tool") and child.Name:lower():find("print") then
				printer = child
				break
			end
		end
	end
	if not printer then
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Tool") and child.Name:lower():find("print") then
				printer = child
				break
			end
		end
	end
	if not printer then
		return { success = false, error = "Money Printer not found in inventory" }
	end

	-- Определяем целевую позицию.
	local hrp = self:_getHrp()
	if not hrp then
		return { success = false, error = "HumanoidRootPart not found" }
	end

	local pos = hrp.Position
	if payload and typeof(payload.x) == "number" then
		pos = Vector3.new(payload.x, pos.Y, pos.Z)
	end
	if payload and typeof(payload.y) == "number" then
		pos = Vector3.new(pos.X, payload.y, pos.Z)
	end
	if payload and typeof(payload.z) == "number" then
		pos = Vector3.new(pos.X, pos.Y, payload.z)
	end

	-- Ищем ближайшую папку MoneyPrinters, используя позиции уже стоящих принтеров.
	local function findMoneyPrintersFolder()
		local closest = nil
		local closestDist = math.huge
		local function scan(parent)
			for _, c in ipairs(parent:GetChildren()) do
				if c.Name == "MoneyPrinters" and (c:IsA("Folder") or c:IsA("Model")) then
					local dist = math.huge
					-- Сначала считаем расстояние до ближайшего существующего принтера.
					for _, child in ipairs(c:GetChildren()) do
						if child.Name:lower():find("print") then
							local part = child:FindFirstChild("Printer_d") or child:FindFirstChild("Handle")
							if part and part:IsA("BasePart") then
								local d = (part.Position - pos).Magnitude
								if d < dist then
									dist = d
								end
							end
						end
					end
					-- Если папка пустая — берём позицию любой BasePart в родителе.
					if dist == math.huge then
						local function findPart(p)
							for _, cc in ipairs(p:GetChildren()) do
								if cc:IsA("BasePart") then
									return cc.Position
								end
								local f = findPart(cc)
								if f then
									return f
								end
							end
							return nil
						end
						local pPos = findPart(c.Parent)
						if pPos then
							dist = (pPos - pos).Magnitude
						end
					end
					if dist < closestDist then
						closestDist = dist
						closest = c
					end
				end
				if not c:IsA("BasePart") then
					scan(c)
				end
			end
		end
		scan(workspace)
		return closest, closestDist
	end

	local folder, dist = findMoneyPrintersFolder()
	if not folder then
		return { success = false, error = "MoneyPrinters folder not found" }
	end
	if dist > 200 then
		return { success = false, error = "MoneyPrinters folder too far: " .. tostring(math.round(dist * 10) / 10) }
	end

	-- Unequip текущий инструмент.
	local currentTool = character:FindFirstChildOfClass("Tool")
	if currentTool then
		currentTool.Parent = backpack
		task.wait(0.3)
	end

	-- Экипируем и сразу перемещаем в папку.
	if self:_isCancelled() then
		return { success = false, error = "cancelled" }
	end

	printer.Parent = character
	task.wait(0.3)

	if self:_isCancelled() then
		return { success = false, error = "cancelled" }
	end

	local ok, err = pcall(function()
		humanoid:UnequipTools()
		task.wait(0.3)
		printer.Parent = folder

		local handle = printer:FindFirstChild("Handle")
		local printerD = printer:FindFirstChild("Printer_d")
		if handle and handle:IsA("BasePart") then
			handle.CFrame = CFrame.new(pos)
			handle.Anchored = true
			handle.CanCollide = true
		end
		if printerD and printerD:IsA("BasePart") then
			printerD.CFrame = CFrame.new(pos)
			printerD.Anchored = true
			printerD.CanCollide = true
		end
	end)

	if not ok then
		return { success = false, error = "failed to place printer: " .. tostring(err) }
	end

	task.wait(0.5)

	return {
		success = true,
		data = {
			printer_name = printer.Name,
			folder = folder:GetFullName(),
			position = {
				x = math.round(pos.X * 10) / 10,
				y = math.round(pos.Y * 10) / 10,
				z = math.round(pos.Z * 10) / 10,
			},
			placed_path = printer.Parent and printer:GetFullName() or "destroyed",
			distance_to_folder = math.round(dist * 10) / 10,
		},
	}
end

-- Printer placement helpers (region-based)
local function findNearestMoneyPrintersFolder(playerPos)
	local folders = {}
	local seen = {}
	local function scan(parent, depth)
		if depth > 8 then return end
		for _, c in ipairs(parent:GetChildren()) do
			if c.Name == "MoneyPrinters" and not seen[c] and
			   (c:IsA("Folder") or c:IsA("Model") or c:IsA("Configuration")) then
				seen[c] = true
				table.insert(folders, c)
			end
			if not c:IsA("BasePart") then
				scan(c, depth + 1)
			end
		end
	end
	scan(game:GetService("Workspace"), 0)
	if #folders == 0 then return nil, nil end
	local best = folders[1]
	local bestDist = math.huge
	for _, f in ipairs(folders) do
		local dist = math.huge
		for _, child in ipairs(f:GetChildren()) do
			local part = child:FindFirstChild("Printer_d") or child:FindFirstChild("Handle")
			if part and part:IsA("BasePart") then
				local d = (part.Position - playerPos).Magnitude
				if d < dist then dist = d end
			end
		end
		if dist == math.huge then
			-- empty folder: distance to any BasePart in parent
			local function findPart(p)
				for _, cc in ipairs(p:GetChildren()) do
					if cc:IsA("BasePart") then return cc.Position end
					local fp = findPart(cc)
					if fp then return fp end
				end
				return nil
			end
			local pPos = findPart(f.Parent)
			if pPos then dist = (pPos - playerPos).Magnitude end
		end
		if dist < bestDist then
			bestDist = dist
			best = f
		end
	end
	return best, bestDist
end

local function getPrinterPlacementInfo(folder)
	local existing = {}
	local positions = {}
	local partSize = nil
	local floorLocalY = nil
	local regionCF, regionSize

	-- Try to get region from an existing real printer (Model, not Tool)
	for _, c in ipairs(folder:GetChildren()) do
		local isPrinter = c.Name:lower():find("print") or c:HasTag("MoneyPrinter")
		if isPrinter and not c:IsA("Tool") then
			table.insert(existing, c)
			local part = c:FindFirstChild("Printer_d") or c:FindFirstChild("Handle")
			if part and part:IsA("BasePart") then
				table.insert(positions, part.Position)
				partSize = part.Size
			end
			local rc = c:GetAttribute("MoneyPrinterApartmentRegionCFrame")
			local rs = c:GetAttribute("MoneyPrinterApartmentRegionSize")
			if typeof(rc) == "CFrame" and typeof(rs) == "Vector3" then
				regionCF = rc
				regionSize = rs
				if part and typeof(part.Position) == "Vector3" then
					local lp = rc:PointToObjectSpace(part.Position)
					floorLocalY = lp.Y
				end
			end
		end
	end

	-- Fallback 1: BasePart named "Region" in the apartment unit (most reliable)
	if typeof(regionCF) ~= "CFrame" and folder.Parent then
		local regionPart = folder.Parent:FindFirstChild("Region")
		if regionPart and regionPart:IsA("BasePart") then
			regionCF = regionPart.CFrame
			regionSize = regionPart.Size
		end
	end

	-- Fallback 2: attributes on folder ancestors
	if typeof(regionCF) ~= "CFrame" then
		local p = folder.Parent
		while p do
			local rc = p:GetAttribute("MoneyPrinterApartmentRegionCFrame")
			local rs = p:GetAttribute("MoneyPrinterApartmentRegionSize")
			if typeof(rc) == "CFrame" and typeof(rs) == "Vector3" then
				regionCF = rc
				regionSize = rs
				break
			end
			p = p.Parent
		end
	end

	-- Fallback 3: search descendants of folder parent for attributes
	if typeof(regionCF) ~= "CFrame" and folder.Parent then
		local function scan(parent, depth)
			if depth > 5 then return end
			for _, c in ipairs(parent:GetChildren()) do
				if c ~= folder then
					local rc = c:GetAttribute("MoneyPrinterApartmentRegionCFrame")
					local rs = c:GetAttribute("MoneyPrinterApartmentRegionSize")
					if typeof(rc) == "CFrame" and typeof(rs) == "Vector3" then
						regionCF = rc
						regionSize = rs
						return
					end
				end
				scan(c, depth + 1)
			end
		end
		scan(folder.Parent, 0)
	end

	-- If we have region but no floor height, try to find a floor part in the unit
	if typeof(regionCF) == "CFrame" and typeof(regionSize) == "Vector3" and not floorLocalY and folder.Parent then
		local bestFloorY = nil
		local bestArea = 0
		local function scanFloor(parent, depth)
			if depth > 3 then return end
			for _, c in ipairs(parent:GetChildren()) do
				if c ~= folder and c:IsA("BasePart") then
					local size = c.Size
					local area = size.X * size.Z
					local bottomY = c.Position.Y - size.Y / 2
					local lp = regionCF:PointToObjectSpace(Vector3.new(0, bottomY, 0))
					-- Only consider parts near the bottom half of the region and with large top area
					if lp.Y < 0 and area > bestArea then
						bestArea = area
						bestFloorY = lp.Y
					end
				end
				scanFloor(c, depth + 1)
			end
		end
		scanFloor(folder.Parent, 0)
		if bestFloorY then
			local s = partSize or Vector3.new(2, 0.5, 2)
			local spacing = math.max(s.X, s.Z)
			floorLocalY = bestFloorY + spacing * 0.5
		end
	end

	-- Final fallback: estimate floor at lower bound + half spacing
	if typeof(regionCF) == "CFrame" and typeof(regionSize) == "Vector3" and not floorLocalY then
		local s = partSize or Vector3.new(2, 0.5, 2)
		local spacing = math.max(s.X, s.Z)
		local halfY = regionSize.Y / 2
		floorLocalY = -halfY + spacing * 0.5
	end

	local orientationCF
	if typeof(regionCF) == "CFrame" then
		orientationCF = regionCF - regionCF.Position
	else
		orientationCF = CFrame.new()
	end
	return {
		folder = folder,
		existing = existing,
		positions = positions,
		regionCF = regionCF,
		regionSize = regionSize,
		floorLocalY = floorLocalY,
		partSize = partSize,
		orientationCF = orientationCF,
	}
end

local function inferGridSpacing(info)
	local spacing = 4
	if #info.positions < 2 or typeof(info.regionCF) ~= "CFrame" then
		return spacing
	end
	local locals = {}
	for _, pos in ipairs(info.positions) do
		table.insert(locals, info.regionCF:PointToObjectSpace(pos))
	end
	local xDists = {}
	local zDists = {}
	for i = 1, #locals do
		for j = i + 1, #locals do
			local dx = math.abs(locals[i].X - locals[j].X)
			local dz = math.abs(locals[i].Z - locals[j].Z)
			if dx > 0.5 and dx < 20 then table.insert(xDists, dx) end
			if dz > 0.5 and dz < 20 then table.insert(zDists, dz) end
		end
	end
	local function median(t)
		if #t == 0 then return nil end
		table.sort(t)
		return t[math.floor(#t / 2) + 1]
	end
	local mx = median(xDists)
	local mz = median(zDists)
	if mx and mz then
		spacing = math.min(mx, mz)
	elseif mx then
		spacing = mx
	elseif mz then
		spacing = mz
	end
	if spacing <= 0 then spacing = 4 end
	return spacing
end

local function generateSlotsInRegion(info, playerPos, maxCount)
	if typeof(info.regionCF) ~= "CFrame" or typeof(info.regionSize) ~= "Vector3" or not info.floorLocalY then
		return nil, "no region attributes on existing printers"
	end
	local size = info.partSize or Vector3.new(4, 4, 4)
	local spacing = math.max(size.X, size.Z)
	local margin = spacing
	local half = info.regionSize / 2
	local minX = -half.X + margin
	local maxX = half.X - margin
	local minZ = -half.Z + margin
	local maxZ = half.Z - margin
	if minX > maxX then minX, maxX = maxX, minX end
	if minZ > maxZ then minZ, maxZ = maxZ, minZ end
	if minX >= maxX or minZ >= maxZ then
		margin = math.min(half.X, half.Z) - 0.5
		minX = -half.X + margin
		maxX = half.X - margin
		minZ = -half.Z + margin
		maxZ = half.Z - margin
	end
	if minX >= maxX or minZ >= maxZ then
		return nil, "region too small for printer size"
	end

	local playerLocal = info.regionCF:PointToObjectSpace(playerPos)
	local startX = playerLocal.X < 0 and minX or maxX
	local stepX = playerLocal.X < 0 and spacing or -spacing
	local startZ = playerLocal.Z < 0 and minZ or maxZ
	local stepZ = playerLocal.Z < 0 and spacing or -spacing

	local occupied = {}
	local function key(x, z)
		return tostring(math.round(x / (spacing / 2))) .. "," .. tostring(math.round(z / (spacing / 2)))
	end
	for _, pos in ipairs(info.positions) do
		local lp = info.regionCF:PointToObjectSpace(pos)
		occupied[key(lp.X, lp.Z)] = true
	end

	local slots = {}
	local function addSlot(lx, lz)
		if #slots >= maxCount then return end
		local k = key(lx, lz)
		if occupied[k] then return end
		for _, pos in ipairs(info.positions) do
			local lp = info.regionCF:PointToObjectSpace(pos)
			local d = math.sqrt((lp.X - lx) ^ 2 + (lp.Z - lz) ^ 2)
			if d < spacing * 0.8 then return end
		end
		local worldPos = info.regionCF:PointToWorldSpace(Vector3.new(lx, info.floorLocalY, lz))
		table.insert(slots, worldPos)
	end

	local z = startZ
	while (stepZ > 0 and z <= maxZ) or (stepZ < 0 and z >= minZ) do
		local x = startX
		while (stepX > 0 and x <= maxX) or (stepX < 0 and x >= minX) do
			addSlot(x, z)
			if #slots >= maxCount then break end
			x += stepX
		end
		if #slots >= maxCount then break end
		z += stepZ
	end

	return slots, nil, spacing
end

local function placeToolInFolder(tool, folder, targetPos, orientationCF)
	-- Remember existing real printers so we don't mistake them for a new conversion
	local existingIds = {}
	for _, c in ipairs(folder:GetChildren()) do
		if c ~= tool and (c.Name:lower():find("print") or c:HasTag("MoneyPrinter")) then
			local id = c:GetAttribute("MoneyPrinterId")
			if id then
				existingIds[id] = true
			end
		end
	end

	local ok, err = pcall(function()
		tool.Parent = folder
		local handle = tool:FindFirstChild("Handle")
		local printerD = tool:FindFirstChild("Printer_d")
		local targetCF = CFrame.new(targetPos) * orientationCF
		if handle and handle:IsA("BasePart") then
			handle.CFrame = targetCF
			handle.Anchored = true
			handle.CanCollide = true
		end
		if printerD and printerD:IsA("BasePart") then
			printerD.CFrame = targetCF
			printerD.Anchored = true
			printerD.CanCollide = true
		end
	end)
	if not ok then
		return false, tostring(err)
	end

	-- wait for server conversion
	local conversionId = nil
	for i = 1, 45 do
		task.wait(0.2)
		if tool.Parent ~= folder then
			-- Tool was destroyed/replaced. Look for a new Model with MoneyPrinterId.
			for _, c in ipairs(folder:GetChildren()) do
				if c ~= tool and (c.Name:lower():find("print") or c:HasTag("MoneyPrinter")) then
					local id = c:GetAttribute("MoneyPrinterId")
					if id and not existingIds[id] then
						return true
					end
				end
			end
		end
		if tool.Parent == folder and tool:GetAttribute("MoneyPrinterId") then
			return true
		end
		for _, c in ipairs(folder:GetChildren()) do
			if c ~= tool and (c.Name:lower():find("print") or c:HasTag("MoneyPrinter")) then
				local id = c:GetAttribute("MoneyPrinterId")
				if id and not existingIds[id] then
					return true
				end
			end
		end
	end
	return false, "conversion timeout"
end

function CommandEngine:_placeAllPrintersCommand(payload)
	local player = self:_getPlayer()
	if not player then
		return { success = false, error = "LocalPlayer not found" }
	end

	local character = self:_getCharacter()
	if not character then
		return { success = false, error = "Character not found" }
	end

	local humanoid = self:_getHumanoid()
	if not humanoid then
		return { success = false, error = "Humanoid not found" }
	end

	if self:_isCancelled() then
		return { success = false, error = "cancelled" }
	end

	local maxTotal = payload and payload.max_total
	if maxTotal == nil then
		maxTotal = 50
	elseif typeof(maxTotal) ~= "number" or maxTotal % 1 ~= 0 then
		return { success = false, error = "param 'max_total' must be an integer" }
	elseif maxTotal < 1 or maxTotal > 50 then
		return { success = false, error = "param 'max_total' out of range [1, 50]" }
	end

	local maxDistance = payload and payload.max_distance
	if maxDistance == nil then
		maxDistance = 200
	elseif typeof(maxDistance) ~= "number" or maxDistance % 1 ~= 0 then
		return { success = false, error = "param 'max_distance' must be an integer" }
	elseif maxDistance < 10 or maxDistance > 500 then
		return { success = false, error = "param 'max_distance' out of range [10, 500]" }
	end

	local backpack = player:FindFirstChild("Backpack")
	if not backpack then
		return { success = false, error = "Backpack not found" }
	end

	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Workspace = game:GetService("Workspace")

	local function countPrintersInBackpack()
		local count = 0
		for _, c in ipairs(backpack:GetChildren()) do
			if c:IsA("Tool") and c.Name:lower():find("print") then
				count += 1
			end
		end
		return count
	end

	local function takePrinterFromBackpack()
		for _, c in ipairs(backpack:GetChildren()) do
			if c:IsA("Tool") and c.Name:lower():find("print") then
				return c
			end
		end
		return nil
	end

	local function getToolSize()
		for _, c in ipairs(backpack:GetChildren()) do
			if c:IsA("Tool") and c.Name:lower():find("print") then
				local part = c:FindFirstChild("Printer_d") or c:FindFirstChild("Handle")
				if part and part:IsA("BasePart") then
					return math.max(part.Size.X, part.Size.Z)
				end
			end
		end
		return 4
	end

	local function getRealPrinterIds(folder)
		local ids = {}
		for _, c in ipairs(folder:GetChildren()) do
			if c:IsA("Model") then
				local id = c:GetAttribute("MoneyPrinterId")
				if id then ids[id] = true end
			end
		end
		return ids
	end

	local function countRealPrintersFromIds(ids)
		local n = 0
		for _ in pairs(ids) do n += 1 end
		return n
	end

	local function findNearestMoneyPrintersFolder(pos)
		local best, bestDist = nil, math.huge
		local seen = {}
		local function scan(parent, depth)
			if depth > 8 then return end
			for _, c in ipairs(parent:GetChildren()) do
				if c.Name == "MoneyPrinters" and not seen[c] and
				   (c:IsA("Folder") or c:IsA("Model") or c:IsA("Configuration")) then
					seen[c] = true
					local d = math.huge
					for _, p in ipairs(c:GetChildren()) do
						local part = p:FindFirstChild("Printer_d") or p:FindFirstChild("Handle") or p:FindFirstChildWhichIsA("BasePart")
						if part and part:IsA("BasePart") then
							d = math.min(d, (part.Position - pos).Magnitude)
						end
					end
					if d < bestDist then bestDist = d; best = c end
				end
				if not c:IsA("BasePart") then scan(c, depth + 1) end
			end
		end
		scan(Workspace, 0)
		return best, bestDist
	end

	local hrp = self:_getHrp()
	if not hrp then
		return { success = false, error = "HumanoidRootPart not found" }
	end

	local folder, folderDist = findNearestMoneyPrintersFolder(hrp.Position)
	if not folder then
		return { success = false, error = "MoneyPrinters folder not found" }
	end
	if folderDist > maxDistance then
		return { success = false, error = "MoneyPrinters folder too far: " .. tostring(math.round(folderDist * 10) / 10) }
	end

	-- Measured room bounds. Prefer getgenv().RoomPerimeter, else hardcoded fallback.
	local bounds
	if typeof(getgenv) == "function" then
		local ok, gp = pcall(getgenv)
		if ok and gp and gp.RoomPerimeter then
			bounds = gp.RoomPerimeter
		end
	end
	if not bounds then
		bounds = {
			minX = 997.1759033203125,
			maxX = 1010.9700927734375,
			minZ = -5993.724609375,
			maxZ = -5977.5517578125,
			floorY = -49.74806213378906,
		}
	end

	local function getExistingModelFootprint()
		for _, c in ipairs(folder:GetChildren()) do
			if c:IsA("Model") and c:GetAttribute("MoneyPrinterId") then
				local ok, ext = pcall(function() return c:GetExtentsSize() end)
				if ok and ext then
					return math.max(ext.X, ext.Z)
				end
			end
		end
		return nil
	end

	-- Collect all existing printers (remove old layout)
	local pickupRemote = ReplicatedStorage:FindFirstChild("__remotes", true)
	if pickupRemote then
		pickupRemote = pickupRemote:FindFirstChild("MoneyPrinterService")
		if pickupRemote then pickupRemote = pickupRemote:FindFirstChild("PickupMoneyPrinter") end
	end

	local function tryFirePrompt(obj)
		if not obj then return false end
		local prompt = obj:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			local ok = pcall(function() fireproximityprompt(prompt) end)
			if ok then return true end
		end
		local clicker = obj:FindFirstChildOfClass("ClickDetector")
		if clicker then
			local ok = pcall(function() fireclickdetector(clicker) end)
			if ok then return true end
		end
		return false
	end

	local function tryRemoteCollect(model)
		if not pickupRemote then return false end
		for _, args in ipairs({ { model }, { model, hrp.Position }, { folder, model }, {} }) do
			local ok, res = pcall(function() return pickupRemote:InvokeServer(unpack(args)) end)
			if ok then return true end
		end
		return false
	end

	local function collectPrinter(model)
		local part = model:FindFirstChild("Printer_d") or model:FindFirstChild("Handle") or model:FindFirstChildWhichIsA("BasePart")
		if part then
			local h = self:_getHrp()
			if h then
				h.CFrame = CFrame.new(part.Position + Vector3.new(0, 3, 0))
			end
			task.wait(0.2)
		end
		if tryRemoteCollect(model) then return true end
		if tryFirePrompt(model) then return true end
		for _, d in ipairs(model:GetDescendants()) do
			if tryFirePrompt(d) then return true end
		end
		local ok = pcall(function() model.Parent = backpack end)
		return ok
	end

	for attempt = 1, 3 do
		local remaining = {}
		for _, c in ipairs(folder:GetChildren()) do
			if c.Name:lower():find("print") then
				table.insert(remaining, c)
			end
		end
		if #remaining == 0 then break end
		for _, c in ipairs(remaining) do
			if c.Parent == folder then
				collectPrinter(c)
				task.wait(0.2)
			end
		end
		task.wait(0.5)
	end

	-- Delete leftover fakes
	for _, c in ipairs(folder:GetChildren()) do
		if c.Name:lower():find("print") and not c:GetAttribute("MoneyPrinterId") then
			pcall(function() c:Destroy() end)
		end
	end
	task.wait(0.2)

	local startBackpackCount = countPrintersInBackpack()
	if startBackpackCount == 0 then
		return { success = false, error = "No Money Printer tools in backpack" }
	end

	local existingFootprint = getExistingModelFootprint()
	local toolSize = getToolSize()
	local size = existingFootprint and math.min(existingFootprint, toolSize) or toolSize
	local half = size / 2

	-- Grid calculation: fit up to maxTotal (default 50)
	local widthX = bounds.maxX - bounds.minX
	local widthZ = bounds.maxZ - bounds.minZ

	local rowDir, colDir, lengthAxis, widthAxis
	local minL, maxL, minW, maxW
	if widthZ >= widthX then
		rowDir = Vector3.new(0, 0, 1)
		colDir = Vector3.new(1, 0, 0)
		lengthAxis, widthAxis = "Z", "X"
		minL, maxL = bounds.minZ, bounds.maxZ
		minW, maxW = bounds.minX, bounds.maxX
	else
		rowDir = Vector3.new(1, 0, 0)
		colDir = Vector3.new(0, 0, 1)
		lengthAxis, widthAxis = "X", "Z"
		minL, maxL = bounds.minX, bounds.maxX
		minW, maxW = bounds.minZ, bounds.maxZ
	end

	local colSideMargin = half  -- 0.5 * size: margin on parallel walls
	local endMargin = half      -- 0.5 * size: margin on far wall
	local desiredStartMargin = size * 2.5
	local minSpacing = size * 0.55 -- allow up to 45% overlap within a row

	-- Compute how many columns fit with the desired start margin
	local availableLength = maxL - minL - desiredStartMargin - endMargin - size
	local targetCols = math.floor(availableLength / minSpacing) + 1
	targetCols = math.max(5, math.min(12, targetCols))

	local maxStartMargin = maxL - minL - endMargin - size - (targetCols - 1) * minSpacing
	local rowStartMargin = math.min(desiredStartMargin, math.max(size, maxStartMargin))
	local rowSpacing = (maxL - minL - rowStartMargin - endMargin - size) / math.max(1, targetCols - 1)

	-- Compute rows
	local availableWidth = maxW - minW - 2 * colSideMargin - size
	local targetRows = math.max(1, math.floor(availableWidth / size) + 1)
	targetRows = math.min(targetRows, math.ceil(maxTotal / targetCols))

	local startL = minL + rowStartMargin + half
	local startW = minW + colSideMargin + half
	local colSpacing = size

	local capacity = targetCols * targetRows
	local totalToPlace = math.min(startBackpackCount, capacity, maxTotal)

	local knownIds = getRealPrinterIds(folder)
	local initialCount = countRealPrintersFromIds(knownIds)

	local results = {
		placed = 0,
		failed = 0,
		errors = {},
	}

	local function placeSlot(slotIndex, row, col)
		local targetL = startL + (col - 1) * rowSpacing
		local targetW = startW + (row - 1) * colSpacing
		local targetPos
		if lengthAxis == "Z" then
			targetPos = Vector3.new(targetW, bounds.floorY, targetL)
		else
			targetPos = Vector3.new(targetL, bounds.floorY, targetW)
		end

		local tool = takePrinterFromBackpack()
		if not tool then
			return false, "no more tools"
		end

		local ok, success, err = pcall(function()
			local h = self:_getHrp()
			if h then
				h.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
			end
			task.wait(0.2)
			local hum = self:_getHumanoid()
			if hum then
				pcall(function() hum:UnequipTools() end)
				task.wait(0.1)
				pcall(function() hum:EquipTool(tool) end)
				task.wait(0.2)
			end
			pcall(function() tool:Activate() end)
			for _ = 1, 20 do
				task.wait(0.15)
				for _, c in ipairs(folder:GetChildren()) do
					if c:IsA("Model") then
						local id = c:GetAttribute("MoneyPrinterId")
						if id and not knownIds[id] then
							knownIds[id] = true
							task.wait(0.3)
							return true
						end
					end
				end
			end
			return false, "conversion timeout"
		end)

		if ok and success == true then
			results.placed += 1
			return true
		else
			results.failed += 1
			table.insert(results.errors, {
				slot = slotIndex,
				row = row,
				col = col,
				pos = { x = math.round(targetPos.X * 10) / 10, y = math.round(targetPos.Y * 10) / 10, z = math.round(targetPos.Z * 10) / 10 },
				error = tostring((ok and err) or success or "unknown"),
			})
			pcall(function()
				if tool and tool.Parent then tool.Parent = backpack end
			end)
			return false, err
		end
	end

	local slotIndex = 1
	for row = 1, targetRows do
		if slotIndex > totalToPlace then break end
		local leftCol = 1
		local rightCol = targetCols
		local rowPlaced = 0
		while leftCol <= rightCol and slotIndex <= totalToPlace do
			if placeSlot(slotIndex, row, leftCol) then rowPlaced += 1 end
			slotIndex += 1
			task.wait(0.6)
			if leftCol < rightCol and slotIndex <= totalToPlace then
				if placeSlot(slotIndex, row, rightCol) then rowPlaced += 1 end
				slotIndex += 1
				task.wait(0.6)
			end
			leftCol += 1
			rightCol -= 1
		end
	end

	local finalBackpackCount = countPrintersInBackpack()
	local finalRealCount = countRealPrintersFromIds(knownIds)

	return {
		success = true,
		data = {
			folder = folder:GetFullName(),
			folder_distance = math.round(folderDist * 10) / 10,
			start_backpack = startBackpackCount,
			start_folder = initialCount,
			placed = results.placed,
			failed = results.failed,
			remaining_backpack = finalBackpackCount,
			final_real_printers = finalRealCount,
			target_total = totalToPlace,
			grid_cols = targetCols,
			grid_rows = targetRows,
			row_spacing = math.round(rowSpacing * 100) / 100,
			col_spacing = math.round(colSpacing * 100) / 100,
			bounds = {
				minX = bounds.minX, maxX = bounds.maxX,
				minZ = bounds.minZ, maxZ = bounds.maxZ,
				floorY = bounds.floorY,
			},
			errors = results.errors,
		},
	}
end

function CommandEngine:_jumpCommand()
	local humanoid = self:_getHumanoid()
	if not humanoid then
		return { success = false, error = "Humanoid not found" }
	end
	if humanoid.Health <= 0 then
		return { success = false, error = "Humanoid is dead" }
	end
	pcall(function()
		humanoid.PlatformStand = false
		humanoid.Sit = false
		humanoid.Jump = true
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end)
	return { success = true, data = { jumped = true } }
end

function CommandEngine:_holdKeyCommand(payload)
	local key = payload and payload.key
	if typeof(key) ~= "string" or #key == 0 or #key > 32 then
		return { success = false, error = "param 'key' must be a non-empty string" }
	end

	key = key:upper()
	local keyCode = Enum.KeyCode[key]
	if not keyCode then
		return { success = false, error = "unknown key: " .. tostring(key) }
	end

	local duration = payload and payload.duration
	if typeof(duration) ~= "number" or duration % 1 ~= 0 then
		return { success = false, error = "param 'duration' must be an integer (ms)" }
	end
	if duration < 0 or duration > 60000 then
		return { success = false, error = "param 'duration' out of range [0, 60000]" }
	end

	local VirtualInputManager = game:GetService("VirtualInputManager")

	local function sendPress(pressed)
		pcall(function()
			VirtualInputManager:SendKeyEvent(pressed, keyCode, false, game)
		end)
	end

	sendPress(true)

	if duration > 0 then
		-- Запускаем отпускание клавиши в фоне, чтобы команда не блокировала воркер.
		local connection
		connection = task.delay(duration / 1000, function()
			sendPress(false)
			if connection then
				connection = nil
			end
		end)
	else
		task.wait()
		sendPress(false)
	end

	return { success = true, data = { key = key, durationMs = duration } }
end

function CommandEngine:_validateTurn(payload)
	local degrees = payload and payload.degrees
	if typeof(degrees) ~= "number" then
		return false, "param 'degrees' must be an integer"
	end
	if degrees % 1 ~= 0 then
		return false, "param 'degrees' must be an integer"
	end
	if degrees < 0 or degrees > 360 then
		return false, "param 'degrees' out of range [0, 360]"
	end
	return true, degrees
end

function CommandEngine:_normalizeAngle(angle)
	while angle < 0 do
		angle = angle + 2 * math.pi
	end
	while angle >= 2 * math.pi do
		angle = angle - 2 * math.pi
	end
	return angle
end

function CommandEngine:_getYaw(cframe)
	local _, yaw = cframe:ToEulerAnglesYXZ()
	return self:_normalizeAngle(yaw)
end

function CommandEngine:_shortestAngleDiff(current, target)
	local diff = target - current
	return math.atan2(math.sin(diff), math.cos(diff))
end

function CommandEngine:_smoothTurn(targetDegrees, withCamera, turnSpeed)
	local ok, degrees = self:_validateTurn({ degrees = targetDegrees })
	if not ok then
		return { success = false, error = degrees }
	end

	self:releaseCamera()

	turnSpeed = tonumber(turnSpeed) or 10
	if type(turnSpeed) ~= "number" or turnSpeed % 1 ~= 0 or turnSpeed < 1 or turnSpeed > 10 then
		return { success = false, error = "param 'speed' must be an integer in [1, 10]" }
	end

	local hrp = self:_getHrp()
	if not hrp then
		return { success = false, error = "HumanoidRootPart not found" }
	end

	local humanoid = self:_getHumanoid()
	local camera = workspace.CurrentCamera
	local originalAutoRotate = humanoid and humanoid.AutoRotate

	if humanoid then
		pcall(function()
			humanoid.AutoRotate = false
		end)
	end

	local currentYaw = self:_getYaw(hrp.CFrame)
	local targetYaw = math.rad(degrees)
	local diff = self:_shortestAngleDiff(currentYaw, targetYaw)

	local function ensureHrp()
		if hrp and hrp.Parent then
			return hrp
		end
		hrp = self:_getHrp()
		return hrp
	end

	-- Начальный угол камеры может отличаться от угла персонажа.
	-- Поворачиваем камеру плавно от её текущего положения к целевому.
	local startCameraYaw = (camera and self:_getYaw(camera.CFrame)) or currentYaw
	local cameraDiff = self:_shortestAngleDiff(startCameraYaw, targetYaw)

	-- Длительность считаем по большему из двух углов (персонаж или камера),
	-- чтобы камера тоже поворачивалась плавно, даже если персонаж уже на месте.
	local maxDiff = math.max(math.abs(diff), math.abs(cameraDiff))
	-- База: 1 секунда на 90 градусов при speed 10. Меньший speed = дольше.
	local baseDuration = maxDiff * (1 / math.rad(90))
	local duration = baseDuration * (10 / turnSpeed)
	duration = math.clamp(duration, 0.5, 5)
	local start = tick()

	local RunService = game:GetService("RunService")
	local cameraBind = "SanDiegoTurnCamera"
	local releaseBind = "SanDiegoTurnCameraRelease"
	local cameraPriority = (Enum.RenderPriority and Enum.RenderPriority.Camera.Value + 1) or 201

	-- Чем медленнее поворот, тем дольше держим камеру после него,
	-- чтобы Roblox-камера успела "подхватить" новое направление.
	local releaseDuration = math.clamp(duration * 0.5, 0.5, 2.0)

	local function cameraCFrameFromYaw(yaw)
		if not (hrp and hrp.Parent) then
			return nil
		end
		local fakeCf = CFrame.new(hrp.Position) * CFrame.Angles(0, yaw, 0)
		local look = fakeCf.LookVector
		return CFrame.new(hrp.Position - look * 10 + Vector3.new(0, 5, 0), hrp.Position + look * 10)
	end

	local function alignCamera()
		if not camera then
			return
		end
		local t = math.min((tick() - start) / duration, 1)
		-- ease-out: быстрее в начале, мягче к концу
		local easedT = math.sin(t * math.pi / 2)
		local yaw = startCameraYaw + cameraDiff * easedT
		local cf = cameraCFrameFromYaw(yaw)
		if not cf then
			return
		end
		pcall(function()
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = cf
		end)
	end

	local function syncCameraController(targetYawValue)
		local player = Players.LocalPlayer
		if not player then
			return
		end
		pcall(function()
			local playerScripts = player:WaitForChild("PlayerScripts", 2)
			if not playerScripts then return end
			local cameraModule = playerScripts:WaitForChild("CameraModule", 2)
			if not cameraModule then return end
			local playerModule = require(cameraModule)
			local cameraController = playerModule:GetCameras()
			local active = cameraController and cameraController.activeCameraController
			if active and typeof(active) == "table" then
				active.azimuth = targetYawValue
				-- Синхронизируем наклон по текущему CFrame камеры.
				local look = camera and camera.CFrame.LookVector
				if look then
					active.elevation = math.asin(math.clamp(look.Y, -1, 1))
				end
			end
		end)
	end

	local function releaseCamera()
		if not (withCamera and camera) then
			return
		end
		pcall(function()
			RunService:UnbindFromRenderStep(cameraBind)
		end)
		pcall(function()
			RunService:UnbindFromRenderStep(releaseBind)
		end)
		-- Пытаемся прописать новый угол в CameraModule, чтобы Custom не сбросил его.
		syncCameraController(targetYaw)
		pcall(function()
			camera.CameraType = Enum.CameraType.Custom
		end)
		local releaseStart = tick()
		RunService:BindToRenderStep(releaseBind, cameraPriority, function()
			if not (hrp and camera) then
				pcall(function()
					RunService:UnbindFromRenderStep(releaseBind)
				end)
				return
			end
			pcall(function()
				camera.CFrame = cameraCFrameFromYaw(targetYaw)
			end)
			if tick() - releaseStart >= releaseDuration then
				pcall(function()
					RunService:UnbindFromRenderStep(releaseBind)
				end)
			end
		end)
	end

	if withCamera and camera then
		pcall(function()
			RunService:UnbindFromRenderStep(cameraBind)
		end)
		pcall(function()
			RunService:UnbindFromRenderStep(releaseBind)
		end)
		RunService:BindToRenderStep(cameraBind, cameraPriority, alignCamera)
	end

	while math.abs(diff) > 0.001 do
		if self:_isCancelled() then
			releaseCamera()
			if humanoid and originalAutoRotate ~= nil then
				pcall(function()
					humanoid.AutoRotate = originalAutoRotate
				end)
			end
			return { success = false, error = "cancelled" }
		end

		hrp = ensureHrp()
		if not hrp then
			releaseCamera()
			if humanoid and originalAutoRotate ~= nil then
				pcall(function()
					humanoid.AutoRotate = originalAutoRotate
				end)
			end
			return { success = false, error = "HumanoidRootPart lost during turn" }
		end

		local t = math.min((tick() - start) / duration, 1)
		local easedT = math.sin(t * math.pi / 2)
		local newYaw = currentYaw + diff * easedT
		local cf = CFrame.new(hrp.Position) * CFrame.Angles(0, newYaw, 0)
		pcall(function()
			hrp.CFrame = cf
		end)

		if t >= 1 then
			break
		end
		task.wait(0.03)
	end

	hrp = ensureHrp()
	if hrp then
		pcall(function()
			hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, targetYaw, 0)
		end)
	end

	if withCamera and camera then
		-- Даём камере довернуться, даже если персонаж уже на целевом угле.
		local remaining = duration - (tick() - start)
		if remaining > 0 then
			task.wait(remaining)
		end
		alignCamera()
		releaseCamera()
	end

	if humanoid and originalAutoRotate ~= nil then
		pcall(function()
			humanoid.AutoRotate = originalAutoRotate
		end)
	end

	hrp = ensureHrp()
	if not hrp then
		return { success = false, error = "HumanoidRootPart lost after turn" }
	end
	local _, finalYaw = hrp.CFrame:ToEulerAnglesYXZ()
	return {
		success = true,
		data = {
			degrees = degrees,
			withCamera = withCamera,
			newYaw = math.round(math.deg(self:_normalizeAngle(finalYaw)) * 10) / 10,
		},
	}
end

function CommandEngine:_turnCommand(payload)
	local ok, degrees = self:_validateTurn(payload)
	if not ok then
		return { success = false, error = degrees }
	end
	local speed = payload and payload.speed
	return self:_smoothTurn(degrees, false, speed)
end

function CommandEngine:_turnWithCameraCommand(payload)
	local ok, degrees = self:_validateTurn(payload)
	if not ok then
		return { success = false, error = degrees }
	end
	local speed = payload and payload.speed
	return self:_smoothTurn(degrees, true, speed)
end

function CommandEngine:_validateTiltCamera(payload)
	local degrees = payload and payload.degrees
	if typeof(degrees) ~= "number" then
		return false, "param 'degrees' must be an integer"
	end
	if degrees % 1 ~= 0 then
		return false, "param 'degrees' must be an integer"
	end
	if degrees < -80 or degrees > 80 then
		return false, "param 'degrees' out of range [-80, 80]"
	end
	return true, degrees
end

function CommandEngine:releaseCamera()
	local RunService = game:GetService("RunService")
	local binds = {
		"SanDiegoTurnCamera",
		"SanDiegoTurnCameraRelease",
		"SanDiegoTiltCamera",
		"SanDiegoTiltCameraHold",
	}
	for _, name in ipairs(binds) do
		pcall(function()
			RunService:UnbindFromRenderStep(name)
		end)
	end
end

function CommandEngine:_tiltCameraCommand(payload)
	local ok, degrees = self:_validateTiltCamera(payload)
	if not ok then
		return { success = false, error = degrees }
	end

	local camera = workspace.CurrentCamera
	if not camera then
		return { success = false, error = "Camera not found" }
	end

	local speed = payload and payload.speed
	if speed == nil then
		speed = 10
	elseif typeof(speed) ~= "number" or speed % 1 ~= 0 or speed < 1 or speed > 10 then
		return { success = false, error = "param 'speed' must be an integer in [1, 10]" }
	end

	self:releaseCamera()

	local targetPitch = math.rad(degrees)
	local currentPitch, cameraYaw, _ = camera.CFrame:ToEulerAnglesYXZ()
	local diff = targetPitch - currentPitch
	if diff > math.pi then
		diff = diff - 2 * math.pi
	elseif diff < -math.pi then
		diff = diff + 2 * math.pi
	end

	local cameraPos = camera.CFrame.Position
	local cameraBind = "SanDiegoTiltCamera"
	local holdBind = "SanDiegoTiltCameraHold"
	local RunService = game:GetService("RunService")
	local cameraPriority = (Enum.RenderPriority and Enum.RenderPriority.Camera.Value + 1) or 201

	local duration = math.max(0.2, math.abs(diff) / math.rad(90)) * (10 / speed)
	duration = math.clamp(duration, 0.2, 2)
	local start = tick()

	local function cameraCFrameFromPitch(pitch)
		return CFrame.new(cameraPos) * CFrame.fromEulerAnglesYXZ(pitch, cameraYaw, 0)
	end

	local function alignCamera()
		if not camera then
			return
		end
		local t = math.min((tick() - start) / duration, 1)
		local easedT = math.sin(t * math.pi / 2)
		local pitch = currentPitch + diff * easedT
		pcall(function()
			camera.CFrame = cameraCFrameFromPitch(pitch)
		end)
	end

	RunService:BindToRenderStep(cameraBind, cameraPriority, alignCamera)

	while tick() - start < duration do
		if self:_isCancelled() then
			self:releaseCamera()
			return { success = false, error = "cancelled" }
		end
		task.wait(0.03)
	end

	self:releaseCamera()

	if self:_isCancelled() then
		return { success = false, error = "cancelled" }
	end

	-- Бесконечный hold: удерживаем наклон, но позволяем меняться yaw (горизонтальный поворот).
	RunService:BindToRenderStep(holdBind, cameraPriority, function()
		if not camera then
			return
		end
		local _, yaw, _ = camera.CFrame:ToEulerAnglesYXZ()
		pcall(function()
			camera.CFrame = CFrame.new(camera.CFrame.Position) * CFrame.fromEulerAnglesYXZ(targetPitch, yaw, 0)
		end)
	end)

	return {
		success = true,
		data = {
			degrees = degrees,
			pitch = math.round(math.deg(targetPitch) * 10) / 10,
		},
	}
end

function CommandEngine:_cancelCurrent()
	self:requestCancel()
	return { success = true, data = { cancelledCommandId = self.currentCommandId } }
end

function CommandEngine:_afkCommand(payload)
	if not self.afk then
		return { success = false, error = "AFK module not available" }
	end

	local enabled = payload and payload.enabled
	if enabled ~= nil then
		enabled = tostring(enabled):lower()
		if enabled == "on" or enabled == "true" or enabled == "1" or enabled == "yes" then
			self.afk:setEnabled(true)
		elseif enabled == "off" or enabled == "false" or enabled == "0" or enabled == "no" then
			self.afk:setEnabled(false)
		else
			return { success = false, error = "enabled must be 'on' or 'off'" }
		end
	end

	local interval = payload and payload.interval
	if interval ~= nil then
		interval = tonumber(interval)
		if type(interval) ~= "number" or interval % 1 ~= 0 or interval < 60 or interval > 3600 then
			return { success = false, error = "interval must be integer in [60, 3600]" }
		end
		self.afk:setInterval(interval)
	end

	return {
		success = true,
		data = {
			enabled = self.afk.enabled,
			interval = self.afk.interval,
		},
	}
end

function CommandEngine:_setActionCommand(payload)
	local action = payload and payload.action
	if action == nil then
		return { success = false, error = "param 'action' is required" }
	end
	if typeof(action) ~= "string" then
		return { success = false, error = "param 'action' must be a string" }
	end
	if #action > 32 then
		return { success = false, error = "param 'action' too long (max 32)" }
	end

	local except = payload and payload.except
	if except ~= nil and typeof(except) ~= "string" then
		return { success = false, error = "param 'except' must be a string" }
	end

	if self.state and self.state.setAction then
		self.state:setAction(action)
		self.state:setActionExcept(except or "")
	end

	return {
		success = true,
		data = {
			action = action,
			except = except or "",
		},
	}
end

function CommandEngine:_validateTimerName(payload)
	local name = payload and payload.name
	if typeof(name) ~= "string" then
		return false, "param 'name' must be a string"
	end
	if name ~= "time_1" and name ~= "time_2" and name ~= "time_3" and name ~= "time_4" and name ~= "time_5" then
		return false, "param 'name' must be one of: time_1, time_2, time_3, time_4, time_5"
	end
	return true, name
end

function CommandEngine:_setTimeCommand(payload)
	local ok, name = self:_validateTimerName(payload)
	if not ok then
		return { success = false, error = name }
	end

	local value = payload and payload.value
	if value ~= nil then
		if typeof(value) ~= "number" or value % 1 ~= 0 then
			return { success = false, error = "param 'value' must be an integer timestamp" }
		end
		if value < 0 or value > 9999999999 then
			return { success = false, error = "param 'value' out of range [0, 9999999999]" }
		end
	end

	if not (self.state and self.state.setTimer) then
		return { success = false, error = "state not available" }
	end

	self.state:setTimer(name, value)
	return {
		success = true,
		data = {
			name = name,
			elapsed = self.state:getTimerElapsed(name),
		},
	}
end

function CommandEngine:_getCustomFieldCommand(payload)
	local ok, name = self:_validateTimerName(payload)
	if not ok then
		return { success = false, error = name }
	end

	if not (self.state and self.state.getTimerElapsed) then
		return { success = false, error = "state not available" }
	end

	return {
		success = true,
		data = {
			name = name,
			elapsed = self.state:getTimerElapsed(name),
		},
	}
end

function CommandEngine:_setTeamCommand(payload)
	local teamName = payload and payload.team
	if typeof(teamName) ~= "string" or #teamName == 0 or #teamName > 32 then
		return { success = false, error = "param 'team' must be a non-empty string (1..32 chars)" }
	end

	local player = Players.LocalPlayer
	if not player then
		return { success = false, error = "LocalPlayer not found" }
	end

	-- San Diego использует RemoteFunction JoinTeam для смены команды.
	local joinTeamRemote
	pcall(function()
		local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("__remotes")
		if not remotes then return end
		local teamService = remotes:FindFirstChild("TeamService")
		if not teamService then return end
		joinTeamRemote = teamService:FindFirstChild("JoinTeam")
	end)

	if joinTeamRemote and (joinTeamRemote:IsA("RemoteFunction") or joinTeamRemote:IsA("RemoteEvent")) then
		local ok, result = pcall(function()
			return joinTeamRemote:InvokeServer(teamName)
		end)
		if not ok then
			return { success = false, error = "JoinTeam remote failed: " .. tostring(result) }
		end
		if typeof(result) == "table" and result.Success == false then
			return { success = false, error = result.Message or "team change rejected by server" }
		end
		return {
			success = true,
			data = {
				team = teamName,
				remoteResult = result,
			},
		}
	end

	-- Fallback: прямое присвоение Player.Team.
	local TeamsService = game:GetService("Teams")
	local team
	for _, t in ipairs(TeamsService:GetTeams()) do
		if t.Name == teamName then
			team = t
			break
		end
	end

	if not team then
		return { success = false, error = "team not found: " .. teamName }
	end

	local ok, err = pcall(function()
		player.Team = team
	end)
	if not ok then
		return { success = false, error = "failed to set team: " .. tostring(err) }
	end

	return {
		success = true,
		data = {
			team = teamName,
		},
	}
end

function CommandEngine:_joinPrivateServer(payload)
	local code = payload and payload.code
	if typeof(code) ~= "string" or code:gsub("%s+", "") == "" then
		return { success = false, error = "param 'code' must be a non-empty string" }
	end
	return self.privateServer:joinByCode(code)
end

function CommandEngine:_parseFormattedNumber(text)
	if typeof(text) == "number" then
		return text
	end
	local s = tostring(text):gsub("[ ,]", "")
	if s == "" then
		return nil
	end
	local num, suffix = s:match("^([%d%.]+)([KkMmBbTt]?)$")
	if num then
		local n = tonumber(num)
		if n then
			local lower = suffix:lower()
			if lower == "k" then
				n = n * 1e3
			elseif lower == "m" then
				n = n * 1e6
			elseif lower == "b" then
				n = n * 1e9
			elseif lower == "t" then
				n = n * 1e12
			end
			return n
		end
	end
	return tonumber(s)
end

function CommandEngine:_getPlayerBalanceFromReplicatedStats(player)
	if not player then
		return nil
	end
	local folder = player:FindFirstChild("ReplicatedStats")
	if not folder then
		return nil
	end
	local money = folder:FindFirstChild("Money")
	if money and money:IsA("StringValue") then
		return self:_parseFormattedNumber(money.Value)
	end
	return nil
end

function CommandEngine:_getLocalPlayerDataViaRemote()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local remote
	pcall(function()
		remote = ReplicatedStorage.__remotes.PlayerDataService.GetPlayerData
	end)
	if not remote then
		return nil, "PlayerDataService.GetPlayerData not found"
	end
	local ok, data = pcall(function()
		return remote:InvokeServer()
	end)
	if not ok then
		return nil, tostring(data)
	end
	if typeof(data) ~= "table" then
		return nil, "invalid data"
	end
	return data, nil
end

function CommandEngine:_resolvePlayer(identifier)
	local Players = game:GetService("Players")
	if identifier == nil then
		return nil, "identifier is nil"
	end

	-- Если число или строка из цифр — считаем UserId.
	local userId = nil
	if typeof(identifier) == "number" then
		userId = identifier
	elseif typeof(identifier) == "string" then
		-- Убираем пробелы.
		local trimmed = identifier:gsub("^%s*(.-)%s*$", "%1")
		if tonumber(trimmed) then
			userId = tonumber(trimmed)
		end
	end

	if userId then
		local byId = Players:GetPlayerByUserId(userId)
		if byId then
			return byId
		end
		-- Может быть игрок с таким UserId ещё не загружен, но пусть имя совпадёт.
		for _, p in ipairs(Players:GetPlayers()) do
			if p.UserId == userId then
				return p
			end
		end
		return nil, "player with user_id " .. tostring(userId) .. " not found"
	end

	-- Иначе ищем по имени или display name (case-insensitive).
	local name = tostring(identifier):lower()
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name:lower() == name or p.DisplayName:lower() == name then
			return p
		end
	end

	return nil, "player '" .. tostring(identifier) .. "' not found"
end

function CommandEngine:_extractBeachHousesFromData(data)
	local names = {}
	if typeof(data.OwnedBeachHouses) == "table" then
		for _, v in ipairs(data.OwnedBeachHouses) do
			local name = typeof(v) == "string" and v or (typeof(v) == "table" and (v.Name or v.name)) or tostring(v)
			if name and name ~= "" then
				table.insert(names, name)
			end
		end
	end
	return names
end

function CommandEngine:_extractApartmentIdsFromWorkspace(userId)
	local ids = {}
	local Workspace = game:GetService("Workspace")
	local gameplay = Workspace:FindFirstChild("Gameplay")
	local apartments = gameplay and gameplay:FindFirstChild("Apartments")
	local doors = apartments and apartments:FindFirstChild("Doors")
	if doors then
		for _, door in ipairs(doors:GetChildren()) do
			local ownerId = door:GetAttribute("ApartmentOwnerUserId")
			if ownerId and ownerId == userId then
				local apartmentId = door:GetAttribute("ApartmentId")
				table.insert(ids, tostring(apartmentId or door.Name))
			end
		end
	end
	return ids
end

function CommandEngine:_extractBeachHousesFromWorkspace(userId)
	local houses = {}
	local Workspace = game:GetService("Workspace")
	local gameplay = Workspace:FindFirstChild("Gameplay")
	local plots = gameplay and gameplay:FindFirstChild("BeachHousePlots")
	if plots then
		for _, plot in ipairs(plots:GetChildren()) do
			local ownerId = plot:GetAttribute("BeachHouseOwnerUserId")
			if ownerId and ownerId == userId then
				local houseType = plot:GetAttribute("BeachHouseType") or "BeachHouse"
				table.insert(houses, tostring(houseType) .. " " .. plot.Name)
			end
		end
	end
	return houses
end

function CommandEngine:_getSinglePlayerEntry(player, localData)
	local Players = game:GetService("Players")
	local localPlayer = Players.LocalPlayer
	local isLocal = player == localPlayer

	local entry = {
		roblox_name = player.Name,
		display_name = player.DisplayName,
		user_id = player.UserId,
		team = player.Team and tostring(player.Team.Name) or "Neutral",
	}

	local balance = self:_getPlayerBalanceFromReplicatedStats(player)
	local beachHouses = self:_extractBeachHousesFromWorkspace(player.UserId)
	local apartments = self:_extractApartmentIdsFromWorkspace(player.UserId)
	local moneyPrinters = nil

	if isLocal and localData then
		balance = localData.Currency and localData.Currency.Money or balance
		local dataBeachHouses = self:_extractBeachHousesFromData(localData)
		for _, name in ipairs(dataBeachHouses) do
			local found = false
			for _, existing in ipairs(beachHouses) do
				if existing == name then
					found = true
					break
				end
			end
			if not found then
				table.insert(beachHouses, name)
			end
		end
		moneyPrinters = 0
		if typeof(localData.MoneyPrinters) == "table" then
			for _ in pairs(localData.MoneyPrinters) do
				moneyPrinters += 1
			end
		end
	end

	entry.balance = balance
	entry.properties = {
		beach_houses = beachHouses,
		apartments = apartments,
	}
	if moneyPrinters ~= nil then
		entry.money_printers = moneyPrinters
	end

	return entry
end

function CommandEngine:_getServerPlayersCommand()
	local Players = game:GetService("Players")
	local localPlayer = Players.LocalPlayer
	local localData = nil
	if localPlayer then
		localData = self:_getLocalPlayerDataViaRemote()
	end

	local result = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if self:_isCancelled() then
			return { success = false, error = "cancelled" }
		end
		table.insert(result, self:_getSinglePlayerEntry(player, localData))
	end

	return { success = true, data = result }
end

function CommandEngine:_getPlayerCommand(payload)
	local identifier = payload and payload.identifier
	if identifier == nil or (typeof(identifier) ~= "string" and typeof(identifier) ~= "number") then
		return { success = false, error = "param 'identifier' is required (string or number)" }
	end

	local player, err = self:_resolvePlayer(identifier)
	if not player then
		return { success = false, error = err or "player not found" }
	end

	local localData = nil
	local Players = game:GetService("Players")
	if player == Players.LocalPlayer then
		localData = self:_getLocalPlayerDataViaRemote()
	end

	return {
		success = true,
		data = self:_getSinglePlayerEntry(player, localData),
	}
end

function CommandEngine:execute(command)
	local name = command.name
	local payload = command.payload or {}
	self.currentCommandId = command.id
	self:resetCancel()

	local result
	if name == "get_commands" then
		local encoded = self:_encodeGetCommandsResult()
		if not encoded then
			result = { success = false, error = "failed to encode commands list" }
		else
			result = { success = true, encoded = encoded }
		end
	elseif name == "move_x" then
		result = self:_moveAxis("x", payload)
	elseif name == "move_y" then
		result = self:_moveAxis("y", payload)
	elseif name == "move_z" then
		result = self:_moveAxis("z", payload)
	elseif name == "move_to" then
		result = self:_moveTo(payload)
	elseif name == "pause" then
		result = self:_pause(payload)
	elseif name == "respawn" then
		result = self:_respawn()
	elseif name == "transfer_money_via_respawn" then
		result = self:_transferMoneyViaRespawn(payload)
	elseif name == "respawn_for_money" then
		result = self:_respawnForMoney(payload)
	elseif name == "place_printer" then
		result = self:_placePrinterCommand(payload)
	elseif name == "place_all_printers" then
		result = self:_placeAllPrintersCommand(payload)
	elseif name == "jump" then
		result = self:_jumpCommand()
	elseif name == "hold_key" then
		result = self:_holdKeyCommand(payload)
	elseif name == "turn" then
		result = self:_turnCommand(payload)
	elseif name == "turn_with_camera" then
		result = self:_turnWithCameraCommand(payload)
	elseif name == "tilt_camera" then
		result = self:_tiltCameraCommand(payload)
	elseif name == "join_private_server" then
		result = self:_joinPrivateServer(payload)
	elseif name == "cancel" then
		result = self:_cancelCurrent()
	elseif name == "afk" then
		result = self:_afkCommand(payload)
	elseif name == "set_action" then
		result = self:_setActionCommand(payload)
	elseif name == "set_time" then
		result = self:_setTimeCommand(payload)
	elseif name == "get_custom_field" then
		result = self:_getCustomFieldCommand(payload)
	elseif name == "set_team" then
		result = self:_setTeamCommand(payload)
	elseif name == "get_server_players" then
		result = self:_getServerPlayersCommand()
	elseif name == "get_player" then
		result = self:_getPlayerCommand(payload)
	else
		result = { success = false, error = "unknown command: " .. tostring(name) }
	end

	self.currentCommandId = nil
	return result
end

return CommandEngine
