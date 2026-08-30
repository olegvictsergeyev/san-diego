local HttpService = game:GetService("HttpService")

local ResultStore = {}
ResultStore.__index = ResultStore

function ResultStore.new(compat, nickname)
	local suffix = nickname and nickname ~= "" and ("-" .. nickname) or ""
	return setmetatable({
		compat = compat,
		folder = "SanDiegoAgent",
		file = "SanDiegoAgent/pending-results" .. suffix .. ".json",
	}, ResultStore)
end

function ResultStore:_ensureFolder()
	if self.compat and self.compat.makeFolder then
		pcall(function()
			self.compat.makeFolder(self.folder)
		end)
	end
end

function ResultStore:_write(data)
	self:_ensureFolder()
	if not (self.compat and self.compat.writeFile) then
		return false
	end
	local ok, json = pcall(function()
		return HttpService:JSONEncode(data)
	end)
	if not ok then
		return false
	end
	return self.compat.writeFile(self.file, json)
end

function ResultStore:_read()
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

function ResultStore:getPending()
	local data = self:_read() or {}
	local pending = {}
	for commandId, item in pairs(data) do
		if typeof(item) == "table" and not item.sent then
			pending[commandId] = {
				commandId = commandId,
				result = item.result,
				status = item.status,
				attempts = tonumber(item.attempts) or 0,
				lastAttemptAt = tonumber(item.lastAttemptAt) or 0,
			}
		end
	end
	return pending
end

function ResultStore:save(commandId, result, status)
	if not commandId then
		return false
	end
	local data = self:_read() or {}
	data[tostring(commandId)] = {
		result = tostring(result),
		status = tostring(status),
		sent = false,
		attempts = 0,
		lastAttemptAt = 0,
		savedAt = tick(),
	}
	return self:_write(data)
end

function ResultStore:markSent(commandId)
	if not commandId then
		return false
	end
	local data = self:_read() or {}
	local item = data[tostring(commandId)]
	if typeof(item) == "table" then
		item.sent = true
		item.sentAt = tick()
	end
	return self:_write(data)
end

function ResultStore:incrementAttempt(commandId)
	if not commandId then
		return false
	end
	local data = self:_read() or {}
	local item = data[tostring(commandId)]
	if typeof(item) == "table" then
		item.attempts = (tonumber(item.attempts) or 0) + 1
		item.lastAttemptAt = tick()
	end
	return self:_write(data)
end

function ResultStore:remove(commandId)
	if not commandId then
		return false
	end
	local data = self:_read() or {}
	data[tostring(commandId)] = nil
	return self:_write(data)
end

return ResultStore
