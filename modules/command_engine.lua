local Players = game:GetService("Players")

local CommandEngine = {}
CommandEngine.__index = CommandEngine

function CommandEngine.new(privateServer, afk, state, printers, vehicles, apartments)
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
	if printers then
		self.printers = printers
	else
		local ok, Printers = pcall(function()
			return require(script.Parent:WaitForChild("printers"))
		end)
		if ok and Printers then
			self.printers = Printers.new()
		end
	end
	if vehicles then
		self.vehicles = vehicles
	else
		local ok, Vehicles = pcall(function()
			return require(script.Parent:WaitForChild("vehicles"))
		end)
		if ok and Vehicles then
			self.vehicles = Vehicles.new()
		end
	end
	if apartments then
		self.apartments = apartments
	else
		local ok, Apartments = pcall(function()
			return require(script.Parent:WaitForChild("apartments"))
		end)
		if ok and Apartments then
			self.apartments = Apartments.new()
		end
	end
	return self
end

function CommandEngine:setAfk(afk)
	self.afk = afk
end

function CommandEngine:setPrinters(printers)
	self.printers = printers
end

function CommandEngine:setVehicles(vehicles)
	self.vehicles = vehicles
end

function CommandEngine:setApartments(apartments)
	self.apartments = apartments
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
			description = "Умереть и возродиться. Команда завершается только когда персонаж полностью готов выполнять новые команды (новый character, живой гуманоид, HumanoidRootPart); таймаут готовности 30 с. skip_in_spawn=true — не респавниться, если персонаж уже в зоне спавна (успех с respawned=false, skipped=true)",
			params = {
				skip_in_spawn = {
					type = "boolean",
					required = false,
					description = "true = не респавниться, если персонаж уже в зоне спавна (его TeamColor или Neutral SpawnLocation, до 6 ст от края площадки); возвращает успех с respawned=false, skipped=true",
				},
			},
		},
		{
			name = "spawn_vehicle",
			description = "Заспавнить технику с ближайшей VehicleSpawner-площадки без открытия панели (без клавиши E). Сервер сам решает вопросы доступа и владения",
			params = {
				name = {
					type = "string",
					required = true,
					min = 1,
					max = 64,
					description = "Имя техники как в списке спавнера (например ducati, C63DTM, 911)",
				},
			},
		},
		{
			name = "rent_apartment",
			description = "Арендовать номер отеля: тот же серверный вызов, что кнопка Purchase Apartment на двери (без нажатия E). Если номер уже арендован — покупка не выполняется, возвращается already_rented. Персонаж должен стоять у неарендованной парадной двери (до 20 ст). apartment_id: конкретный номер, 0 или не передан — ближайшая свободная дверь. Требует команды Civilian",
			params = {
				apartment_id = {
					type = "integer",
					required = false,
					min = 0,
					max = 10000,
					description = "ApartmentId конкретного номера; 0 или не передан — ближайшая свободная парадная дверь",
				},
			},
		},
		{
			name = "open_door",
			description = "Открыть дверь номера: тот же серверный вызов, что кнопка Open Door (без нажатия E). Если дверь уже открыта — ничего не делает, возвращает успех с open=true. Ближайшая доступная дверь (своя парадная или любая Interior, до 20 ст)",
			params = {},
		},
		{
			name = "close_door",
			description = "Закрыть дверь номера: тот же серверный вызов, что кнопка Close Door (без нажатия E). Если дверь уже закрыта — ничего не делает, возвращает успех с open=false. Ближайшая доступная дверь (своя парадная или любая Interior, до 20 ст)",
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
			name = "get_inventory",
			description = "Вернуть инвентарь персонажа: содержимое рюкзака (по именам с количеством), предмет в руке и сводку по принтерам (в рюкзаке, в руке, суммарно, с уникальными id экземпляров)",
			params = {},
		},
		{
			name = "pickup_printer",
			description = "Подобрать расставленные Money Printer обратно в инвентарь. Работает в своей комнате. Нужен фильтр: либо printer_id (MoneyPrinterId модели), либо floating=true — только «плавающие» принтеры (вставшие не на пол, например на шкаф). Каждый подбор верифицируется по исчезновению модели",
			params = {
				printer_id = {
					type = "string",
					required = false,
					min = 1,
					max = 64,
					description = "MoneyPrinterId конкретного принтера (опционально, вместо floating)",
				},
				floating = {
					type = "boolean",
					required = false,
					description = "Подбирать только «плавающие» принтеры (дно выше пола комнаты > 1.5 ст)",
				},
				max_count = {
					type = "integer",
					required = false,
					min = 1,
					max = 50,
					description = "Максимум принтеров для подбора (по умолчанию 50)",
				},
			},
		},
		{
			name = "pickup_all_printers",
			description = "Подобрать ВСЕ расставленные Money Printer апартамента (все комнаты) обратно в инвентарь. Надёжно: перед каждым подбором персонаж подводится к промпту и ждётся репликация позиции на сервер, неуспешные подборы повторяются до 3 раз — срабатывает даже если персонаж стоит на принтере. Требует стоять внутри своего апартамента",
			params = {},
		},
		{
			name = "deploy_printers",
			description = "Проверить инвентарь и расстановку принтеров: если у персонажа есть Money Printer в рюкзаке/руке и разложено менее 50 — подобрать все разложенные и разложить заново сеткой по комнате (ряды прижаты к стене напротив двери, шаг 1.4, валидация мебели). Затем встать ровно по центру комнаты спиной к стене с дверью. Если принтеров в инвентаре нет — только встать по центру спиной к двери. Требует стоять в целевой комнате своего апартамента",
			params = {},
		},
		{
			name = "fly_car",
			description = "Полёт машины: поднять и держать на высоте, пока не придёт отмена. height — градация 0..10, 1 = ~1 ст над поверхностью (рейкаст), 10 = +10 ст — максимум, разрешённый анти-читом в движении (висение выше не требуется). height=0 — быстрая посадка (падение + тормоз) и завершение сессии. Машина держится стабильно на месте. Требует сидеть в машине",
			params = {
				height = {
					type = "integer",
					required = true,
					min = 0,
					max = 10,
					description = "Градация высоты 0..10 (1 ≈ 1 ст над поверхностью, 10 = максимум безопасной; 0 = посадка)",
				},
			},
		},
		{
			name = "nav_car",
			description = "Перемещение летающей машины на смещение по осям: x и z — расстояние в стадах со знаком направления (±2000). По оси Y машина НЕ смещается: летит на текущей высоте (при активной сессии fly_car — на её высоте, иначе на текущей над поверхностью), повторяя рельеф. Скорость фиксированная 20 ст/с. Прерывается командой cancel: движение остановится, при активной сессии fly_car машина останется висеть, иначе сессия завершится. Требует сидеть в машине",
			params = {
				x = {
					type = "integer",
					required = true,
					min = -2000,
					max = 2000,
					description = "Смещение по X в стадах (+/- направление)",
				},
				z = {
					type = "integer",
					required = true,
					min = -2000,
					max = 2000,
					description = "Смещение по Z в стадах (+/- направление)",
				},
			},
		},
		{
			name = "buy_printer",
			description = "Купить N Money Printer у витрины. Требует стоять у витрины (prompt в зоне досягаемости). Покупка выполняется прямым вводом в ProximityPrompt (без эмуляции клавиш), каждая покупка верифицируется по фактическому приросту числа принтеров; при нехватке денег команда останавливается и возвращает сколько куплено",
			params = {
				count = {
					type = "integer",
					required = false,
					min = 1,
					max = 50,
					description = "Сколько принтеров купить (по умолчанию 1, максимум 50)",
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
			name = "drive",
			description = "Наземная езда (мотоцикл/машина). x — смещение по оси X со знаком направления в стадах (±20000); торможение резкое с остановкой у цели. z — абсолютная координата полосы (по умолчанию 150.07 — главный проспект); если z не передан — машина быстро выравнивается на эту полосу и придерживается её всю дистанцию. Если x не передан (0) — только встать в полосу z, не уезжая. speed — ограничение скорости по шкале 0..10 (линейно 0..580 ст/с; 10 или отсутствует = полная скорость, 0 = не уезжать, только встать в полосу). При встрече невидимых стен полоса смещается; если свободной полосы нет — торможение и ошибка blocked. Требует сидеть в транспорте",
			params = {
				x = {
					type = "integer",
					required = false,
					min = -20000,
					max = 20000,
					description = "Смещение по X в стадах со знаком (0 или отсутствует = не уезжать, только встать в полосу z)",
				},
				z = {
					type = "number",
					required = false,
					min = -20000,
					max = 20000,
					description = "Абсолютная координата полосы z (по умолчанию 150.07 — главный проспект San Diego)",
				},
				speed = {
					type = "integer",
					required = false,
					min = 0,
					max = 10,
					description = "Ограничение скорости по шкале 0..10: линейно 0..580 ст/с (10 или отсутствует = полная; 0 = не уезжать, только встать в полосу)",
				},
				jump_off = {
					type = "boolean",
					required = false,
					description = "true = не тормозить у цели: по достижении цели спрыгнуть с транспорта, техника с сохранением скорости катится дальше сама (по умолчанию false — обычная остановка у цели)",
				},
			},
		},
		{
			name = "update_agent",
			description = "Обновить агента до актуальной версии: штатная остановка и перезапуск загрузчика с GitHub",
			params = {
				delay = {
					type = "integer",
					required = false,
					min = 0,
					max = 300,
					description = "Задержка перед перезапуском в секундах (по умолчанию 5)",
				},
			},
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
				min = 0,
				max = 10,
				description = "Скорость поворота: 10 — быстро (по умолчанию), 1 — медленно, 0 — ничего не делать (ни персонаж, ни камера не поворачиваются)",
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

-- Защита шаговых телепортов (move_x/z, move_to): не входить в стены
-- и препятствия. Перед шагом луч вперёд на уровне пояса; при ударе —
-- пробуем подъём: вершина ≤12 ст над текущим уровнем → переносим шаг на
-- вершину, иначе шаг блокируется. После шага луч вниз прилипает к земле
-- (склоны/холмы — подъём/спуск, а не провал внутрь геометрии).
-- Возвращает скорректированную позицию или nil + причина.
function CommandEngine:_adjustStep(currentPos, targetPos)
	local char = self:_getCharacter()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	local flat = Vector3.new(targetPos.X - currentPos.X, 0, targetPos.Z - currentPos.Z)
	local dist = flat.Magnitude
	if dist > 0.01 then
		local dir = flat.Unit
		local hit = workspace:Raycast(currentPos + Vector3.new(0, -1, 0), dir * (dist + 2), params)
		if hit then
			local probe = workspace:Raycast(hit.Position + dir * 1.5 + Vector3.new(0, 25, 0), Vector3.new(0, -60, 0), params)
			local topY = probe and probe.Position.Y
			if topY and (topY - currentPos.Y) <= 12 then
				targetPos = Vector3.new(targetPos.X, topY + 3.2, targetPos.Z)
			else
				return nil, "blocked: " .. hit.Instance.Name
			end
		end
	end
	local down = workspace:Raycast(targetPos + Vector3.new(0, 5, 0), Vector3.new(0, -60, 0), params)
	if down then
		targetPos = Vector3.new(targetPos.X, down.Position.Y + 3.2, targetPos.Z)
	end
	return targetPos
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

	-- Базовые шаги: speed=10 = 8 студий за шаг, пауза 0.25 с = 32 ст/с.
	-- ЛИМИТ АНТИЧИТА SAN DIEGO (AntiTp) — эмпирически ~32-45 ст/с (проверено
	-- Potassium-тестами: 32 ст/с × 25с чисто, 48 ст/с — rollback позиции;
	-- rollback'и НЕ жгут инфракции, но срывают погоню). 32 ст/с = максимум
	-- проверенный чистым, поэтому speed=10 выдаёт именно его, не выше.
	-- speed 1..10 масштабирует только длину шага, поэтому min в 10 раз медленнее.
	-- ВАЖНО: никогда не анкорить персонажа во время движения и не делать
	-- одиночных прыжков > 16 студий — фиксируется античитом.
	local baseStep, baseWait
	if axis == "y" then
		baseStep = 8
		baseWait = 0.25
	else
		baseStep = 8
		baseWait = 0.25
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

	local blockedReason = nil
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
		if axis ~= "y" then
			local adjusted, reason = self:_adjustStep(hrp.Position, newPos)
			if not adjusted then
				blockedReason = reason
				break
			end
			newPos = adjusted
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
	if axis ~= "y" and not blockedReason then
		local adjusted, reason = self:_adjustStep(hrp.Position, finalPos)
		if adjusted then
			finalPos = adjusted
		else
			blockedReason = reason
		end
	end
	if not blockedReason then
		if not setHrpCFrame(CFrame.new(finalPos) * CFrame.Angles(0, startYaw, 0)) then
			return { success = false, error = "HumanoidRootPart lost during movement" }
		end
	end

	local finalHrp = self:_getHrp()
	local result = {
		success = true,
		data = {
			newPosition = {
				x = math.round((finalHrp and finalHrp.Position.X or finalPos.X) * 10) / 10,
				y = math.round((finalHrp and finalHrp.Position.Y or finalPos.Y) * 10) / 10,
				z = math.round((finalHrp and finalHrp.Position.Z or finalPos.Z) * 10) / 10,
			},
		},
	}
	if blockedReason then
		result.success = false
		result.error = blockedReason
		result.data.blocked = true
	end
	return result
end

-- Тангенциальный обход препятствия (tangent bug) для move_to: боковые
-- шаги вдоль стены до тех пор, пока прямой шаг к цели снова не проходит
-- (_adjustStep сам перешагивает низкие препятствия и прилипает к земле).
-- Сторона обхода выбирается по свободному пространству по бокам; при
-- тупике сбоку или повторном посещении клетки сторона меняется. Бюджеты:
-- длина детура и время. Возвращает true, когда курс к цели открыт.
function CommandEngine:_avoidAround(hrp, targetPos, stepSize, waitTime, setHrpCFrame, startYaw)
	local pos = hrp.Position
	local rx, rz = targetPos.X - pos.X, targetPos.Z - pos.Z
	local remaining = math.sqrt(rx * rx + rz * rz)
	if remaining < 0.01 then
		return false, "at target"
	end
	local dirTo = Vector3.new(rx / remaining, 0, rz / remaining)
	local left = Vector3.new(-dirTo.Z, 0, dirTo.X)

	-- выбор стороны обхода: свободнее пространство по бокам
	local char = self:_getCharacter()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	local function sideClearance(sideVec)
		local hit = workspace:Raycast(pos + Vector3.new(0, -1, 0), sideVec * 40, params)
		return hit and hit.Distance or 40
	end
	local side = sideClearance(left) >= sideClearance(left * -1) and 1 or -1

	local maxDetour = math.clamp(remaining * 2, 120, 800)
	local detour = 0
	local visited = {}
	local t0 = tick()

	while detour < maxDetour and tick() - t0 < 120 do
		if self:_isCancelled() then
			return false, "cancelled"
		end
		local p = hrp.Position
		local dxr, dzr = targetPos.X - p.X, targetPos.Z - p.Z
		local rem = math.sqrt(dxr * dxr + dzr * dzr)
		if rem < 0.5 then
			return true
		end
		-- курс к цели открыт? — обход окончен
		local d = Vector3.new(dxr / rem, 0, dzr / rem)
		local advance = math.min(stepSize, rem)
		local probe = self:_adjustStep(p, Vector3.new(p.X + d.X * advance, p.Y, p.Z + d.Z * advance))
		if probe then
			return true
		end
		-- боковой шаг вдоль препятствия
		local newPos = self:_adjustStep(p, p + left * side * stepSize)
		if not newPos then
			-- в тупике сбоку — разворачиваем обход на другую сторону
			side = -side
			newPos = self:_adjustStep(p, p + left * side * stepSize)
			if not newPos then
				return false, "walled from both sides"
			end
		end
		-- анти-зацикливание: повторное попадание в клетку — меняем сторону
		local key = math.round(newPos.X / 4) * 100000 + math.round(newPos.Z / 4)
		visited[key] = (visited[key] or 0) + 1
		if visited[key] > 2 then
			side = -side
		end
		if not setHrpCFrame(CFrame.new(newPos) * CFrame.Angles(0, startYaw, 0)) then
			return false, "HumanoidRootPart lost during movement"
		end
		detour = detour + stepSize
		task.wait(waitTime)
	end
	return false, "detour budget exceeded"
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

	-- Адаптивное шагание к цели: каждый шаг считается от текущей позиции.
	-- При свободном пути эквивалентно прямой линии; при блоке — тангенциальный
	-- обход (_avoidAround) до восстановления прямого прохода. Контроль
	-- прогресса (зацикливание) и общий дедлайн.
	-- Те же параметры, что и в _moveAxis: 8 студий за шаг, пауза 0.25 с.
	-- speed=10 = 32 ст/с — максимум проверенный чистым (лимит античита
	-- ~32-45 ст/с, см. _moveAxis), не выше.
	local baseStep = 8
	local baseWait = 0.25
	local stepSize = baseStep * (speed / 10)
	local waitTime = baseWait
	local deadline = tick() + (dist / 32) * 4 + 180
	local bestRemaining = dist
	local noProgress = 0
	local blockedReason = nil

	while tick() < deadline do
		if self:_isCancelled() then
			return { success = false, error = "cancelled" }
		end
		local p = hrp.Position
		local rx, rz = x - p.X, z - p.Z
		local remaining = math.sqrt(rx * rx + rz * rz)
		if remaining < 0.5 then
			break
		end
		if remaining < bestRemaining - 1.5 then
			bestRemaining = remaining
			noProgress = 0
		else
			noProgress = noProgress + 1
			if noProgress > 80 then
				blockedReason = "avoid loop: no progress to target"
				break
			end
		end
		local dir = Vector3.new(rx / remaining, 0, rz / remaining)
		local advance = math.min(stepSize, remaining)
		local stepTarget = Vector3.new(p.X + dir.X * advance, p.Y, p.Z + dir.Z * advance)
		local adjusted, reason = self:_adjustStep(p, stepTarget)
		if adjusted then
			if not setHrpCFrame(CFrame.new(adjusted) * CFrame.Angles(0, startYaw, 0)) then
				return { success = false, error = "HumanoidRootPart lost during movement" }
			end
			task.wait(waitTime)
		else
			local okAvoid, avoidErr = self:_avoidAround(hrp, Vector3.new(x, p.Y, z), stepSize, waitTime, setHrpCFrame, startYaw)
			if not okAvoid then
				blockedReason = tostring(reason) .. " (avoid: " .. tostring(avoidErr) .. ")"
				break
			end
		end
	end

	if self:_isCancelled() then
		return { success = false, error = "cancelled" }
	end
	if not blockedReason and tick() >= deadline then
		blockedReason = "timeout: deadline exceeded"
	end

	if not blockedReason then
		local finalTarget = Vector3.new(x, hrp.Position.Y, z)
		local adjusted = self:_adjustStep(hrp.Position, finalTarget)
		if adjusted then
			finalTarget = adjusted
		end
		if not setHrpCFrame(CFrame.new(finalTarget) * CFrame.Angles(0, startYaw, 0)) then
			return { success = false, error = "HumanoidRootPart lost during movement" }
		end
	end

	local finalHrp = self:_getHrp()
	local result = {
		success = true,
		data = {
			newPosition = {
				x = math.round((finalHrp and finalHrp.Position.X or x) * 10) / 10,
				y = math.round((finalHrp and finalHrp.Position.Y or pos.Y) * 10) / 10,
				z = math.round((finalHrp and finalHrp.Position.Z or z) * 10) / 10,
			},
		},
	}
	if blockedReason then
		result.success = false
		result.error = blockedReason
		result.data.blocked = true
	end
	return result
end

function CommandEngine:_chasePlayer(player, options)
    options = options or {}
    local timeout = tonumber(options.timeout) or 30
    local threshold = tonumber(options.threshold) or 10
    local heightThreshold = tonumber(options.heightThreshold) or 5
    local maxStep = tonumber(options.maxStep) or 100
    local maxVerticalStep = tonumber(options.maxVerticalStep) or 8
    local dieOnReach = options.dieOnReach == true
    local dieDelay = tonumber(options.dieDelay) or 0.3

    local function tryTeleportToTarget(targetHrp)
        local hrp = self:_getHrp()
        if not hrp then
            return false
        end

        local targetPos = targetHrp.Position
        local currentY = hrp.Position.Y
        local groundY = self:_getGroundY(targetPos)

        -- Не прыгаем слишком резко по высоте
        local destY = currentY
        local dyToGround = groundY - currentY
        if math.abs(dyToGround) <= maxVerticalStep then
            destY = groundY
        elseif dyToGround > 0 then
            destY = currentY + maxVerticalStep
        else
            destY = currentY - maxVerticalStep
        end

        -- Не телепортируемся, если сами в воздухе
        if not self:_isGrounded(hrp) then
            return false
        end

        local ok = pcall(function()
            local _, yaw = hrp.CFrame:ToEulerAnglesYXZ()
            hrp.CFrame = CFrame.new(Vector3.new(targetPos.X, destY, targetPos.Z)) * CFrame.Angles(0, yaw, 0)
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

            -- === ЦЕЛЬ ДОСТИГНУТА ===
            if dist2d < threshold and dy < heightThreshold then
                if dieOnReach then
                    task.wait(dieDelay)
                    local killed = self:_killCharacter()
                    return {
                        success = true,
                        data = {
                            distance = dist2d,
                            heightDiff = dy,
                            killed = killed
                        }
                    }
                end
                return { success = true, data = { distance = dist2d, heightDiff = dy } }
            end

            -- Если падаем — ждём, не даём новых команд
            local state = self:_getHumanoidState()
            if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.FallingDown then
                task.wait(0.1)
                continue
            end

            -- Телепортируемся только если очень близко И рядом по высоте
            if dist2d < 12 and dy < heightThreshold * 2 then
                if not tryTeleportToTarget(targetHrp) then
                    warn("[SanDiegoAgent][CommandEngine] close teleport failed")
                end
            else
                -- Горизонтальное движение короткими шагами
                local dx2d = tPos.X - lPos.X
                local dz2d = tPos.Z - lPos.Z
                local stepRatio = dist2d > 0 and math.min(1, maxStep / dist2d) or 0
                local destX = math.round(lPos.X + dx2d * stepRatio)
                local destZ = math.round(lPos.Z + dz2d * stepRatio)

                -- Не идём, если под точкой назначения пропасть
                local destGroundY = self:_getGroundY(Vector3.new(destX, lPos.Y, destZ))
                if math.abs(destGroundY - lPos.Y) > maxVerticalStep * 2 then
                    warn("[SanDiegoAgent][CommandEngine] destination unsafe, skipping horizontal move")
                else
                    local moveResult = self:_moveTo({ x = destX, z = destZ, speed = 10 })
                    if not moveResult.success then
                        warn("[SanDiegoAgent][CommandEngine] chase horizontal move failed:", tostring(moveResult.error))
                        return { success = false, error = "chase horizontal move failed: " .. tostring(moveResult.error) }
                    end
                end
            end

            -- Вертикальная коррекция — только маленькими шагами
            local newHrp = self:_getHrp()
            local newTargetHrp = self:_getPlayerHrp(player)
            if newHrp and newTargetHrp then
                local dyNow = newTargetHrp.Position.Y - newHrp.Position.Y
                if math.abs(dyNow) > 0.5 then
                    local yValue = math.clamp(math.round(dyNow), -maxVerticalStep, maxVerticalStep)
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

-- Зона спавна: включённые SpawnLocation игрока (его TeamColor или
-- Neutral) рядом с персонажем — по XZ в пределах полуплощадки + 6 ст,
-- по высоте от -5 до +8 от площадки. Возвращает inZone, spawnName.
function CommandEngine:_isInSpawnZone()
	local hrp = self:_getHrp()
	if not hrp then
		return false, nil, { reason = "no_hrp" }
	end
	local player = self:_getPlayer()
	local pos = hrp.Position
	local playerTeamColor = player and player.TeamColor or nil
	local ok, inZone, spawnName, diag = pcall(function()
		-- Диагностика: ближайшая Enabled-площадка независимо от команды/попадания.
		local nearest = nil
		local nearestDist = math.huge
		for _, inst in ipairs(workspace:GetDescendants()) do
			if inst:IsA("SpawnLocation") and inst.Enabled then
				local dXZ = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(inst.Position.X, 0, inst.Position.Z)).Magnitude
				if dXZ < nearestDist then
					nearestDist = dXZ
					nearest = inst
				end
				local teamOk = inst.Neutral
				if not teamOk and player then
					teamOk = inst.TeamColor == player.TeamColor
				end
				if teamOk then
					local dx = math.abs(pos.X - inst.Position.X)
					local dz = math.abs(pos.Z - inst.Position.Z)
					local dy = pos.Y - inst.Position.Y
					if dx <= inst.Size.X / 2 + 6
						and dz <= inst.Size.Z / 2 + 6
						and dy >= -5 and dy <= 8
					then
						return true, inst.Name, nil
					end
				end
			end
		end
		if nearest then
			local dx = math.abs(pos.X - nearest.Position.X)
			local dz = math.abs(pos.Z - nearest.Position.Z)
			local dy = pos.Y - nearest.Position.Y
			return false, nil, {
				reason = "out_of_zone",
				pos = { x = math.floor(pos.X * 10) / 10, y = math.floor(pos.Y * 10) / 10, z = math.floor(pos.Z * 10) / 10 },
				player_team_color = playerTeamColor and tostring(playerTeamColor) or "nil",
				nearest = {
					name = nearest.Name,
					neutral = nearest.Neutral,
					team_color = tostring(nearest.TeamColor),
					dx = math.floor(dx * 10) / 10,
					dz = math.floor(dz * 10) / 10,
					dy = math.floor(dy * 10) / 10,
					need_dx = math.floor((nearest.Size.X / 2 + 6) * 10) / 10,
					need_dz = math.floor((nearest.Size.Z / 2 + 6) * 10) / 10,
					dist_xz = math.floor(nearestDist * 10) / 10,
				},
			}
		end
		return false, nil, { reason = "no_enabled_spawn" }
	end)
	if ok then
		return inZone, spawnName, diag
	end
	return false, nil, { reason = "scan_error", err = tostring(inZone) }
end

function CommandEngine:_respawn(payload)
	local skipInSpawn = false
	if payload and payload.skip_in_spawn ~= nil then
		if typeof(payload.skip_in_spawn) ~= "boolean" then
			return { success = false, error = "skip_in_spawn must be a boolean" }
		end
		skipInSpawn = payload.skip_in_spawn
	end
	local humanoid = self:_getHumanoid()
	if not humanoid then
		return { success = false, error = "Humanoid not found" }
	end
	if self:_isCancelled() then
		return { success = false, error = "cancelled" }
	end
	local spawnCheckDiag = nil
	if skipInSpawn then
		local inSpawn, spawnName, diag = self:_isInSpawnZone()
		spawnCheckDiag = diag
		local px, py, pz = 0, 0, 0
		local hrpNow = self:_getHrp()
		if hrpNow then
			px, py, pz = hrpNow.Position.X, hrpNow.Position.Y, hrpNow.Position.Z
		end
		local diagStr = "nil"
		if diag then
			if diag.reason == "out_of_zone" and diag.nearest then
				diagStr = string.format("out_of_zone nearest=%s dXZ=%.1f dx=%.1f dz=%.1f dy=%.1f need=(%.1f,%.1f) neutral=%s padTeam=%s playerTeam=%s",
					tostring(diag.nearest.name), diag.nearest.dist_xz, diag.nearest.dx, diag.nearest.dz, diag.nearest.dy,
					diag.nearest.need_dx, diag.nearest.need_dz,
					tostring(diag.nearest.neutral), tostring(diag.nearest.team_color), tostring(diag.player_team_color))
			else
				diagStr = tostring(diag.reason)
			end
		end
		warn(string.format("[CommandEngine] respawn spawn-check: inSpawn=%s pos=(%.1f, %.1f, %.1f) %s",
			tostring(inSpawn), px, py, pz, diagStr))
		if inSpawn then
			return {
				success = true,
				data = {
					respawned = false,
					skipped = true,
					in_spawn = true,
					spawn = spawnName,
					spawn_check = spawnCheckDiag,
				},
			}
		end
	end
	local player = self:_getPlayer()
	humanoid.Health = 0

	-- После возрождения сбрасываем time_2.
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

	-- Команда завершается только когда персонаж готов выполнять новые
	-- команды: новый character с живым гуманоидом и HumanoidRootPart.
	if player then
		local t0 = tick()
		local ready = false
		while tick() - t0 < 30 do
			if self:_isCancelled() then
				return { success = false, error = "cancelled" }
			end
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if char and hum and hrp and hum.Health > 0 then
				ready = true
				break
			end
			task.wait(0.25)
		end
		if not ready then
			return { success = false, error = "respawn timeout: character not ready after 30s" }
		end
	end

	return { success = true, data = { respawned = true, skipped = false, spawn_check = spawnCheckDiag } }
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

		-- Перед смертью подбегаем к цели. Если не достигли — НЕ убиваем, итерация не считается за respawn.
		-- Таймаут 25с: скорость движения ограничена античитом ~12 ст/с (см. _moveAxis).
		local chaseResult = self:_chasePlayer(targetPlayer, {
			timeout = 25,
			threshold = 1,
			heightThreshold = 1,
			dieOnReach = true,
			dieDelay = 0.3,
		})

		if not chaseResult.success then
			warn("[SanDiegoAgent][CommandEngine] failed to reach target before respawn:", tostring(chaseResult.error))
			attempts += 1  -- считаем попытку, чтобы не зависнуть навечно
			task.wait(2)
			continue
		end

		-- chaseResult.success == true и персонаж уже мёртв (убит внутри _chasePlayer)
		-- Проверяем баланс после смерти.
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

function CommandEngine:_isGrounded(hrp)
    local rp = RaycastParams.new()
    rp.FilterDescendantsInstances = { hrp.Parent }
    rp.FilterType = Enum.RaycastFilterType.Blacklist
    return workspace:Raycast(hrp.Position, Vector3.new(0, -6, 0), rp) ~= nil
end

function CommandEngine:_getGroundY(pos, ignoreModel)
    local rp = RaycastParams.new()
    rp.FilterDescendantsInstances = { ignoreModel or self:_getHrp().Parent }
    rp.FilterType = Enum.RaycastFilterType.Blacklist
    local r = workspace:Raycast(Vector3.new(pos.X, pos.Y + 10, pos.Z), Vector3.new(0, -1000, 0), rp)
    return r and r.Position.Y or pos.Y
end

function CommandEngine:_getHumanoidState()
    local hrp = self:_getHrp()
    if not hrp then return nil end
    local hum = hrp.Parent:FindFirstChildOfClass("Humanoid")
    return hum and hum:GetState() or nil
end

function CommandEngine:_killCharacter()
    local hrp = self:_getHrp()
    if not hrp then return false end
    local hum = hrp.Parent:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.Health = 0
        return true
    end
    return false
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

	-- Подбегаем к цели и умираем только если достигли.
	-- Таймаут 25с: скорость движения ограничена античитом ~12 ст/с (см. _moveAxis).
	local chaseResult = self:_chasePlayer(targetPlayer, {
		timeout = 25,
		threshold = 1,
		heightThreshold = 1,
		dieOnReach = true,
		dieDelay = 0.3,
	})

	if not chaseResult.success then
		warn("[SanDiegoAgent][CommandEngine] failed to reach target before respawn:", tostring(chaseResult.error))
		return {
			success = false,
			error = "failed to reach target: " .. tostring(chaseResult.error),
			data = {
				target_user_id = targetPlayer.UserId,
				target_name = targetPlayer.Name,
				respawned = false,
				reached = false,
				before_balance = beforeBalance,
				after_balance = beforeBalance,
				target_amount = amount,
			},
		}
	end

	-- Персонаж уже умер внутри _chasePlayer. Ждём возрождения.

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

function CommandEngine:_getInventoryCommand()
	if not self.printers then
		return { success = false, error = "printers module unavailable" }
	end
	local ok, inv = pcall(function()
		return self.printers:getInventory()
	end)
	if not ok then
		return { success = false, error = tostring(inv) }
	end
	return { success = true, data = inv }
end

function CommandEngine:_buyPrinterCommand(payload)
	if not self.printers then
		return { success = false, error = "printers module unavailable" }
	end
	local count = tonumber(payload.count) or 1
	local ok, res = pcall(function()
		return self.printers:buyPrinters(count, function()
			return self:_isCancelled()
		end)
	end)
	if not ok then
		return { success = false, error = tostring(res) }
	end
	if not res.success then
		return { success = false, error = res.error, data = { bought = res.bought } }
	end
	return { success = true, data = res }
end

function CommandEngine:_pickupPrinterCommand(payload)
	if not self.printers then
		return { success = false, error = "printers module unavailable" }
	end
	payload = payload or {}
	if typeof(payload.printer_id) ~= "string" or #payload.printer_id == 0 then
		payload.printer_id = nil
	end
	local ok, res = pcall(function()
		return self.printers:pickupPrinters({
			printer_id = payload.printer_id,
			floating = payload.floating == true,
			max_count = payload.max_count,
		}, function()
			return self:_isCancelled()
		end)
	end)
	if not ok then
		return { success = false, error = tostring(res) }
	end
	if not res.success then
		return { success = false, error = res.error, data = { picked = res.picked, failed = res.failed } }
	end
	return { success = true, data = res }
end

function CommandEngine:_pickupAllPrintersCommand()
	if not self.printers then
		return { success = false, error = "printers module unavailable" }
	end
	local ok, res = pcall(function()
		return self.printers:pickupAllPrinters(function()
			return self:_isCancelled()
		end)
	end)
	if not ok then
		return { success = false, error = tostring(res) }
	end
	if not res.success then
		return { success = false, error = res.error, data = { picked = res.picked, failed = res.failed } }
	end
	return { success = true, data = res }
end

function CommandEngine:_deployPrintersCommand()
	if not self.printers then
		return { success = false, error = "printers module unavailable" }
	end
	local ok, res = pcall(function()
		local room, err = self.printers:detectRoom()
		if not room then
			return { success = false, error = err }
		end
		local isCancelled = function()
			return self:_isCancelled()
		end
		local out = {
			inventory = self.printers:getInventory().printers_total,
			placed_before = self.printers:countPlaced(room),
			redeployed = false,
		}
		if out.inventory > 0 and out.placed_before < self.printers.MAX_BUY then
			if out.placed_before > 0 then
				local pu = self.printers:pickupAllPrinters(isCancelled)
				if not pu.success then
					out.error = "pickup failed: " .. tostring(pu.error)
					return { success = false, error = out.error, data = out }
				end
				out.picked = pu.picked
			end
			local pg = self.printers:placeRoomGrid(self.printers.MAX_BUY, isCancelled)
			if not pg.success then
				out.error = "place failed: " .. tostring(pg.error)
				return { success = false, error = out.error, data = out }
			end
			out.redeployed = true
			out.placed = pg.placed
			out.failed = pg.failed
			out.cells = pg.cells
			out.start_side = pg.start_side
			out.room_total = pg.room_total
		end
		local st = self.printers:standCenterBackToDoor()
		if not st.success then
			out.error = "stand failed: " .. tostring(st.error)
			return { success = false, error = out.error, data = out }
		end
		out.position = { x = math.round(st.x * 100) / 100, z = math.round(st.z * 100) / 100 }
		out.facing = st.facing
		out.door_side = st.door_side
		return { success = true, data = out }
	end)
	if not ok then
		return { success = false, error = tostring(res) }
	end
	if not res.success then
		return { success = false, error = res.error, data = res.data }
	end
	return { success = true, data = res.data }
end

function CommandEngine:_flyCarCommand(payload)
	if not self.vehicles then
		return { success = false, error = "vehicles module unavailable" }
	end
	payload = payload or {}
	local height = payload.height
	if typeof(height) ~= "number" or height % 1 ~= 0 or height < 0 or height > 10 then
		return { success = false, error = "height must be an integer 0..10" }
	end
	local ok, res = pcall(function()
		local isCancelled = function()
			return self:_isCancelled()
		end
		if height == 0 then
			return self.vehicles:land(isCancelled)
		end
		return self.vehicles:hover(height)
	end)
	if not ok then
		return { success = false, error = tostring(res) }
	end
	if not res.success then
		return { success = false, error = res.error, data = res.data }
	end
	return { success = true, data = res.data }
end

function CommandEngine:_navCarCommand(payload)
	if not self.vehicles then
		return { success = false, error = "vehicles module unavailable" }
	end
	payload = payload or {}
	local x, z = payload.x, payload.z
	if typeof(x) ~= "number" or x % 1 ~= 0 or x < -2000 or x > 2000 then
		return { success = false, error = "x must be an integer in [-2000, 2000]" }
	end
	if typeof(z) ~= "number" or z % 1 ~= 0 or z < -2000 or z > 2000 then
		return { success = false, error = "z must be an integer in [-2000, 2000]" }
	end
	local ok, res = pcall(function()
		return self.vehicles:navigate(x, z, function()
			return self:_isCancelled()
		end)
	end)
	if not ok then
		return { success = false, error = tostring(res) }
	end
	if not res.success then
		return { success = false, error = res.error, data = res.data }
	end
	return { success = true, data = res.data }
end

function CommandEngine:_driveCommand(payload)
	if not self.vehicles then
		return { success = false, error = "vehicles module unavailable" }
	end
	payload = payload or {}
	local x, z = payload.x, payload.z
	if x ~= nil and (typeof(x) ~= "number" or x % 1 ~= 0 or x < -20000 or x > 20000) then
		return { success = false, error = "x must be an integer in [-20000, 20000]" }
	end
	if z ~= nil and (typeof(z) ~= "number" or z < -20000 or z > 20000) then
		return { success = false, error = "z must be a number in [-20000, 20000]" }
	end
	local speed = payload.speed
	if speed ~= nil and (typeof(speed) ~= "number" or speed % 1 ~= 0 or speed < 0 or speed > 10) then
		return { success = false, error = "speed must be an integer in [0, 10]" }
	end
	local jumpOff = payload.jump_off
	if jumpOff ~= nil and typeof(jumpOff) ~= "boolean" then
		return { success = false, error = "jump_off must be a boolean" }
	end
	local ok, res = pcall(function()
		return self.vehicles:drive(x, z, function()
			return self:_isCancelled()
		end, speed, jumpOff)
	end)
	if not ok then
		return { success = false, error = tostring(res) }
	end
	if not res.success then
		return { success = false, error = res.error, data = res.data }
	end
	return { success = true, data = res.data }
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

	turnSpeed = tonumber(turnSpeed) or 10
	if type(turnSpeed) ~= "number" or turnSpeed % 1 ~= 0 or turnSpeed < 0 or turnSpeed > 10 then
		return { success = false, error = "param 'speed' must be an integer in [0, 10]" }
	end

	-- speed 0 = отсутствие поворота: ни персонаж, ни камера не меняются,
	-- команда ничего не делает (успешный no-op)
	if turnSpeed == 0 then
		local hrp0 = self:_getHrp()
		local yaw = nil
		if hrp0 then
			local _, y = hrp0.CFrame:ToEulerAnglesYXZ()
			yaw = math.round(math.deg(self:_normalizeAngle(y)) * 10) / 10
		end
		return { success = true, data = { degrees = degrees, withCamera = withCamera, newYaw = yaw, noRotation = true } }
	end

	self:releaseCamera()

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

-- Обновление агента «по воздуху»: штатная остановка через флаг StopSanDiegoAgent
-- (подхватывает ui_panel watcher) и повторный запуск загрузчика с GitHub.
-- Команда возвращается немедленно со статусом scheduled; реальный перезапуск
-- происходит в фоне через delay секунд — результат команды успевает уйти на бэкенд.
function CommandEngine:_updateAgentCommand(payload)
	if typeof(getgenv) ~= "function" then
		return { success = false, error = "getgenv is not available in this environment" }
	end
	if typeof(loadstring) ~= "function" then
		return { success = false, error = "loadstring is not available in this environment" }
	end

	local delay = 5
	if payload and payload.delay ~= nil then
		if typeof(payload.delay) ~= "number" or payload.delay % 1 ~= 0 then
			return { success = false, error = "param 'delay' must be an integer" }
		end
		delay = math.clamp(payload.delay, 0, 300)
	end

	local loaderUrl = self.privateServer and tostring(self.privateServer.loaderUrl) or nil
	if not loaderUrl or loaderUrl == "" then
		return { success = false, error = "loader url not configured" }
	end

	task.spawn(function()
		task.wait(delay)
		local genv = getgenv()
		warn("[SanDiegoAgent][CommandEngine] update_agent: stopping agent for reload")
		genv.StopSanDiegoAgent = true
		-- Ждём фактической остановки (watcher в ui_panel обрабатывает флаг).
		local waited = 0
		while genv.SanDiegoAgentRunning and waited < 15 do
			task.wait(0.2)
			waited = waited + 0.2
		end
		if genv.SanDiegoAgentRunning then
			warn("[SanDiegoAgent][CommandEngine] update_agent: agent did not stop in 15s, aborting reload to avoid double start")
			genv.StopSanDiegoAgent = false
			return
		end
		task.wait(0.5)
		genv.StopSanDiegoAgent = false
		warn("[SanDiegoAgent][CommandEngine] update_agent: reloading " .. loaderUrl)
		local ok, err = pcall(function()
			loadstring(game:HttpGet(loaderUrl .. "?nocache=" .. tostring(tick())))()
		end)
		if not ok then
			warn("[SanDiegoAgent][CommandEngine] update_agent: reload failed: " .. tostring(err))
		end
	end)

	return { success = true, data = { update = "scheduled", delay = delay, loader = loaderUrl } }
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

function CommandEngine:_rentApartmentCommand(payload)
	if not self.apartments then
		return { success = false, error = "apartments module unavailable" }
	end
	local apartmentId = payload and payload.apartment_id
	if apartmentId == 0 then
		-- 0 = ближайшая свободная дверь (как непереданный параметр)
		apartmentId = nil
	end
	if apartmentId ~= nil and (typeof(apartmentId) ~= "number" or apartmentId % 1 ~= 0 or apartmentId < 1 or apartmentId > 10000) then
		return { success = false, error = "apartment_id must be an integer in [1, 10000] (or 0 for nearest)" }
	end
	local ok, res = pcall(function()
		return self.apartments:rent(apartmentId, function()
			return self:_isCancelled()
		end)
	end)
	if not ok then
		return { success = false, error = tostring(res) }
	end
	return res
end

function CommandEngine:_doorCommand(targetOpen)
	if not self.apartments then
		return { success = false, error = "apartments module unavailable" }
	end
	local ok, res = pcall(function()
		return self.apartments:setDoorOpen(targetOpen, function()
			return self:_isCancelled()
		end)
	end)
	if not ok then
		return { success = false, error = tostring(res) }
	end
	return res
end

function CommandEngine:_openDoorCommand()
	return self:_doorCommand(true)
end

function CommandEngine:_closeDoorCommand()
	return self:_doorCommand(false)
end

function CommandEngine:_joinPrivateServer(payload)
	local code = payload and payload.code
	if typeof(code) ~= "string" or code:gsub("%s+", "") == "" then
		return { success = false, error = "param 'code' must be a non-empty string" }
	end
	-- Если InvokeServer упадёт/отклонит join ПОСЛЕ того, как агент уже
	-- персистнул результат "completed", Agent перезапишет его ошибкой.
	self._lastJoinCommandId = self.currentCommandId
	return self.privateServer:joinByCode(code)
end

function CommandEngine:onTeleportFailed(err)
	local commandId = self._lastJoinCommandId
	if commandId and typeof(self.onJoinTeleportFailed) == "function" then
		pcall(function()
			self.onJoinTeleportFailed(commandId, err)
		end)
	end
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

-- Спавн техники с ближайшей VehicleSpawner-площадки без открытия панели (E).
-- Вызывает тот же Pronghorn-ремоут, что кнопка панели: сервер валидирует
-- доступ/владение и спавнит технику на площадке.
function CommandEngine:_spawnVehicleCommand(payload)
	local name = payload.name
	if type(name) ~= "string" or #name == 0 then
		return { success = false, error = "param 'name' must be a non-empty string" }
	end
	if #name > 64 then
		return { success = false, error = "param 'name' too long (max 64)" }
	end

	local hrp = self:_getHrp()
	if not hrp then
		return { success = false, error = "character not available" }
	end

	local gameplay = workspace:FindFirstChild("Gameplay")
	local spawnersFolder = gameplay and gameplay:FindFirstChild("VehicleSpawners")
	if not spawnersFolder then
		return { success = false, error = "VehicleSpawners folder not found" }
	end

	local nearest, nearestDist = nil, math.huge
	for _, spawner in ipairs(spawnersFolder:GetChildren()) do
		if spawner.Name == "VehicleSpawner" then
			local okPos, pos = pcall(function()
				return spawner:GetPivot().Position
			end)
			if okPos and pos then
				local dist = (pos - hrp.Position).Magnitude
				if dist < nearestDist then
					nearest = spawner
					nearestDist = dist
				end
			end
		end
	end
	if not nearest then
		return { success = false, error = "no VehicleSpawner models found" }
	end
	if nearestDist > 50 then
		return { success = false, error = string.format("no vehicle spawner nearby (nearest is %.0f studs away)", nearestDist) }
	end

	local okRequire, client = pcall(function()
		return require(game.ReplicatedStorage.SharedModules.Pronghorn.Remotes).Client
	end)
	if not okRequire or not client or not client.VehicleSpawnerService then
		return { success = false, error = "vehicle spawner remotes unavailable: " .. tostring(client) }
	end

	local vehiclesFolder = workspace:FindFirstChild("Vehicles")
	local before = {}
	if vehiclesFolder then
		for _, v in ipairs(vehiclesFolder:GetChildren()) do
			before[v] = true
		end
	end

	local okCall, spawnResult = pcall(function()
		return client.VehicleSpawnerService:SpawnVehicleFromSpawner(nearest, name)
	end)
	if not okCall then
		return { success = false, error = "spawn call failed: " .. tostring(spawnResult) }
	end
	if not spawnResult then
		return { success = false, error = "server rejected spawn of '" .. name .. "'" }
	end

	-- ожидание появления техники (новый экземпляр в Workspace.Vehicles)
	local spawned = nil
	if vehiclesFolder then
		local deadline = tick() + 8
		while tick() < deadline do
			for _, v in ipairs(vehiclesFolder:GetChildren()) do
				if not before[v] then
					spawned = v
					break
				end
			end
			if spawned then
				break
			end
			task.wait(0.25)
		end
	end

	local data = {
		name = name,
		spawner_distance = math.round(nearestDist * 10) / 10,
		spawned = spawned ~= nil,
	}
	if spawned then
		local okPivot, pivot = pcall(function()
			return spawned:GetPivot().Position
		end)
		if okPivot and pivot then
			data.position = {
				x = math.round(pivot.X * 10) / 10,
				y = math.round(pivot.Y * 10) / 10,
				z = math.round(pivot.Z * 10) / 10,
			}
		end
	end

	return { success = true, data = data }
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
		result = self:_respawn(payload)
	elseif name == "transfer_money_via_respawn" then
		result = self:_transferMoneyViaRespawn(payload)
	elseif name == "respawn_for_money" then
		result = self:_respawnForMoney(payload)
	elseif name == "get_inventory" then
		result = self:_getInventoryCommand()
	elseif name == "buy_printer" then
		result = self:_buyPrinterCommand(payload)
	elseif name == "pickup_printer" then
		result = self:_pickupPrinterCommand(payload)
	elseif name == "pickup_all_printers" then
		result = self:_pickupAllPrintersCommand()
	elseif name == "deploy_printers" then
		result = self:_deployPrintersCommand()
	elseif name == "fly_car" then
		result = self:_flyCarCommand(payload)
	elseif name == "nav_car" then
		result = self:_navCarCommand(payload)
	elseif name == "drive" then
		result = self:_driveCommand(payload)
	elseif name == "spawn_vehicle" then
		result = self:_spawnVehicleCommand(payload)
	elseif name == "rent_apartment" then
		result = self:_rentApartmentCommand(payload)
	elseif name == "open_door" then
		result = self:_openDoorCommand()
	elseif name == "close_door" then
		result = self:_closeDoorCommand()
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
	elseif name == "update_agent" then
		result = self:_updateAgentCommand(payload)
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
