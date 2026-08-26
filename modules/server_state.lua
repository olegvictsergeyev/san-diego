local HttpService = game:GetService("HttpService")

local ServerState = {}
ServerState.__index = ServerState

function ServerState.new(compat, nickname)
	local suffix = nickname and nickname ~= "" and ("-" .. nickname) or ""
	return setmetatable({
		compat = compat,
		folder = "SanDiegoAgent",
		file = "SanDiegoAgent/last-server" .. suffix .. ".json",
	}, ServerState)
end

function ServerState:_ensureFolder()
	if self.compat and self.compat.makeFolder then
		self.compat.makeFolder(self.folder)
	end
end

function ServerState:save(placeId, jobId)
	if not jobId then
		return false
	end
	local ok, json = pcall(function()
		return HttpService:JSONEncode({
			placeId = tostring(placeId or game.PlaceId),
			jobId = tostring(jobId),
			savedAt = tick(),
		})
	end)
	if not ok then
		return false
	end
	self:_ensureFolder()
	if self.compat and self.compat.writeFile then
		return self.compat.writeFile(self.file, json)
	end
	return false
end

function ServerState:load()
	if not (self.compat and self.compat.readFile) then
		return nil
	end
	local ok, content = self.compat.readFile(self.file)
	if not ok or not content or content == "" then
		return nil
	end
	local parseOk, data = pcall(function()
		return HttpService:JSONDecode(content)
	end)
	if not parseOk or typeof(data) ~= "table" then
		return nil
	end
	return data
end

function ServerState:clear()
	if not (self.compat and self.compat.isFile and self.compat.writeFile) then
		return
	end
	local ok, exists = self.compat.isFile(self.file)
	if ok and exists then
		self.compat.writeFile(self.file, "{}")
	end
end

return ServerState
