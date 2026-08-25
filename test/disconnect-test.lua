local CoreGui = game:GetService("CoreGui")
local out = {}

local function log(s)
	table.insert(out, tostring(s))
	print(tostring(s))
end

local function pathOf(obj)
	local parts = {}
	while obj do
		table.insert(parts, 1, obj.Name)
		obj = obj.Parent
	end
	return table.concat(parts, ".")
end

local function fireBtn(btn)
	log("FIRE: button=" .. btn.Name .. " class=" .. btn.ClassName)
	local signals = { "Activated", "MouseButton1Click", "MouseButton1Down" }

	if typeof(firesignal) == "function" then
		for _, name in ipairs(signals) do
			local sig = btn[name]
			if sig then
				local ok, err = pcall(firesignal, sig)
				log("  firesignal " .. name .. " ok=" .. tostring(ok) .. " err=" .. tostring(err or ""))
			end
		end
	else
		log("  firesignal not available")
	end

	if typeof(getconnections) == "function" then
		for _, name in ipairs(signals) do
			local sig = btn[name]
			if sig then
				local conns = getconnections(sig)
				log("  getconnections " .. name .. " count=" .. tostring(#conns))
				for i, conn in ipairs(conns) do
					local fn = conn.Function
					log("    conn " .. tostring(i) .. " fn=" .. tostring(fn) .. " type=" .. typeof(fn))
					if typeof(fn) == "function" then
						local ok, err = pcall(fn)
						log("    pcall fn ok=" .. tostring(ok) .. " err=" .. tostring(err or ""))
					end
				end
			end
		end
	else
		log("  getconnections not available")
	end
end

log("===== DISCONNECT TEST =====")

local promptGui = CoreGui:FindFirstChild("RobloxPromptGui")
log("RobloxPromptGui found=" .. tostring(promptGui ~= nil))

if promptGui then
	local overlay = promptGui:FindFirstChild("promptOverlay")
	log("promptOverlay found=" .. tostring(overlay ~= nil))

	if overlay then
		local prompt = overlay:FindFirstChild("ErrorPrompt")
		log("ErrorPrompt found=" .. tostring(prompt ~= nil) .. " visible=" .. tostring(prompt and prompt.Visible))

		if prompt then
			local title = prompt:FindFirstChild("TitleFrame", true)
			if title then
				local lbl = title:FindFirstChild("ErrorTitle")
				if lbl then
					log("Title=" .. lbl.Text)
				end
			end

			local message = prompt:FindFirstChild("ErrorMessage", true)
			if message then
				log("Message=" .. message.Text)
			end

			local reconnect = prompt:FindFirstChild("ReconnectButton", true)
			local leave = prompt:FindFirstChild("LeaveButton", true)

			log("ReconnectButton found=" .. tostring(reconnect ~= nil))
			log("LeaveButton found=" .. tostring(leave ~= nil))

			if reconnect then
				fireBtn(reconnect)
			end
		end
	end
end

log("===== DONE =====")

local full = table.concat(out, "\n")
pcall(function()
	setclipboard(full)
	log("Output copied to clipboard.")
end)
