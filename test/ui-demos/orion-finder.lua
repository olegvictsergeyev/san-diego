--[[
    Orion Value Finder
    ==================
    Плавно ищет в дереве игры Value-объекты по их значению.
    Можно искать число (например, свой текущий баланс) или текстовое вхождение.
]]

local Players = game:GetService("Players")

local function loadOrion()
	local ok, Orion = pcall(function()
		return loadstring(game:HttpGet("https://raw.githubusercontent.com/OrionLibrary/Orion/main/source.lua"))()
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

local function searchByValue(root, targetText, exact, onProgress)
	local found = {}
	local count = 0
	local stack = { root }

	while #stack > 0 do
		local current = table.remove(stack)
		local children = current:GetChildren()
		for _, child in ipairs(children) do
			if child:IsA("ValueBase") then
				local ok, value = pcall(function()
					return child.Value
				end)
				if ok and matchesValue(value, targetText, exact) then
					table.insert(found, child)
				end
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

local function getFinderGui()
	return game.CoreGui:FindFirstChild("Value Finder")
end

local function getInputText()
	local gui = getFinderGui()
	if not gui then return "" end
	for _, desc in ipairs(gui:GetDescendants()) do
		if desc.Name == "textBoxFrame" then
			local info = desc:FindFirstChild("textboxInfo")
			if info and info:IsA("TextLabel") and info.Text == "Value to find" then
				for _, inner in ipairs(desc:GetDescendants()) do
					if inner:IsA("TextBox") then
						return inner.Text
					end
				end
			end
		end
	end
	return ""
end

local function buildUI()
	local Orion = loadOrion()
	if not Orion then return end

	local window = Orion:CreateOrion("Value Finder")
	local tabSearch = window:CreateSection("Search")

	tabSearch:TextLabel("Enter value to find (number or text)")

	tabSearch:TextBox("Value to find", "100", function(text)
		-- В некоторых executor'ах Orion TextBox callback не срабатывает мгновенно.
		-- Текст читается напрямую из GUI перед поиском.
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
			tabSearch:TextLabel("LocalPlayer not found")
			return
		end

		local targetText = getInputText()
		if targetText == "" then
			tabSearch:TextLabel("Enter a value first")
			return
		end

		tabSearch:TextLabel("Searching for: " .. targetText)

		local roots
		if searchEverywhere then
			roots = { game }
			tabSearch:TextLabel("Mode: full game tree")
		else
			roots = {
				player:FindFirstChild("leaderstats"),
				player:FindFirstChild("PlayerGui"),
				player:FindFirstChild("Backpack"),
				player,
			}
		end

		task.spawn(function()
			local allFound = {}
			local totalChecked = 0

			for _, root in ipairs(roots) do
				if root then
					local found, checked = searchByValue(root, targetText, exactMatch, function(count)
						tabSearch:TextLabel("Checked: " .. tostring(count))
					end)
					for _, item in ipairs(found) do
						table.insert(allFound, item)
					end
					totalChecked = totalChecked + checked
				end
			end

			tabSearch:TextLabel("Total checked: " .. tostring(totalChecked) .. ", found: " .. tostring(#allFound))

			if #allFound == 0 then
				tabSearch:TextLabel("Nothing found")
				return
			end

			local maxResults = 20
			if #allFound > maxResults then
				tabSearch:TextLabel("Showing first " .. tostring(maxResults) .. " results")
			end

			for i = 1, math.min(#allFound, maxResults) do
				local item = allFound[i]
				local path = item:GetFullName()
				local currentValue = "?"
				pcall(function()
					currentValue = tostring(item.Value)
				end)
				tabSearch:TextLabel(item.Name .. " = " .. currentValue .. " (" .. item.ClassName .. ")")
				tabSearch:TextButton("Copy path", path, function()
					copyToClipboard(path)
					tabSearch:TextLabel("Copied: " .. path)
				end)
			end
		end)
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
