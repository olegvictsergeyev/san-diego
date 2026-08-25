local Players = game:GetService("Players")

local PrivateServer = {}
PrivateServer.__index = PrivateServer

function PrivateServer.new()
	return setmetatable({}, PrivateServer)
end

function PrivateServer:_log(label, ...)
	print("[PrivateServer][" .. tostring(label) .. "]", ...)
end

function PrivateServer:_getPlayerGui()
	local player = Players.LocalPlayer
	if not player then
		return nil, "LocalPlayer not found"
	end
	local ok, pg = pcall(function()
		return player:WaitForChild("PlayerGui", 5)
	end)
	if ok and pg then
		return pg
	end
	return nil, "PlayerGui not found"
end

function PrivateServer:_find(root, path)
	if not root then
		return nil
	end
	local current = root
	for _, name in ipairs(path) do
		current = current:FindFirstChild(name)
		if not current then
			return nil
		end
	end
	return current
end

function PrivateServer:_waitFor(root, name, timeout)
	timeout = timeout or 5
	local elapsed = 0
	while elapsed < timeout do
		local child = root:FindFirstChild(name)
		if child then
			return child
		end
		task.wait(0.1)
		elapsed = elapsed + 0.1
	end
	return root:FindFirstChild(name)
end

function PrivateServer:_fireClick(button, label)
	if not button then
		self:_log("CLICK", label or "?", "button is nil")
		return false, "button is nil"
	end
	if not getconnections then
		self:_log("CLICK", label or "?", "getconnections not available")
		return false, "getconnections not available"
	end
	local conns = getconnections(button.MouseButton1Click)
	self:_log("CLICK", label or "?", button:GetFullName(), "connections:", #conns)
	-- Обработчики кнопок могут уходить в сетевые запросы, поэтому
	-- вызываем их в отдельном потоке, чтобы не блокировать основной скрипт.
	task.spawn(function()
		for _, conn in ipairs(conns) do
			local ok, err = pcall(conn.Function)
			self:_log("CLICK", label or "?", "fired", ok and "OK" or "ERR", err or "")
		end
	end)
	return true
end

function PrivateServer:joinByCode(code)
	if typeof(code) ~= "string" or code:gsub("%s+", "") == "" then
		return { success = false, error = "private server code must be a non-empty string" }
	end

	self:_log("START", "joinByCode", code)

	local pg, err = self:_getPlayerGui()
	if not pg then
		self:_log("ERROR", err or "PlayerGui not found")
		return { success = false, error = err or "PlayerGui not found" }
	end

	local sg = self:_waitFor(pg, "ServersGui", 10)
	if not sg then
		self:_log("ERROR", "ServersGui not found")
		return { success = false, error = "ServersGui not found" }
	end
	self:_log("FOUND", "ServersGui")

	local frame = self:_find(sg, { "Frame" })
	if not frame then
		self:_log("ERROR", "ServersGui.Frame not found")
		return { success = false, error = "ServersGui.Frame not found" }
	end

	sg.Enabled = true
	frame.Visible = true
	self:_log("UI", "ServersGui enabled and visible")

	local tabBtn = self:_find(sg, { "Frame", "Categories", "JoinByCode", "Button" })
	if not tabBtn then
		self:_log("ERROR", "JoinByCode tab button not found")
		return { success = false, error = "JoinByCode tab button not found" }
	end
	local ok, clickErr = self:_fireClick(tabBtn, "JoinByCode")
	if not ok then
		return { success = false, error = clickErr }
	end
	task.wait(0.3)

	local textBox = self:_find(sg, { "Frame", "Main", "ServerBrowser", "Bottom", "TextBox" })
	if not textBox then
		self:_log("ERROR", "code TextBox not found")
		return { success = false, error = "code TextBox not found" }
	end
	textBox.Text = code
	self:_log("UI", "code set")

	local joinBtn = self:_find(sg, { "Frame", "Main", "ServerBrowser", "Bottom", "Join", "Button" })
	if not joinBtn then
		self:_log("ERROR", "Join button not found")
		return { success = false, error = "Join button not found" }
	end
	ok, clickErr = self:_fireClick(joinBtn, "Join")
	if not ok then
		return { success = false, error = clickErr }
	end

	self:_log("WAIT", "waiting for DecisionPromptGui...")
	local promptGui = self:_waitFor(pg, "DecisionPromptGui", 15)
	if not promptGui then
		self:_log("ERROR", "DecisionPromptGui did not appear")
		return { success = false, error = "DecisionPromptGui did not appear" }
	end
	self:_log("FOUND", "DecisionPromptGui")

	-- Даём GUI один кадр на инициализацию подключений.
	task.wait(0.3)

	local yesBtn = self:_find(promptGui, { "Frame", "ButtonRow", "YesButton" })
	if not yesBtn then
		self:_log("ERROR", "Yes button not found")
		return { success = false, error = "Yes button not found" }
	end
	ok, clickErr = self:_fireClick(yesBtn, "YesButton")
	if not ok then
		return { success = false, error = clickErr }
	end

	-- Даём кнопке время сработать до возможного телепорта/выгрузки скрипта.
	task.wait(0.5)

	return {
		success = true,
		data = {
			code = code,
			action = "teleport_started",
		},
	}
end

return PrivateServer
