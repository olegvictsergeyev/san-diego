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

local Printers = {}
Printers.__index = Printers

-- Фильтр имён Tool'ов-принтеров (Money Printer, Super Money Printer и т.п.)
Printers.PRINTER_NAME_PATTERN = "print"
-- Витринный предмет за игровую валюту (Super Money Printer / Booster — за Robux)
Printers.DISPLAY_ITEM_NAME = "Money Printer"
-- Больше 50 принтеров персонажу не нужно (лимит расстановки)
Printers.MAX_BUY = 50

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

-- Одна покупка: прямой ввод в промпт (аналог удержания E).
function Printers:_pressPrompt(prompt)
	prompt:InputHoldBegin()
	task.wait((tonumber(prompt.HoldDuration) or 0) + 0.3)
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
		task.wait(1) -- серверу нужно время выдать Tool; заодно не спамим покупками

		local nowTotal = self:getInventory().printers_total
		if nowTotal <= startTotal + bought then
			-- Покупка не прошла: обычно не хватило денег (промпт молча отказывает).
			return {
				success = false,
				error = "purchase did not increase printer count (insufficient funds?)",
				bought = bought,
			}
		end
		bought = nowTotal - startTotal
	end

	return {
		success = true,
		bought = bought,
		requested = requested,
		printers_total = self:getInventory().printers_total,
	}
end

return Printers
