--[[
    San Diego Agent
    ===============
    Тонкий загрузчик для UI-модуля агента.
    Конфигурация теперь находится в modules/ui_panel.lua.

    Для остановки выполните в консоли executor'а:
        getgenv().StopSanDiegoAgent = true
]]

local UI_PANEL_URL = "https://raw.githubusercontent.com/olegvictsergeyev/san-diego/main/modules/ui_panel.lua?nocache=" .. tostring(tick())

local function loadUiPanel()
    if script and typeof(script) == "Instance" and script.Parent then
        -- Локальный запуск: require из папки modules
        return require(script.Parent:WaitForChild("modules"):WaitForChild("ui_panel"))
    else
        -- Запуск через loadstring: загружаем модуль по raw-URL
        local source = game:HttpGet(UI_PANEL_URL)
        local fn, err = loadstring(source, "ui_panel")
        if not fn then
            error("failed to load ui_panel: " .. tostring(err))
        end
        return fn()
    end
end

local UIPanel = loadUiPanel()
print("[SanDiegoAgent][Loader] ui_panel loaded, version unknown until run")
UIPanel.run()
