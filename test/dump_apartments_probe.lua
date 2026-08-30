local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local gameplay = Workspace:FindFirstChild("Gameplay")
if not gameplay then
	print("Gameplay not found")
	return
end

local apartments = gameplay:FindFirstChild("Apartments")
if not apartments then
	print("Apartments not found")
	return
end

local function dumpInstance(inst, depth)
	local indent = string.rep("  ", depth)
	local line = indent .. inst.Name .. " (" .. inst.ClassName .. ")"
	local attrs = inst:GetAttributes()
	if next(attrs) then
		line = line .. " attrs=" .. HttpService:JSONEncode(attrs)
	end
	print(line)
	if not inst:IsA("ValueBase") then
		for _, child in ipairs(inst:GetChildren()) do
			dumpInstance(child, depth + 1)
		end
	end
end

print("=== Apartments structure ===")
for _, child in ipairs(apartments:GetChildren()) do
	dumpInstance(child, 0)
end
