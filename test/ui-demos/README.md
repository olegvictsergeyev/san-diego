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

## Остальные библиотеки

| Файл | Библиотека | Статус |
|---|---|---|
| `mercury-demo.lua` | Mercury | URL и темы исправлены, требуется тест в executor'е |
| `linoria-demo.lua` | Linoria | Работает |
| `kavo-demo.lua` | Kavo | Переписан с учетом API, требуется тест в executor'е |
| `material-demo.lua` | Material Lua | Переписан с учетом API, требуется тест в executor'е |
| `orion-demo.lua` | Orion | Переписан с учетом API, требуется тест в executor'е |

## Запуск

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/olegvictsergeyev/san-diego/main/test/ui-demos/rayfield-demo.lua"))()
```

Или скопируй содержимое файла и вставь в executor.
