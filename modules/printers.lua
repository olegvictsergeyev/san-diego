-- Модуль учёта и покупки Money Printer.
--
-- Учёт: принтеры — это Tool "Money Printer" (имя содержит "print") в Backpack
-- или в руке (Character). У каждого экземпляра есть атрибут PersistentToolId
-- (уникальный UUID, переживает респавн) — можно различать конкретные принтеры.
--
-- Покупка: на витрине Workspace.Gameplay.WorldBuyableItems["Money Printer"]
-- стоит ProximityPrompt (E, HoldDuration 0.25). Вместо эмуляции клавиши
-- используем прямой ввод prompt:InputHoldBegin()/InputHoldEnd() — официальное
-- API, работает на Xeno/Delta/мобилке одинаково. Покупка верифицируется по
-- фактическому приросту числа принтеров; если прироста нет — останавливаемся
-- (скорее всего не хватило денег).

local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")

local Printers = {}
Printers.__index = Printers

-- Фильтр имён Tool'ов-принтеров (Money Printer, Super Money Printer и т.п.)
Printers.PRINTER_NAME_PATTERN = "print"
-- Витринный предмет за игровую валюту (Super Money Printer / Booster — за Robux)
Printers.DISPLAY_ITEM_NAME = "Money Printer"
-- Больше 50 принтеров персонажу не нужно (лимит расстановки)
Printers.MAX_BUY = 50
-- Пауза между покупками. Замерено на живом сервере: подтверждение выдачи
-- Tool идёт за 0.11–0.16 с, серия из 8 покупок с паузой 0.15–0.8 с прошла
-- без единого несрабатывания. 0.25 с — запас на сетевой джиттер (мобилка).
Printers.BUY_PAUSE = 0.25
-- Сколько ждём фактического появления принтера после нажатия, прежде чем
-- считать покупку неудавшейся (нет денег / лаг сервера).
Printers.BUY_CONFIRM_TIMEOUT = 3

-- Размещение (механика игры, замерено на живом сервере):
-- принтер экипируется в руку, сервер ставит модель на
-- charPos + LookVector * 4 (MoneyPrinterConfig.PLACEMENT_FORWARD_DISTANCE = 4)
-- с рейкастом вниз для поиска пола; активация — клик мышью (Tool.Activated).
Printers.PLACE_FORWARD = 4
-- Шаг сетки размещения: габарит модели (2.11 x 1.79) минус частичное
-- наложение друг на друга (владелец разрешил компактную укладку).
Printers.GRID_STEP = 1.4
-- Отступ первой ячейки от грани (половина габарита + запас от стены).
Printers.GRID_EDGE_MARGIN = 1.05

-- Подбор принтера: клиент вызывает RemoteFunction с ЭКЗЕМПЛЯРОМ модели
-- (InvokeServer(id) сервер отклоняет, InvokeServer(model) — принимает;
-- проверено на живом сервере). Персонажа подводим ближе к точке промпта —
-- сервер может валидировать дистанцию.
Printers.PICKUP_REMOTE_PATH = "__remotes.MoneyPrinterService.PickupMoneyPrinter"
Printers.PICKUP_CONFIRM_TIMEOUT = 5

function Printers.new()
	local self = setmetatable({}, Printers)
	return self
end

function Printers:_player()
	return Players.LocalPlayer
end

function Printers:_isPrinterTool(instance)
	return instance and instance:IsA("Tool")
		and instance.Name:lower():find(self.PRINTER_NAME_PATTERN) ~= nil
end

-- Все Tool'ы-принтеры: рюкзак + рука.
function Printers:_printerTools()
	local player = self:_player()
	local tools = {}
	local backpack = player and player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, child in ipairs(backpack:GetChildren()) do
			if self:_isPrinterTool(child) then
				table.insert(tools, child)
			end
		end
	end
	local character = player and player.Character
	if character then
		for _, child in ipairs(character:GetChildren()) do
			if self:_isPrinterTool(child) then
				table.insert(tools, child)
			end
		end
	end
	return tools
end

-- Полный срез инвентаря: всё в рюкзаке, что в руке, сводка по принтерам.
function Printers:getInventory()
	local player = self:_player()
	local backpack = player and player:FindFirstChildOfClass("Backpack")
	local backpackCounts = {}
	local printersBackpack = 0
	if backpack then
		for _, child in ipairs(backpack:GetChildren()) do
			backpackCounts[child.Name] = (backpackCounts[child.Name] or 0) + 1
			if self:_isPrinterTool(child) then
				printersBackpack = printersBackpack + 1
			end
		end
	end

	local held = nil
	local printersHeld = 0
	local character = player and player.Character
	if character then
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Tool") then
				held = held or child.Name
				if self:_isPrinterTool(child) then
					printersHeld = printersHeld + 1
				end
			end
		end
	end

	local ids = {}
	for _, tool in ipairs(self:_printerTools()) do
		local id = tool:GetAttribute("PersistentToolId")
		table.insert(ids, id or tool.Name)
	end

	return {
		held = held,
		backpack = backpackCounts,
		backpack_total = backpack and #backpack:GetChildren() or 0,
		printers_backpack = printersBackpack,
		printers_held = printersHeld,
		printers_total = printersBackpack + printersHeld,
		printer_ids = ids,
	}
end

-- ProximityPrompt покупки принтера за игровую валюту.
function Printers:findBuyPrompt()
	local gameplay = workspace:FindFirstChild("Gameplay")
	local wbi = gameplay and gameplay:FindFirstChild("WorldBuyableItems")
	local stand = wbi and wbi:FindFirstChild(self.DISPLAY_ITEM_NAME)
	if not stand then
		return nil
	end
	return stand:FindFirstChild("ProximityPrompt", true)
end

-- Дистанция от персонажа до промпта (nil — позиция недоступна).
function Printers:_promptDistance(prompt)
	local player = self:_player()
	local character = player and player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local parent = prompt and prompt.Parent
	if not hrp or not parent then
		return nil
	end
	local pos
	if parent:IsA("Attachment") then
		pos = parent.WorldPosition
	elseif parent:IsA("BasePart") then
		pos = parent.Position
	else
		return nil
	end
	return (pos - hrp.Position).Magnitude
end

-- Можно ли сейчас покупать: промпт включён и персонаж в зоне досягаемости.
function Printers:canBuy(prompt)
	if not prompt or not prompt.Enabled then
		return false
	end
	local dist = self:_promptDistance(prompt)
	if not dist then
		return false
	end
	return dist <= (prompt.MaxActivationDistance or 10)
end

function Printers:_pressPrompt(prompt)
	prompt:InputHoldBegin()
	task.wait((tonumber(prompt.HoldDuration) or 0) + 0.05)
	prompt:InputHoldEnd()
end

-- Купить count принтеров. isCancelled — опциональная функция для остановки.
-- Возвращает { success, bought, ... }: при ошибке — error и сколько куплено.
function Printers:buyPrinters(count, isCancelled)
	local requested = math.clamp(tonumber(count) or 1, 1, self.MAX_BUY)
	local prompt = self:findBuyPrompt()
	if not prompt then
		return { success = false, error = "Money Printer stand not found on this server" }
	end

	local startTotal = self:getInventory().printers_total
	local target = math.min(startTotal + requested, self.MAX_BUY)
	local bought = 0

	while startTotal + bought < target do
		if isCancelled and isCancelled() then
			return { success = false, error = "cancelled", bought = bought }
		end
		if not self:canBuy(prompt) then
			return {
				success = false,
				error = string.format("prompt not reachable (dist=%s)", tostring(self:_promptDistance(prompt))),
				bought = bought,
			}
		end

		self:_pressPrompt(prompt)
		-- Ждём фактического появления принтера (быстрее фиксированной паузы):
		-- сервер подтверждает за ~0.1–0.2 с, при лагах — до BUY_CONFIRM_TIMEOUT.
		local confirmed = false
		local waitStart = tick()
		while tick() - waitStart < self.BUY_CONFIRM_TIMEOUT do
			task.wait(0.1)
			if isCancelled and isCancelled() then
				return { success = false, error = "cancelled", bought = bought }
			end
			if self:getInventory().printers_total > startTotal + bought then
				confirmed = true
				break
			end
		end
		if not confirmed then
			-- Покупка не прошла: обычно не хватило денег (промпт молча отказывает).
			return {
				success = false,
				error = "purchase did not increase printer count (insufficient funds?)",
				bought = bought,
			}
		end
		bought = self:getInventory().printers_total - startTotal
		task.wait(self.BUY_PAUSE)
	end

	return {
		success = true,
		bought = bought,
		requested = requested,
		printers_total = self:getInventory().printers_total,
	}
end

-- ==================== РАЗМЕЩЕНИЕ В КОМНАТЕ ====================

-- Определяет комнату, внутри которой стоит персонаж: ищем юнит квартиры,
-- чей невидимый Part "Region" содержит позицию персонажа. Работает для
-- любой комнаты (комнаты у всех разные, Region есть в каждом юните).
function Printers:detectRoom()
	local player = self:_player()
	local character = player and player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return nil, "character not found"
	end
	local gameplay = workspace:FindFirstChild("Gameplay")
	local units = gameplay and gameplay:FindFirstChild("Apartments") and gameplay.Apartments:FindFirstChild("Units")
	if not units then
		return nil, "apartments not found on this server"
	end
	for _, unit in ipairs(units:GetChildren()) do
		local region = unit:FindFirstChild("Region", true)
		if region and region:IsA("BasePart") then
			local half = region.Size / 2
			local rp = region.Position
			local p = hrp.Position
			if math.abs(p.X - rp.X) <= half.X and math.abs(p.Y - rp.Y) <= half.Y + 3 and math.abs(p.Z - rp.Z) <= half.Z then
				local folder = unit:FindFirstChild("MoneyPrinters", true)
				return {
					unit = unit,
					region = region,
					folder = folder,
					ownerUserId = unit:GetAttribute("ApartmentOwnerUserId"),
				}
			end
		end
	end
	return nil, "character is not inside any apartment room"
end

-- Внутренние границы комнаты.
-- Основной источник — структурные стены: тонкие длинные CanCollide-части
-- вдоль грани региона (мебель таким фильтром не проходит). Если на стороне
-- стены не нашлось — фолбэк: рейкасты от центра региона по 4 сторонам
-- (берём самое дальнее попадание), затем граница региона с запасом.
function Printers:_interiorBounds(region)
	local rp, rs = region.Position, region.Size
	local player = self:_player()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	if player and player.Character then
		params.FilterDescendantsInstances = {player.Character}
	end
	local ray = workspace:Raycast(Vector3.new(rp.X, rp.Y, rp.Z), Vector3.new(0, -rs.Y, 0), params)
	local floorY = ray and ray.Position.Y or (rp.Y - rs.Y / 2)
	local center = Vector3.new(rp.X, floorY + 1.5, rp.Z)
	local maxRay = math.max(rs.X, rs.Z) + 10

	local function comp(v, axis)
		if axis == "X" then return v.X end
		if axis == "Y" then return v.Y end
		return v.Z
	end

	-- стены ищем по всему юниту (родительская цепочка региона ведёт к модели)
	local unit = region:FindFirstAncestorOfClass("Model") or region.Parent
	local function wallFaceFromUnit(axis, side)
		local longAxis = axis == "X" and "Z" or "X"
		local edge = side == "min" and (comp(rp, axis) - comp(rs, axis) / 2)
			or (comp(rp, axis) + comp(rs, axis) / 2)
		local best = nil
		for _, p in ipairs(unit:GetDescendants()) do
			if p:IsA("BasePart") and p.CanCollide then
				local ps, pp = p.Size, p.Position
				if comp(ps, axis) <= 2 and comp(ps, longAxis) >= 8 and ps.Y >= 4
					and math.abs(comp(pp, axis) - edge) < 3 then
					local face = side == "min" and (comp(pp, axis) + comp(ps, axis) / 2)
						or (comp(pp, axis) - comp(ps, axis) / 2)
					if not best or (side == "min" and face > best) or (side == "max" and face < best) then
						best = face
					end
				end
			end
		end
		return best
	end

	local function faceRay(dir)
		local best = nil
		for h = 0.6, 2.6, 1 do
			local origin = Vector3.new(center.X, floorY + h, center.Z)
			local hit = workspace:Raycast(origin, dir * maxRay, params)
			if hit then
				local d = (hit.Position - origin).Magnitude
				if not best or d > best then
					best = d
				end
			end
		end
		return best
	end

	local margin = 0.6
	local minXW, maxXW = wallFaceFromUnit("X", "min"), wallFaceFromUnit("X", "max")
	local minZW, maxZW = wallFaceFromUnit("Z", "min"), wallFaceFromUnit("Z", "max")
	local minXD, maxXD = faceRay(Vector3.new(-1, 0, 0)), faceRay(Vector3.new(1, 0, 0))
	local minZD, maxZD = faceRay(Vector3.new(0, 0, -1)), faceRay(Vector3.new(0, 0, 1))
	local margin = 0.6
	-- грани региона по осям
	local regionMinX, regionMaxX = rp.X - rs.X / 2, rp.X + rs.X / 2
	local regionMinZ, regionMaxZ = rp.Z - rs.Z / 2, rp.Z + rs.Z / 2
	return {
		minX = minXW or (minXD and (center.X - minXD + margin) or (regionMinX + margin)),
		maxX = maxXW or (maxXD and (center.X + maxXD - margin) or (regionMaxX - margin)),
		minZ = minZW or (minZD and (center.Z - minZD + margin) or (regionMinZ + margin)),
		maxZ = maxZW or (maxZD and (center.Z + maxZD - margin) or (regionMaxZ - margin)),
		floorY = floorY,
	}
end

-- Валидация точки (XZ): повторяем серверный профиль рейкаста — вниз
-- с высоты персонажа (~floorY+4). Любой хит выше пола — мебель/шкаф/
-- стоящий принтер → точка занята. Отсутствие хита — считаем занятым.
function Printers:_isFreeSpot(x, z, floorY)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local player = self:_player()
	if player and player.Character then
		params.FilterDescendantsInstances = {player.Character}
	end
	local hit = workspace:Raycast(Vector3.new(x, floorY + 3.8, z), Vector3.new(0, -5, 0), params)
	if not hit then
		return false
	end
	return hit.Position.Y <= floorY + 0.1
end

-- Число уже стоящих принтеров (моделей с MoneyPrinterId) в комнате.
function Printers:countPlaced(room)
	if not room or not room.folder then
		return 0
	end
	local n = 0
	for _, c in ipairs(room.folder:GetChildren()) do
		if c:GetAttribute("MoneyPrinterId") then
			n = n + 1
		end
	end
	return n
end

-- Экипирует один принтер из рюкзака в руку.
function Printers:_equipPrinter()
	local player = self:_player()
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local backpack = player and player:FindFirstChildOfClass("Backpack")
	if not (humanoid and backpack) then
		return nil
	end
	-- уже в руке? (неудачная конверсия на прошлой попытке)
	for _, c in ipairs(character:GetChildren()) do
		if self:_isPrinterTool(c) then
			return c
		end
	end
	local tool = nil
	for _, c in ipairs(backpack:GetChildren()) do
		if self:_isPrinterTool(c) then
			tool = c
			break
		end
	end
	if not tool then
		return nil
	end
	humanoid:EquipTool(tool)
	return tool
end

-- Активация экипированного инструмента: клик в центр экрана через
-- VirtualInputManager (официальный ввод, реплицируется на сервер).
function Printers:_clickActivate()
	local camera = workspace.CurrentCamera
	if not camera then
		return false
	end
	local vp = camera.ViewportSize
	local x, y = vp.X / 2, vp.Y / 2
	VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
	task.wait(0.08)
	VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
	return true
end

-- Ставит персонажа в точку (XZ) и разворачивает по заданному вектору.
-- Микроперемещения ≤ 4 ст с паузами — скорость ~единицы ст/с, что на порядки
-- ниже порога античита; ходить нельзя — расставленные принтеры блокируют путь.
function Printers:_positionCharacter(x, z, forwardVec)
	local hrp = self:_player().Character:FindFirstChild("HumanoidRootPart")
	local pos = Vector3.new(x, hrp.Position.Y, z)
	hrp.CFrame = CFrame.new(pos, pos + forwardVec)
	task.wait(0.15)
end

-- Находит RemoteFunction подбора по пути из конфига.
function Printers:_pickupRemote()
	local node = game:GetService("ReplicatedStorage")
	for part in self.PICKUP_REMOTE_PATH:gmatch("[^%.]+") do
		node = node and node:FindFirstChild(part)
	end
	return node
end

-- Подбирает один принтер (модель из папки MoneyPrinters комнаты).
-- Подводит персонажа к точке промпта, вызывает RemoteFunction с моделью,
-- ждёт исчезновения модели из папки. Надёжность (проверено на живом
-- сервере): после микротелепорта ждём 0.7 с — сервер должен увидеть
-- новую позицию персонажа, иначе InvokeServer вернёт false (старая
-- позиция слишком далеко от промпта, персонаж «стоит на принтере»).
-- Неуспех → до 3 попыток с повторным подводом.
-- Персонаж всегда подводится в сторону ЦЕНТРА апартамента (и не выходит
-- за внутренние границы) — иначе при промпте, обращённом к стене,
-- персонаж телепортировался за пределы комнаты.
function Printers:_pickupOne(model, isCancelled)
	if not (model and model.Parent) then
		return { success = false, error = "model is gone" }
	end
	local remote = self:_pickupRemote()
	if not remote then
		return { success = false, error = "pickup remote not found" }
	end
	local room = self:detectRoom()
	if not room then
		return { success = false, error = "not inside an apartment" }
	end
	local b = self:_interiorBounds(room.region)
	local center = room.region.Position
	local modelPos = model:GetBoundingBox().Position
	local prompt = model:FindFirstChild("MoneyPrinterPickupPrompt", true)
	local wp = prompt and prompt.Parent and prompt.Parent.WorldPosition
	local lastErr = "unknown"
	for attempt = 1, 3 do
		if not model.Parent then
			return { success = true }
		end
		if isCancelled and isCancelled() then
			return { success = false, error = "cancelled" }
		end
		-- направление от принтера к центру апартамента (внутрь, вдали от стен)
		local dir = Vector3.new(center.X - modelPos.X, 0, center.Z - modelPos.Z)
		if dir.Magnitude < 0.01 then
			dir = Vector3.new(1, 0, 0)
		end
		local cx = math.clamp(modelPos.X + dir.Unit.X * 2.5, b.minX + 0.5, b.maxX - 0.5)
		local cz = math.clamp(modelPos.Z + dir.Unit.Z * 2.5, b.minZ + 0.5, b.maxZ - 0.5)
		self:_positionCharacter(cx, cz, dir.Unit)
		task.wait(0.7) -- репликация позиции на сервер
		if wp and (Vector3.new(cx, 0, cz) - Vector3.new(wp.X, 0, wp.Z)).Magnitude > 7 then
			lastErr = "character too far from prompt after clamping"
			task.wait(0.5)
		else
			local ok, res = pcall(function()
				return remote:InvokeServer(model)
			end)
			if not ok then
				lastErr = "pickup invoke failed: " .. tostring(res)
			else
				lastErr = "pickup not confirmed (res=" .. tostring(res) .. ")"
				local t0 = tick()
				while tick() - t0 < self.PICKUP_CONFIRM_TIMEOUT do
					if isCancelled and isCancelled() then
						return { success = false, error = "cancelled" }
					end
					task.wait(0.1)
					if not model.Parent then
						return { success = true }
					end
				end
			end
			task.wait(0.5)
		end
	end
	return { success = false, error = lastErr }
end

-- Подбирает ВСЕ расставленные принтеры апартамента (все комнаты).
-- Каждый подбор — через _pickupOne (подвод + 0.7 с + ретрай), поэтому
-- срабатывает даже если персонаж стоит на принтере.
function Printers:pickupAllPrinters(isCancelled)
	local room, err = self:detectRoom()
	if not room then
		return { success = false, error = err }
	end
	if not room.folder then
		return { success = false, error = "MoneyPrinters folder not found in room" }
	end
	local player = self:_player()
	if room.ownerUserId and room.ownerUserId ~= player.UserId then
		return { success = false, error = "room is owned by another player (ApartmentOwnerUserId=" .. tostring(room.ownerUserId) .. ")" }
	end
	local targets = {}
	for _, c in ipairs(room.folder:GetChildren()) do
		if c:GetAttribute("MoneyPrinterId") then
			table.insert(targets, c)
		end
	end
	if #targets == 0 then
		return { success = false, error = "no placed printers found" }
	end
	local picked, failed = 0, 0
	for _, model in ipairs(targets) do
		if isCancelled and isCancelled() then
			return { success = false, error = "cancelled", picked = picked, failed = failed + (#targets - picked - failed) }
		end
		local res = self:_pickupOne(model, isCancelled)
		if res.success then
			picked = picked + 1
		else
			failed = failed + 1
			if res.error == "cancelled" then
				return { success = false, error = "cancelled", picked = picked, failed = failed }
			end
		end
	end
	return {
		success = picked > 0,
		picked = picked,
		failed = failed,
		inventory = self:getInventory().printers_total,
		room_total = self:countPlaced(room),
	}
end

-- Подбирает принтеры комнаты. Фильтры:
--   opts.printer_id — конкретный принтер по MoneyPrinterId;
--   opts.floating   — только «плавающие» (дно выше пола комнаты > 1.5 ст,
--                     например те, что встали на шкаф вместо пола);
--   opts.max_count  — не больше столько штук.
-- Без printer_id и floating=true возвращает ошибку (защита от сбора всего).
function Printers:pickupPrinters(opts, isCancelled)
	opts = opts or {}
	local room, err = self:detectRoom()
	if not room then
		return { success = false, error = err }
	end
	if not room.folder then
		return { success = false, error = "MoneyPrinters folder not found in room" }
	end
	local player = self:_player()
	if room.ownerUserId and room.ownerUserId ~= player.UserId then
		return { success = false, error = "room is owned by another player (ApartmentOwnerUserId=" .. tostring(room.ownerUserId) .. ")" }
	end
	if not opts.printer_id and not opts.floating then
		return { success = false, error = "specify printer_id or floating=true" }
	end

	local b = self:_interiorBounds(room.region)
	local maxCount = math.clamp(tonumber(opts.max_count) or self.MAX_BUY, 1, self.MAX_BUY)
	local targets = {}
	for _, c in ipairs(room.folder:GetChildren()) do
		local id = c:GetAttribute("MoneyPrinterId")
		if id then
			local match = false
			if opts.printer_id then
				match = (id == opts.printer_id)
			elseif opts.floating then
				local cf, size = c:GetBoundingBox()
				match = (cf.Position.Y - size.Y / 2) > b.floorY + 1.5
			end
			if match then
				table.insert(targets, c)
			end
		end
		if #targets >= maxCount then
			break
		end
	end
	if #targets == 0 then
		return { success = false, error = "no matching printers found" }
	end

	local picked = 0
	local failed = 0
	for _, model in ipairs(targets) do
		if isCancelled and isCancelled() then
			return { success = false, error = "cancelled", picked = picked, failed = failed }
		end
		local res = self:_pickupOne(model, isCancelled)
		if res.success then
			picked = picked + 1
		else
			failed = failed + 1
			if res.error == "cancelled" then
				return { success = false, error = "cancelled", picked = picked, failed = failed }
			end
		end
	end
	return {
		success = picked > 0,
		picked = picked,
		failed = failed,
		inventory = self:getInventory().printers_total,
		room_total = self:countPlaced(room),
	}
end

-- === Раскладка в комнате (прижато к стенам) ===
-- Геометрия калибрована на живом сервере: сервер ставит модель на
-- charPos + look*4; корпус выступает назад (к стене) на PRINTER_BACK,
-- полуширина вдоль стены PRINTER_SIDE. Старт — от левого угла стены,
-- напротив которой дверь; ряды идут вглубь комнаты шагом GRID_STEP.
Printers.PRINTER_BACK = 1.095
Printers.PRINTER_SIDE = 0.962
Printers.FLUSH_EPS = 0.02

local DOOR_OPPOSITE = { minX = "maxX", maxX = "minX", minZ = "maxZ", maxZ = "minZ" }

-- Прямоугольник комнаты вокруг персонажа: рейкасты в 4 стороны
-- (максимум по высотам 0.3..2.5 — перепрыгиваем мелкую мебель),
-- ужатые границами апартамента.
function Printers:detectRoomRect()
	local room, err = self:detectRoom()
	if not room then
		return nil, err
	end
	local b = self:_interiorBounds(room.region)
	local player = self:_player()
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return nil, "HumanoidRootPart not found"
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {player.Character}
	local px, pz = hrp.Position.X, hrp.Position.Z
	local function wallDist(dir)
		local best = nil
		for dy = 0.3, 2.5, 0.55 do
			local hit = workspace:Raycast(Vector3.new(px, b.floorY + dy, pz), dir * 40, params)
			if hit then
				best = math.max(best or 0, hit.Distance)
			end
		end
		return best
	end
	local rect = {
		minX = b.minX, maxX = b.maxX, minZ = b.minZ, maxZ = b.maxZ,
		floorY = b.floorY,
		region = room.region, unit = room.unit, folder = room.folder,
		ownerUserId = room.ownerUserId,
	}
	local dW = wallDist(Vector3.new(-1, 0, 0))
	if dW then rect.minX = math.max(px - dW + 0.05, b.minX) end
	local dE = wallDist(Vector3.new(1, 0, 0))
	if dE then rect.maxX = math.min(px + dE - 0.05, b.maxX) end
	local dS = wallDist(Vector3.new(0, 0, -1))
	if dS then rect.minZ = math.max(pz - dS + 0.05, b.minZ) end
	local dN = wallDist(Vector3.new(0, 0, 1))
	if dN then rect.maxZ = math.min(pz + dN - 0.05, b.maxZ) end
	return rect
end

-- Сторона комнаты с дверью: модель "Door" → ближайшая стена rect'а.
-- nil, если дверь не найдена.
function Printers:findDoorSide(rect)
	local door = rect.unit and rect.unit:FindFirstChild("Door", true)
	if not door then
		return nil
	end
	local pos = door:IsA("Model") and door:GetBoundingBox().Position or door.Position
	local cands = {
		{ "minX", math.abs(pos.X - rect.minX) },
		{ "maxX", math.abs(pos.X - rect.maxX) },
		{ "minZ", math.abs(pos.Z - rect.minZ) },
		{ "maxZ", math.abs(pos.Z - rect.maxZ) },
	}
	table.sort(cands, function(a, b2)
		return a[2] < b2[2]
	end)
	return cands[1][1]
end

-- Сетка ячеек внутри комнаты: прижата к startSide стене (зад на
-- PRINTER_BACK+EPS от стены), первый принтер прижат к левому углу,
-- колонки вдоль стены шагом GRID_STEP, ряды вглубь. Ячейки валидируются
-- рейкастами (мебель, шкафы, уже стоящие принтеры).
function Printers:buildRoomGrid(rect, startSide, maxTotal)
	local axis, sign, wallFace
	if startSide == "minX" then axis, sign, wallFace = "x", -1, rect.minX
	elseif startSide == "maxX" then axis, sign, wallFace = "x", 1, rect.maxX
	elseif startSide == "minZ" then axis, sign, wallFace = "z", -1, rect.minZ
	else axis, sign, wallFace = "z", 1, rect.maxZ end
	local faced = axis == "x" and Vector3.new(sign, 0, 0) or Vector3.new(0, 0, sign)
	local left = Vector3.new(faced.Z, 0, -faced.X)
	local leftOnB = axis == "x" and left.Z or left.X
	local leftBSign = leftOnB >= 0 and 1 or -1
	local cornerB = leftBSign > 0
		and (axis == "x" and rect.maxZ or rect.maxX)
		or (axis == "x" and rect.minZ or rect.minX)
	local bLimit = leftBSign > 0
		and (axis == "x" and rect.minZ or rect.minX)
		or (axis == "x" and rect.maxZ or rect.maxX)
	local step = self.GRID_STEP
	local back = self.PRINTER_BACK + self.FLUSH_EPS
	local side = self.PRINTER_SIDE + self.FLUSH_EPS
	local cells = {}
	local row = 0
	while #cells < maxTotal do
		local cellA = wallFace - sign * (back + row * step)
		local charA = cellA - sign * self.PLACE_FORWARD
		local aMin = (axis == "x" and rect.minX or rect.minZ) + 0.5
		local aMax = (axis == "x" and rect.maxX or rect.maxZ) - 0.5
		if charA < aMin or charA > aMax then
			break
		end
		local col, rowCells = 0, 0
		while #cells < maxTotal do
			local cellB = cornerB - leftBSign * (side + col * step)
			if leftBSign > 0 and cellB - side < bLimit + self.FLUSH_EPS then break end
			if leftBSign < 0 and cellB + side > bLimit - self.FLUSH_EPS then break end
			local x = axis == "x" and cellA or cellB
			local z = axis == "x" and cellB or cellA
			if self:_isFreeSpot(x, z, rect.floorY)
				and self:_isFreeSpot(x - faced.X * self.PLACE_FORWARD, z - faced.Z * self.PLACE_FORWARD, rect.floorY) then
				table.insert(cells, {
					x = x, z = z,
					charX = x - faced.X * self.PLACE_FORWARD,
					charZ = z - faced.Z * self.PLACE_FORWARD,
					forward = faced, row = row, col = col,
				})
				rowCells = rowCells + 1
			end
			col = col + 1
			if col > 80 then break end
		end
		row = row + 1
		if rowCells == 0 and col == 0 then
			break
		end
		if row > 60 then break end
	end
	return cells
end

-- Ставит один принтер в ячейку: подвод (0.6 с на репликацию), экипировка,
-- клик, поиск новой модели, сверка bbox с ячейкой (прижат к стене);
-- при промахе — подбор и повтор, до 3 попыток.
-- Диагностика: attempts-log с причиной каждой попытки (в error data),
-- чтобы по результату команды было видно, где именно обрывается цепочка.
function Printers:_placeCell(rect, cell, isCancelled)
	local axisX = math.abs(cell.forward.X) > 0.5
	local attemptsLog = {}
	for attempt = 1, 3 do
		if isCancelled and isCancelled() then
			return { success = false, error = "cancelled" }
		end
		self:_positionCharacter(cell.charX, cell.charZ, cell.forward)
		task.wait(0.6)
		local existing = {}
		for _, c in ipairs(rect.folder:GetChildren()) do
			if c:GetAttribute("MoneyPrinterId") then
				existing[c] = true
			end
		end
		local beforeCount = 0
		for _ in pairs(existing) do
			beforeCount = beforeCount + 1
		end
		local tool = self:_equipPrinter()
		if not tool then
			table.insert(attemptsLog, string.format("attempt %d: no printer tool left", attempt))
			return { success = false, error = "no printer tool left", attempts_log = attemptsLog }
		end
		task.wait(0.4)
		self:_clickActivate()
		local newModel, t0 = nil, tick()
		while tick() - t0 < 4 do
			if isCancelled and isCancelled() then
				return { success = false, error = "cancelled" }
			end
			task.wait(0.2)
			for _, c in ipairs(rect.folder:GetChildren()) do
				if c:GetAttribute("MoneyPrinterId") and not existing[c] then
					newModel = c
				end
			end
			if newModel then
				break
			end
		end
		if newModel then
			task.wait(0.5)
			local cf, size = newModel:GetBoundingBox()
			local backCoord, expectedBack, lateralErr
			if axisX then
				backCoord = cell.forward.X < 0 and (cf.Position.X - size.X / 2) or (cf.Position.X + size.X / 2)
				expectedBack = cell.x + cell.forward.X * self.PRINTER_BACK
				lateralErr = math.abs(cf.Position.Z - cell.z)
			else
				backCoord = cell.forward.Z < 0 and (cf.Position.Z - size.Z / 2) or (cf.Position.Z + size.Z / 2)
				expectedBack = cell.z + cell.forward.Z * self.PRINTER_BACK
				lateralErr = math.abs(cf.Position.X - cell.x)
			end
			if math.abs(backCoord - expectedBack) < 0.15 and lateralErr < 0.5 then
				return { success = true }
			end
			-- промах (устаревшая позиция/поворот на сервере) — снять и повторить
			table.insert(attemptsLog, string.format(
				"attempt %d: model spawned but misplaced (back err %.2f, lateral err %.2f)",
				attempt, math.abs(backCoord - expectedBack), lateralErr))
			self:_pickupOne(newModel, isCancelled)
			task.wait(0.5)
		else
			-- модель не появилась: сервер отклонил постановку. Уточняем причину.
			local note = string.format("attempt %d: no model after 4s (folder had %d)", attempt, beforeCount)
			local hrp = self:_player().Character and self:_player().Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				note = note .. string.format(", char at (%.1f, %.1f, %.1f)", hrp.Position.X, hrp.Position.Y, hrp.Position.Z)
				local dev = math.sqrt((hrp.Position.X - cell.charX) ^ 2 + (hrp.Position.Z - cell.charZ) ^ 2)
				if dev > 1.5 then
					note = note .. string.format(" — POSITION REVERTED (dev %.1f studs from cell)", dev)
				end
			end
			local hum = self:_player().Character and self:_player().Character:FindFirstChildOfClass("Humanoid")
			if hum and hum:GetState() == Enum.HumanoidStateType.Dead then
				note = note .. " — HUMANOID DEAD"
			end
			-- инструмент остался в руке? (клик мог уйти в UI вместо мира)
			local held = nil
			for _, c in ipairs(self:_player().Character:GetChildren()) do
				if self:_isPrinterTool(c) then
					held = c.Name
					break
				end
			end
			note = note .. (held and (", tool still held: " .. held) or ", tool GONE (consumed/returned)")
			table.insert(attemptsLog, note)
		end
	end
	return { success = false, error = "placement failed after retries", attempts_log = attemptsLog }
end

-- Раскладывает до maxTotal принтеров сеткой по комнате персонажа.
-- Стартовая стена — напротив двери (модель Door), фолбэк — стена,
-- на которую смотрит персонаж.
function Printers:placeRoomGrid(maxTotal, isCancelled)
	maxTotal = math.clamp(tonumber(maxTotal) or 50, 1, self.MAX_BUY)
	local rect, err = self:detectRoomRect()
	if not rect then
		return { success = false, error = err }
	end
	if not rect.folder then
		return { success = false, error = "MoneyPrinters folder not found in room" }
	end
	local player = self:_player()
	if rect.ownerUserId and rect.ownerUserId ~= player.UserId then
		return { success = false, error = "room is owned by another player (ApartmentOwnerUserId=" .. tostring(rect.ownerUserId) .. ")" }
	end
	local doorSide = self:findDoorSide(rect)
	local startSide = doorSide and DOOR_OPPOSITE[doorSide] or nil
	if not startSide then
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not hrp then
			return { success = false, error = "HumanoidRootPart not found" }
		end
		local look = hrp.CFrame.LookVector
		if math.abs(look.X) >= math.abs(look.Z) then
			startSide = look.X > 0 and "maxX" or "minX"
		else
			startSide = look.Z > 0 and "maxZ" or "minZ"
		end
	end
	local cells = self:buildRoomGrid(rect, startSide, maxTotal)
	if #cells == 0 then
		return { success = false, error = "no grid cells fit into the room" }
	end
	local placed, failed = 0, 0
	for _, cell in ipairs(cells) do
		if isCancelled and isCancelled() then
			return { success = false, error = "cancelled", placed = placed, failed = failed }
		end
		local res = self:_placeCell(rect, cell, isCancelled)
		if res.success then
			placed = placed + 1
		else
			if res.error == "cancelled" then
				return { success = false, error = "cancelled", placed = placed, failed = failed }
			end
			if res.error == "no printer tool left" then
				break
			end
			failed = failed + 1
			if placed + failed == 1 then
				return { success = false, error = res.error, placed = 0, failed = failed, attempts_log = res.attempts_log }
			end
		end
	end
	return {
		success = placed > 0,
		placed = placed,
		failed = failed,
		cells = #cells,
		start_side = startSide,
		room_total = self:countPlaced({ folder = rect.folder }),
	}
end

-- Встаёт персонажем ровно по центру комнаты спиной к стене с дверью
-- (лицом от двери). Дверь ищется по модели Door; без двери — спиной
-- к ближайшей к исходному положению стене.
function Printers:standCenterBackToDoor()
	local rect, err = self:detectRoomRect()
	if not rect then
		return { success = false, error = err }
	end
	local player = self:_player()
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return { success = false, error = "HumanoidRootPart not found" }
	end
	local doorSide = self:findDoorSide(rect)
	local faceDir
	if doorSide == "maxX" then faceDir = Vector3.new(-1, 0, 0)
	elseif doorSide == "minX" then faceDir = Vector3.new(1, 0, 0)
	elseif doorSide == "maxZ" then faceDir = Vector3.new(0, 0, -1)
	elseif doorSide == "minZ" then faceDir = Vector3.new(0, 0, 1)
	else
		local look = hrp.CFrame.LookVector
		faceDir = Vector3.new(-look.X, 0, -look.Z)
		if faceDir.Magnitude < 0.01 then
			faceDir = Vector3.new(1, 0, 0)
		end
	end
	local cx = (rect.minX + rect.maxX) / 2
	local cz = (rect.minZ + rect.maxZ) / 2
	self:_positionCharacter(cx, cz, faceDir)
	return {
		success = true,
		x = cx, z = cz,
		facing = { math.round(faceDir.X * 100) / 100, math.round(faceDir.Z * 100) / 100 },
		door_side = doorSide,
	}
end

return Printers
