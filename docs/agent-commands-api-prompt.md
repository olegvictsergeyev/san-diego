# Промт для второго агента: API команд San Diego (RBT)

## Контекст

Roblox-агент для игры **San Diego** отправляет статус и выполняет команды, полученные от сервера RBT.

Базовый URL: `http://195.161.68.193:5173/api`.
Авторизация не требуется.

## Формат статуса

`POST /game/update` принимает JSON:

```json
{
  "nickname": "PlayerOne",
  "place_id": "136020512003847",
  "server_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
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

Правила:
- `nickname` — обязателен.
- `place_id` — строка, `tostring(game.PlaceId)`.
- `server_id` — строка, `tostring(game.JobId)`. Если не передан, Job не создаётся.
- `status` — опционально (`online`, `in_game`, `offline`).
- `balance` — число или строка, опционально.
- `version` — строка версии ПО агента.
- `game_slug` больше не используется.
- `custom_data` — опционально, tracked-поля (например, `location`, `team`).

Tracked-поля для `san-diego`:
- `position_x`, `position_y`, `position_z` (`number`) — координаты персонажа.
- `team` (`string`) — команда/роль.
- `balance` (`number`) — баланс игрока.
- `current_command` (`string`) — имя выполняемой команды (если статус `in_progress` или `error`).
- `command_started_at` (`string`) — время взятия команды в работу в формате ISO 8601 с часовым поясом +03:00.

## Модель команды

```json
{
  "id": 42,
  "command_type": "move_x",
  "payload": "{\"value\": 10}",
  "status": "pending",
  "result": null,
  "created_at": "2026-08-24T12:00:00Z",
  "updated_at": "2026-08-24T12:00:01Z"
}
```

Возможные статусы:
- `pending` — команда создана, ждёт исполнителя.
- `in_progress` — команду забрал аккаунт и выполняет.
- `completed` — команда выполнена успешно.
- `error` — при выполнении произошла ошибка.
- `cancelled` — команда отменена.
- `declined` — команда зависла: агент не прислал результат в течение 5 минут.

## Endpoint'ы

### 1. Long-poll следующей команды

```
GET /commands/next?nickname={nickname}&long_poll=true&timeout=30
```

Поведение:
- Передаётся `nickname`, `long_poll=true` и `timeout` (секунды, 1..300).
- Сервер удерживает соединение до `timeout` секунд и возвращает одну команду, либо `null` при таймауте.
- После получения команды или таймаута агент сразу открывает новый long poll.
- `game_slug`, `last_id`, `last_status` не передаются.

Ответы:
- `200 OK` + тело команды — есть команда.
- `200 OK` + `null` — таймаут, команд нет.
- `400 Bad Request` — отсутствует `nickname`.

### 2. Отправка результата выполнения

```
POST /commands/{id}/result
```

Тело:
```json
{
  "result": "JSON-строка или текстовое описание результата",
  "status": "completed" | "error" | "cancelled"
}
```

Правила:
- `result` — строка, опционально.
- `status` — обязательно.
- Для `get_commands` `result` должен быть JSON-строкой, которая декодируется в объект `{ "commands": [...], "version": "1.11.0" }`.
- Без обёртки `{ success, data }`.
- **Агент сохраняет результат локально и повторяет отправку, пока сервер не примет его.** Сервер должен обрабатывать повторные `POST /commands/{id}/result` идемпотентно.

### 3. Альтернативное обновление статуса (опционально)

```
POST /commands/{id}/status
```

Тело:
```json
{
  "status": "in_progress" | "completed" | "error" | "cancelled" | "declined",
  "message": "optional human-readable message"
}
```

Используется, например, для отмены текущей команды.

## Формат ответа на `get_commands`

```json
{
  "commands": [
    {
      "name": "move_x",
      "params": {
        "value": { "type": "number", "min": -7000, "max": 7000 },
        "speed": { "type": "number", "min": 1, "max": 10 }
      }
    },
    {
      "name": "move_to",
      "params": {
        "x": { "type": "number", "min": -7000, "max": 7000 },
        "z": { "type": "number", "min": -7000, "max": 7000 },
        "speed": { "type": "number", "min": 1, "max": 10 }
      }
    },
    {
      "name": "respawn",
      "params": {}
    },
    {
      "name": "transfer_money_via_respawn",
      "params": {
        "identifier": { "type": "string", "min": 1, "max": 64 },
        "amount": { "type": "number", "min": 0, "max": 1000000000 },
        "max_attempts": { "type": "number", "min": 1, "max": 500 },
        "wait_seconds": { "type": "number", "min": 2, "max": 60 },
        "move_to_target": { "type": "string", "min": 2, "max": 3 }
      }
    },
    {
      "name": "respawn_for_money",
      "params": {
        "identifier": { "type": "string", "min": 1, "max": 64 },
        "amount": { "type": "number", "min": 0, "max": 1000000000 },
        "wait_seconds": { "type": "number", "min": 2, "max": 60 },
        "move_to_target": { "type": "string", "min": 2, "max": 3 }
      }
    },
    {
      "name": "jump",
      "params": {}
    },
    {
      "name": "hold_key",
      "params": {
        "key": { "type": "string", "min": 1, "max": 32 },
        "duration": { "type": "number", "min": 0, "max": 60000 }
      }
    },
    {
      "name": "turn",
      "params": {
        "degrees": { "type": "number", "min": 0, "max": 360 },
        "speed": { "type": "number", "min": 1, "max": 10 }
      }
    },
    {
      "name": "turn_with_camera",
      "params": {
        "degrees": { "type": "number", "min": 0, "max": 360 },
        "speed": { "type": "number", "min": 1, "max": 10 }
      }
    },
    {
      "name": "tilt_camera",
      "params": {
        "degrees": { "type": "number", "min": -80, "max": 80 },
        "speed": { "type": "number", "min": 1, "max": 10 }
      }
    },
    {
      "name": "join_private_server",
      "params": {
        "code": { "type": "string", "min": 1, "max": 64 }
      }
    },
    {
      "name": "afk",
      "params": {
        "enabled": { "type": "string", "min": 2, "max": 5 },
        "interval": { "type": "number", "min": 60, "max": 3600 }
      }
    },
    {
      "name": "set_action",
      "params": {
        "action": { "type": "string", "min": 0, "max": 32 },
        "except": { "type": "string", "min": 0, "max": 256 }
      }
    },
    {
      "name": "set_time",
      "params": {
        "name": { "type": "string", "min": 1, "max": 6 },
        "value": { "type": "number", "min": 0, "max": 9999999999 }
      }
    },
    {
      "name": "get_custom_field",
      "params": {
        "name": { "type": "string", "min": 1, "max": 6 }
      }
    },
    {
      "name": "get_server_players",
      "params": {}
    },
    {
      "name": "get_player",
      "params": {
        "identifier": { "type": "string", "min": 1, "max": 64 }
      }
    },
  ]
}
```

Правила:
- `commands` — массив.
- Каждая команда: `name` (строка) и `params` (объект).
- `params` для команды без параметров — пустой объект `{}`, не массив.
- `type`: `"number"` или `"string"`.
- Для чисел: `min` и `max`.
- Для строк: `min` и `max` (длина строки).
- Не передавать `label`, `step_percent`, `default` и другие UI-поля.
- Служебная команда `get_commands` в ответе не нужна.

## Надёжная доставка результатов

1. После получения команды агент сразу отправляет `POST /commands/{id}/status` со статусом `in_progress` (ack).
2. На протяжении выполнения длительных команд агент шлёт heartbeat `POST /commands/{id}/status` со статусом `in_progress` каждые 30 секунд.
3. По завершении агент сохраняет результат в локальный файл и сразу пытается отправить `POST /commands/{id}/result`.
4. Если отправка не удалась, агент повторяет попытку каждые 10 секунд из фонового потока.
5. При старте агента, перед началом нового long poll, все неотправленные результаты предыдущей сессии отправляются повторно.
6. У каждой команды есть внутренний таймаут выполнения (по умолчанию 300 секунд, для `pause`/`hold_key` — `duration + запас`, для `join_private_server` — 60 секунд). Если команда зависла, агент принудительно отменяет её и отправляет статус `error`.
7. Сервер должен принимать повторные `POST /commands/{id}/result` без побочных эффектов (идемпотентность), потому что сетевой сбой может произойти после того, как сервер уже записал результат, но до получения ответа агентом.

## Порядок взаимодействия

1. Агент при старте отправляет `POST /game/update` с `place_id`, `server_id`, `version`.
2. Агент доставляет результаты команд, оставшиеся от прошлой сессии.
3. Агент начинает long poll `GET /commands/next?nickname=...&long_poll=true&timeout=30`.
4. Сервер отдаёт команду в статусе `in_progress` с полем `taken_at`.
5. Агент подтверждает получение через `POST /commands/{id}/status` (`in_progress`) и при необходимости отправляет heartbeat каждые 30 секунд.
6. Агент выполняет команду и отправляет `POST /commands/{id}/result`.
7. При необходимости агент отправляет `POST /commands/{id}/status` (например, для отмены).
8. Если сервер не получит результат или heartbeat дольше внутреннего таймаута команды (по умолчанию 5 минут), команду можно считать зависшей и переводить в `declined`.

## Логика отмены

- Отмена реализована как отдельная команда `cancel`.
- Сервер создаёт команду `cancel`.
- Агент прерывает выполнение текущей команды, отправляет статус `cancelled` для текущей, и завершает команду `cancel`.

## Требования к реализации

1. Использовать long polling вместо коротких запросов.
2. Отправлять `nickname` в каждом запросе `GET /commands/next`.
3. Принимать `POST /commands/{id}/result` и `POST /commands/{id}/status` идемпотентно (агент может повторять запросы при сетевых сбоях).
4. Отправлять heartbeat `POST /game/update` при старте, изменениях и раз в 5 минут.
