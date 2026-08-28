local Players = game:GetService("Players")

local CommandEngine = {}
CommandEngine.__index = CommandEngine

function CommandEngine.new(privateServer, afk)
	local self = setmetatable({}, CommandEngine)
	self.cancelled = false
	self.currentCommandId = nil
	self.afk = afk
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

function CommandEngine:isBusy()
	return self.currentCommandId ~= nil
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
	local HttpService = game:GetService("HttpService")
	local ok, json = pcall(function()
		return HttpService:JSONEncode(response)
	end)
	if not ok then
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
		hrp.CFrame = CFrame.new(newPos) * CFrame.Angles(0, startYaw, 0)
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
	hrp.CFrame = CFrame.new(finalPos) * CFrame.Angles(0, startYaw, 0)

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
	if dist < 0.1 then
		hrp.CFrame = CFrame.new(Vector3.new(x, pos.Y, z)) * CFrame.Angles(0, startYaw, 0)
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
		hrp.CFrame = CFrame.new(newPos) * CFrame.Angles(0, startYaw, 0)
		task.wait(waitTime)
	end

	if self:_isCancelled() then
		return { success = false, error = "cancelled" }
	end

	hrp.CFrame = CFrame.new(Vector3.new(x, pos.Y, z)) * CFrame.Angles(0, startYaw, 0)

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
	local ok, err = pcall(function()
		VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
		if duration > 0 then
			task.wait(duration / 1000)
			VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
		else
			task.wait()
			VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
		end
	end)
	if not ok then
		return { success = false, error = "VirtualInputManager failed: " .. tostring(err) }
	end

	if self:_isCancelled() then
		return { success = false, error = "cancelled" }
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
		local fakeCf = CFrame.new(hrp.Position) * CFrame.Angles(0, yaw, 0)
		local look = fakeCf.LookVector
		return CFrame.new(hrp.Position - look * 10 + Vector3.new(0, 5, 0), hrp.Position + look * 10)
	end

	local function alignCamera()
		if not (hrp and camera) then
			return
		end
		local t = math.min((tick() - start) / duration, 1)
		-- ease-out: быстрее в начале, мягче к концу
		local easedT = math.sin(t * math.pi / 2)
		local yaw = startCameraYaw + cameraDiff * easedT
		pcall(function()
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = cameraCFrameFromYaw(yaw)
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

		local t = math.min((tick() - start) / duration, 1)
		local easedT = math.sin(t * math.pi / 2)
		local newYaw = currentYaw + diff * easedT
		local cf = CFrame.new(hrp.Position) * CFrame.Angles(0, newYaw, 0)
		hrp.CFrame = cf

		if t >= 1 then
			break
		end
		task.wait(0.03)
	end

	hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, targetYaw, 0)

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

function CommandEngine:_setTeamCommand(payload)
	local teamName = payload and payload.team
	if typeof(teamName) ~= "string" or #teamName == 0 or #teamName > 32 then
		return { success = false, error = "param 'team' must be a non-empty string (1..32 chars)" }
	end

	local player = Players.LocalPlayer
	if not player then
		return { success = false, error = "LocalPlayer not found" }
	end

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

function CommandEngine:execute(command)
	local name = command.name
	local payload = command.payload or {}
	self.currentCommandId = command.id
	self:resetCancel()

	local result
	if name == "get_commands" then
		local encoded = self:_encodeGetCommandsResult()
		result = { success = true, encoded = encoded or "{\"commands\":[]}" }
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
	elseif name == "set_team" then
		result = self:_setTeamCommand(payload)
	else
		result = { success = false, error = "unknown command: " .. tostring(name) }
	end

	self.currentCommandId = nil
	return result
end

return CommandEngine
