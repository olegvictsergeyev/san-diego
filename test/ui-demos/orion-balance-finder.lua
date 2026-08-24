--[[
    Orion Balance / Value Finder
    ==============================
    Плавно ищет в дереве игры Value-объект с заданным именем.
    Полезно для определения пути к балансу.
]]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local function loadOrion()
	local ok, Orion = pcall(function()
		return loadstring(game:HttpGet("https://raw.githubusercontent.com/OrionLibrary/Orion/main/source.lua"))()
	end)
	if not ok then
		warn("[BalanceFinder] Failed to load Orion:", tostring(Orion))
		return nil
	end
	return Orion
end

local function copyToClipboard(text)
	pcall(function()
		setclipboard(tostring(text))
	end)
end

local function searchInstance(root, targetName, onProgress)
	local found = {}
	local count = 0
	local stack = { root }

	while #stack > 0 do
		local current = table.remove(stack)
		local children = current:GetChildren()
		for _, child in ipairs(children) do
			if child.Name == targetName then
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

local function getValueText(instance)
	if instance:IsA("ValueBase") then
		return tostring(instance.Value)
	end
	return "<not a ValueBase>"
end

local function buildUI()
	local Orion = loadOrion()
	if not Orion then return end

	local window = Orion:CreateOrion("Balance Finder")
	local tabSearch = window:CreateSection("Search")

	tabSearch:TextLabel("Enter value name (e.g. Cash, Money, Balance)")

	local inputName = ""
	tabSearch:TextBox("Value name", "Cash", function(text)
		inputName = text
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

		local targetName = inputName
		if targetName == "" then
			tabSearch:TextLabel("Enter a name first")
			return
		end

		tabSearch:TextLabel("Searching for: " .. targetName)

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
					local found, checked = searchInstance(root, targetName, function(count)
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

			for _, item in ipairs(allFound) do
				local path = item:GetFullName()
				local valueText = getValueText(item)
				tabSearch:TextLabel(path .. " = " .. valueText)
				tabSearch:TextButton("Copy path", path, function()
					copyToClipboard(path)
					tabSearch:TextLabel("Copied: " .. path)
				end)
			end
		end)
	end)

	print("[BalanceFinder] UI built")
end

local ok, err = xpcall(buildUI, function(msg)
	return debug.traceback(tostring(msg), 2)
end)
if not ok then
	print("[BalanceFinder] ERROR:\n" .. tostring(err))
	warn("[BalanceFinder] ERROR:\n" .. tostring(err))
end
