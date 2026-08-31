--[[
    San Diego Agent — Probe: search loaded modules for printer placement logic
    =========================================================================
    Перебирает все загруженные модули и ищет MoneyPrinter / placement / drop
    в их исходном коде.
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
    if writefile then pcall(function() writefile("loaded_modules_search_log.txt", text) end) end
end

log("========== SEARCH LOADED MODULES ==========")

local getloadedmodules = getloadedmodules
if not getloadedmodules then
    log("ERROR: getloadedmodules unavailable")
    copy()
    return
end

local modules = getloadedmodules()
log("Loaded modules:", tostring(#modules))

local keywords = {
    "MoneyPrinter", "money printer", "Money Printer",
    "CanBeDropped", "Drop", "drop", "PlaceTool", "PlaceItem", "place",
    "ActivateTool", "ActivatedTool", "ToolActivated",
    "PickupMoneyPrinter", "Confiscate",
}

local function decompileAndSearch(module)
    local ok, source = pcall(function()
        if decompile then
            return decompile(module)
        else
            return module.Source
        end
    end)
    if not ok or not source or #source == 0 then
        return nil
    end
    local found = {}
    for _, keyword in ipairs(keywords) do
        if source:lower():find(keyword:lower()) then
            table.insert(found, keyword)
        end
    end
    if #found > 0 then
        return source, found
    end
    return nil
end

local function formatPath(module)
    local ok, fullName = pcall(function() return module:GetFullName() end)
    if ok then return fullName end
    local ok2, name = pcall(function() return module.Name end)
    return ok2 and name or "unknown"
end

local candidates = {}
for _, module in ipairs(modules) do
    if typeof(module) == "Instance" and module:IsA("ModuleScript") then
        local source, found = decompileAndSearch(module)
        if source then
            table.insert(candidates, {
                module = module,
                path = formatPath(module),
                size = #source,
                found = found,
                source = source
            })
        end
    end
end

log("Candidates found:", tostring(#candidates))
for _, cand in ipairs(candidates) do
    log("\n--- Module:", cand.path, "Size:", tostring(cand.size), "---")
    log("Keywords:", table.concat(cand.found, ", "))
    
    -- Save full source to file
    local safeName = cand.path:gsub("[^%w%._-]", "_")
    if writefile then
        pcall(function() writefile("module_" .. safeName .. ".lua", cand.source) end)
    end
    
    -- Show snippets around each keyword
    local source = cand.source
    for _, keyword in ipairs(cand.found) do
        local pattern = "()" .. keyword
        for pos in string.gmatch(source, pattern) do
            local start = math.max(1, pos - 200)
            local finish = math.min(#source, pos + 400)
            log("\n--- '" .. keyword .. "' snippet ---")
            log(string.sub(source, start, finish))
            break -- only first occurrence per keyword
        end
    end
end

log("\n========== END ==========")
copy()
