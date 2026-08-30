local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local getPlayerData = ReplicatedStorage.__remotes.PlayerDataService.GetPlayerData

local function tryInvokeWithTimeout(label, timeout, ...)
	task.spawn(function(...)
		local start = tick()
		local ok, res = pcall(function(...)
			return getPlayerData:InvokeServer(...)
		end, ...)
		print("--- " .. label .. " (" .. string.format("%.2f", tick() - start) .. "s) ---")
		if not ok then
			print("ERROR", tostring(res))
		elseif res == nil then
			print("nil")
		elseif typeof(res) ~= "table" then
			print("type", typeof(res), tostring(res))
		else
			print("OK", "Money", tostring(res.Currency and res.Currency.Money), "Vehicles", #(res.OwnedVehicles or {}), "Houses", #(res.OwnedBeachHouses or {}), "Printers", (function() local c = 0 for _ in pairs(res.MoneyPrinters or {}) do c += 1 end return c end)())
		end
	end, ...)
end

tryInvokeWithTimeout("no args", 5)
task.wait(0.5)
tryInvokeWithTimeout("LocalPlayer", 5, Players.LocalPlayer)
task.wait(0.5)
tryInvokeWithTimeout("UserId self", 5, Players.LocalPlayer.UserId)
task.wait(0.5)

for _, p in ipairs(Players:GetPlayers()) do
	if p ~= Players.LocalPlayer then
		tryInvokeWithTimeout("player " .. p.Name, 5, p)
		task.wait(0.3)
		tryInvokeWithTimeout("userid " .. p.UserId, 5, p.UserId)
		task.wait(0.3)
	end
end

-- сканируем Workspace.Vehicles на предмет атрибутов владельца
print("\n=== Workspace.Vehicles scan ===")
local vehiclesFolder = Workspace:FindFirstChild("Vehicles")
if vehiclesFolder then
	local count = 0
	for _, v in ipairs(vehiclesFolder:GetChildren()) do
		local attrs = v:GetAttributes()
		if next(attrs) then
			count += 1
			print("Vehicle:", v.Name, "attrs:", HttpService:JSONEncode(attrs))
		end
	end
	print("Vehicles with attributes:", count, "/", #vehiclesFolder:GetChildren())
else
	print("Workspace.Vehicles not found")
end

-- сканируем BeachHousePlots / Apartments
print("\n=== Gameplay property scan ===")
local gameplay = Workspace:FindFirstChild("Gameplay")
if gameplay then
	for _, name in ipairs({"BeachHousePlots", "Apartments", "Autoshops", "VehicleSpawners"}) do
		local folder = gameplay:FindFirstChild(name)
		if folder then
			local sample = {}
			for _, child in ipairs(folder:GetChildren()) do
				if #sample < 3 then
					table.insert(sample, child.Name .. " attrs=" .. HttpService:JSONEncode(child:GetAttributes()))
				end
			end
			print(name, "children:", #folder:GetChildren(), "samples:", table.concat(sample, "; "))
		end
	end
end

print("\n=== done ===")
