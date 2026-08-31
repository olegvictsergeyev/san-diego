--[[
    San Diego Agent — Test: simulate mouse click to place printer
    =============================================================
    Экипирует принтер и имитирует клик мышью разными способами:
    - VirtualUser:ClickButton1
    - mouse1click / mouse1press+release
    - UserInputService.InputBegan fire
    Проверяет, появится ли Model в MoneyPrinters.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")

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
    if writefile then pcall(function() writefile("printer_click_placement_test_log.txt", text) end) end
end

local function getPlayerPos()
    local char = player.Character or player.CharacterAdded:Wait()
    local hrp = char:FindFirstChild("HumanoidRootPart")
    return hrp and hrp.Position
end

local function findMoneyPrintersFolder()
    local playerPos = getPlayerPos()
    local folders = {}
    local seen = {}
    local function scan(parent, depth)
        if depth > 8 then return end
        for _, c in ipairs(parent:GetChildren()) do
            if c.Name == "MoneyPrinters" and not seen[c] and
               (c:IsA("Folder") or c:IsA("Model") or c:IsA("Configuration")) then
                seen[c] = true
                table.insert(folders, c)
            end
            if not c:IsA("BasePart") then scan(c, depth + 1) end
        end
    end
    scan(Workspace, 0)
    if #folders == 0 then return nil end
    local best = folders[1]
    local bestDist = math.huge
    for _, f in ipairs(folders) do
        local dist = math.huge
        for _, child in ipairs(f:GetChildren()) do
            local part = child:FindFirstChild("Printer_d") or child:FindFirstChild("Handle")
            if part and part:IsA("BasePart") then
                local d = (part.Position - playerPos).Magnitude
                if d < dist then dist = d end
            end
        end
        if dist < bestDist then
            bestDist = dist
            best = f
        end
    end
    return best
end

local function countPrinters(folder)
    local count = 0
    for _, c in ipairs(folder:GetChildren()) do
        if c.Name:lower():find("print") or c:HasTag("MoneyPrinter") then
            count += 1
        end
    end
    return count
end

log("========== PRINTER CLICK PLACEMENT TEST ==========")
log("Player:", player.Name)
log("Instructions: stand in apartment, look at floor where you want to place")
log("Make sure you have at least 1 Money Printer in backpack")

local folder = findMoneyPrintersFolder()
if not folder then
    log("ERROR: No MoneyPrinters folder found")
    copy()
    return
end
log("Target folder:", folder:GetFullName())

local backpack = player:FindFirstChild("Backpack")
local tool = nil
if backpack then
    for _, c in ipairs(backpack:GetChildren()) do
        if c:IsA("Tool") and c.Name:lower():find("print") then
            tool = c
            break
        end
    end
end

if not tool then
    log("ERROR: No Money Printer in backpack")
    copy()
    return
end
log("Tool found:", tool.Name)

local char = player.Character or player.CharacterAdded:Wait()
local humanoid = char:FindFirstChildOfClass("Humanoid")
if not humanoid then
    log("ERROR: No humanoid")
    copy()
    return
end

-- Check connections
log("\n--- Checking input/tool connections ---")
if getconnections then
    local ok, conns = pcall(function() return getconnections(UserInputService.InputBegan) end)
    if ok and conns then
        log("UserInputService.InputBegan connections:", tostring(#conns))
        for i, conn in ipairs(conns) do
            log("  ", tostring(i), tostring(conn.Function))
        end
    end
    ok, conns = pcall(function() return getconnections(UserInputService.InputEnded) end)
    if ok and conns then
        log("UserInputService.InputEnded connections:", tostring(#conns))
    end
end

local function tryClickMethod(name, action)
    log("\n--- Trying click method:", name, "---")

    -- Return tool to backpack
    if tool.Parent ~= backpack then
        pcall(function()
            humanoid:UnequipTools()
            tool.Parent = backpack
        end)
        task.wait(0.5)
    end

    local before = countPrinters(folder)
    log("  printers in folder before:", tostring(before))

    -- Equip
    local ok, err = pcall(function() humanoid:EquipTool(tool) end)
    if not ok then
        log("  equip failed:", tostring(err))
        return
    end
    task.wait(0.5)
    log("  tool parent:", tool.Parent and tool.Parent.Name or "nil")

    -- Log current mouse target
    local mouse = player:GetMouse()
    if mouse then
        log("  mouse target:", mouse.Target and mouse.Target:GetFullName() or "nil")
        log("  mouse hit:", tostring(mouse.Hit.Position))
    end

    -- Perform action
    local aok, aerr = pcall(action)
    if not aok then
        log("  action error:", tostring(aerr))
    end

    task.wait(3)
    local after = countPrinters(folder)
    log("  printers in folder after 3s:", tostring(after))

    if after > before then
        log("  *** METHOD WORKED! ***")
    else
        log("  method did not place printer")
    end

    -- Cleanup
    pcall(function()
        humanoid:UnequipTools()
        if tool.Parent ~= backpack then
            tool.Parent = backpack
        end
    end)
    task.wait(0.5)
end

-- Method 1: VirtualUser ClickButton1
tryClickMethod("VirtualUser:ClickButton1", function()
    local mouse = player:GetMouse()
    if mouse and mouse.Target then
        local cf = mouse.Hit
        log("  ClickButton1 at", tostring(cf.Position))
        VirtualUser:ClickButton1(cf.Position, mouse.Target)
    else
        log("  no mouse target")
    end
end)

-- Method 2: mouse1click
tryClickMethod("mouse1click()", function()
    if mouse1click then
        mouse1click()
    else
        log("  mouse1click not available")
    end
end)

-- Method 3: mouse1press + mouse1release
tryClickMethod("mouse1press + mouse1release", function()
    if mouse1press and mouse1release then
        mouse1press()
        task.wait(0.1)
        mouse1release()
    else
        log("  mouse1press not available")
    end
end)

-- Method 4: VirtualUser with mouse position
tryClickMethod("VirtualUser:MoveMouse + ClickButton1", function()
    local mouse = player:GetMouse()
    if mouse then
        local pos = mouse.Hit.Position
        local screenPos, onScreen = Workspace.CurrentCamera:WorldToScreenPoint(pos)
        if onScreen then
            log("  moving mouse to screen", tostring(screenPos))
            VirtualUser:MoveMouse(Vector2.new(screenPos.X, screenPos.Y))
            task.wait(0.2)
            VirtualUser:ClickButton1(pos, mouse.Target)
        else
            log("  target not on screen")
        end
    end
end)

-- Method 5: Fire InputBegan manually
tryClickMethod("UserInputService.InputBegan:Fire", function()
    local mouse = player:GetMouse()
    if UserInputService.InputBegan then
        local input = {}
        input.UserInputType = Enum.UserInputType.MouseButton1
        input.KeyCode = Enum.KeyCode.Unknown
        input.Position = mouse and mouse.Hit.Position or Vector3.new(0, 0, 0)
        UserInputService.InputBegan:Fire(input, false)
        task.wait(0.1)
        if UserInputService.InputEnded then
            UserInputService.InputEnded:Fire(input, false)
        end
    end
end)

log("\n========== END TEST ==========")
copy()
