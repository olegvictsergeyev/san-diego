local Compat = {}

function Compat.httpGet(url)
	local ok, body = pcall(function()
		return game:HttpGet(url)
	end)
	if not ok then
		local req = request or http_request
		if req then
			local resp = req({ Url = url, Method = "GET" })
			body = resp and resp.Body
		end
	end
	return body
end

function Compat.request(options)
	local req = request or http_request
	if req then
		return req(options)
	end
	return nil
end

function Compat.queueOnTeleport(code)
	local q = queue_on_teleport
	if typeof(q) ~= "function" then
		return false
	end
	local ok = pcall(q, code)
	return ok
end

function Compat.gethui()
	if typeof(gethui) == "function" then
		return gethui()
	end
	return game.CoreGui
end

function Compat.setClipboard(text)
	if typeof(setclipboard) == "function" then
		pcall(setclipboard, tostring(text))
	end
end

function Compat.getConnections(signal)
	if typeof(getconnections) == "function" then
		return getconnections(signal)
	end
	return {}
end

function Compat.fireClickDetector(detector)
	if typeof(fireclickdetector) == "function" then
		pcall(fireclickdetector, detector)
	end
end

function Compat.fireTouchInterest(part, toucher, toggle)
	if typeof(firetouchinterest) == "function" then
		pcall(firetouchinterest, part, toucher, toggle)
	end
end

function Compat.consolePrint(...)
	if typeof(rconsoleprint) == "function" then
		pcall(rconsoleprint, ...)
	end
end

return Compat
