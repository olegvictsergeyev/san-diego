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
  "status": "online",
  "balance": 1250,
  "version": "0.1.0"
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
- `location` (`string`) — координаты.
- `team` (`string`) — команда/роль.

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

## Endpoint'ы

### 1. Long-poll следующей команды

```
GET /commands/next?nickname={nickname}
```

Поведение:
- Передаётся **только** `nickname`.
- Сервер возвращает одну команду для данного nickname/place или пустой ответ при таймауте.
- `game_slug`, `last_id`, `last_status` не передаются.

Ответы:
- `200 OK` + тело команды — есть команда.
- `204 No Content` — нет команд.
- `400 Bad Request` — отсутствует `nickname`.

### 2. Обновление статуса команды

```
POST /commands/{id}/status
```

Тело:
```json
{
  "status": "in_progress" | "completed" | "error" | "cancelled",
  "message": "optional human-readable message"
}
```

### 3. Отправка результата выполнения

```
POST /commands/{id}/result
```

Тело:
```json
{
  "result": "JSON-строка или текстовое описание результата",
  "status": "completed" | "error"
}
```

Правила:
- `result` — всегда строка.
- Для `get_commands` `result` должен быть JSON-строкой, которая декодируется в объект `{ commands: [...] }`.
- Без обёртки `{ success, data }`.

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
      "name": "respawn",
      "params": {}
    },
    {
      "name": "turn",
      "params": {
        "degrees": { "type": "number", "min": 0, "max": 360 }
      }
    },
    {
      "name": "turn_with_camera",
      "params": {
        "degrees": { "type": "number", "min": 0, "max": 360 }
      }
    },
    {
      "name": "join_private_server",
      "params": {
        "code": { "type": "string", "min": 1, "max": 64 }
      }
    }
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

## Порядок взаимодействия

1. Агент при старте отправляет `POST /game/update` с `place_id`, `server_id`, `version`.
2. Сервер при необходимости создаёт команду `get_commands`.
3. Агент получает `get_commands` и отвечает JSON-строкой со списком команд.
4. Сервер отправляет обычные команды через `GET /commands/next`.
5. Агент выполняет команду и отправляет `POST /commands/{id}/result`.
6. При необходимости агент обновляет статус через `POST /commands/{id}/status`.

## Логика отмены

- Отмена реализована как отдельная команда `cancel`.
- Сервер создаёт команду `cancel`.
- Агент прерывает выполнение текущей команды, отправляет статус `cancelled` для текущей, и завершает команду `cancel`.

## Требования к реализации

1. Использовать тот же стек, что и существующий сервис.
2. Сохранить совместимость с `POST /game/update`.
3. Добавить схемы/миграции для сущностей `Command` и `Job`.
4. Предоставить OpenAPI/Swagger-документацию для новых endpoint'ов.
5. Обеспечить атомарность выдачи команды: одну `pending` команду может забрать только один аккаунт.
6. Реализовать long-poll с разумным таймаутом (25–55 секунд).
7. Идентифицировать персонажа по `nickname` + `place_id`.
8. Хранить `server_id` (`JobId`) как отдельную сущность, привязанную к `place_id`.
9. При изменении версии или появлении нового `place_id` запрашивать `get_commands`.
