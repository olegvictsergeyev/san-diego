--[[
    San Diego Agent — Test: run place_all_printers command standalone
    ================================================================
    Загружает modules/command_engine.lua и вызывает _placeAllPrintersCommand
    с маленьким max_total, чтобы проверить логику расстановки.
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
    if writefile then pcall(function() writefile("place_all_printers_command_test_log.txt", text) end) end
end

log("========== PLACE ALL PRINTERS COMMAND TEST ==========")

local baseUrl = "https://raw.githubusercontent.com/olegvictsergeyev/san-diego/main"
local url = baseUrl .. "/modules/command_engine.lua?nocache=" .. tostring(tick())
log("Loading command_engine from", url)

local source = game:HttpGet(url)
if typeof(source) ~= "string" or #source == 0 then
    log("ERROR: empty source")
    copy()
    return
end
log("Source length:", tostring(#source))

local fn, err = loadstring(source, "command_engine")
if not fn then
    log("ERROR loadstring:", tostring(err))
    copy()
    return
end

local CommandEngine = fn()
if not CommandEngine or typeof(CommandEngine) ~= "table" then
    log("ERROR: command_engine did not return table")
    copy()
    return
end

local engine = CommandEngine.new()
if not engine then
    log("ERROR: failed to instantiate CommandEngine")
    copy()
    return
end
engine.cancelled = false
log("Engine created")

log("Calling _placeAllPrintersCommand with max_total=3 ...")
local ok, result = pcall(function()
    return engine:_placeAllPrintersCommand({ max_total = 3, max_distance = 200 })
end)

if not ok then
    log("ERROR during command:", tostring(result))
    copy()
    return
end

log("Result success:", tostring(result.success))
if result.error then
    log("Result error:", tostring(result.error))
end
if result.data then
    log("Result data:")
    for k, v in pairs(result.data) do
        if typeof(v) == "table" then
            log("  " .. k .. " =", "(table)")
            for kk, vv in pairs(v) do
                log("    " .. tostring(kk) .. " =", tostring(vv))
            end
        else
            log("  " .. k .. " =", tostring(v))
        end
    end
end

log("\n========== END ==========")
copy()
