--[[
    San Diego Agent — Find lost printers
    ===================================
    Ищет все объекты, похожие на Money Printer, во всей игре:
    - Workspace (модели, парт, Tool'ы)
    - Backpack игрока
    - Character игрока
    - ReplicatedStorage и другие сервисы
    Выводит имя, класс, полный путь, позицию и расстояние до игрока.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

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
    if writefile then pcall(function() writefile("find_lost_printers_log.txt", text) end) end
end

log("========== FIND LOST PRINTERS ==========")
log("Player:", player.Name)

local function getPlayerPos()
    local char = player.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    return hrp and hrp.Position
end

local playerPos = getPlayerPos()
log("Player pos:", tostring(playerPos))

local found = {}

local function record(obj, source)
    local pos
    if obj:IsA("BasePart") then
        pos = obj.Position
    elseif obj:IsA("Model") then
        local ok, pivotPos = pcall(function() return obj:GetPivot().Position end)
        if ok then pos = pivotPos end
    end
    local dist = pos and playerPos and (pos - playerPos).Magnitude or nil
    local id = obj:GetAttribute("MoneyPrinterId")
    table.insert(found, {
        obj = obj,
        source = source,
        path = obj:GetFullName(),
        class = obj.ClassName,
        pos = pos,
        dist = dist,
        id = id,
    })
end

local function scan(parent, source)
    for _, c in ipairs(parent:GetDescendants()) do
        local isPrinter = false
        pcall(function()
            if c.Name:lower():find("print") then isPrinter = true end
            if c:HasTag("MoneyPrinter") then isPrinter = true end
            if c:GetAttribute("MoneyPrinterId") then isPrinter = true end
        end)
        if isPrinter then
            record(c, source)
        end
    end
end

log("Scanning Workspace...")
scan(Workspace, "Workspace")
log("Scanning ReplicatedStorage...")
scan(ReplicatedStorage, "ReplicatedStorage")
log("Scanning player services...")
scan(player:FindFirstChild("Backpack") or player, "Backpack")
scan(player.Character or player, "Character")
scan(player:FindFirstChild("StarterGear") or player, "StarterGear")

-- Also scan Lighting and other common services
pcall(function() scan(game:GetService("Lighting"), "Lighting") end)
pcall(function() scan(game:GetService("ReplicatedFirst"), "ReplicatedFirst") end)

log("Found", tostring(#found), "printer-like objects")

-- Sort by distance
if playerPos then
    table.sort(found, function(a, b)
        if not a.dist then return false end
        if not b.dist then return true end
        return a.dist < b.dist
    end)
end

for i, item in ipairs(found) do
    log("--- #" .. tostring(i) .. " ---")
    log("  Source:", item.source)
    log("  Path:", item.path)
    log("  Class:", item.class)
    if item.pos then
        log("  Pos:", tostring(item.pos), "Dist:", tostring(math.round((item.dist or 0) * 10) / 10))
    else
        log("  Pos: N/A")
    end
    if item.id then
        log("  MoneyPrinterId:", tostring(item.id))
    end
end

if #found == 0 then
    log("No printer objects found anywhere. They may have been destroyed or are in a service not scanned.")
else
    log("\nSummary: found", tostring(#found), "objects. Check if any are outside the apartment / below the floor.")
end

log("========== END ==========")
copy()
