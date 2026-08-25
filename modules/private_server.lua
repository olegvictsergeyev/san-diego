local Players = game:GetService("Players")

local PrivateServer = {}
PrivateServer.__index = PrivateServer

function PrivateServer.new()
	return setmetatable({}, PrivateServer)
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

function PrivateServer:_fireClick(button)
	if not button then
		return false, "button is nil"
	end
	if not getconnections then
		return false, "getconnections not available"
	end
	-- Обработчики кнопок могут уходить в сетевые запросы, поэтому
	-- вызываем их в отдельном потоке, чтобы не блокировать основной скрипт.
	task.spawn(function()
		for _, conn in ipairs(getconnections(button.MouseButton1Click)) do
			pcall(conn.Function)
		end
	end)
	return true
end

function PrivateServer:joinByCode(code)
	if typeof(code) ~= "string" or code:gsub("%s+", "") == "" then
		return { success = false, error = "private server code must be a non-empty string" }
	end

	local pg, err = self:_getPlayerGui()
	if not pg then
		return { success = false, error = err or "PlayerGui not found" }
	end

	local sg = self:_waitFor(pg, "ServersGui", 10)
	if not sg then
		return { success = false, error = "ServersGui not found" }
	end

	local frame = self:_find(sg, { "Frame" })
	if not frame then
		return { success = false, error = "ServersGui.Frame not found" }
	end

	sg.Enabled = true
	frame.Visible = true

	local tabBtn = self:_find(sg, { "Frame", "Categories", "JoinByCode", "Button" })
	if not tabBtn then
		return { success = false, error = "JoinByCode tab button not found" }
	end
	local ok, clickErr = self:_fireClick(tabBtn)
	if not ok then
		return { success = false, error = clickErr }
	end
	task.wait(0.3)

	local textBox = self:_find(sg, { "Frame", "Main", "ServerBrowser", "Bottom", "TextBox" })
	if not textBox then
		return { success = false, error = "code TextBox not found" }
	end
	textBox.Text = code

	local joinBtn = self:_find(sg, { "Frame", "Main", "ServerBrowser", "Bottom", "Join", "Button" })
	if not joinBtn then
		return { success = false, error = "Join button not found" }
	end
	ok, clickErr = self:_fireClick(joinBtn)
	if not ok then
		return { success = false, error = clickErr }
	end

	local promptGui = self:_waitFor(pg, "DecisionPromptGui", 5)
	if not promptGui then
		return { success = false, error = "DecisionPromptGui did not appear" }
	end

	local yesBtn = self:_find(promptGui, { "Frame", "ButtonRow", "YesButton" })
	if not yesBtn then
		return { success = false, error = "Yes button not found" }
	end
	ok, clickErr = self:_fireClick(yesBtn)
	if not ok then
		return { success = false, error = clickErr }
	end

	return {
		success = true,
		data = {
			code = code,
			action = "teleport_started",
		},
	}
end

return PrivateServer
