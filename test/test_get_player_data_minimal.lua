local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local getPlayerData = ReplicatedStorage.__remotes.PlayerDataService.GetPlayerData

local function try(label, ...)
	local ok, res = pcall(function(...)
		return getPlayerData:InvokeServer(...)
	end, ...)
	print("--- " .. label .. " ---")
	if not ok then
		print("ERROR", tostring(res))
	elseif res == nil then
		print("nil")
	elseif typeof(res) ~= "table" then
		print("type", typeof(res), tostring(res))
	else
		print("OK", "Money", tostring(res.Currency and res.Currency.Money), "Vehicles", #(res.OwnedVehicles or {}), "Houses", #(res.OwnedBeachHouses or {}), "Printers", (function() local c = 0 for _ in pairs(res.MoneyPrinters or {}) do c += 1 end return c end)())
	end
end

try("no args")
try("LocalPlayer", Players.LocalPlayer)
try("UserId self", Players.LocalPlayer.UserId)

for _, p in ipairs(Players:GetPlayers()) do
	if p ~= Players.LocalPlayer then
		try("player " .. p.Name, p)
		try("userid " .. p.UserId, p.UserId)
	end
end
print("done")
