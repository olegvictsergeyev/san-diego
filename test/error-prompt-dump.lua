local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local out = {}

local function log(s)
	table.insert(out, tostring(s))
	print(tostring(s))
end

local function pathOf(obj)
	local parts = {}
	local current = obj
	while current do
		table.insert(parts, 1, current.Name)
		current = current.Parent
	end
	return table.concat(parts, ".")
end

local function dumpInstance(inst, depth)
	depth = depth or 0
	local prefix = string.rep("  ", depth)
	local info = prefix .. inst.ClassName .. " " .. inst.Name
	if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
		info = info .. ' | Text="' .. tostring(inst.Text):sub(1, 200) .. '"'
	end
	if inst:IsA("ImageButton") or inst:IsA("ImageLabel") then
		info = info .. " | Image=" .. tostring(inst.Image):sub(1, 100)
	end
	log(info)
	for _, child in ipairs(inst:GetChildren()) do
		dumpInstance(child, depth + 1)
	end
end

local function tryDump(namePattern)
	for _, sg in ipairs(CoreGui:GetChildren()) do
		if sg:IsA("ScreenGui") and (namePattern == nil or sg.Name:lower():find(namePattern)) then
			log("===== SCREENGUI: " .. sg.Name .. " =====")
			dumpInstance(sg)
		end
	end
end

log("===== ERROR PROMPT DUMP =====")
log("tick=" .. tostring(tick()))

log("--- searching RobloxPromptGui ---")
tryDump("robloxprompt")
tryDump("prompt")
tryDump("error")

log("--- all ScreenGuis in CoreGui ---")
for _, sg in ipairs(CoreGui:GetChildren()) do
	if sg:IsA("ScreenGui") then
		log("ScreenGui: " .. sg.Name)
	end
end

log("===== DONE =====")

local full = table.concat(out, "\n")
pcall(function()
	setclipboard(full)
	log("Dump copied to clipboard.")
end)
