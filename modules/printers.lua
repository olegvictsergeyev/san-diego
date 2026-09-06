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
Printers.PLACE_CONFIRM_TIMEOUT = 2.5
-- Шаг сетки размещения: габарит модели (2.11 x 1.79) минус частичное
-- наложение друг на друга (владелец разрешил компактную укладку).
Printers.GRID_STEP = 1.4
-- Отступ первой ячейки от грани (половина габарита + запас от стены).
Printers.GRID_EDGE_MARGIN = 1.05

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

-- Валидация точки (XZ): рейкаст вниз — должно быть чистое место
-- (пол или уже стоящий принтер ~1.2 высотой). Мебель (dy > 1.3) отсекается.
function Printers:_isFreeSpot(x, z, floorY)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local player = self:_player()
	if player and player.Character then
		params.FilterDescendantsInstances = {player.Character}
	end
	local hit = workspace:Raycast(Vector3.new(x, floorY + 2, z), Vector3.new(0, -3, 0), params)
	if not hit then
		return true -- пусто (на всякий случай считаем свободным)
	end
	return (hit.Position.Y - floorY) <= 1.3
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

-- Размещает ОДИН принтер: экипирует, кликает, ждёт новую модель в папке.
-- Персонаж должен уже стоять в нужной точке и смотреть в нужную сторону.
function Printers:placeOne(room, isCancelled)
	if not room or not room.folder then
		return { success = false, error = "room not detected" }
	end
	local existing = self:countPlaced(room)
	local tool = self:_equipPrinter()
	if not tool then
		return { success = false, error = "no printer tools left in backpack" }
	end
	task.wait(0.35)
	local okClick = self:_clickActivate()
	if not okClick then
		return { success = false, error = "VirtualInputManager unavailable" }
	end
	local t0 = tick()
	while tick() - t0 < self.PLACE_CONFIRM_TIMEOUT do
		task.wait(0.1)
		if isCancelled and isCancelled() then
			return { success = false, error = "cancelled" }
		end
		if self:countPlaced(room) > existing then
			return { success = true, placed = self:countPlaced(room) - existing }
		end
	end
	return { success = false, error = "placement not confirmed (limit/stack/position?)" }
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

-- Строит сетку ячеек: начало от ЛЕВОГО угла стены, на которую смотрит
-- персонаж; колонки идут вправо вдоль стены, ряды — вглубь комнаты.
-- Гарантирует: ячейки не выходят за внутренние границы, позиция персонажа
-- (ячейка минус PLACE_FORWARD вдоль взгляда) остаётся внутри комнаты.
function Printers:buildGrid(room, maxTotal)
	local hrp = self:_player().Character:FindFirstChild("HumanoidRootPart")
	local look = hrp.CFrame.LookVector
	local b = self:_interiorBounds(room.region)

	-- Ось стены — доминирующая ось взгляда; sign — направление взгляда по ней.
	local axis, sign
	if math.abs(look.X) >= math.abs(look.Z) then
		axis, sign = "x", look.X > 0 and 1 or -1
	else
		axis, sign = "z", look.Z > 0 and 1 or -1
	end
	local intoRoom = -sign -- вглубь комнаты (от стены)
	local wallFace = sign > 0
		and (axis == "x" and b.maxX or b.maxZ)
		or (axis == "x" and b.minX or b.minZ)

	-- Правая рука персонажа вдоль стены; левый угол — крайняя точка влево.
	local right = hrp.CFrame.RightVector
	local leftOnB = axis == "x" and -right.Z or -right.X
	local leftOnBSign = leftOnB >= 0 and 1 or -1
	local cornerB = leftOnBSign > 0
		and (axis == "x" and b.maxZ or b.maxX)
		or (axis == "x" and b.minZ or b.minX)
	local bLimit = leftOnBSign > 0
		and (axis == "x" and b.minZ or b.minX)
		or (axis == "x" and b.maxZ or b.maxX)

	local step = self.GRID_STEP
	local margin = self.GRID_EDGE_MARGIN
	local cells = {}
	local skipped = 0
	local row = 0
	while #cells < maxTotal do
		local cellA = wallFace + intoRoom * (margin + row * step)
		local charA = cellA - sign * self.PLACE_FORWARD
		-- позиция персонажа должна оставаться внутри комнаты по оси A
		local aMin = (axis == "x" and b.minX or b.minZ) + 0.5
		local aMax = (axis == "x" and b.maxX or b.maxZ) - 0.5
		if charA < aMin or charA > aMax then
			break
		end
		local col = 0
		local rowCells = 0
		while #cells < maxTotal do
			local cellB = cornerB - leftOnBSign * (margin + col * step)
			-- не пересекаем правый угол
			if leftOnBSign > 0 and cellB < bLimit + margin then break end
			if leftOnBSign < 0 and cellB > bLimit - margin then break end
			local x = axis == "x" and cellA or cellB
			local z = axis == "x" and cellB or cellA
			local forwardVec = axis == "x" and Vector3.new(sign, 0, 0) or Vector3.new(0, 0, sign)
			-- валидация: и под принтер, и под персонажа должно быть свободно
			if self:_isFreeSpot(x, z, b.floorY)
				and self:_isFreeSpot(x - forwardVec.X * self.PLACE_FORWARD, z - forwardVec.Z * self.PLACE_FORWARD, b.floorY) then
				table.insert(cells, {
					x = x, z = z,
					charX = x - forwardVec.X * self.PLACE_FORWARD,
					charZ = z - forwardVec.Z * self.PLACE_FORWARD,
					forward = forwardVec,
					row = row, col = col,
				})
				rowCells = rowCells + 1
			else
				skipped = skipped + 1
			end
			col = col + 1
		end
		row = row + 1
		if rowCells == 0 and col == 0 then
			-- по оси B даже первый ряд не поместился
			break
		end
	end
	return cells, { axis = axis, wallFace = wallFace, bounds = b, skipped = skipped }
end

-- Размещает до maxTotal принтеров сеткой от левого угла стены.
-- Требует: персонаж внутри своей комнаты, смотрит на стену-старт.
function Printers:placeGrid(maxTotal, isCancelled)
	maxTotal = math.clamp(tonumber(maxTotal) or 50, 1, self.MAX_BUY)
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
	local startPlaced = self:countPlaced(room)
	local target = math.min(startPlaced + maxTotal, self.MAX_BUY)
	local cells = self:buildGrid(room, target - startPlaced)
	if #cells == 0 then
		return { success = false, error = "no grid cells fit into the room" }
	end

	local placed = 0
	local failed = 0
	for i, cell in ipairs(cells) do
		if isCancelled and isCancelled() then
			return { success = false, error = "cancelled", placed = placed, failed = failed }
		end
		self:_positionCharacter(cell.charX, cell.charZ, cell.forward)
		local res = self:placeOne(room, isCancelled)
		if res.success then
			placed = placed + 1
		else
			failed = failed + 1
			if res.error ~= "cancelled" and placed + failed == 1 then
				-- первая же ячейка не встала — что-то системно не так, не молотим
				return { success = false, error = res.error, placed = 0, failed = failed }
			end
		end
	end

	return {
		success = placed > 0,
		placed = placed,
		failed = failed,
		existing = startPlaced,
		room_total = self:countPlaced(room),
		cells = #cells,
	}
end

return Printers
