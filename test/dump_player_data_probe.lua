--[[
    San Diego Agent — Probe: dump player data structure
    =====================================================
    Тестовый скрипт. Показывает, какие объекты лежат в игроках и в общих
    хранилищах, чтобы найти, где хранятся дома и транспорт.
    Запусти в executor'е и скопируй сюда вывод.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local function describe(instance, depth)
	if not instance then return "nil" end
	local indent = string.rep("  ", depth or 0)
	local info = indent .. instance.Name .. " (" .. instance.ClassName .. ")"
	if instance:IsA("ValueBase") then
		local v = instance.Value
		info = info .. " = " .. tostring(v) .. " (" .. typeof(v) .. ")"
	end
	return info
end

local function dumpChildren(parent, depth, maxDepth, out)
	if not parent then return end
	if depth > maxDepth then return end
	for _, child in ipairs(parent:GetChildren()) do
		table.insert(out, describe(child, depth))
		if not child:IsA("ValueBase") then
			dumpChildren(child, depth + 1, maxDepth, out)
		end
	end
end

local function dumpPlayer(player)
	local lines = {}
	table.insert(lines, "\n========== PLAYER: " .. player.Name .. " (" .. tostring(player.UserId) .. ") ==========")

	table.insert(lines, "-- direct children --")
	dumpChildren(player, 0, 2, lines)

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		table.insert(lines, "-- leaderstats --")
		dumpChildren(leaderstats, 0, 2, lines)
	end

	local reps = player:FindFirstChild("ReplicatedStats")
	if reps then
		table.insert(lines, "-- ReplicatedStats --")
		dumpChildren(reps, 0, 2, lines)
	end

	local pg = player:FindFirstChild("PlayerGui")
	if pg then
		table.insert(lines, "-- PlayerGui top-level --")
		dumpChildren(pg, 0, 1, lines)
	end

	print(table.concat(lines, "\n"))
end

local function dumpStorage()
	local lines = {}
	table.insert(lines, "\n========== ReplicatedStorage top-level ==========")
	dumpChildren(ReplicatedStorage, 0, 1, lines)

	-- Ищем папки с данными по UserId или никнейму
	local function maybePlayerDataFolder(child)
		local name = child.Name:lower()
		return name:find("player") or name:find("profile") or name:find("data") or name:find("save")
	end

	for _, child in ipairs(ReplicatedStorage:GetChildren()) do
		if maybePlayerDataFolder(child) and not child:IsA("ValueBase") then
			table.insert(lines, "\n-- ReplicatedStorage." .. child.Name .. " --")
			dumpChildren(child, 0, 2, lines)
		end
	end

	print(table.concat(lines, "\n"))
end

local function dumpWorkspaceVehicles()
	local lines = {}
	table.insert(lines, "\n========== Workspace top-level children ==========")
	dumpChildren(Workspace, 0, 1, lines)

	local vehicleRoots = {}
	for _, child in ipairs(Workspace:GetChildren()) do
		local name = child.Name:lower()
		if name:find("vehicle") or name:find("car") or name:find("spawn") or name:find("garage") or name:find("parking") then
			table.insert(vehicleRoots, child)
		end
	end

	if #vehicleRoots > 0 then
		table.insert(lines, "\n-- suspected vehicle/parking folders --")
		for _, root in ipairs(vehicleRoots) do
			dumpChildren(root, 0, 2, lines)
		end
	end

	print(table.concat(lines, "\n"))
end

for _, player in ipairs(Players:GetPlayers()) do
	dumpPlayer(player)
end

dumpStorage()
dumpWorkspaceVehicles()
