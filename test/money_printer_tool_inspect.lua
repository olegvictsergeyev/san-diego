--[[
    San Diego Agent — Probe: inspect Money Printer Tool contents
    ==========================================================
    Находит Tool Money Printer в Backpack/Character и полностью исследует
    его детей: ищет LocalScripts, ModuleScripts, ClickDetectors, ProximityPrompts.
    Декомпилирует найденные скрипты.
]]

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local logs = {}

local function log(...)
    local msg = "[" .. os.date("%H:%M:%S") .. "] " .. table.concat({ ... }, " ")
    table.insert(logs, msg)
    print(msg)
    warn(msg)
end

local function copy()
    local text = table.concat(logs, "\n")
    if setclipboard then pcall(function() setclipboard(text) end) end
    if writefile then pcall(function() writefile("money_printer_tool_inspect_log.txt", text) end) end
end

local function decompileAndLog(obj)
    local ok, source = pcall(function()
        if decompile then return decompile(obj) else return obj.Source end
    end)
    if ok and source and #source > 0 then
        log("  Decompiled length:", tostring(#source))
        if writefile then
            local safeName = obj.Name:gsub("[^%w%._-]", "_") .. "_" .. obj.ClassName
            pcall(function() writefile("tool_script_" .. safeName .. ".lua", source) end)
        end
        -- Show whole source if small enough
        if #source <= 4000 then
            log("  Source:\n" .. source)
        else
            log("  Source too long, saved to file")
        end
    else
        log("  Failed to decompile:", tostring(source))
    end
end

local function inspectTool(tool, label)
    log("\n--- Inspecting", label, ":", tool:GetFullName(), "Class:", tool.ClassName, "---")
    log("Descendants count:", tostring(#tool:GetDescendants()))
    
    local hasScript = false
    local function scan(parent, depth)
        if depth > 10 then return end
        for _, c in ipairs(parent:GetChildren()) do
            if c:IsA("LocalScript") or c:IsA("Script") or c:IsA("ModuleScript") then
                hasScript = true
                log("\nFound script:", c.ClassName, c.Name, "in", c.Parent and c.Parent:GetFullName() or "nil")
                decompileAndLog(c)
            elseif c:IsA("ClickDetector") or c:IsA("ProximityPrompt") then
                log("Found interactive:", c.ClassName, c.Name, "in", c.Parent and c.Parent:GetFullName() or "nil")
            elseif c:IsA("BasePart") then
                log("Part:", c.Name, "Class:", c.ClassName)
            end
            scan(c, depth + 1)
        end
    end
    
    scan(tool, 0)
    
    if not hasScript then
        log("  No scripts inside this tool.")
    end
end

log("========== MONEY PRINTER TOOL INSPECT ==========")
log("Player:", player.Name)

local backpack = player:FindFirstChild("Backpack")
local character = player.Character

local tool = nil

if backpack then
    for _, c in ipairs(backpack:GetChildren()) do
        if c:IsA("Tool") and c.Name:lower():find("print") then
            tool = c
            break
        end
    end
end

if not tool and character then
    for _, c in ipairs(character:GetChildren()) do
        if c:IsA("Tool") and c.Name:lower():find("print") then
            tool = c
            break
        end
    end
end

if not tool then
    log("ERROR: Money Printer Tool not found in Backpack or Character")
    copy()
    return
end

inspectTool(tool, "Money Printer Tool")

-- Also inspect tool if cloned from ReplicatedStorage
local function findToolTemplate()
    local candidates = {}
    local function scan(parent)
        for _, c in ipairs(parent:GetChildren()) do
            if c:IsA("Tool") and c.Name:lower():find("print") then
                table.insert(candidates, c)
            end
            scan(c)
        end
    end
    scan(game:GetService("ReplicatedStorage"))
    scan(game:GetService("Workspace"))
    scan(game:GetService("Lighting"))
    return candidates
end

log("\nSearching for tool templates...")
local templates = findToolTemplate()
log("Found", tostring(#templates), "tool template(s)")
for _, t in ipairs(templates) do
    inspectTool(t, "Template")
end

log("\n========== END ==========")
copy()
