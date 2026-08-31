--[[
    San Diego Agent — Benchmark: доход с 50 принтеров vs. всех принтеров
    ===================================================================
    1. Собирает текущие принтеры и раскладывает ровно 50.
    2. Ставит игрока в центр площадки и замеряет прирост баланса за 2 минуты.
    3. Снова собирает принтеры и раскладывает ВСЕ Tool'ы из Backpack'а
       (игнорируя штатный лимит в 50).
    4. Ещё один центрированный 2-минутный замер.

    Результат копируется в буфер обмена и пишется в файл
    printer_income_benchmark_log.txt.
]]

local baseUrl = "https://raw.githubusercontent.com/olegvictsergeyev/san-diego/main"

local logs = {}

local function log(...)
    local msg = "[" .. os.date("%H:%M:%S") .. "] " .. table.concat({ ... }, " ")
    table.insert(logs, msg)
    print(msg)
    warn(msg)
end

local function copyLog()
    local text = table.concat(logs, "\n")
    pcall(function() setclipboard(text) end)
    pcall(function() writefile("printer_income_benchmark_log.txt", text) end)
end

local function loadModule(path)
    local url = baseUrl .. "/" .. path .. "?nocache=" .. tostring(tick())
    log("Loading module:", path)
    local source = game:HttpGet(url)
    if typeof(source) ~= "string" or #source == 0 then
        error("empty source for " .. path)
    end

    -- Для теста убираем лимит max_total = 50, позволяя разложить все принтеры.
    source = source:gsub("maxTotal < 1 or maxTotal > 50", "maxTotal < 1 or maxTotal > 500")

    local fn, err = loadstring(source, path)
    if not fn then
        error("loadstring failed for " .. path .. ": " .. tostring(err))
    end
    local mod = fn()
    if typeof(mod) ~= "table" then
        error("module " .. path .. " did not return a table")
    end
    return mod
end

log("========== PRINTER INCOME BENCHMARK ==========")

local CommandEngine = loadModule("modules/command_engine.lua")
local StateCollector = loadModule("modules/state_collector.lua")

local engine = CommandEngine.new()
if not engine then
    log("ERROR: failed to create CommandEngine")
    copyLog()
    return
end
engine.cancelled = false

local collector = StateCollector.new("", "benchmark")

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart")

local function getBalance()
    local ok, bal = pcall(function() return collector:getBalance() end)
    if ok and typeof(bal) == "number" then
        return bal
    end
    return 0
end

local function countBackpackPrinters()
    local n = 0
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return 0 end
    for _, c in ipairs(backpack:GetChildren()) do
        if c:IsA("Tool") and c.Name:lower():find("print") then
            n += 1
        end
    end
    return n
end

local function getBoundsFromResult(result)
    if result and result.data and result.data.bounds then
        return result.data.bounds
    end
    -- Fallback на измеренные ранее границы комнаты.
    return {
        minX = 997.1759033203125,
        maxX = 1010.9700927734375,
        minZ = -5993.724609375,
        maxZ = -5977.5517578125,
        floorY = -49.74806213378906,
    }
end

local function moveToCenter(bounds)
    local cx = (bounds.minX + bounds.maxX) / 2
    local cz = (bounds.minZ + bounds.maxZ) / 2
    local cy = bounds.floorY + 3
    local target = Vector3.new(cx, cy, cz)
    pcall(function()
        if hrp and hrp.Parent then
            hrp.CFrame = CFrame.new(target)
            hrp.AssemblyLinearVelocity = Vector3.zero
        end
    end)
    return target
end

local function keepPlayerCentered(bounds, duration)
    local start = tick()
    while tick() - start < duration do
        moveToCenter(bounds)
        task.wait(0.5)
    end
    moveToCenter(bounds)
end

local function measureIncome(label, bounds, duration)
    log("--- Measurement:", label, "---")
    moveToCenter(bounds)
    task.wait(0.5)
    moveToCenter(bounds)

    local startBalance = getBalance()
    log(label, "start balance:", tostring(startBalance))

    keepPlayerCentered(bounds, duration)

    local endBalance = getBalance()
    log(label, "end balance:", tostring(endBalance))

    local income = endBalance - startBalance
    log(label, "income over", tostring(duration), "s:", tostring(income))

    return {
        start = startBalance,
        finish = endBalance,
        income = income,
    }
end

local function runPlacement(label, maxTotal)
    log("--- Placement:", label, "(max_total=" .. tostring(maxTotal) .. ") ---")
    local ok, result = pcall(function()
        return engine:_placeAllPrintersCommand({ max_total = maxTotal, max_distance = 200 })
    end)
    if not ok then
        log("Placement CRASH:", tostring(result))
        return nil
    end

    log("Placement success:", tostring(result.success))
    if result.error then
        log("Placement error:", tostring(result.error))
    end
    if result.data then
        for k, v in pairs(result.data) do
            if k ~= "errors" then
                log("  " .. tostring(k) .. " =", tostring(v))
            end
        end
        if result.data.errors and #result.data.errors > 0 then
            log("  errors table has", tostring(#result.data.errors), "entries (skipped for brevity)")
        end
    end
    return result
end

-- === Benchmark 1: 50 принтеров ===
local result50 = runPlacement("50 printers", 50)
local bounds = getBoundsFromResult(result50)
local stats50
if result50 and result50.success then
    stats50 = measureIncome("50 printers", bounds, 120)
else
    log("Aborting benchmark because 50-printer placement failed")
    copyLog()
    return
end

-- === Benchmark 2: все принтеры ===
local totalTools = countBackpackPrinters()
log("Printer tools currently in backpack:", tostring(totalTools))

-- Высокий max_total, чтобы команда разложила всё, что влезет.
local resultAll = runPlacement("all printers", 500)
local statsAll
if resultAll and resultAll.success then
    bounds = getBoundsFromResult(resultAll)
    statsAll = measureIncome("all printers", bounds, 120)
else
    log("All-printer placement failed, second measurement skipped")
end

-- === Summary ===
log("\n========== SUMMARY ==========")
if stats50 then
    log("50 printers income / 2 min:", tostring(stats50.income))
end
if statsAll then
    log("all printers income / 2 min:", tostring(statsAll.income))
end
if stats50 and statsAll then
    log("delta (all - 50):", tostring(statsAll.income - stats50.income))
end
log("========== END ==========")

copyLog()
