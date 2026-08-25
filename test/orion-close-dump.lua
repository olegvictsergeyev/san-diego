local CoreGui = game:GetService("CoreGui")
local out = {}

local function log(s)
	table.insert(out, tostring(s))
	print(tostring(s))
end

local function pathOf(obj)
	local parts = {}
	while obj do
		table.insert(parts, 1, obj.Name)
		obj = obj.Parent
	end
	return table.concat(parts, ".")
end

local function findOrionGui()
	for _, root in ipairs({ CoreGui }) do
		for _, sg in ipairs(root:GetChildren()) do
			if sg:IsA("ScreenGui") then
				if sg.Name == "San Diego Agent" then
					return sg
				end
				for _, desc in ipairs(sg:GetDescendants()) do
					if (desc:IsA("TextLabel") or desc:IsA("TextButton") or desc:IsA("TextBox")) and desc.Text == "San Diego Agent" then
						return sg
					end
				end
			end
		end
	end
	return nil
end

log("===== ORION CLOSE BUTTON DUMP =====")

local gui = findOrionGui()
if not gui then
	log("Orion ScreenGui not found")
else
	log("Orion ScreenGui: " .. gui.Name)
	for _, desc in ipairs(gui:GetDescendants()) do
		if desc:IsA("TextButton") or desc:IsA("ImageButton") then
			local info = pathOf(desc) .. " | class=" .. desc.ClassName
			if desc:IsA("TextButton") then
				info = info .. " | Text=\"" .. tostring(desc.Text) .. "\""
			end
			if desc:IsA("ImageButton") or desc:FindFirstChildOfClass("ImageLabel") then
				local img = desc:IsA("ImageButton") and desc.Image or nil
				info = info .. " | Image=" .. tostring(img or "")
			end
			info = info .. " | Size=" .. tostring(desc.Size) .. " | Pos=" .. tostring(desc.Position) .. " | ZIndex=" .. tostring(desc.ZIndex)
			log(info)
		end
	end
end

log("===== DONE =====")

local full = table.concat(out, "\n")
pcall(function()
	setclipboard(full)
	log("Dump copied to clipboard.")
end)
