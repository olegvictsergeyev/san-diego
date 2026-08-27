local Players = game:GetService("Players")

local Afk = {}
Afk.__index = Afk

function Afk.new(config)
	local self = setmetatable({}, Afk)
	self.enabled = config.afkEnabled ~= false
	self.interval = tonumber(config.afkInterval) or 600
	if self.interval < 60 then
		self.interval = 60
	end
	self.running = false
	self.isBusyCheck = nil
	self.thread = nil
	return self
end

function Afk:setEnabled(enabled)
	self.enabled = enabled == true
end

function Afk:setInterval(seconds)
	seconds = tonumber(seconds) or 600
	if seconds < 60 then
		seconds = 60
	elseif seconds > 3600 then
		seconds = 3600
	end
	self.interval = seconds
end

function Afk:setBusyCheck(check)
	self.isBusyCheck = check
end

function Afk:isBusy()
	if typeof(self.isBusyCheck) == "function" then
		local ok, busy = pcall(self.isBusyCheck)
		if ok then
			return busy == true
		end
	end
	return false
end

function Afk:_getHrp()
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

function Afk:_getHumanoid()
	local player = Players.LocalPlayer
	if not player then return nil end
	local character = player.Character
	if not character then return nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then return humanoid end
	return nil
end

function Afk:_getYaw(cframe)
	local _, yaw = cframe:ToEulerAnglesYXZ()
	while yaw < 0 do
		yaw = yaw + 2 * math.pi
	end
	while yaw >= 2 * math.pi do
		yaw = yaw - 2 * math.pi
	end
	return yaw
end

function Afk:_normalizeAngle(angle)
	while angle < 0 do
		angle = angle + 2 * math.pi
	end
	while angle >= 2 * math.pi do
		angle = angle - 2 * math.pi
	end
	return angle
end

function Afk:_shortestAngleDiff(current, target)
	local diff = target - current
	return math.atan2(math.sin(diff), math.cos(diff))
end

-- Незаметное действие: поворот персонажа на небольшой угол и обратно.
function Afk:_doTinyWiggle()
	local hrp = self:_getHrp()
	local humanoid = self:_getHumanoid()
	if not hrp or not humanoid then return end
	if humanoid.Health <= 0 then return end
	if humanoid:GetState() == Enum.HumanoidStateType.Dead then return end

	local currentYaw = self:_getYaw(hrp.CFrame)
	local wiggle = math.rad(2)
	local direction = math.random() > 0.5 and 1 or -1
	local tempYaw = self:_normalizeAngle(currentYaw + wiggle * direction)
	local diff = self:_shortestAngleDiff(currentYaw, tempYaw)

	hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, currentYaw + diff, 0)
	task.wait(0.08)
	hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, currentYaw, 0)
end

function Afk:_performAction()
	if not self.enabled then return end
	if self:isBusy() then return end
	local ok, err = pcall(function()
		self:_doTinyWiggle()
	end)
	if not ok then
		warn("[SanDiegoAgent][AFK] action failed:", tostring(err))
	end
end

function Afk:start()
	if self.running then return end
	self.running = true
	self.thread = task.spawn(function()
		while self.running do
			local waited = 0
			while waited < self.interval do
				if not self.running then break end
				task.wait(5)
				waited = waited + 5
			end
			if self.running then
				self:_performAction()
			end
		end
	end)
end

function Afk:stop()
	self.running = false
end

return Afk
