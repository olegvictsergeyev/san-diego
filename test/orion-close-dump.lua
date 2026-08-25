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
	local roots = { game.CoreGui }
	local hui = gethui and gethui() or nil
	if hui then
		table.insert(roots, hui)
	end
	for _, root in ipairs(roots) do
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
	log("All ScreenGuis in CoreGui:")
	for _, sg in ipairs(CoreGui:GetChildren()) do
		if sg:IsA("ScreenGui") then
			log("  " .. sg.Name)
		end
	end
	if hui then
		log("All ScreenGuis in gethui():")
		for _, sg in ipairs(hui:GetChildren()) do
			if sg:IsA("ScreenGui") then
				log("  " .. sg.Name)
			end
		end
	end
else
	log("Orion ScreenGui: " .. gui.Name)
	for _, desc in ipairs(gui:GetDescendants()) do
		if desc:IsA("TextButton") or desc:IsA("ImageButton") then
			local info = pathOf(desc) .. " | class=" .. desc.ClassName
			if desc:IsA("TextButton") then
				info = info .. " | Text=\"" .. tostring(desc.Text) .. "\""
			end
			if desc:IsA("ImageButton") then
				info = info .. " | Image=" .. tostring(desc.Image or "")
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
