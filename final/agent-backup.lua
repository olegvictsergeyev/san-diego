local function httpGet(url)
	local ok, body = pcall(function()
		local req = request or http_request
		if req then
			local res = req({ Url = url, Method = "GET", Headers = { ["Cache-Control"] = "no-cache" } })
			return res and res.Body
		end
		return game:HttpGet(url)
	end)
	if ok then
		return body
	end
	return nil
end

local function getLatestCommitSha()
	local apiUrl = "https://api.github.com/repos/olegvictsergeyev/san-diego/commits/main"
	local body = httpGet(apiUrl)
	if not body then
		return nil
	end
	return body:match('"sha"%s*:%s*"([a-f0-9]+)"')
end

local sha = getLatestCommitSha()
local baseUrl
if sha then
	baseUrl = "https://raw.githubusercontent.com/olegvictsergeyev/san-diego/" .. sha
	print("[SanDiegoAgent][Backup] latest commit:", sha)
else
	baseUrl = "https://raw.githubusercontent.com/olegvictsergeyev/san-diego/main"
	warn("[SanDiegoAgent][Backup] failed to fetch latest commit, falling back to main")
end

getgenv().SanDiegoAgentBaseUrl = baseUrl

local loaderUrl = baseUrl .. "/final/agent.lua?nocache=" .. tostring(tick())
local source = httpGet(loaderUrl)
if source then
	loadstring(source, "agent")()
else
	warn("[SanDiegoAgent][Backup] failed to load agent from " .. loaderUrl)
end
