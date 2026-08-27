local Autoexec = {}
Autoexec.__index = Autoexec

local CANDIDATES = {
	"autoexec/san-diego-agent.lua",
	"synapse/autoexec/san-diego-agent.lua",
	"krnl/autoexec/san-diego-agent.lua",
	"fluxus/autoexec/san-diego-agent.lua",
	"delta/autoexec/san-diego-agent.lua",
	"xeno/autoexec/san-diego-agent.lua",
	"hydrogen/autoexec/san-diego-agent.lua",
	"oxygen/autoexec/san-diego-agent.lua",
	"isaeva/autoexec/san-diego-agent.lua",
	"codex/autoexec/san-diego-agent.lua",
}

function Autoexec.new()
	return setmetatable({}, Autoexec)
end

function Autoexec:_makeLoaderCode(loaderUrl)
	local baseUrl = tostring(loaderUrl):match("(.+)/final/agent%.lua$") or tostring(loaderUrl)
	local backupUrl = baseUrl .. "/final/agent-backup.lua"
	return 'loadstring(game:HttpGet("' .. backupUrl .. '?nocache=" .. tostring(tick())))()'
end

function Autoexec:install(loaderUrl)
	if typeof(writefile) ~= "function" or typeof(isfile) ~= "function" then
		return nil, "file operations not available"
	end

	local code = self:_makeLoaderCode(loaderUrl)

	for _, path in ipairs(CANDIDATES) do
		local exists, existsErr = pcall(function()
			return isfile(path)
		end)
		if exists then
			print("[SanDiegoAgent][Autoexec] already installed at " .. path)
			return path
		end

		local ok = pcall(function()
			writefile(path, code)
		end)
		if ok then
			local verify, verifyErr = pcall(function()
				return isfile(path)
			end)
			if verify then
				print("[SanDiegoAgent][Autoexec] installed at " .. path)
				return path
			end
		end
	end

	return nil, "no writable autoexec path found"
end

return Autoexec
