local HttpService = game:GetService("HttpService")

local function urlEncode(str)
	if not str then return "" end
	local result = {}
	str = tostring(str)
	for i = 1, #str do
		local c = str:sub(i, i)
		local b = c:byte()
		if (b >= 48 and b <= 57) or (b >= 65 and b <= 90) or (b >= 97 and b <= 122) or c == "-" or c == "_" or c == "." or c == "~" then
			table.insert(result, c)
		else
			table.insert(result, string.format("%%%02X", b))
		end
	end
	return table.concat(result)
end

local HttpClient = {}
HttpClient.__index = HttpClient

function HttpClient.new(baseUrl, timeout)
	local self = setmetatable({}, HttpClient)
	self.baseUrl = baseUrl
	self.timeout = timeout or 60
	return self
end

function HttpClient:_getRequestFunction()
	if syn and syn.request then
		return syn.request, "syn.request"
	elseif http and http.request then
		return http.request, "http.request"
	elseif fluxus and fluxus.request then
		return fluxus.request, "fluxus.request"
	elseif getgenv().request then
		return getgenv().request, "request"
	elseif getgenv().http_request then
		return getgenv().http_request, "http_request"
	else
		return nil, "HttpService:RequestAsync"
	end
end

function HttpClient:_makeUrl(path)
	local url = self.baseUrl
	if url:sub(-1) == "/" then
		url = url:sub(1, -2)
	end
	if path:sub(1, 1) ~= "/" then
		path = "/" .. path
	end
	return url .. path
end

function HttpClient:request(method, path, body, headers, query)
	local requestFunc, methodName = self:_getRequestFunction()
	local url = self:_makeUrl(path)

	if query then
		local parts = {}
		for k, v in pairs(query) do
			table.insert(parts, urlEncode(k) .. "=" .. urlEncode(tostring(v)))
		end
		if #parts > 0 then
			url = url .. "?" .. table.concat(parts, "&")
		end
	end

	headers = headers or {}
	headers["Content-Type"] = headers["Content-Type"] or "application/json"

	local ok, res = pcall(function()
		if requestFunc then
			local opts = {
				Url = url,
				Method = method,
				Headers = headers,
			}
			if body then
				opts.Body = typeof(body) == "string" and body or HttpService:JSONEncode(body)
			end
			return requestFunc(opts)
		else
			local opts = {
				Url = url,
				Method = method,
				Headers = headers,
			}
			if body then
				opts.Body = typeof(body) == "string" and body or HttpService:JSONEncode(body)
			end
			return HttpService:RequestAsync(opts)
		end
	end)

	if not ok then
		return false, tostring(res)
	end

	local parsedBody
	if res.Body and res.Body ~= "" then
		local parseOk, parsed = pcall(function()
			return HttpService:JSONDecode(res.Body)
		end)
		if parseOk then
			parsedBody = parsed
		else
			parsedBody = res.Body
		end
	end

	return true, {
		statusCode = res.StatusCode,
		body = parsedBody,
		rawBody = res.Body,
		headers = res.Headers,
		method = methodName,
	}
end

function HttpClient:post(path, body, headers)
	return self:request("POST", path, body, headers)
end

function HttpClient:get(path, query, headers)
	return self:request("GET", path, nil, headers, query)
end

return HttpClient
