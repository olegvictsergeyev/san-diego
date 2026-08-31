--[[
    San Diego Agent — Probe: search PlayerScripts for placement logic
    ================================================================
    Перебирает LocalScripts/Scripts в PlayerScripts и ReplicatedFirst,
    декомпилирует их и ищет MoneyPrinter / Tool / Drop / Place.
]]

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

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
    if writefile then pcall(function() writefile("playerscripts_placement_search_log.txt", text) end) end
end

local function decompileAndSearch(scriptObj)
    local ok, source = pcall(function()
        if decompile then return decompile(scriptObj) else return scriptObj.Source end
    end)
    if not ok or not source or #source == 0 then
        return nil
    end
    local keywords = {"MoneyPrinter", "Money Printer", "money printer", "Place", "place", "Drop", "drop", "Tool", "tool", "Activated", "Backpack"}
    local found = {}
    for _, kw in ipairs(keywords) do
        if source:lower():find(kw:lower()) then
            table.insert(found, kw)
        end
    end
    if #found == 0 then return nil end
    return source, found
end

log("========== SEARCH PLAYERSCRIPTS ==========")
log("Player:", player.Name)

local playerScripts = player:WaitForChild("PlayerScripts", 5)
if not playerScripts then
    log("ERROR: PlayerScripts not found")
    copy()
    return
end

local candidates = {}
local function scan(parent, depth)
    if depth > 5 then return end
    for _, c in ipairs(parent:GetChildren()) do
        if c:IsA("LocalScript") or c:IsA("Script") or c:IsA("ModuleScript") then
            local source, found = decompileAndSearch(c)
            if source then
                table.insert(candidates, {obj = c, path = c:GetFullName(), source = source, found = found})
            end
        end
        scan(c, depth + 1)
    end
end

scan(playerScripts, 0)
scan(ReplicatedFirst, 0)

log("Candidates found:", tostring(#candidates))
for _, data in ipairs(candidates) do
    log("\n==============================")
    log("SCRIPT:", data.path, "Class:", data.obj.ClassName)
    log("Keywords:", table.concat(data.found, ", "))
    log("Length:", tostring(#data.source))
    
    if writefile then
        local safeName = data.path:gsub("[^%w%._-]", "_")
        pcall(function() writefile("playerscript_" .. safeName .. ".lua", data.source) end)
    end
    
    for _, kw in ipairs(data.found) do
        local pos = data.source:lower():find(kw:lower())
        if pos then
            local start = math.max(1, pos - 300)
            local finish = math.min(#data.source, pos + 600)
            log("\n--- '" .. kw .. "' snippet ---")
            log(string.sub(data.source, start, finish))
        end
    end
end

log("\n========== END ==========")
copy()
