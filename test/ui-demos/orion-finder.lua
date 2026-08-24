--[[
    Orion Value Finder
    ==================
    Плавно ищет в дереве игры Value-объекты по их значению.
    Можно искать число (например, свой текущий баланс) или текстовое вхождение.
]]

local Players = game:GetService("Players")

local function loadOrion()
	local ok, Orion = pcall(function()
		local url = "https://raw.githubusercontent.com/OrionLibrary/Orion/main/source.lua"
		local src = game:HttpGet(url)
		-- Патчим TextBox Orion: callback на каждое изменение текста и без очистки поля.
		local pattern = "TextBox%.FocusLost:Connect%(function%(EnterPressed%).-end%)"
		local replacement = [[TextBox:GetPropertyChangedSignal("Text"):Connect(function()
			callback(TextBox.Text)
		end)]]
		src = src:gsub(pattern, replacement)
		return loadstring(src)()
	end)
	if not ok then
		warn("[ValueFinder] Failed to load Orion:", tostring(Orion))
		return nil
	end
	return Orion
end

local function copyToClipboard(text)
	pcall(function()
		setclipboard(tostring(text))
	end)
end

local function matchesValue(value, targetText, exact)
	local valueText = tostring(value)
	local targetNum = tonumber(targetText)
	local valueNum = typeof(value) == "number" and value or tonumber(valueText)

	if targetNum and valueNum then
		if exact then
			return valueNum == targetNum
		else
			-- Для чисел "вхождение" не имеет смысла, поэтому сравниваем на равенство.
			return valueNum == targetNum
		end
	end

	if exact then
		return valueText == targetText
	end

	return string.find(valueText, targetText, 1, true) ~= nil
end

local function waitForChild(parent, name, timeout)
	if not parent then return nil end
	timeout = timeout or 3
	local ok, child = pcall(function()
		return parent:WaitForChild(name, timeout)
	end)
	if ok and child then
		return child
	end
	return nil
end

local textClasses = {
	TextLabel = true,
	TextBox = true,
	TextButton = true,
	TextBlock = true,
}

local function getCompareValue(instance)
	if instance:IsA("ValueBase") then
		local ok, value = pcall(function()
			return instance.Value
		end)
		if ok then return value end
	end
	if textClasses[instance.ClassName] then
		local ok, text = pcall(function()
			return instance.Text
		end)
		if ok then return text end
	end
	return nil
end

local function searchByValue(root, targetText, exact, onProgress)
	local found = {}
	local count = 0
	local stack = { root }

	while #stack > 0 do
		local current = table.remove(stack)
		local children = current:GetChildren()
		for _, child in ipairs(children) do
			local compareValue = getCompareValue(child)
			if compareValue and matchesValue(compareValue, targetText, exact) then
				table.insert(found, child)
			end
			table.insert(stack, child)
			count = count + 1
			if count % 200 == 0 then
				if onProgress then
					onProgress(count)
				end
				task.wait(0.001)
			end
		end
	end

	return found, count
end

local function dumpPlayerValues()
	local player = Players.LocalPlayer
	if not player then
		print("[ValueFinder] LocalPlayer not found")
		return
	end
	print("[ValueFinder] Dumping values under player...")
	local roots = {
		waitForChild(player, "leaderstats", 3),
		waitForChild(player, "PlayerGui", 3),
		waitForChild(player, "Backpack", 3),
		player,
	}
	local count = 0
	for _, root in ipairs(roots) do
		if root then
			for _, desc in ipairs(root:GetDescendants()) do
				local compareValue = getCompareValue(desc)
				if compareValue then
					count = count + 1
					print("[ValueFinder] Dump: " .. desc:GetFullName() .. " = " .. tostring(compareValue) .. " (" .. desc.ClassName .. ")")
				end
			end
		end
	end
	print("[ValueFinder] Dumped " .. tostring(count) .. " values")
end

local function buildUI()
	local Orion = loadOrion()
	if not Orion then return end

	local window = Orion:CreateOrion("Value Finder")
	local tabSearch = window:CreateSection("Search")

	tabSearch:TextLabel("Enter value to find (number or text)")

	local inputValue = ""
	tabSearch:TextBox("Value to find", "100", function(text)
		inputValue = text
	end)

	local exactMatch = false
	tabSearch:Toggle("Exact match", function(state)
		exactMatch = state
	end)

	local searchEverywhere = false
	tabSearch:Toggle("Search everywhere", function(state)
		searchEverywhere = state
	end)

	tabSearch:TextButton("Search", "Start smooth search", function()
		local player = Players.LocalPlayer
		if not player then
			print("[ValueFinder] LocalPlayer not found")
			return
		end

		local targetText = inputValue
		if targetText == "" then
			print("[ValueFinder] Enter a value first")
			return
		end

		print("[ValueFinder] Searching for: " .. targetText)

		local roots
		if searchEverywhere then
			roots = { game }
			print("[ValueFinder] Mode: full game tree")
		else
			roots = {
				waitForChild(player, "leaderstats", 3),
				waitForChild(player, "PlayerGui", 3),
				waitForChild(player, "Backpack", 3),
				player,
			}
			for i, root in ipairs(roots) do
				if root then
					print("[ValueFinder] Root " .. tostring(i) .. ": " .. root:GetFullName() .. " (children: " .. tostring(#root:GetChildren()) .. ")")
				else
					print("[ValueFinder] Root " .. tostring(i) .. ": nil")
				end
			end
		end

		task.spawn(function()
			local allFound = {}
			local totalChecked = 0

			for _, root in ipairs(roots) do
				if root then
					local found, checked = searchByValue(root, targetText, exactMatch, function(count)
						print("[ValueFinder] Checked: " .. tostring(count))
					end)
					for _, item in ipairs(found) do
						table.insert(allFound, item)
					end
					totalChecked = totalChecked + checked
				end
			end

			print("[ValueFinder] Total checked: " .. tostring(totalChecked) .. ", found: " .. tostring(#allFound))

			if #allFound == 0 then
				print("[ValueFinder] Nothing found")
				return
			end

			local maxResults = 20
			if #allFound > maxResults then
				print("[ValueFinder] Showing first " .. tostring(maxResults) .. " results")
			end

			for i = 1, math.min(#allFound, maxResults) do
				local item = allFound[i]
				local path = item:GetFullName()
				local currentValue = "?"
				local compareValue = getCompareValue(item)
				if compareValue then
					currentValue = tostring(compareValue)
				end
				print("[ValueFinder] Result: " .. item.Name .. " = " .. currentValue .. " (" .. item.ClassName .. ") at " .. path)
				tabSearch:TextButton("Copy: " .. item.Name, path, function()
					copyToClipboard(path)
					print("[ValueFinder] Copied: " .. path)
				end)
			end
		end)
	end)

	tabSearch:TextButton("Dump values", "Print all values under player", function()
		dumpPlayerValues()
	end)

	print("[ValueFinder] UI built")
end

local ok, err = xpcall(buildUI, function(msg)
	return debug.traceback(tostring(msg), 2)
end)
if not ok then
	print("[ValueFinder] ERROR:\n" .. tostring(err))
	warn("[ValueFinder] ERROR:\n" .. tostring(err))
end
