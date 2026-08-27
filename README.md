# San Diego Agent

Агент для Roblox-игры **San Diego**. Отправляет статусы игровых аккаунтов на сервис и выполняет команды от сервера.

## Структура

```
san-diego/
├── final/
│   └── agent.lua           # готовый скрипт для запуска в executor'е
├── modules/
│   ├── http_client.lua     # HTTP-клиент с fallback'ами для разных executor'ов
│   ├── state_collector.lua # сбор состояния персонажа
│   ├── command_engine.lua  # движок команд + отмена
│   └── agent.lua           # основной цикл агента
├── test/
│   └── agent-standalone.lua # локальная отладка без raw-URL, всё в одном файле
├── docs/
│   └── agent-commands-api-prompt.md  # промт для другого агента (backend API)
└── README.md
```

## Быстрый старт

1. Создайте игру и tracked-поля:
   ```bash
   POST /games { "name": "San Diego", "slug": "san-diego" }
   POST /games/{id}/fields { "name": "location", "field_type": "string" }
   POST /games/{id}/fields { "name": "team", "field_type": "string" }
   ```

   Формат `POST /game/update`:
   ```json
   {
     "nickname": "PlayerOne",
     "game_slug": "san-diego",
     "server_id": "...",
     "place_id": "...",
     "status": "idle",
     "version": "1.0.0",
     "custom_data": {
       "position_x": 123.5,
       "position_y": 10.0,
       "position_z": -45.2,
       "team": "Civilian",
       "balance": 1250,
       "current_command": "move_x",
       "command_started_at": "2026-08-27T15:30:00+03:00"
     }
   }
   ```

2. Замените в `final/agent.lua` URL модулей на свои raw-ссылки с GitHub:
   ```lua
   moduleUrls = {
       http_client = "https://raw.githubusercontent.com/YOUR_USER/san-diego/main/modules/http_client.lua",
       ...
   }
   ```

3. При необходимости измените `balancePath` — путь к балансу в `LocalPlayer`.

4. Запустите `final/agent.lua` в Roblox-executor'е.

5. Для остановки выполните в консоли:
   ```lua
   getgenv().StopSanDiegoAgent = true
   ```

## Локальное тестирование

Для отладки без публикации в git и без реального сервера используйте `test/agent-standalone.lua`:

- Все модули встроены в один файл — не требует `readfile`/`require`.
- `useMockHttp = true` — HTTP-запросы печатаются в консоль, команды берутся из встроенной очереди.
- В очередь можно добавлять свои команды через `http:enqueueCommand("move_x", { value = 10 })`.

## Команды

Агент поддерживает:
- `get_commands` — вернуть список доступных команд и их параметры.
- `move_x`, `move_y`, `move_z` — сместить персонажа по оси. Опциональный параметр `speed` (1..10, по умолчанию 10) задаёт скорость: 10 — максимальная, 1 — в 10 раз медленнее.
- `turn` — повернуть персонажа на абсолютный угол (0..360). Опциональный параметр `speed` (1..10, по умолчанию 10) регулирует скорость: 10 — быстро, 1 — медленно.
- `turn_with_camera` — повернуть персонажа и камеру на абсолютный угол. Опциональный параметр `speed` (1..10, по умолчанию 10) регулирует скорость и время "передачи" управления камерой обратно игроку.
- `pause` — подождать N секунд.
- `respawn` — умереть и возродиться.
- `join_private_server` — перейти на приватный сервер по коду.
- `cancel` — отменить текущую команду.
- `afk` — управление AFK-режимом (`enabled`: `on`/`off`, `interval` в секундах). По умолчанию включён и раз в 10 минут выполняет незаметное движение, чтобы аккаунт не выкинуло из игры.

## API для команд

См. `docs/agent-commands-api-prompt.md` — промт для другого агента, который создаст backend-часть под команды.

## Конфигурация

Все настройки в начале `final/agent.lua`:
- `baseUrl` — URL существующего сервиса.
- `gameSlug` — идентификатор игры (`san-diego`).
- `statusInterval` — интервал проверки изменений статуса в секундах (рекомендуется 5–10). `POST /game/update` отправляется только если данные изменились.
- `balancePath` — путь к балансу, например `"leaderstats.Cash"`.
- `useRemoteModules` — `true` для загрузки модулей по raw-URL, `false` для локального `require`.
- `afkEnabled` — `true` для включения периодического AFK-действия.
- `afkInterval` — интервал AFK-действия в секундах (по умолчанию 600).

## Правила работы с репозиторием

- Все изменения ведутся в одной ветке `main`.
- `final/` содержит только одобренные скрипты.
- `test/` — для черновиков и экспериментов (создайте при необходимости).
- Модули из `modules/` публикуются в git и подключаются через raw-URL.
- При добавлении новых команд или изменении API обязательно следовать `AGENTS.md`.
