--[[
    San Diego Agent — Probe: list all remotes and find placement candidates
    ======================================================================
    Перебирает все RemoteEvent/RemoteFunction под ReplicatedStorage (рекурсивно)
    и выводит имена, содержащие Place/Drop/MoneyPrinter/Tool/Use/Activate.
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
    if writefile then pcall(function() writefile("remotes_list_log.txt", text) end) end
end

log("========== LIST ALL REMOTES ==========")

local remotes = {}
local function scan(parent, depth)
    if depth > 10 then return end
    for _, c in ipairs(parent:GetChildren()) do
        if c:IsA("RemoteEvent") or c:IsA("RemoteFunction") then
            table.insert(remotes, c)
        end
        scan(c, depth + 1)
    end
end
scan(ReplicatedStorage, 0)

log("Total remotes:", tostring(#remotes))

local keywords = {"Place", "place", "Drop", "drop", "MoneyPrinter", "Money", "Printer", "Tool", "tool", "Use", "use", "Activate", "activate", "Deploy", "deploy", "Spawn", "spawn"}
local candidates = {}

for _, remote in ipairs(remotes) do
    local name = remote.Name
    for _, kw in ipairs(keywords) do
        if name:lower():find(kw:lower()) then
            table.insert(candidates, remote)
            break
        end
    end
end

log("\nCandidates by name:")
for _, remote in ipairs(candidates) do
    log(remote.ClassName, "-", remote:GetFullName())
end

-- Also list remotes in MoneyPrinterService and similar services
log("\n--- MoneyPrinterService / related services ---")
for _, remote in ipairs(remotes) do
    if remote:GetFullName():lower():find("moneyprinter") or remote:GetFullName():lower():find("printer") then
        log(remote.ClassName, "-", remote:GetFullName())
    end
end

log("\n--- Full list of all remote paths (first 300) ---")
for i, remote in ipairs(remotes) do
    if i > 300 then
        log("... and", tostring(#remotes - 300), "more")
        break
    end
    log(i, remote.ClassName, remote:GetFullName())
end

log("\n========== END ==========")
copy()
