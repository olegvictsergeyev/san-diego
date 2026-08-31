--[[
    San Diego Agent — Test: measure room perimeter by walking around
    ==================================================================
    Игрок обходит периметр комнаты (по углам или вдоль стен), скрипт записывает
    координаты и запоминает ограничивающий прямоугольник в getgenv().RoomPerimeter.
    Потом этот прямоугольник можно использовать для точной расстановки принтеров,
    не опираясь на позицию игрока.

    Как использовать:
    1. Встань в любой угол комнаты.
    2. Запусти скрипт.
    3. Иди вдоль стен комнаты (обходи периметр). Можно просто пройтись по всем
       углам: нижний левый -> нижний правый -> верхний правый -> верхний левый.
    4. Остановись. Скрипт сам поймёт, что ты перестал двигаться, и сохранит
       координаты.
    5. Скопируй координаты из лога / из getgenv().RoomPerimeter.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local logs = {}

local function log(...)
    local parts = {}
    for _, v in ipairs({ ... }) do table.insert(parts, tostring(v)) end
    local msg = "[" .. os.date("%H:%M:%S") .. "] " .. table.concat(parts, " ")
    table.insert(logs, msg)
    print(msg)
    warn(msg)
end

local function copy()
    local text = table.concat(logs, "\n")
    if setclipboard then pcall(function() setclipboard(text) end) end
    if writefile then pcall(function() writefile("measure_room_perimeter_log.txt", text) end) end
end

log("========== MEASURE ROOM PERIMETER ==========")
log("Player:", player.Name)

local function getCharacter()
    local char = player.Character
    if char then return char end
    return player.CharacterAdded:Wait()
end

local function getHrp()
    local char = getCharacter()
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local hrp = getHrp()
if not hrp then
    log("ERROR: HumanoidRootPart not found")
    copy()
    return
end

log("Instructions:")
log("  Walk around the room perimeter along the walls.")
log("  Stop moving when done. Script will auto-finish after 2 seconds of standing still.")
log("  Max recording time: 30 seconds.")
log("Starting in 1 second...")

task.wait(1)

local positions = {}
local startedAt = tick()
local lastMoveAt = tick()
local lastPos = hrp.Position
local stillThreshold = 0.2 -- studs per check
local stillDuration = 2.0 -- seconds
local maxDuration = 30.0

local connection
connection = RunService.RenderStepped:Connect(function()
    hrp = getHrp()
    if not hrp then return end

    local pos = hrp.Position
    table.insert(positions, Vector3.new(pos.X, 0, pos.Z))

    local dxz = Vector3.new(pos.X - lastPos.X, 0, pos.Z - lastPos.Z)
    local dist = dxz.Magnitude
    if dist > stillThreshold then
        lastMoveAt = tick()
    end
    lastPos = pos

    local elapsed = tick() - startedAt
    local stillFor = tick() - lastMoveAt

    if elapsed >= 1 and stillFor >= stillDuration then
        log("Detected stop after", tostring(math.round(elapsed * 10) / 10), "s")
        connection:Disconnect()
    elseif elapsed >= maxDuration then
        log("Max recording time reached")
        connection:Disconnect()
    end
end)

-- Wait until recording finishes
while connection.Connected do
    task.wait(0.1)
end

log("Recorded points:", tostring(#positions))
if #positions < 3 then
    log("ERROR: Not enough points. Walk around more.")
    copy()
    return
end

-- Compute axis-aligned bounding box
local minX, maxX = math.huge, -math.huge
local minZ, maxZ = math.huge, -math.huge
for _, p in ipairs(positions) do
    minX = math.min(minX, p.X)
    maxX = math.max(maxX, p.X)
    minZ = math.min(minZ, p.Z)
    maxZ = math.max(maxZ, p.Z)
end

local center2D = Vector3.new((minX + maxX) / 2, 0, (minZ + maxZ) / 2)
local size2D = Vector3.new(maxX - minX, 0, maxZ - minZ)

log("Bounding box:")
log("  minX=", tostring(math.round(minX * 100) / 100), "maxX=", tostring(math.round(maxX * 100) / 100))
log("  minZ=", tostring(math.round(minZ * 100) / 100), "maxZ=", tostring(math.round(maxZ * 100) / 100))
log("  sizeX=", tostring(math.round(size2D.X * 100) / 100), "sizeZ=", tostring(math.round(size2D.Z * 100) / 100))
log("  center=", tostring(math.round(center2D.X * 100) / 100), ",", tostring(math.round(center2D.Z * 100) / 100))

-- Find floor Y at center
local floorY = nil
local floorPart = nil
local params
pcall(function()
    local p = RaycastParams.new()
    p.FilterType = Enum.RaycastFilterType.Blacklist
    p.FilterDescendantsInstances = { getCharacter() }
    params = p
end)
local result
pcall(function()
    result = Workspace:Raycast(Vector3.new(center2D.X, hrp.Position.Y + 10, center2D.Z), Vector3.new(0, -100, 0), params)
end)
if result then
    floorPart = result.Instance
    floorY = result.Position.Y
    log("Floor Y at center:", tostring(math.round(floorY * 100) / 100), "part:", floorPart and floorPart.Name or "nil")
else
    floorY = hrp.Position.Y - 3
    log("WARNING: Raycast to floor failed, using fallback Y:", tostring(math.round(floorY * 100) / 100))
end

-- Store globally for placement scripts
local perimeter = {
    minX = minX,
    maxX = maxX,
    minZ = minZ,
    maxZ = maxZ,
    floorY = floorY,
    center = center2D,
    size = size2D,
}
if getgenv then
    getgenv().RoomPerimeter = perimeter
    log("Stored in getgenv().RoomPerimeter")
end

-- Draw corner markers
local function clearMarkers()
    for _, c in ipairs(Workspace:GetChildren()) do
        if c.Name == "RoomPerimeterMarker" then
            pcall(function() c:Destroy() end)
        end
    end
end
clearMarkers()

local cornerY = floorY and (floorY + 0.5) or (hrp.Position.Y - 2)
local corners = {
    Vector3.new(minX, cornerY, minZ),
    Vector3.new(maxX, cornerY, minZ),
    Vector3.new(maxX, cornerY, maxZ),
    Vector3.new(minX, cornerY, maxZ),
}

for i, pos in ipairs(corners) do
    local part = Instance.new("Part")
    part.Name = "RoomPerimeterMarker"
    part.Anchored = true
    part.CanCollide = false
    part.Size = Vector3.new(0.5, 4, 0.5)
    part.Position = pos
    part.Color = Color3.fromRGB(255, 0, 0)
    part.Material = Enum.Material.Neon
    part.Transparency = 0.5
    part.Parent = Workspace
end

-- Draw connecting lines between corners
for i = 1, 4 do
    local a = corners[i]
    local b = corners[i % 4 + 1]
    local mid = (a + b) / 2
    local diff = b - a
    local part = Instance.new("Part")
    part.Name = "RoomPerimeterMarker"
    part.Anchored = true
    part.CanCollide = false
    part.Color = Color3.fromRGB(255, 100, 100)
    part.Material = Enum.Material.Neon
    part.Transparency = 0.7
    part.CFrame = CFrame.lookAt(a, b)
    part.Size = Vector3.new(0.2, 0.2, diff.Magnitude)
    part.CFrame = CFrame.new(mid, b)
    part.Parent = Workspace
end

log("Red markers show measured perimeter corners.")
log("Use this table in placement scripts:")
log("  getgenv().RoomPerimeter =", "{ minX=", tostring(minX), "maxX=", tostring(maxX), "minZ=", tostring(minZ), "maxZ=", tostring(maxZ), "floorY=", tostring(floorY), "}")

log("========== END ==========")
copy()
