# Task 6 Brief: Сцена лобби + автозагрузки + главная сцена (ассемблинг, ПОСЛЕДНЯЯ задача)

Проект VibeFPS (Godot 4.7.2 stable, GDScript, Jolt). Рабочий каталог: `E:\projects\VibeFPS`.
Фаза 3 «Лобби», финальная сборка. Готово: SaveSystem (T1), Автомат (T2), GameState (T3), ShopPoint/DoorPoint/`_try_interact` (T4), смерть→лобби + очки (T5). Твоя задача — собрать сцену лобби, зарегистрировать автозагрузки и сделать лобби главной сценой.

**Contract (обязательно):**
- НЕ коммитить; никаких субагентов; проверки — только `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 <фильтр>` (Godot headless; напрямую godot не запускать).
- В `project.godot` есть НЕзакоммиченная правка владельца: удалены §1A-ключи (`run/max_fps`, `window/vsync/vsync_mode`, `scaling_3d/scale`) вместе с их комментариями. НЕ возвращай их и не трогай эти строки — добавляешь ТОЛЬКО автозагрузки и меняешь `run/main_scene`.
- Полный отчёт: `C:\Users\serhio\.opencode\plan\sdd\2026-10-10-vibefps-phase3-lobby\task-6-report.md`; финальное сообщение — короткий статус.
- Кириллица в файлах — UTF-8 (норма).

## Files
- Create: `lobby.tscn`
- Modify: `project.godot` (`[autoload]` GameState+SaveSystem; `run/main_scene` → uid lobby)
- Modify: `tests/smoke.gd` (+секция загрузки `lobby.tscn`)
- ВОЗМОЖНО (см. «Интеграционный риск»): `tests/progression.gd`, `tests/interact.gd`, `tests/enemies.gd`

## Потребляемые интерфейсы (читай файлы)
- `player.tscn` (инстанс игрока), `scripts/shop_point.gd` (`weapon_id`, слой/маска/группа задаёт скрипт), `scripts/door_point.gd` (`location_id`), `scripts/range_target.gd` + `scripts/hurtbox.gd` (мишени; `zone`).
- `scripts/game_state.gd` (class_name GameState), `scripts/save_system.gd` (class_name SaveSystem) — регистрируются как автозагрузки.
- `range.tscn` — образец геометрии/света/мишеней (НЕ менять `range.tscn` и `range_scene.gd`).
- Слои: 1 — мир/игрок, 4 — мишени, 6 `interactable`. Action `interact` (E) уже есть.

## Step 1: Создать `lobby.tscn`
По образцу `range.tscn` (без NavigationRegion3D и без врага; `lobby.gd` НЕ нужен — навмеша нет):
- `Lobby` (Node3D): `WorldEnvironment` (sky, как в range.tscn), `DirectionalLight3D` (тени), `Floor` StaticBody3D слой 1 (комната ~20×12, верхняя грань `y = 0`), 2-3 стены;
- `Player` — инстанс `player.tscn` на спавне `(0, 0, 0)`;
- `ShopPoint` (`scripts/shop_point.gd`, `weapon_id = "auto"`) у стены;
- `DoorPoint` (`scripts/door_point.gd`, `location_id = "range"`) на дальней стене (дверь «Первая локация» — временно ведёт в `range.tscn`);
- Тест-стенд: 3 мишени по образцу `range.tscn` (StaticBody3D слой 4 + `Hurtbox` zone 0 + `range_target.gd`) на дистанциях 5/8/12 м от спавна.
- Заголовок сцены: `uid` (задай по образцу `auto.tscn` — `uid="uid://..."`, рукописный допустим, риск коллизии низкий) и `format=3`.

## Step 2: Зарегистрировать автозагрузки и сменить главную сцену
В `project.godot`:
```
[autoload]
GameState="*res://scripts/game_state.gd"
SaveSystem="*res://scripts/save_system.gd"
```
`run/main_scene` → uid файла `lobby.tscn` (из его заголовка).
После правки: `git diff project.godot` — убедиться, что §1A-строки владельца НЕ вернулись и не удалены, и что `--import` их не трогает (прогони `run_checks.ps1 weapon_data` и снова проверь diff).

## ⚠️ Интеграционный риск (решить в этой задаче): автозагрузки vs тестовые инстансы
Тесты Tasks 3-5 (`tests/progression.gd`, `tests/interact.gd`, `tests/enemies.gd`) создают СВОЙ `GameState`/`SaveSystem` и добавляют в `root`, а продакшн-код ищет состояние через `get_node_or_null("/root/GameState")`. После регистрации автозагрузок этот путь в тестах может резолвиться в АВТОЗАГРУЗКУ, а не в тестовый инстанс — тогда проверки разъедутся.
- СНАЧАЛА выясни ЭМПИРИЧЕСКИ, добавляет ли движок автозагрузки в режиме `--script` (прогони полный сьют после Step 2 и посмотри, сломался ли `progression`/`interact`/`enemies`).
- Если НЕ сломались (автозагрузок в `--script` нет) — ничего не правь, просто зафиксируй факт в отчёте.
- Если сломались — приведи затронутые тесты к robust-паттерну: «сначала взять существующий `/root/GameState` / `/root/SaveSystem`, если он есть, иначе создать и добавить; затем ЯВНО выставить тестовые `save_path` (тестовый файл) и `scene_changer` (fake) и сбросить поля». Либо, если проще и надёжнее, в начале теста удалить автозагрузку из root и добавить свой инстанс. Зафиксируй выбранное решение и изменённые строки в отчёте. НЕ меняй смысл проверок — только способ получения инстанса.

## Step 3: Расширить `tests/smoke.gd` секцией лобби
По образцу существующей секции `main.tscn`: `load("res://lobby.tscn")`, инстанс, `root.add_child`, `await physics_frame`; ассерты: корень есть; `Player` есть; пол на слое 1; `ShopPoint` в группе `"interactable"` и на слое 6; `DoorPoint` в группе и на слое 6; три мишени с хитбоксами `zone == 0`. Секцию `main.tscn` НЕ трогать.

## Step 4: Прогон
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 smoke` → PASS.
Run полный: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1` → `0 failed`. Ожидаемый список: smoke, movement, input_actions, input_gate, weapon_data, integrity, weapon, auto_weapon, projectile, enemies, waves (SKIP — файла нет, это Фаза 4), save, progression, interact.

## Step 5: Ручная проверка владельцем (НЕ субагентом)
Владелец запускает игру: лобби открывается, персонаж ходит, E у точки покупки при 0 очков не покупает; дверь ведёт в range.tscn (временный бой); убийство врага даёт 10 очков; смерть возвращает в лобби. Ты этого не делаешь — только напоминаешь в отчёте.

## TDD Evidence (в отчёте)
smoke-секция лобби: до создания `lobby.tscn` — FAIL (сцены нет), после — PASS. Изменения тестов под автозагрузки (если были) — с прогоном до/после.

## Инварианты проекта (не ломать)
- `range.tscn`/`range_scene.gd` не менять (навмеш/тир/враг).
- Слой 6 не добавлять в маску снарядов.
- Смена главной сцены не должна ломать существующие тесты (они грузят сцены явно — `smoke` про `main.tscn`, `enemies` про `range.tscn`).
- `user://save.json` не должен появляться от прогонов тестов (тесты используют свои файлы).