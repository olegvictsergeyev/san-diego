local function httpGet(url)
	local ok, res = pcall(function()
		local req = request or http_request
		if req then
			return req({ Url = url, Method = "GET", Headers = { ["Cache-Control"] = "no-cache" } })
		end
		return { Body = game:HttpGet(url) }
	end)
	if not ok then
		print("[SanDiegoAgent][Backup] httpGet error:", tostring(res))
		return nil
	end
	local body = res and (res.Body or res.body)
	if not body or body == "" then
		print("[SanDiegoAgent][Backup] empty body for", url)
		return nil
	end
	return body
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
print("[SanDiegoAgent][Backup] loading", loaderUrl)
local source = httpGet(loaderUrl)
if source then
	local fn, err = loadstring(source, "agent")
	if fn then
		fn()
	else
		warn("[SanDiegoAgent][Backup] loadstring failed: " .. tostring(err))
	end
else
	warn("[SanDiegoAgent][Backup] failed to load agent from " .. loaderUrl)
end
