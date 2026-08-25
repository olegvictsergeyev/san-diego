--[[
    Orion Command Engine Test
    ==========================
    Локальное тестирование команд без сервера.
    Загружает command_engine из репозитория и выполняет команды по кнопкам.
]]

local Players = game:GetService("Players")

local function loadModule(name)
	local url = "https://raw.githubusercontent.com/olegvictsergeyev/san-diego/main/modules/" .. name .. ".lua?nocache=" .. tostring(tick())
	local source = game:HttpGet(url)
	local fn, err = loadstring(source, name)
	if not fn then
		error("failed to load module " .. name .. ": " .. tostring(err))
	end
	return fn()
end

local CommandEngine = loadModule("command_engine")

local function loadOrion()
	local ok, Orion = pcall(function()
		local src = game:HttpGet("https://raw.githubusercontent.com/OrionLibrary/Orion/main/source.lua")
		src = src:gsub("TextBox%.FocusLost:Connect%(function%(EnterPressed%).-end%)", [[TextBox:GetPropertyChangedSignal("Text"):Connect(function()
			callback(TextBox.Text)
		end)]])
		return loadstring(src)()
	end)
	if not ok then
		error("Failed to load Orion: " .. tostring(Orion))
	end
	return Orion
end

local function buildUI()
	local Orion = loadOrion()
	local window = Orion:CreateOrion("Command Engine Test")
	local tab = window:CreateSection("Commands")

	local engine = CommandEngine.new()

	local function runCommand(name, payload)
		local command = {
			id = "manual-" .. tostring(tick()),
			name = name,
			payload = payload,
		}
		print("[CommandTest] Executing:", name, "payload:", tostring(payload))
		local ok, result = pcall(function()
			return engine:execute(command)
		end)
		if ok then
			print("[CommandTest] Result:", tostring(result))
		else
			warn("[CommandTest] Error:", tostring(result))
		end
	end

	local valueInput = "100"
	tab:TextBox("Value", "100", function(text)
		valueInput = text
	end)

	tab:TextButton("Move X", "Сместить по оси X", function()
		runCommand("move_x", { value = tonumber(valueInput) })
	end)

	tab:TextButton("Move Y", "Сместить по оси Y", function()
		runCommand("move_y", { value = tonumber(valueInput) })
	end)

	tab:TextButton("Move Z", "Сместить по оси Z", function()
		runCommand("move_z", { value = tonumber(valueInput) })
	end)

	tab:TextButton("Pause 3s", "Подождать 3 секунды", function()
		runCommand("pause", { duration = 3 })
	end)

	tab:TextButton("Cancel", "Отменить текущую команду", function()
		runCommand("cancel", {})
	end)

	print("[CommandTest] UI built")
end

local ok, err = xpcall(buildUI, function(msg)
	return debug.traceback(tostring(msg), 2)
end)
if not ok then
	print("[CommandTest] ERROR:\n" .. tostring(err))
end
