# Правила работы над San Diego Agent

Этот документ описывает обязательные шаги при изменении и расширении агента.

## 1. При добавлении новой команды

1. **Обновить версию агента** в `modules/ui_panel.lua` (`CONFIG.version`).
   - `patch` (третья цифра) — исправления багов и мелкие доработки.
   - `minor` (вторая цифра) — новые команды или значимые функции.
   - `major` (первая цифра) — ломающие изменения API.

2. **Добавить команду в спецификацию** `modules/command_engine.lua`:
   - Имя, описание, параметры (`type`, `required`, `min`, `max`, `description`).
   - Для строк `min`/`max` означают длину.
   - Для чисел `min`/`max` означают диапазон.

3. **Реализовать обработчик** в `modules/command_engine.lua`:
   - Валидация входящего `payload`.
   - Возврат `{ success = true, data = {...} }` или `{ success = false, error = "..." }`.
   - Если требуется сложная логика UI/телепорта — вынести в отдельный модуль `modules/`.

4. **Если команда требует нового модуля**:
   - Создать `modules/<module_name>.lua`.
   - Подключить его в `modules/ui_panel.lua` через `loadModule`.
   - Добавить URL модуля в `CONFIG.moduleUrls` (для remote-запуска).
   - Передать инстанс в `CommandEngine.new(...)` или другой модуль при необходимости.
   - Подключить локально через `require(script.Parent:WaitForChild("<module_name>"))` с `pcall`-fallback внутри `command_engine.lua`, чтобы модуль работал и при локальном, и при remote-запуске.

5. **Проверить `get_commands`**:
   - Убедиться, что ответ содержит новую команду с правильными параметрами.
   - Служебная команда `get_commands` в ответе не должна присутствовать.

6. **Обновить документацию**:
   - `docs/agent-commands-api-prompt.md` — добавить команду в пример `get_commands`.
   - `docs/backend-agent-brief.md` — добавить команду в список поддерживаемых.
   - `README.md` — добавить команду в раздел "Команды".

7. **Переподключение после дисконнекта**:
   - При ошибке 277/278 (дисконнект) отправляется лог в `custom_data.disconnect`, сохраняется сервер с флагом `reconnectPending`, и, если включено, нажимается кнопка Reconnect.
   - При старте агента `ensureCorrectServer` выполняет телепорт/reconnect только если `reconnectPending == true`. Обычный заход в игру без дисконнекта не должен вызывать телепорт.
   - Если перед вылетом была команда `join_private_server` с кодом, агент сначала пытается зайти по этому коду. Если кода нет или reconnect по коду не удался — fallback на телепорт по `place_id`/`server_id`.

## 2. При изменении backend-контракта

1. Если backend меняет формат запроса/ответа, сначала согласовать изменения с backend-разработчиком.
2. Обновить `modules/http_client.lua`, `modules/agent.lua` и `docs/agent-commands-api-prompt.md`.
3. Long polling `/commands/next` использует query-параметры `nickname`, `long_poll=true`, `timeout=30`.
4. Результат команды отправляется через `POST /commands/{id}/result` с полями `result` (строка) и `status`.
5. Проверить обратную совместимость.

## 3. При изменении UI/UX

1. Не ломать существующий Orion UI без согласования.
2. Новые UI-элементы добавлять в `modules/ui_panel.lua`.
3. Любые эксперименты — в `test/ui-demos/`.

## 4. Общие правила

1. Избегать глобальных `__namecall`-хуков — они ломают внутренние системы Roblox и UI.
2. Клики по внутриигровым кнопкам выполнять через `getconnections` и `pcall`; сетевые обработчики запускать в `task.spawn`, чтобы не блокировать основной поток.
3. Не хранить секреты в коде.
4. Перед git-коммитом убедиться, что все изменённые файлы синхронизированы.
5. `POST /game/update` (статус аккаунта) отправляется:
   - при изменении данных из лога: позиции, баланса, статуса, текущей команды и т.д.;
   - при старте агента;
   - принудительно раз в 5 минут, если не было других отправок.
   Повторяющиеся идентичные статусы между этими событиями не отправляются.

## 5. Совместимость экзекьюторов

- **Целевые экзекьюторы:** Xeno и Delta. Всё производственное обязано работать на их общем подмножестве API.
- **Разработка и отладка** ведутся в **Isaeva** — его специфичные функции нельзя использовать в продакшен-коде без fallback.
- Проверенные на Isaeva возможности, которые безопасно использовать (если поддерживаются Xeno/Delta):
  - `loadstring`, `game:HttpGet`, `request`, `http_request`
  - `getconnections`, `fireclickdetector`, `firetouchinterest`
  - `setclipboard`, `gethui`
  - `queue_on_teleport` (глобальная)
  - `hookmetamethod`, `hookfunction`, `getrawmetatable`, `setreadonly`
  - файловые операции: `makefolder`, `writefile`, `readfile`, `listfiles`, `isfolder`, `isfile`, `delfile`, `delfolder`
  - `getgc`, `getinstances`, `getnilinstances`
  - `gethiddenproperty`, `sethiddenproperty`, `getsenv`, `getmenv`, `getreg`, `gettenv`
  - `checkcaller`, `islclosure`, `dumpstring`, `decompile`, `saveinstance`
  - `messagebox`, `rconsoleprint`/`rconsolewarn`/`rconsoleerr`, `consolecreate`/`consoledestroy`/`consoleprint`
  - `Drawing`, `WebSocket`, `crypt.base64encode`
- **Нельзя полагаться** на библиотеки-таблицы экзекьюторов (`syn`, `xeno`, `delta`, `issaeva`, `fluxus`, `hydrogen`, `codex`, `oxygen`, `krnl`) — в Isaeva они `nil`.
- Для пережития телепорта используем глобальный `queue_on_teleport`, чтобы перезапустить загрузчик `final/agent.lua`. Если `queue_on_teleport` недоступен — полагаться на `autoexec`.
- UI-элементы агента прятать в `gethui()` при наличии, иначе в `CoreGui`.
