# Краткий бриф для backend-агента: API команд San Diego

## Задача

Добавить к существующему сервису `http://195.161.68.193:5173/api` endpoint'ы для управления командами, которые выполняет внутриигровой Roblox-агент.

## Статус аккаунта

Агент отправляет `POST /game/update` каждые 5–10 секунд:

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

Tracked-поля для игры `san-diego`:
- `location` (string)
- `team` (string)

## Endpoint'ы команд

### `GET /commands/next`

Long-poll. Query-параметры:
- `nickname` (обязательно)
- `game_slug` (обязательно)
- `last_id` (опционально) — ID предыдущей команды
- `last_status` (опционально) — финальный статус предыдущей команды

Поведение:
- Держать соединение до появления команды (таймаут 25–55 сек).
- Если есть `pending`-команда для этого `nickname` + `game_slug` — перевести в `in_progress` и вернуть (`200`).
- Если есть `in_progress`-команда — вернуть её, чтобы агент мог продолжить после реконнекта.
- Если `last_id` + `last_status` переданы — обновить предыдущую команду.
- Если команд нет — `204 No Content`.

### `POST /commands/{id}/status`

Тело:
```json
{
  "status": "in_progress" | "completed" | "error" | "cancelled",
  "message": "optional"
}
```

### `POST /commands/{id}/result`

Тело — произвольный JSON с результатом выполнения.

## Поддерживаемые команды

- `get_commands` — без параметров, возвращает список доступных команд.
- `move_x`, `move_y`, `move_z` — параметр `value` (number, -7000..7000).
- `pause` — параметр `duration` (number, 0..86400).
- `respawn` — без параметров.
- `join_private_server` — параметр `code` (string, 1..64).
- `cancel` — без параметров, отменяет текущую команду.
- `turn` — параметр `degrees` (integer, 0..360). Плавно поворачивает персонажа на абсолютный угол.
- `turn_with_camera` — параметр `degrees` (integer, 0..360). Поворачивает персонажа и камеру.

## Жизненный цикл команды

1. Агент получает команду через `GET /commands/next`.
2. Агент отправляет `POST /commands/{id}/status` со статусом `in_progress`.
3. Агент выполняет команду.
4. Агент отправляет `POST /commands/{id}/result`.
5. Агент отправляет `POST /commands/{id}/status` со статусом `completed` или `error`.

## Отмена

Команда `cancel`:
1. Прерывает текущую команду.
2. Текущая команда получает статус `cancelled`.
3. Сама команда `cancel` получает статус `completed`.

## Требования

- Одна команда в работе у одного аккаунта одновременно.
- Атомарная выдача `pending`-команд.
- Сохранение истории/результатов команд.
- OpenAPI/Swagger-документация.
- Стек и структура — как у существующего сервиса.
