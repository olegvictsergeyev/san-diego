--[[
    San Diego Agent — Probe: find modules using placement constants
    ================================================================
    Перебирает все загруженные модули и ищет PLACEMENT_FORWARD_DISTANCE,
    PLACEMENT_RAYCAST_UP, PLACEMENT_RAYCAST_DOWN.
]]

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
    if writefile then pcall(function() writefile("placement_constants_search_log.txt", text) end) end
end

log("========== SEARCH PLACEMENT CONSTANTS ==========")

local getloadedmodules = getloadedmodules
if not getloadedmodules then
    log("ERROR: getloadedmodules unavailable")
    copy()
    return
end

local modules = getloadedmodules()
log("Loaded modules:", tostring(#modules))

local constants = {
    "PLACEMENT_FORWARD_DISTANCE",
    "PLACEMENT_RAYCAST_UP",
    "PLACEMENT_RAYCAST_DOWN",
    "PLACEMENT_FORWARD",
    "PICKUP_DISTANCE",
}

local function formatPath(module)
    local ok, fullName = pcall(function() return module:GetFullName() end)
    if ok then return fullName end
    local ok2, name = pcall(function() return module.Name end)
    return ok2 and name or "unknown"
end

local foundModules = {}
for _, module in ipairs(modules) do
    if typeof(module) == "Instance" and module:IsA("ModuleScript") then
        local ok, source = pcall(function()
            if decompile then return decompile(module) else return module.Source end
        end)
        if ok and source and #source > 0 then
            for _, const in ipairs(constants) do
                if source:find(const) then
                    if not foundModules[module] then
                        foundModules[module] = {path = formatPath(module), matches = {}}
                    end
                    table.insert(foundModules[module].matches, const)
                end
            end
        end
    end
end

log("Modules using placement constants:")
local count = 0
for module, data in pairs(foundModules) do
    count += 1
    log("\n---", data.path, "---")
    log("Constants:", table.concat(data.matches, ", "))
    local ok, source = pcall(function()
        if decompile then return decompile(module) else return module.Source end
    end)
    if ok and source then
        for _, const in ipairs(data.matches) do
            local pos = source:find(const)
            if pos then
                local start = math.max(1, pos - 400)
                local finish = math.min(#source, pos + 800)
                log("\n--- '" .. const .. "' snippet ---")
                log(string.sub(source, start, finish))
            end
        end
        if writefile then
            local safeName = data.path:gsub("[^%w%._-]", "_")
            pcall(function() writefile("placement_const_" .. safeName .. ".lua", source) end)
        end
    end
end
log("\nTotal:", tostring(count))
log("\n========== END ==========")
copy()
