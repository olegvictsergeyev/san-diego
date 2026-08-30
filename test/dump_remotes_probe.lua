--[[
    San Diego Agent — Probe: dump remotes
    =====================================================
    Выводит RemoteFunction/RemoteEvent/BindableFunction/Event
    в ReplicatedStorage.__remotes, особенно сервисы данных игрока.
    Запусти и скопируй сюда вывод.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local remotesRoot = ReplicatedStorage:FindFirstChild("__remotes")
if not remotesRoot then
	warn("__remotes not found in ReplicatedStorage")
	return
end

local function describeRemote(r)
	local info = {
		name = r.Name,
		class = r.ClassName,
		path = r:GetFullName(),
		attributes = {},
	}
	for _, attr in ipairs(r:GetAttributes()) do
		info.attributes[attr] = tostring(r:GetAttribute(attr))
	end
	return info
end

local function scanFolder(folder, out)
	if not folder then return end
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("RemoteFunction") or child:IsA("RemoteEvent") or child:IsA("BindableFunction") or child:IsA("BindableEvent") then
			table.insert(out, describeRemote(child))
		elseif child:IsA("Folder") then
			scanFolder(child, out)
		end
	end
end

local interesting = {
	"PlayerDataService", "VehicleService", "ApartmentService", "AutoshopService",
	"BackpackService", "TeamService", "CurrencyService", "BeachHouseService",
	"VehicleCustomisationService", "VehicleMarketService", "VehicleSpawnerService",
	"MoneyPrinterService", "ShowroomService",
}

local result = {}
for _, serviceName in ipairs(interesting) do
	local folder = remotesRoot:FindFirstChild(serviceName)
	if folder then
		local list = {}
		scanFolder(folder, list)
		result[serviceName] = list
	else
		result[serviceName] = "not found"
	end
end

local ok, json = pcall(function()
	return HttpService:JSONEncode(result)
end)
print("=== remotes probe ===")
if ok then
	print(json)
else
	print("encode error:", tostring(json))
end
print("=== end remotes probe ===")
