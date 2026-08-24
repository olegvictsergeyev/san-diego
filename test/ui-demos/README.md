# UI Library Demos

Демонстрационные скрипты для разных Roblox UI библиотек.

Запусти любой файл в Roblox-executor'е, чтобы посмотреть визуал и доступные элементы.

## Rayfield

Rayfield не поддерживает смену темы на лету. Тема задаётся один раз при создании окна. Поэтому для каждой темы отдельный файл:

- `rayfield-demo.lua` — стандартная тема (Default) со всеми элементами.
- `rayfield-light.lua` — встроенная светлая тема.
- `rayfield-gold.lua` — кастомная золотая тема.
- `rayfield-ping.lua` — кастомная розовая тема.

Дополнительно:
- `rayfield-simple.lua` — минимальный рабочий пример.
- `rayfield-debug.lua` — пошаговое добавление элементов с `pcall`.
- `rayfield-theme-test.lua` — проверка, какие темы работают при создании окна.

## Остальные библиотеки

| Файл | Библиотека | Статус |
|---|---|---|
| `mercury-demo.lua` | Mercury | Требует отладки |
| `linoria-demo.lua` | Linoria | Работает |
| `kavo-demo.lua` | Kavo | Требует отладки |
| `material-demo.lua` | Material Lua | Требует отладки |
| `orion-demo.lua` | Orion | Требует отладки |

## Запуск

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/olegvictsergeyev/san-diego/main/test/ui-demos/rayfield-demo.lua"))()
```

Или скопируй содержимое файла и вставь в executor.
