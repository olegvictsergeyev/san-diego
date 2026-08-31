--[[
    San Diego Agent — Test: hook InputBegan to catch placement function
    ==================================================================
    Хукает все соединения на UserInputService.InputBegan, просит вручную
    поставить принтер, логирует вызванную функцию и декомпилирует её.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local logs = {}

local function log(...)
    local msg = "[" .. os.date("%H:%M:%S") .. "] " .. table.concat({ ... }, " ")
    table.insert(logs, msg)
    print(msg)
    warn(msg)
end

local function copy(text)
    if not text then text = table.concat(logs, "\n") end
    if setclipboard then pcall(function() setclipboard(text) end) end
    if writefile then pcall(function() writefile("printer_input_hook_test_log.txt", text) end) end
end

local function safeDump(obj)
    local ok, s = pcall(function() return tostring(obj) end)
    return ok and s or "???"
end

local function decompileFn(fn)
    if not fn then return nil end
    if decompile then
        local ok, src = pcall(function() return decompile(fn) end)
        if ok and src then return src end
    end
    local info = debug.getinfo(fn)
    if info then
        return string.format("-- function info: name=%s source=%s linedefined=%s", safeDump(info.name), safeDump(info.source), safeDump(info.linedefined))
    end
    return "-- could not decompile"
end

log("========== PRINTER INPUT HOOK TEST ==========")
log("Player:", player.Name)

if not getconnections then
    log("ERROR: getconnections not available")
    copy()
    return
end

if not hookfunction then
    log("ERROR: hookfunction not available")
    copy()
    return
end

local hookedFns = {}
local triggeredFns = {}

local function hookConnection(conn)
    local fn = conn.Function
    if not fn then return end
    if hookedFns[fn] then return end
    hookedFns[fn] = true

    local newFn = function(...)
        local args = {...}
        local input = args[1]
        local inputType = "nil"
        local keyCode = "nil"
        local position = "nil"
        if input then
            pcall(function()
                inputType = tostring(input.UserInputType)
                keyCode = tostring(input.KeyCode)
                position = tostring(input.Position)
            end)
        end
        log("[INPUT BEGAN] inputType=", inputType, "keyCode=", keyCode, "position=", position)
        log("  function:", safeDump(fn))
        if not triggeredFns[fn] then
            triggeredFns[fn] = true
            log("  *** NEW FUNCTION TRIGGERED ***")
            local src = decompileFn(fn)
            if src then
                log("  decompiled source (first 800 chars):\n", string.sub(src, 1, 800))
                copy(src) -- copy full source
            end
        end
        return fn(...)
    end

    local ok, err = pcall(function()
        hookfunction(fn, newFn)
    end)
    if not ok then
        log("  failed to hook function:", safeDump(err))
    end
end

log("Hooking UserInputService.InputBegan connections...")
local ok, conns = pcall(function() return getconnections(UserInputService.InputBegan) end)
if not ok or not conns then
    log("ERROR: getconnections failed:", safeDump(conns))
    copy()
    return
end

log("Found", tostring(#conns), "connections")
for i, conn in ipairs(conns) do
    hookConnection(conn)
end

log("\n!!! Now manually place 1 Money Printer using your normal method !!!")
log("(for example: equip the tool and press the button/key you usually press)")
log("Waiting 15 seconds...")

for i = 1, 15 do
    log("waiting...", tostring(i), "/15")
    task.wait(1)
end

log("\n--- Functions triggered during test ---")
local count = 0
for fn, _ in pairs(triggeredFns) do
    count += 1
    log("Function #", tostring(count), safeDump(fn))
    local src = decompileFn(fn)
    if src then
        log("Source:\n", string.sub(src, 1, 1000))
    end
end
if count == 0 then
    log("No functions were triggered")
end

log("\n========== END TEST ==========")
copy()
