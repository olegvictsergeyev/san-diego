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
function Vehicles:drive(dx, laneZ, isCancelled)
	dx = tonumber(dx) or 0
	laneZ = tonumber(laneZ) or self.DEFAULT_LANE_Z
	if dx % 1 ~= 0 or math.abs(dx) > self.MAX_DRIVE_DIST then
		return { success = false, error = "x must be an integer in [-" .. self.MAX_DRIVE_DIST .. ", " .. self.MAX_DRIVE_DIST .. "]" }
	end
	if math.abs(laneZ) > 20000 then
		return { success = false, error = "z must be in [-20000, 20000]" }
	end
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
		return { success = true, data = { aligned = true, lane_z = laneZ, position = math.floor(root.Position.X) } }
	end
	-- ФАЗА 1: полный разгон + пробег + резкое торможение у цели
	local ACCEL, BRAKE_CMD, BRAKE_REAL = 60, 80, 65
	local v, phase = 0, "accel"
	local vmax, t300 = 0, nil
	local stuckAt, stuckDist = tick(), math.huge
	local abortReason, brakeStartX = nil, nil
	local timeout = math.abs(dx) / 200 + 40
	while tick() - t0 < timeout and s.root.Parent do
		if isCancelled and isCancelled() then
			abortReason = "cancelled"
			phase = "brake"
		end
		local p = root.Position
		local gy = self:_groundY(s, p)
		-- курс и руление: поворот носа к желаемому направлению
		local d = courseDir(p)
		pcall(function()
			s.ao.CFrame = CFrame.lookAt(p, p + d)
		end)
		local errYaw = yawErrTo(d)
		-- препятствия впереди (низким и средним лучом вдоль оси дороги;
		-- пока далеко от полосы и идёт выравнивание — не детектим)
		if phase ~= "brake" and math.abs(p.Z - laneZ) < 10 then
			local ahead = Vector3.new(6 * dir, 0, 0)
			local b1 = workspace:Raycast(p + Vector3.new(0, 0.3, 0) + ahead, ahead * 5, s.rayParams)
			local b2 = workspace:Raycast(p + Vector3.new(0, 1.6, 0) + ahead, ahead * 5, s.rayParams)
			if b1 or b2 then
				local hitName = "unknown"
				pcall(function()
					hitName = (b1 or b2).Instance:GetFullName()
				end)
				local shifted = false
				for _, dz in ipairs({14, -14, 28, -28, 42, -42}) do
					local tp = Vector3.new(p.X, p.Y, laneZ + dz)
					local h1 = workspace:Raycast(tp + Vector3.new(0, 0.3, 0), Vector3.new(30 * dir, 0, 0), s.rayParams)
					local h2 = workspace:Raycast(tp + Vector3.new(0, 1.6, 0), Vector3.new(30 * dir, 0, 0), s.rayParams)
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
		if phase == "accel" then
			v = math.min(v + ACCEL * self.DT, self.DRIVE_VMAX)
			if not t300 and v >= 300 then
				t300 = tick() - t0
			end
			if dir * (targetX - p.X) <= (v * v) / (2 * BRAKE_REAL) then
				phase = "brake"
				brakeStartX = p.X
			end
		elseif phase == "brake" then
			v = math.max(v - BRAKE_CMD * self.DT, 0)
			if v <= 0 then break end
		end
		-- тяга только вдоль продольной оси; при большом отклонении курса
		-- эффективная скорость падает (cos) — техника сначала разворачивается
		local ve = v * math.clamp(math.cos(errYaw), 0, 1)
		pcall(function()
			s.bv.Velocity = flatLook() * ve + Vector3.new(0, holdY(p), 0)
		end)
		local speed = s.root.AssemblyLinearVelocity.Magnitude
		-- сброс анти-чита/срыв сцепления: скорость рухнула при высокой команде
		if phase ~= "brake" and ve > 30 and speed < ve * 0.35 then
			abortReason = string.format("knock at v=%d", math.floor(ve))
			phase = "brake"
		end
		vmax = math.max(vmax, speed)
		-- сторож застревания: команда есть, расстояние до цели не убывает
		local targetDist = (Vector2.new(targetX, laneZ) - Vector2.new(p.X, p.Z)).Magnitude
		if tick() - stuckAt >= 1.5 then
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
		task.wait(self.DT)
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
		brake_dist = math.floor(brakeDist),
		lane_z = laneZ,
		time = math.floor((tick() - t0) * 10) / 10,
	}
	if t300 then
		data.t_300 = math.floor(t300 * 10) / 10
	end
	if abortReason then
		return { success = false, error = abortReason, data = data }
	end
	return { success = true, data = data }
end

return Vehicles
