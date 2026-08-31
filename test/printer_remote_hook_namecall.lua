--[[
    San Diego Agent — Probe: hook __namecall during manual printer placement
    ======================================================================
    Хукает __namecall, чтобы поймать FireServer / InvokeServer.
    Просит вручную поставить принтер.
    
    ВАЖНО: этот хук радикальный — он перехватывает ВСЕ ':'-вызовы.
    В продакшене запрещён (см. AGENTS.md). Используй только для теста.
    После теста перезайди (rejoin), чтобы снять хуки.
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
    if writefile then pcall(function() writefile("printer_remote_hook_namecall_log.txt", text) end) end
end

local function safeToString(obj)
    local ok, res = pcall(function()
        if typeof(obj) == "Instance" then
            return obj.ClassName .. ":" .. obj.Name .. " (" .. obj:GetFullName() .. ")"
        elseif typeof(obj) == "CFrame" or typeof(obj) == "Vector3" or typeof(obj) == "Color3" then
            return tostring(obj)
        elseif type(obj) == "table" then
            local parts = {}
            for k, v in pairs(obj) do
                table.insert(parts, tostring(k) .. "=" .. safeToString(v))
            end
            return "{" .. table.concat(parts, ", ") .. "}"
        elseif type(obj) == "string" then
            return '"' .. obj .. '"'
        elseif type(obj) == "number" or type(obj) == "boolean" then
            return tostring(obj)
        elseif obj == nil then
            return "nil"
        else
            return typeof(obj) .. ":" .. tostring(obj)
        end
    end)
    return ok and res or "[ERR]"
end

log("========== HOOK __NAMECALL DURING MANUAL PLACE ==========")
log("Player:", player.Name)
log("Радикальный хук. Перезайди после теста.")
log("Возьми принтер в руки и поставь его. Ловлю 20 секунд.\n")

local namecallDetected = false

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    if method == "FireServer" or method == "InvokeServer" then
        if typeof(self) == "Instance" and (self:IsA("RemoteEvent") or self:IsA("RemoteFunction")) then
            local args = {...}
            local parts = {}
            for i, arg in ipairs(args) do
                parts[i] = safeToString(arg)
            end
            log("NAMECALL", self.ClassName .. "[\"" .. self.Name .. "\"]", method, table.concat(parts, " | "))
            local ok, fullName = pcall(function() return self:GetFullName() end)
            if ok then log("  path:", fullName) end
            namecallDetected = true
        end
    end
    return oldNamecall(self, ...)
end)

log("__namecall hooked")
log("Жду 20 секунд...")

for i = 1, 20 do
    task.wait(1)
    log("t+", tostring(i))
end

log("\n========== END ==========")
log("Detected namecall remotes:", namecallDetected and "YES" or "NO")
log("Перезайди, чтобы снять хуки.")
copy()
