--[[
    San Diego Agent — Probe: list all ClientModules by name
    ========================================================
    Выводит все ModuleScript в ReplicatedStorage.ClientModules,
    отмечая те, в имени которых есть Money / Printer / Place / Tool.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
    if writefile then pcall(function() writefile("client_modules_list.txt", text) end) end
end

log("========== CLIENT MODULES LIST ==========")

local root = ReplicatedStorage:FindFirstChild("ClientModules")
if not root then
    log("ERROR: ClientModules not found")
    copy()
    return
end

local keywords = { "money", "print", "place", "tool", "deploy", "drop", "world", "buyable", "item", "backpack" }
local interesting = {}

local function scan(parent, depth)
    if depth > 6 then return end
    for _, c in ipairs(parent:GetChildren()) do
        if c:IsA("ModuleScript") or c:IsA("LocalScript") or c:IsA("Script") then
            local nameLower = c.Name:lower()
            local isInteresting = false
            for _, kw in ipairs(keywords) do
                if nameLower:find(kw) then
                    isInteresting = true
                    break
                end
            end
            if isInteresting then
                table.insert(interesting, c)
                log("[INTERESTING]", c:GetFullName(), "Class:", c.ClassName, "Depth:", tostring(depth))
            else
                log("  ", c:GetFullName(), "Class:", c.ClassName)
            end
        end
        scan(c, depth + 1)
    end
end

scan(root, 0)

log("\n--- Interesting modules summary ---")
for _, c in ipairs(interesting) do
    log(c:GetFullName())
end

log("\n========== END ==========")
copy()
