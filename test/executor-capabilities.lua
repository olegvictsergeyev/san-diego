local Players = game:GetService("Players")
local out = {}

local function log(s)
	table.insert(out, tostring(s))
	print(tostring(s))
end

local function testCall(name, fn)
	local t = typeof(fn)
	if t ~= "function" then
		log("[SKIP] " .. name .. " | type=" .. t)
		return
	end
	local ok, res = pcall(fn)
	if not ok then
		log("[FAIL] " .. name .. " | err=" .. tostring(res):sub(1, 160))
		return
	end
	local rt = typeof(res)
	local line
	if rt == "table" then
		line = "[OK]   " .. name .. " | type=table len=" .. tostring(#res)
	elseif rt == "Instance" then
		line = "[OK]   " .. name .. " | type=Instance class=" .. res.ClassName .. " name=" .. res.Name
	else
		line = "[OK]   " .. name .. " | type=" .. rt .. " val=" .. tostring(res):sub(1, 120)
	end
	log(line)
end

log("===== EXECUTOR CAPABILITIES =====")
log("tick=" .. tostring(tick()))
log("placeId=" .. tostring(game.PlaceId))
log("jobId=" .. tostring(game.JobId))

testCall("identifyexecutor", function() return identifyexecutor() end)
testCall("getexecutorname", function() if getexecutorname then return getexecutorname() end return "missing" end)
testCall("printidentity", function() printidentity() return "called" end)

log("===== LIBRARIES =====")
local libs = {
	"syn", "xeno", "delta", "issaeva", "fluxus", "hydrogen", "codex", "oxygen", "krnl",
	"crypt", "bit", "debug", "Drawing", "WebSocket",
}
for _, lib in ipairs(libs) do
	local val = _G[lib]
	local t = typeof(val)
	if t == "table" then
		local keys = {}
		for k in pairs(val) do
			table.insert(keys, tostring(k))
			if #keys >= 30 then break end
		end
		log("[LIB]  " .. lib .. " | keys=" .. table.concat(keys, ", "))
	else
		log("[LIB]  " .. lib .. " | type=" .. t)
	end
end

testCall("crypt.base64encode", function()
	if crypt and crypt.base64encode then return crypt.base64encode("test") end
	return "missing"
end)
testCall("Drawing.new", function()
	if Drawing and Drawing.new then return Drawing.new("Square") end
	return "missing"
end)
testCall("WebSocket.connect", function()
	if WebSocket and WebSocket.connect then return typeof(WebSocket.connect) end
	return "missing"
end)

log("===== GLOBAL FUNCTIONS =====")
local tests = {
	{"loadstring", function() local f = loadstring("return 2+2") return f and f() end},
	{"game:HttpGet", function() return game:HttpGet("https://raw.githubusercontent.com/olegvictsergeyev/san-diego/main/README.md") end},
	{"request", function() if request then return request({Url = "https://raw.githubusercontent.com/olegvictsergeyev/san-diego/main/README.md", Method = "GET"}) end return "missing" end},
	{"http_request", function() if http_request then return http_request({Url = "https://raw.githubusercontent.com/olegvictsergeyev/san-diego/main/README.md", Method = "GET"}) end return "missing" end},
	{"getconnections", function() local rs = game:GetService("RunService") return "count=" .. tostring(#getconnections(rs.Heartbeat)) end},
	{"fireclickdetector", function() local cd = workspace:FindFirstChildWhichIsA("ClickDetector", true) if cd then fireclickdetector(cd) return cd:GetFullName() end return "no ClickDetector" end},
	{"firetouchinterest", function() local p = workspace:FindFirstChildWhichIsA("BasePart", true) local c = Players.LocalPlayer.Character if p and c and c:FindFirstChild("HumanoidRootPart") then firetouchinterest(p, c.HumanoidRootPart, 0) return "fired" end return "no part/char" end},
	{"setclipboard", function() setclipboard("test") return "set" end},
	{"gethui", function() local h = gethui() return h and h:GetFullName() or "nil" end},
	{"queue_on_teleport", function() local q = queue_on_teleport if typeof(q) ~= "function" then return "missing: " .. typeof(q) end q("--test") return "queued" end},
	{"hookmetamethod", function() return typeof(hookmetamethod) end},
	{"hookfunction", function() return typeof(hookfunction) end},
	{"getrawmetatable", function() return typeof(getrawmetatable) end},
	{"setreadonly", function() return typeof(setreadonly) end},
	{"isrbxactive", function() return tostring(isrbxactive()) end},
	{"getfpscap", function() return tostring(getfpscap()) end},
	{"setfpscap", function() setfpscap(60) return "set" end},
	{"getgc", function() return "len=" .. tostring(#getgc()) end},
	{"getinstances", function() return "len=" .. tostring(#getinstances()) end},
	{"getnilinstances", function() return "len=" .. tostring(#getnilinstances()) end},
	{"gethiddenproperty", function() return typeof(gethiddenproperty) end},
	{"sethiddenproperty", function() return typeof(sethiddenproperty) end},
	{"getsenv", function() return typeof(getsenv) end},
	{"getmenv", function() return typeof(getmenv) end},
	{"getreg", function() return typeof(getreg) end},
	{"gettenv", function() return typeof(gettenv) end},
	{"checkcaller", function() return tostring(checkcaller()) end},
	{"islclosure", function() return tostring(islclosure(print)) end},
	{"dumpstring", function() return typeof(dumpstring) end},
	{"decompile", function() return typeof(decompile) end},
	{"saveinstance", function() return typeof(saveinstance) end},
	{"messagebox", function() return typeof(messagebox) end},
	{"rconsoleprint", function() return typeof(rconsoleprint) end},
	{"rconsolewarn", function() return typeof(rconsolewarn) end},
	{"rconsoleerr", function() return typeof(rconsoleerr) end},
	{"consolecreate", function() return typeof(consolecreate) end},
	{"consoledestroy", function() return typeof(consoledestroy) end},
	{"consoleprint", function() return typeof(consoleprint) end},
	{"getcustomasset", function() return typeof(getcustomasset) end},
	{"setscriptable", function() return typeof(setscriptable) end},
	{"getscriptable", function() return typeof(getscriptable) end},
}
for _, t in ipairs(tests) do
	testCall(t[1], t[2])
end

log("===== FILE OPERATIONS =====")
testCall("makefolder/writefile/readfile/listfiles/isfolder/isfile/delfile/delfolder", function()
	local folder = "__sda_cap"
	local file = folder .. "/test.txt"
	if typeof(makefolder) == "function" then
		pcall(makefolder, folder)
	end
	writefile(file, "ok")
	local content = readfile(file)
	local files = listfiles(folder)
	local isF = isfolder(folder)
	local isFi = isfile(file)
	delfile(file)
	delfolder(folder)
	return string.format("content=%s files=%s isfolder=%s isfile=%s", tostring(content), tostring(#files), tostring(isF), tostring(isFi))
end)

log("===== DONE =====")

local full = table.concat(out, "\n")
pcall(function()
	setclipboard(full)
	log("Output copied to clipboard.")
end)
