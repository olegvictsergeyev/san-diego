# Промт для второго агента: API команд San Diego

## Контекст

Мы делаем агента для Roblox-игры **San Diego**, который:
1. Периодически отправляет статус игрового аккаунта на сервис через `POST /game/update`.
2. Получает и выполняет команды от сервера в режиме **long-polling**.
3. Умеет отменять текущую команду по отдельной команде `cancel`.
4. При запуске сразу отправляет статус и регистрирует набор поддерживаемых команд через `get_commands`.

Базовый URL существующего сервиса: `http://195.161.68.193:5173/api`.
Авторизация не требуется.

## Что нужно создать

Нужно добавить к существующему сервису набор endpoint'ов для управления командами.

## Формат статуса

`POST /game/update` принимает JSON:

```json
{
  "nickname": "PlayerOne",
  "game_slug": "san-diego",
  "server_id": "abc-123-uuid",
  "place_id": "123456789",
  "status": "online",
  "balance": 1250.50,
  "custom_data": {
    "location": "123.5, 10.0, -45.2",
    "team": "Civilian"
  }
}
```

Правила:
- `nickname`, `game_slug`, `server_id`, `place_id` — обязательны.
- `status` — опционально (`online`, `in_game`, `offline`).
- `balance` — число или строка, опционально.
- `custom_data` — опционально, содержит tracked-поля.

Tracked-поля, которые нужно создать для игры `san-diego`:
- `location` (`string`) — координаты или название зоны.
- `team` (`string`) — текущая команда/роль.

## Модель команды

```json
{
  "id": "uuid-string",
  "game_slug": "san-diego",
  "nickname": "PlayerOne",
  "name": "move_x",
  "payload": { "value": 10 },
  "status": "pending",
  "created_at": "2026-08-24T12:00:00Z",
  "updated_at": "2026-08-24T12:00:01Z",
  "result": null
}
```

Возможные статусы:
- `pending` — команда создана, ждёт исполнителя.
- `in_progress` — команду забрал аккаунт и выполняет.
- `completed` — команда выполнена успешно.
- `error` — при выполнении произошла ошибка.
- `cancelled` — команда отменена (явно или через команду `cancel`).

## Endpoint'ы

### 1. Long-poll следующей команды

```
GET /commands/next?nickname={nickname}&game_slug={game_slug}&last_id={last_id}&last_status={last_status}
```

Поведение:
- Сервер держит соединение открытым (keep-alive / long-poll) до появления новой команды.
- Если для данного `nickname` + `game_slug` есть команда в статусе `pending`, сервер сразу возвращает её и переводит в `in_progress`.
- Если есть команда в статусе `in_progress` для этого аккаунта (например, после реконнекта), сервер возвращает её, чтобы аккаунт мог продолжить выполнение.
- Если `last_id` и `last_status` переданы, сервер обновляет статус предыдущей команды перед выдачей новой.
- Если новых команд нет, соединение висит до таймаута (25–55 секунд), после чего возвращается `204 No Content`.
- При разрыве соединения клиент открывает новое.
- В один момент у одного аккаунта может быть только одна команда `in_progress`.

Ответы:
- `200 OK` + тело команды — есть команда.
- `204 No Content` — нет команд, таймаут long-poll.
- `400 Bad Request` — отсутствуют обязательные параметры.

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

Поведение:
- Меняет статус команды.
- Обновляет `updated_at`.
- `message` сохраняется для диагностики.

### 3. Отправка результата выполнения

```
POST /commands/{id}/result
```

Тело — произвольный JSON:
```json
{
  "success": true,
  "data": { "x": 150.5, "y": 10.0, "z": -45.2 },
  "message": "Moved successfully"
}
```

Поведение:
- Сохраняет результат команды.
- Не меняет статус автоматически (статус обновляется отдельным `POST /commands/{id}/status`).

## Порядок взаимодействия

1. Агент при старте отправляет `POST /game/update`.
2. Агент открывает `GET /commands/next`.
3. Получив команду, отправляет `POST /commands/{id}/status` со статусом `in_progress`.
4. Выполняет команду.
5. По завершении отправляет:
   - сначала `POST /commands/{id}/result` с результатом;
   - затем `POST /commands/{id}/status` со статусом `completed` или `error`.
6. Сразу открывает новый `GET /commands/next`, передавая `last_id` и `last_status`.

## Команды

Сервер должен позволять создавать команды с такими именами и payload'ами:

### `get_commands`

Без параметров. Возвращает спецификацию всех доступных команд.

Пример ответа:
```json
{
  "success": true,
  "commands": [
    {
      "name": "get_commands",
      "description": "Вернуть список доступных команд",
      "params": {}
    },
    {
      "name": "move_x",
      "description": "Сместить персонажа по оси X",
      "params": {
        "value": {
          "type": "number",
          "required": true,
          "min": -10000,
          "max": 10000,
          "description": "Смещение по оси X в студиях"
        }
      }
    },
    {
      "name": "move_y",
      "description": "Сместить персонажа по оси Y",
      "params": {
        "value": {
          "type": "number",
          "required": true,
          "min": -10000,
          "max": 10000,
          "description": "Смещение по оси Y в студиях"
        }
      }
    },
    {
      "name": "move_z",
      "description": "Сместить персонажа по оси Z",
      "params": {
        "value": {
          "type": "number",
          "required": true,
          "min": -10000,
          "max": 10000,
          "description": "Смещение по оси Z в студиях"
        }
      }
    },
    {
      "name": "pause",
      "description": "Подождать N секунд",
      "params": {
        "duration": {
          "type": "number",
          "required": true,
          "min": 0,
          "max": 300,
          "description": "Длительность паузы в секундах"
        }
      }
    },
    {
      "name": "cancel",
      "description": "Отменить текущую команду",
      "params": {}
    }
  ]
}
```

### `move_x`, `move_y`, `move_z`

Payload:
```json
{ "value": 10 }
```

Агент смещает персонажа по соответствующей оси на `value` студий.

### `pause`

Payload:
```json
{ "duration": 5 }
```

Агент ждёт `duration` секунд.

### `cancel`

Payload: пустой.

Агент прерывает выполнение текущей команды.

## Логика отмены

- Отмена реализована как отдельная команда `cancel`.
- Сервер создаёт команду `cancel` с `status = pending`.
- Когда агент забирает её через `/commands/next`:
  1. Прерывает выполнение текущей команды.
  2. Отправляет `POST /commands/{current_id}/status` со статусом `cancelled`.
  3. Отправляет `POST /commands/{cancel_id}/result` и `POST /commands/{cancel_id}/status` со статусом `completed`.

## Требования к реализации

1. Использовать тот же стек и структуру, что и существующий сервис.
2. Сохранить совместимость с `POST /game/update`.
3. Добавить схемы/миграции для новой сущности `Command`.
4. Предоставить OpenAPI/Swagger-документацию для новых endpoint'ов.
5. Обеспечить атомарность выдачи команды: одну `pending` команду может забрать только один аккаунт.
6. Реализовать long-poll с разумным таймаутом (25–55 секунд).
7. Поддерживать `last_id` + `last_status` для финализации предыдущей команды.
8. `game_slug` для San Diego: `san-diego`.
9. Персонаж идентифицируется по `nickname` + `game_slug`.
