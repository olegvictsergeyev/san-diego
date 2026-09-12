local Players = game:GetService("Players")

local Vehicles = {}
Vehicles.__index = Vehicles

-- Параметры безопасного полёта, калиброванные на живом сервере (см. тесты):
-- ABS_CEILING — абсолютный потолок ~66-67 ст: выше анти-чит мгновенно
--   сбрасывает машину на y≈22-23 с полной остановкой.
-- HOVER_STEP — высота fly_car задаётся в градациях 0..10, 1 градация = 1 ст
--   над поверхностью (рейкаст). 10 = +10 ст — максимум, разрешённый
--   анти-читом В ДВИЖЕНИИ (проверено: 30+ с полёта на 20 ст/с без сбросов).
--   Выше +10 ст в движении анти-чит сбрасывает машину каждые ~13-15 с.
-- NAV_SPEED — 20 ст/с: на +10 ст выше скорость накапливает «подозрение»
--   анти-чита (25 ст/с — срабатывания при длительном полёте; 20 ст/с —
--   30+ с чисто). Сбросы не смертельны — контроллер восстанавливается.
-- Высота при nav_car НЕ меняется: машина летит на текущей высоте
-- (над поверхностью = как при старте, при активной сессии fly_car —
-- на её высоте), повторяя рельеф по рейкасту.
Vehicles.ABS_CEILING = 64
Vehicles.HOVER_STEP = 1
Vehicles.NAV_SPEED = 20
Vehicles.MAX_DIST = 2000
Vehicles.DT = 0.05
-- Главный проспект карты San Diego: полоса по умолчанию для наземной
-- езды (команда drive) — ровная линия, проверенная на 7000+ стадах
Vehicles.DEFAULT_LANE_Z = 150.07
Vehicles.MAX_DRIVE_DIST = 20000
-- Анти-чит: при реальной скорости ~613+ ст/с сервер качнул технику,
-- обнулил скорость и откатил на точку нарушения (rewind).
-- Кап 580 = максимум проверенный чистым заездом (предел 613 −5%).
Vehicles.DRIVE_VMAX = 580
-- Режим замера порога античита (probe=true у drive): разгон капами
-- от PROBE_V0 с шагом PROBE_STEP каждые PROBE_STEP_SEC, пока игровое
-- уведомление WarningGui не зафиксирует срабатывание. Порог = кап
-- на момент срабатывания (уходит в result команды → логи бэкенда).
Vehicles.PROBE_V0 = 150
Vehicles.PROBE_STEP = 10
Vehicles.PROBE_STEP_SEC = 2
Vehicles.PROBE_ACCEL = 30
-- Допуск прибытия по X по умолчанию: |фактическая X − целевая| больше
-- этого значения = ошибка missed target. Переопределяется параметром
-- tolerance команды drive.
Vehicles.ARRIVE_TOLERANCE = 40

function Vehicles.new()
	local self = setmetatable({}, Vehicles)
	self.session = nil
	return self
end

-- Машина игрока: идём от сиденья вверх по предкам до модели с деталью Root.
-- Работает только когда персонаж сидит в VehicleSeat: тогда сетевое
-- владение сборкой у клиента и наша физика реплицируется на сервер.
function Vehicles:_car()
	local player = Players.LocalPlayer
	local char = player and player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	if not (seat and seat:IsA("VehicleSeat")) then
		return nil, "character is not in a vehicle"
	end
	local node = seat.Parent
	while node and node ~= workspace do
		local r = node:FindFirstChild("Root")
		if r and r:IsA("BasePart") then
			return r, nil, node
		end
		node = node.Parent
	end
	return nil, "vehicle model (Root part) not found"
end

function Vehicles:_makeRayParams(model)
	local player = Players.LocalPlayer
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {model, player.Character}
	return params
end

function Vehicles:_groundY(s, p)
	local hit = workspace:Raycast(p + Vector3.new(0, 5, 0), Vector3.new(0, -220, 0), s.rayParams)
	return hit and hit.Position.Y or (p.Y - (s.navStuds or s.studs or 1))
end

function Vehicles:_teardown()
	local s = self.session
	self.session = nil
	if not s then return end
	s.alive = false
	task.wait(0.3)
	pcall(function() s.bv.Velocity = Vector3.zero end)
	pcall(function() s.bv:Destroy() end)
	pcall(function() s.ao:Destroy() end)
	pcall(function() s.att:Destroy() end)
end

-- Контрольный цикл сессии: пишет Velocity/каждый тик в зависимости от режима.
function Vehicles:_loop(s)
	local lastY = s.root.Position.Y
	local lastCheck = tick()
	while s.alive do
		if not s.root.Parent then break end -- машина пересоздана сервером
		local p = s.root.Position
		local groundY = self:_groundY(s, p)
		local vx, vy, vz = 0, 0, 0
		if s.mode == "hover" then
			local targetY = math.min(groundY + s.studs, self.ABS_CEILING)
			vx = math.clamp((s.holdX - p.X) * 3, -12, 12)
			vz = math.clamp((s.holdZ - p.Z) * 3, -12, 12)
			vy = math.clamp((targetY - p.Y) * 3, -12, 12)
		elseif s.mode == "nav" then
			-- высота НЕ меняем: повторяем рельеф на стартовой высоте
			local targetY = math.min(groundY + (s.navStuds or self.HOVER_STEP), self.ABS_CEILING)
			vx = math.clamp((s.navX - p.X) * 3, -self.NAV_SPEED, self.NAV_SPEED)
			vz = math.clamp((s.navZ - p.Z) * 3, -self.NAV_SPEED, self.NAV_SPEED)
			vy = math.clamp((targetY - p.Y) * 3, -14, 14)
			if math.abs(s.navX - p.X) < 1 and math.abs(s.navZ - p.Z) < 1 then
				s.navArrived = true
			end
		elseif s.mode == "landing" then
			if not s.modeSince then s.modeSince = tick() end
			local gy = groundY + 0.3
			vx = math.clamp((s.holdX - p.X) * 3, -12, 12)
			vz = math.clamp((s.holdZ - p.Z) * 3, -12, 12)
			if p.Y - groundY > 8 then
				-- падение: не тормозим (проверено — анти-чит не трогает,
				-- машина цела), только держим горизонталь
				vy = -60
			else
				vy = math.clamp((gy - p.Y) * 4, -20, 20)
			end
			-- касание: близко к земле ИЛИ посадка длится >15 с (backstop)
			if p.Y - groundY < 0.6 or tick() - s.modeSince > 15 then
				s.landed = true
				break
			end
		end
		if s.mode ~= "drive" then
			pcall(function()
				s.bv.Velocity = Vector3.new(vx, vy, vz)
			end)
		end
		-- детект сброса анти-чита: падение >6 ст за 0.3 с
		if tick() - lastCheck > 0.3 then
			if lastY - p.Y > 6 then
				s.knocks = s.knocks + 1
			end
			lastY = p.Y
			lastCheck = tick()
		end
		task.wait(self.DT)
	end
	pcall(function() s.bv.Velocity = Vector3.zero end)
end

-- Снимает «чужие» констрейнты агента с детали: после перезагрузки агента
-- (update_agent/телепорт) сессия предыдущего инстанса остаётся висеть
-- на машине и конфликтует с новой (два BodyVelocity душат друг друга).
function Vehicles:_cleanupStray(root)
	for _, d in ipairs(root:GetChildren()) do
		if d.Name == "SDFlyBV" or d.Name == "SDFlyAO" or d.Name == "SDFlyAtt" then
			pcall(function()
				d:Destroy()
			end)
		end
	end
end

function Vehicles:_ensureSession(root, model)
	local s = self.session
	if s and s.root == root and s.root.Parent and s.bv and s.bv.Parent then
		return s
	end
	self:_teardown()
	self:_cleanupStray(root)
	local bv = Instance.new("BodyVelocity")
	bv.Name = "SDFlyBV"
	bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	bv.Velocity = Vector3.zero
	bv.Parent = root
	local att = Instance.new("Attachment")
	att.Name = "SDFlyAtt"
	att.Parent = root
	local ao = Instance.new("AlignOrientation")
	ao.Name = "SDFlyAO"
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = att
	ao.RigidityEnabled = true
	ao.CFrame = root.CFrame
	ao.MaxTorque = math.huge
	ao.MaxAngularVelocity = math.huge
	ao.Parent = root
	s = {
		root = root,
		model = model,
		rayParams = self:_makeRayParams(model),
		bv = bv,
		ao = ao,
		att = att,
		mode = "hover",
		level = nil,
		studs = self.HOVER_STEP,
		holdX = root.Position.X,
		holdZ = root.Position.Z,
		navX = root.Position.X,
		navZ = root.Position.Z,
		navArrived = false,
		landed = false,
		knocks = 0,
		alive = true,
	}
	self.session = s
	task.spawn(function()
		self:_loop(s)
	end)
	return s
end

-- Зависание на высоте level (1..10). Машина держится, пока не придёт
-- fly_car с height=0 или nav_car. Точка удержания — позиция на момент команды.
function Vehicles:hover(level)
	level = math.floor(tonumber(level) or 0)
	if level < 1 or level > 10 then
		return { success = false, error = "height must be an integer 1..10 (use 0 to land)" }
	end
	local root, err, model = self:_car()
	if not root then
		return { success = false, error = err }
	end
	local s = self:_ensureSession(root, model)
	s.mode = "hover"
	s.level = level
	s.studs = level * self.HOVER_STEP
	s.holdX = root.Position.X
	s.holdZ = root.Position.Z
	s.navArrived = false
	return { success = true, data = { height = level, studs = s.studs, mode = "hover" } }
end

-- Посадка и завершение сессии. Ждёт касания до 45 с; isCancelled —
-- кооперативное прерывание (команда cancel): мгновенный сброс констрейнтов
-- (высота ≤ +10 ст — падение безопасно).
function Vehicles:land(isCancelled)
	local s = self.session
	if not s then
		return { success = true, data = { landed = true, note = "no active fly session" } }
	end
	s.mode = "landing"
	s.modeSince = nil
	s.holdX = s.root.Position.X
	s.holdZ = s.root.Position.Z
	local knocks = s.knocks
	local level = s.level
	local t0 = tick()
	while not s.landed and tick() - t0 < 45 and s.root.Parent do
		if isCancelled and isCancelled() then
			self:_teardown()
			return { success = false, error = "cancelled", data = { landed = false, knocks = knocks, height = level } }
		end
		task.wait(0.1)
	end
	self:_teardown()
	return { success = true, data = { landed = true, knocks = knocks, height = level } }
end

-- Перемещение на смещение (dx, dz) в стадах по безопасному профилю
-- (+10 над поверхностью, 20 ст/с). Если сессия fly_car была активна —
-- после прибытия вернётся в зависание на прежней высоте, иначе сядет.
-- isCancelled — кооперативное прерывание: отменяем движение, при активной
-- сессии fly_car остаёмся висеть на месте, иначе мгновенно сбрасываем
-- констрейнты (падение с ≤10 ст безопасно).
function Vehicles:navigate(dx, dz, isCancelled)
	dx = tonumber(dx) or 0
	dz = tonumber(dz) or 0
	if dx == 0 and dz == 0 then
		return { success = false, error = "x and z are both 0" }
	end
	if math.abs(dx) > self.MAX_DIST or math.abs(dz) > self.MAX_DIST then
		return { success = false, error = "distance per axis must be <= " .. self.MAX_DIST }
	end
	local root, err = self:_car()
	if not root then
		return { success = false, error = err }
	end
	local _, _, model = self:_car()
	local s = self:_ensureSession(root, model)
	local startX, startZ = root.Position.X, root.Position.Z
	-- высота полёта = текущая (не смещаем Y): при активной сессии fly_car —
	-- её высота, иначе — текущая высота над поверхностью (мин. 0.5 ст)
	if s.level then
		s.navStuds = s.level * self.HOVER_STEP
	else
		s.navStuds = math.clamp(root.Position.Y - self:_groundY(s, root.Position), 0.5, 10)
	end
	s.mode = "nav"
	s.navX = startX + dx
	s.navZ = startZ + dz
	s.navArrived = false
	local resumeLevel = s.level
	local dist = math.sqrt(dx * dx + dz * dz)
	-- запас на восстановления после сбросов анти-чита (~4 с каждое)
	local timeout = math.min(dist / self.NAV_SPEED + 40, 150)
	local t0 = tick()
	while not s.navArrived and tick() - t0 < timeout and s.root.Parent do
		if isCancelled and isCancelled() then
			local kn = s.knocks
			if resumeLevel then
				s.mode = "hover"
				s.studs = resumeLevel * self.HOVER_STEP
				s.holdX = s.root.Position.X
				s.holdZ = s.root.Position.Z
				return { success = false, error = "cancelled", data = { knocks = kn, resumed = "hover", height = resumeLevel } }
			end
			self:_teardown()
			return { success = false, error = "cancelled", data = { landed = false, knocks = kn } }
		end
		task.wait(0.1)
	end
	local travelled = math.sqrt((s.root.Position.X - startX) ^ 2 + (s.root.Position.Z - startZ) ^ 2)
	local knocks = s.knocks
	if not s.navArrived then
		-- таймаут: сессию НЕ оставляем — иначе её цикл продолжит писать
		-- скорости и конфликтовать со следующими командами
		if resumeLevel then
			s.mode = "hover"
			s.studs = resumeLevel * self.HOVER_STEP
			s.holdX = s.root.Position.X
			s.holdZ = s.root.Position.Z
			return { success = false, error = "nav timeout", data = { travelled = math.floor(travelled), knocks = knocks, resumed = "hover", height = resumeLevel } }
		end
		self:_teardown()
		return { success = false, error = "nav timeout", data = { travelled = math.floor(travelled), knocks = knocks } }
	end
	if resumeLevel then
		s.mode = "hover"
		s.studs = resumeLevel * self.HOVER_STEP
		s.holdX = s.root.Position.X
		s.holdZ = s.root.Position.Z
		return { success = true, data = { travelled = math.floor(travelled), knocks = knocks, resumed = "hover", height = resumeLevel } }
	end
	-- высота в nav не менялась — посадка не нужна, просто снимаем констрейнты
	self:_teardown()
	return { success = true, data = { landed = true, travelled = math.floor(travelled), knocks = knocks } }
end

-- Наземная езда на полной скорости (мотоцикл/машина). Профиль проверен
-- на живых заездах: разгон без потолка (команда 60 ст/с², физически
-- достижимо ~630 ст/с на мотоцикле), полоса z держится P-регулятором,
-- торможение 80 ст/с² (реальное ~65) с точной остановкой у цели,
-- активная остановка в конце (техника сохраняет импульс и катится сама,
-- если просто снять констрейнты). Анти-чит горизонтальную скорость
-- техники на земле не ограничивает (проверено до 633 ст/с); единственные
-- препятствия — невидимые стены NavBlockers: при встрече полоса смещается
-- (z±14..±42), если свободной полосы нет — торможение и ошибка blocked.
-- dx — смещение по X со знаком (0 = не ехать, только встать в полосу),
-- laneZ — абсолютная целевая координата полосы (по умолчанию
-- DEFAULT_LANE_Z — главный проспект). isCancelled — кооперативная отмена.
-- speedLevel — ограничение скорости по шкале 0..10 (линейно 0..DRIVE_VMAX;
-- 10 или nil = полная скорость; 0 = не уезжать, только встать в полосу).
-- jumpOff — без торможения: по достижении цели персонаж спрыгивает с
-- транспорта (humanoid.Sit = false), техника с сохранением скорости
-- катится дальше сама; констрейнты снимаются, импульс не обнуляется.
-- tolerance — допуск прибытия по X: |факт − цель| > tolerance = ошибка
-- missed target (по умолчанию ARRIVE_TOLERANCE).
function Vehicles:drive(dx, laneZ, isCancelled, speedLevel, jumpOff, tolerance, probe, isAnticheatTriggered)
	dx = tonumber(dx) or 0
	laneZ = tonumber(laneZ) or self.DEFAULT_LANE_Z
	speedLevel = tonumber(speedLevel) or 10
	jumpOff = jumpOff == true
	tolerance = tonumber(tolerance) or self.ARRIVE_TOLERANCE
	if dx % 1 ~= 0 or math.abs(dx) > self.MAX_DRIVE_DIST then
		return { success = false, error = "x must be an integer in [-" .. self.MAX_DRIVE_DIST .. ", " .. self.MAX_DRIVE_DIST .. "]" }
	end
	if math.abs(laneZ) > 20000 then
		return { success = false, error = "z must be in [-20000, 20000]" }
	end
	if speedLevel < 0 or speedLevel > 10 or speedLevel % 1 ~= 0 then
		return { success = false, error = "speed must be an integer in [0, 10]" }
	end
	-- потолок скорости по шкале; 0 = стоять в полосе (как dx = 0)
	local targetVmax = math.floor(self.DRIVE_VMAX * speedLevel / 10)
	if speedLevel == 0 then
		dx = 0
	end
	-- Режим замера: кап наращивается от PROBE_V0 до срабатывания
	-- античита; speedLevel при этом игнорируется.
	probe = probe == true
	local probeVmax = self.PROBE_V0
	local probeStepAt = 0
	local probeTriggered, probeTriggerV = false, nil
	local root, err, model = self:_car()
	if not root then
		return { success = false, error = err }
	end
	local s = self:_ensureSession(root, model)
	s.mode = "drive"
	s.studs = math.max(root.Position.Y - self:_groundY(s, root.Position), 0.8)
	local dir = dx < 0 and -1 or (dx > 0 and 1 or 0)
	local startX = root.Position.X
	local targetX = startX + dx
	local t0 = tick()
	-- Курс: основная ось X + плавная коррекция к полосе поворотом руля.
	-- Движение всегда вдоль продольной оси техники (LookVector), z меняется
	-- только изменением курса — никакого бокового скольжения.
	local function courseDir(p)
		local dz = math.clamp((laneZ - p.Z) * 0.04, -0.4, 0.4)
		return Vector3.new(dir, 0, dz).Unit
	end
	local function flatLook()
		local look = root.CFrame.LookVector
		local f = Vector3.new(look.X, 0, look.Z)
		if f.Magnitude > 0.01 then
			return f.Unit
		end
		return Vector3.new(dir ~= 0 and dir or 1, 0, 0)
	end
	local function yawErrTo(d)
		return math.acos(math.clamp(flatLook():Dot(d), -1, 1))
	end
	local function holdY(p)
		local gy = self:_groundY(s, p)
		local vy = math.clamp((gy + s.studs - p.Y) * 4, -14, 14)
		if vy < 0 and p.Y < gy + s.studs + 0.3 then
			vy = math.max(vy, -2)
		end
		return vy
	end
	if dir ~= 0 then
		-- ФАЗА 0: развернуться носом к курсу (руление с лёгким ходом)
		local turned = false
		while not turned and tick() - t0 < 12 and s.root.Parent do
			if isCancelled and isCancelled() then
				self:_teardown()
				return { success = false, error = "cancelled", data = { aligned = false } }
			end
			local p = root.Position
			local d = courseDir(p)
			pcall(function()
				s.ao.CFrame = CFrame.lookAt(p, p + d)
			end)
			local errYaw = yawErrTo(d)
			local creep = errYaw > 0.6 and 4 or 14
			pcall(function()
				s.bv.Velocity = flatLook() * creep + Vector3.new(0, holdY(p), 0)
			end)
			turned = errYaw < 0.1
			task.wait(self.DT)
		end
		-- ВРАТА ВЫРАВНИВАНИЯ: на медленных мобилках физика/AO отстают,
		-- и без гейта техника стартовала бы на полном ходу с кривым носом
		-- — «сбивается с траектории и едет не туда». Лучше честный отказ.
		if not s.root.Parent then
			self:_teardown()
			return { success = false, error = "vehicle disappeared during align" }
		end
		local finalYaw = yawErrTo(courseDir(root.Position))
		if finalYaw > 0.35 then
			pcall(function()
				s.bv.Velocity = Vector3.zero
			end)
			self:_teardown()
			return { success = false, error = string.format("align timeout (yaw err %.2f)", finalYaw), data = { aligned = false } }
		end
	end
	pcall(function()
		s.bv.Velocity = Vector3.zero
	end)
	task.wait(0.3)
	pcall(function()
		s.root.AssemblyLinearVelocity = Vector3.zero
	end)
	if dir == 0 then
		-- x не передан: встать в полосу боковым выравниванием и держать позицию
		local aligned = math.abs(root.Position.Z - laneZ) < 0.5
		while not aligned and tick() - t0 < 10 and s.root.Parent do
			if isCancelled and isCancelled() then
				self:_teardown()
				return { success = false, error = "cancelled", data = { aligned = false } }
			end
			local p = root.Position
			local vz = math.clamp((laneZ - p.Z) * 4, -40, 40)
			pcall(function()
				s.bv.Velocity = Vector3.new(0, holdY(p), vz)
			end)
			aligned = math.abs(p.Z - laneZ) < 0.5 and s.root.AssemblyLinearVelocity.Magnitude < 8
			task.wait(self.DT)
		end
		pcall(function()
			s.bv.Velocity = Vector3.zero
		end)
		self:_teardown()
		return { success = true, data = { aligned = true, lane_z = laneZ, position = math.floor(root.Position.X), target_vmax = targetVmax } }
	end
	-- ФАЗА 1: разгон + пробег + резкое торможение у цели.
	-- Разгон масштабируется от speedLevel: иначе у speed 7 и speed 10
	-- первые ~5.5 с (0→300 ст/с) идентичны — кажется, что ограничение
	-- скорости игнорируется (наблюдено вживую). Торможение НЕ трогаем:
	-- дистанция остановки считается по фиксированному BRAKE_REAL.
	local ACCEL, BRAKE_CMD, BRAKE_REAL = 60 * math.max(speedLevel, 1) / 10, 80, 65
	if probe then
		ACCEL = self.PROBE_ACCEL
	end
	local capV = probe and probeVmax or targetVmax
	local v, phase = 0, "accel"
	local vmax, t300 = 0, nil
	local stuckAt, stuckDist = tick(), math.huge
	local abortReason, brakeStartX = nil, nil
	local jumped, jumpSpeed = false, 0
	local knockTicks = 0
	local timeout = math.max(math.abs(dx) / 200 + 40, math.abs(dx) / math.max(targetVmax, 30) * 1.5 + 40)
	if probe then
		-- Полный проход по шкале замера + запас на разгон/торможение.
		timeout = (self.DRIVE_VMAX - self.PROBE_V0) / self.PROBE_STEP * self.PROBE_STEP_SEC + 90
	end
	-- Медленные мобилки: тик длиннее номинала, поэтому dt меряем по
	-- факту — иначе интегратор скорости врёт, а дистанция торможения
	-- рассчитана по командной скорости → перелёт цели.
	local lastTick = tick()
	while tick() - t0 < timeout and s.root.Parent do
		if isCancelled and isCancelled() then
			abortReason = "cancelled"
			phase = "brake"
		end
		local now = tick()
		local dtReal = math.min(now - lastTick, 0.5)
		lastTick = now
		if probe then
			-- Шаг наращивания капа или фиксация срабатывания античита.
			if isAnticheatTriggered and isAnticheatTriggered() then
				probeTriggered = true
				probeTriggerV = math.floor(probeVmax)
				abortReason = "probe: anticheat triggered"
				phase = "brake"
			elseif now - probeStepAt >= self.PROBE_STEP_SEC and probeVmax < self.DRIVE_VMAX then
				probeVmax = math.min(probeVmax + self.PROBE_STEP, self.DRIVE_VMAX)
				probeStepAt = now
				capV = probeVmax
				warn(string.format(
					"[SanDiegoAgent][Vehicles] probe step: cap=%d actual=%d",
					probeVmax,
					math.floor(s.root.AssemblyLinearVelocity.Magnitude)
				))
			end
		end
		local p = root.Position
		local gy = self:_groundY(s, p)
		-- курс и руление: поворот носа к желаемому направлению
		local d = courseDir(p)
		pcall(function()
			s.ao.CFrame = CFrame.lookAt(p, p + d)
		end)
		local errYaw = yawErrTo(d)
		-- препятствия впереди (лучи вдоль оси дороги; дальность — от
		-- скорости: на мобиле тик длинный, фиксированные 36 стадов
		-- «пролетаются» за один тик до того, как луч сработает);
		-- пока далеко от полосы и идёт выравнивание — не детектим
		if phase ~= "brake" and math.abs(p.Z - laneZ) < 10 then
			local lookAhead = math.max(40, v * 0.6)
			local ahead = Vector3.new(lookAhead * dir, 0, 0)
			local b1 = workspace:Raycast(p + Vector3.new(6 * dir, 0.3, 0), ahead, s.rayParams)
			local b2 = workspace:Raycast(p + Vector3.new(6 * dir, 1.6, 0), ahead, s.rayParams)
			if b1 or b2 then
				local hitName = "unknown"
				pcall(function()
					hitName = (b1 or b2).Instance:GetFullName()
				end)
				local shifted = false
				for _, dz in ipairs({14, -14, 28, -28, 42, -42}) do
					local tp = Vector3.new(p.X, p.Y, laneZ + dz)
					local h1 = workspace:Raycast(tp + Vector3.new(0, 0.3, 0), ahead, s.rayParams)
					local h2 = workspace:Raycast(tp + Vector3.new(0, 1.6, 0), ahead, s.rayParams)
					if not h1 and not h2 then
						laneZ = laneZ + dz
						shifted = true
						break
					end
				end
				if not shifted then
					abortReason = "blocked: " .. hitName
					phase = "brake"
				end
			end
		end
		-- сторож схода с полосы: толчок/срыв отбросил технику далеко от
		-- курса — дальше на ходу она уйдёт ещё дальше, тормозим честно
		if phase ~= "brake" and math.abs(p.Z - laneZ) > 60 then
			abortReason = string.format("off course (lane err %.0f)", math.abs(p.Z - laneZ))
			phase = "brake"
		end
		if phase == "accel" then
			v = math.min(v + ACCEL * dtReal, capV)
			if not t300 and v >= 300 then
				t300 = now - t0
			end
			if jumpOff then
				-- без торможения: цель достигнута (или будет достигнута
				-- на следующих тиках) — спрыгиваем, техника катится сама
				if dir * (targetX - p.X) <= math.max(v * dtReal * 1.5, 3) then
					jumped = true
					jumpSpeed = s.root.AssemblyLinearVelocity.Magnitude
					break
				end
			elseif not probe and dir * (targetX - p.X) <= (v * v) / (2 * BRAKE_REAL) then
				phase = "brake"
				brakeStartX = p.X
			end
		elseif phase == "brake" then
			v = math.max(v - BRAKE_CMD * dtReal, 0)
			if v <= 0 then break end
		end
		-- тяга только вдоль продольной оси; при большом отклонении курса
		-- эффективная скорость падает (cos) — техника сначала разворачивается
		local ve = v * math.clamp(math.cos(errYaw), 0, 1)
		pcall(function()
			s.bv.Velocity = flatLook() * ve + Vector3.new(0, holdY(p), 0)
		end)
		local speed = s.root.AssemblyLinearVelocity.Magnitude
		-- сброс анти-чита/срыв сцепления: скорость рухнула при высокой
		-- команде; на мобиле чтение скорости «скачет» — гистерезис
		-- из 2 подряд тиков против ложных срабатываний
		if phase ~= "brake" and ve > 30 and speed < ve * 0.35 then
			knockTicks = knockTicks + 1
			if knockTicks >= 2 then
				abortReason = string.format("knock at v=%d", math.floor(ve))
				phase = "brake"
			end
		else
			knockTicks = 0
		end
		vmax = math.max(vmax, speed)
		-- сторож застревания, сильно ослабленный: только в фазе разгона/
		-- крейсера, только пока цель не пройдена, окно 4 с. Перелёт цели
		-- с медленным торможением (байк сохраняет импульс, реальное
		-- замедление слабее BRAKE_REAL) — допустим и НЕ считается ошибкой.
		local targetDist = (Vector2.new(targetX, laneZ) - Vector2.new(p.X, p.Z)).Magnitude
		if phase ~= "brake" and dir * (targetX - p.X) > 0 then
			if tick() - stuckAt >= 4 then
				if v > 10 and (stuckDist - targetDist) < 1.5 then
					abortReason = "stuck/locked"
					v = 0
					pcall(function()
						s.bv.Velocity = Vector3.zero
					end)
					break
				end
				stuckAt, stuckDist = tick(), targetDist
			end
		end
		task.wait(self.DT)
	end
	-- ПРЫЖОК (jump_off): спрыгиваем у цели, технику не тормозим —
	-- снимаем персонажа с сиденья и убираем констрейнты, импульс
	-- сохраняется, техника катится дальше сама.
	if jumped then
		local pEnd = s.root.Position
		local travelled = math.abs(pEnd.X - startX)
		pcall(function()
			local player = Players.LocalPlayer
			local hum = player and player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.Sit = false
			end
		end)
		self:_teardown()
		local data = {
			travelled = math.floor(travelled),
			vmax = math.floor(vmax),
			target_vmax = targetVmax,
			brake_dist = -1,
			lane_z = laneZ,
			time = math.floor((tick() - t0) * 10) / 10,
			jumped = true,
			jump_speed = math.floor(jumpSpeed),
		}
		if t300 then
			data.t_300 = math.floor(t300 * 10) / 10
		end
		return { success = true, data = data }
	end
	-- АКТИВНАЯ ОСТАНОВКА: техника сохраняет импульс — держим ноль,
	-- пока реальная скорость не упадёт (иначе укатится сама)
	pcall(function()
		s.bv.Velocity = Vector3.zero
	end)
	local tStop = tick()
	while s.root.AssemblyLinearVelocity.Magnitude > 2 and tick() - tStop < 4 and s.root.Parent do
		pcall(function()
			local p = s.root.Position
			s.ao.CFrame = CFrame.lookAt(p, p + Vector3.new(dir, 0, 0))
		end)
		task.wait(0.1)
	end
	local pEnd = s.root.Position
	local travelled = math.abs(pEnd.X - startX)
	local brakeDist = brakeStartX and math.abs(brakeStartX - pEnd.X) or -1
	self:_teardown()
	pcall(function()
		s.root.AssemblyLinearVelocity = Vector3.zero
	end)
	local data = {
		travelled = math.floor(travelled),
		vmax = math.floor(vmax),
		target_vmax = targetVmax,
		brake_dist = math.floor(brakeDist),
		lane_z = laneZ,
		time = math.floor((tick() - t0) * 10) / 10,
	}
	if probe then
		data.probe = true
		data.probe_triggered = probeTriggered
		data.probe_threshold = probeTriggerV
		data.probe_cap_reached = math.floor(probeVmax)
	end
	-- верификация прибытия: без неё бэкенд цепляет следующие шаги сцена-
	-- рия от НЕправильной точки — «приехал не туда», а дальше всё ломается
	local overshoot = (pEnd.X - targetX) * dir
	data.overshoot = math.floor(overshoot)
	data.tolerance = tolerance
	if t300 then
		data.t_300 = math.floor(t300 * 10) / 10
	end
	if not abortReason and not probe and math.abs(overshoot) > tolerance then
		return { success = false, error = string.format("missed target by %d studs", math.floor(overshoot)), data = data }
	end
	if abortReason then
		return { success = false, error = abortReason, data = data }
	end
	return { success = true, data = data }
end

return Vehicles
