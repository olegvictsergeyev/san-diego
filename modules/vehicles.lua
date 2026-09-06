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
-- NAV_ALT — высота перемещения nav_car = максимальной безопасной (10 ст).
-- NAV_SPEED — 25 ст/с: фиксированная допустимая скорость перемещения.
Vehicles.ABS_CEILING = 64
Vehicles.HOVER_STEP = 1
Vehicles.NAV_ALT = 10
Vehicles.NAV_SPEED = 25
Vehicles.MAX_DIST = 2000
Vehicles.DT = 0.05

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
	return hit and hit.Position.Y or (p.Y - (s.studs or self.NAV_ALT))
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
			local targetY = math.min(groundY + self.NAV_ALT, self.ABS_CEILING)
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
		pcall(function()
			s.bv.Velocity = Vector3.new(vx, vy, vz)
		end)
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

function Vehicles:_ensureSession(root, model)
	local s = self.session
	if s and s.root == root and s.root.Parent and s.bv and s.bv.Parent then
		return s
	end
	self:_teardown()
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
		studs = self.NAV_ALT,
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

-- Посадка и завершение сессии. Ждёт касания до 45 с.
function Vehicles:land()
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
		task.wait(0.1)
	end
	self:_teardown()
	return { success = true, data = { landed = true, knocks = knocks, height = level } }
end

-- Перемещение на смещение (dx, dz) в стадах по безопасному профилю
-- (+6 над поверхностью, 25 ст/с). Если сессия fly_car была активна —
-- после прибытия вернётся в зависание на прежней высоте, иначе сядет.
function Vehicles:navigate(dx, dz)
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
	s.mode = "nav"
	s.navX = startX + dx
	s.navZ = startZ + dz
	s.navArrived = false
	local resumeLevel = s.level
	local dist = math.sqrt(dx * dx + dz * dz)
	local timeout = math.min(dist / self.NAV_SPEED + 90, 280)
	local t0 = tick()
	while not s.navArrived and tick() - t0 < timeout and s.root.Parent do
		task.wait(0.1)
	end
	local travelled = math.sqrt((s.root.Position.X - startX) ^ 2 + (s.root.Position.Z - startZ) ^ 2)
	local knocks = s.knocks
	if not s.navArrived then
		return { success = false, error = "nav timeout", data = { travelled = math.floor(travelled), knocks = knocks } }
	end
	if resumeLevel then
		s.mode = "hover"
		s.studs = resumeLevel * self.HOVER_STEP
		s.holdX = s.root.Position.X
		s.holdZ = s.root.Position.Z
		return { success = true, data = { travelled = math.floor(travelled), knocks = knocks, resumed = "hover", height = resumeLevel } }
	end
	s.mode = "landing"
	s.modeSince = nil
	s.holdX = s.root.Position.X
	s.holdZ = s.root.Position.Z
	t0 = tick()
	while not s.landed and tick() - t0 < 45 and s.root.Parent do
		task.wait(0.1)
	end
	self:_teardown()
	return { success = true, data = { landed = true, travelled = math.floor(travelled), knocks = knocks } }
end

return Vehicles
