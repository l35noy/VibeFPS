# VibeFPS — Фаза 3: Лобби, очки, покупки, сохранение — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Исполнители НЕ коммитят: `git add`/`commit` делает только владелец.

**Goal:** Сделать лобби — сердце игры: зона отдыха с полным здоровьем, точкой покупки/экипировки оружия, мини-тиром, дверью-порталом во временный бой (`range.tscn`); смерть возвращает в лобби; очки начисляются за убийства; покупки, экипировка и очки переживают перезапуск через автосохранение.

**Architecture:** Лобби — отдельная сцена (`lobby.tscn`), становится главной (`run/main_scene`). Глобальное состояние — автозагрузки `GameState` (очки, купленное оружие, экипировка, открытые локации, **единственный владелец смены сцен**) и `SaveSystem` (`user://save.json`). Оружие параметризуется `WeaponData`, второй тип (автомат) — новый `.tres` + сцена на базе пистолета; авто-огонь удержанием уже реализован в `pistol.gd`. Взаимодействие — слой 6 `interactable`, действие `interact` (E) уже объявлено в `project.godot`. Всё, что проверяемо headless, проверяется headless; тест, не имеющий автозагрузки, сам инстанцирует синглтон в `root`.

**Tech Stack:** Godot 4.7.2 stable (`E:\Godot\Godot_v4.7.2-stable_win64.exe`), GDScript, Jolt Physics, PowerShell. Проверки — только `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 <filter>`.

**Spec:** `C:\Users\serhio\.opencode\plan\2026-10-07-vibefps-foundation-design.md` (§6.1 автозагрузки, §7.4/§7.5 очки, §9.1 лобби, §9.6 смерть, §9.7 прогрессия, §9.8 оружие, таблица фаз §9: **Фаза 3 = лобби**). Решения владельца 2026-10-10: автомат (второе оружие), мини-тир в лобби, дверь → `range.tscn` как временный бой, числа по спеке + временные стоимости.

## Global Constraints

- Темп физики: `physics/common/physics_ticks_per_second=120`, Jolt. Снаряд Area3D-детект дискретный: при 70 м/с и 120 Гц пролетает ~0.58 м/тик — хитбоксы не тоньше 0.5 м (правило проекта).
- Переходы между сценами ТОЛЬКО через `GameState.enter_location(id)` / `GameState.return_to_lobby(reason)`. Запрещён прямой `change_scene_to_file` в игровых сценах (спека §6.1).
- Снаряд при попадании в `Hurtbox` вызывает `apply_damage(damage)` → `damage_taken(amount * damage_multiplier)` — хитбокс не хранит здоровье.
- Гейт ввода — `InputGate.is_play_input_allowed(mouse_mode)`: ввод игрока разрешён только при `MOUSE_MODE_CAPTURED`. Свободный курсор гасит движение, обзор, прыжок, огонь И взаимодействие.
- Ввод: `interact` = E уже в `project.godot` (проверен `tests/input_actions.gd`), слой 6 объявлен `interactable`, в коде никем не используется.
- Коммиты — только владелец. Разрешено «модифицировать» файлы задач, но НЕ `docs/superpowers/**` и `sdd/**` (история).
- Игровые числа — ВРЕМЕННЫЕ по умолчанию (как баланс 2026-10-10): подтверждаются при первой настоящей локации (Фаза 4), помечаются в отчётах как временные.
- Существующие сьюты должны остаться зелёными, кроме осознанных регрессий, объявленных в задачах (контракт «смерть → лобби» меняет секции респавна в `tests/enemies.gd`).

## Review Focus

- **Смерть без автозагрузки**: тест инстанцирует `player.gd` без `/root/GameState` — поведение должно быть «старый респавн на месте», а не падение (fallback обязателен). Пинается в Task 5.
- **Повреждённый/отсутствующий save.json**: `SaveSystem.load()` возвращает дефолтный словарь и не бросает; `save()` при недоступном файле возвращает `false`. Пинается в Task 1.
- **Повторная покупка уже купленного оружия**: не списывает очки повторно, а только экипирует. Пинается в Task 3.
- **Покупка без средств / экипировка некупленного**: отклоняется с `false`, состояние не меняется. Пинается в Task 3.
- **Дверь в локацию до её открытия**: `enter_location` на закрытую локацию — `false`, смена сцены не вызывается. Пинается в Task 3.
- **Смена сцены в headless**: `change_scene_to_file` не тестируется напрямую — GameState тестируется через подменяемый `scene_changer: Callable` (паттерн probe проекта). Пинается в Task 3.
- **Взаимодействие (E) только при захваченном курсоре**: `_try_interact` в `player.gd` гейтится `InputGate`, как движение/огонь. Пинается в Task 4.

## File Structure (карта владения файлами)

| Файл | Ответственность | Задача |
|---|---|---|
| `scripts/save_system.gd` (новый) | автозагрузка: `user://save.json`, словарь `Dictionary`, повреждённый файл | 1 |
| `tests/save.gd` (новый) | save/load/повреждённый файл/изоляция пути | 1 |
| `scripts/weapon_data.gd` | + `price: int` (стоимость покупки; 0 = стартовое бесплатное) | 2 |
| `tests/weapon_data.gd` | + пин `price` пистолета = 0 | 2 |
| `data/weapons/auto.tres` (новый) | `WeaponData` автомата (урон 15, 300 RPM, магазин 36, reload 1.6, 70 м/с, радиус 0.06, жизнь 3.0, жёлтый, price 300) | 2 |
| `auto.tscn` (новый) | оружейная сцена автомата (структура `pistol.tscn`, свой цвет корпуса) | 2 |
| `scripts/projectile.gd` | + экспорты `radius` / `color` (след снаряда из данных оружия) | 2 |
| `scripts/pistol.gd` | `_instantiate_projectile()` передаёт `projectile_radius`/`projectile_color` в снаряд | 2 |
| `tests/auto_weapon.gd` (новый) | автомат: магазин/темп/урон/цвет/price; снаряд-след из данных | 2 |
| `tools/run_checks.ps1` | `$Tests` += `"auto_weapon"` | 2 |
| `scripts/game_state.gd` (новый) | автозагрузка: очки, owned/equipped оружие, unlocked локации, `enter_location`/`return_to_lobby`, автосейв | 3 |
| `tests/progression.gd` (новый) | очки, покупка, экипировка, открытие локаций, автосейв через SaveSystem | 3 |
| `scripts/shop_point.gd` (новый) | точка покупки/экипировки: Area3D слой 6, группа `"interactable"`, `interact(player) -> bool` | 4 |
| `scripts/door_point.gd` (новый) | дверь-портал: Area3D слой 6, группа `"interactable"`, `interact(player) -> bool` | 4 |
| `scripts/player.gd` | `_try_interact()`: ближайший интерактив в радиусе, `interact` (E) | 4 |
| `tests/interact.gd` (новый) | взаимодействие: точка в радиусе/вне, гейт ввода, вызов `interact` | 4 |
| `scripts/player.gd` | смерть → `GameState.return_to_lobby('death')` (fallback: респавн) | 5 |
| `scripts/enemy_contact.gd` | смерть врага → `GameState.award_points(10)` (fallback: без начисления) | 5 |
| `tests/enemies.gd` | регрессия: секции респавна игрока под новый контракт; начисление очков за убийство | 5 |
| `lobby.tscn` (новый) | сцена лобби: пол/свет/стены, Player, ShopPoint, DoorPoint, мини-тир (3 мишени) | 6 |
| `project.godot` | `[autoload]` GameState + SaveSystem; `run/main_scene` → uid `lobby.tscn` | 6 |
| `tests/smoke.gd` | + загрузка `lobby.tscn`: узлы/проводка | 6 |
| `CHECKLIST.md` | обновляется Lead-ом ПО ФАКТУ после задач (не в этой задаче) | — |

**Параллелизм:** Task 1 (трек B «сохранение») и Task 2 (трек A «арсенал») независимы — разные файлы, разрешён параллельный запуск двумя субагентами. Task 3 — после Task 1 (интерфейс `SaveSystem`). Task 4 — после Task 3 (`GameState` API). Task 5 — после Task 3 и Task 4 (обе правят `player.gd` — последовательно). Task 6 — последняя, собирает сцену и включает автозагрузки; до неё `GameState`/`SaveSystem` в `project.godot` НЕ объявлены, тесты инстанцируют их вручную.

---

## Task 1: SaveSystem — автозагрузка сохранения (трек B)

**Files:**
- Create: `scripts/save_system.gd`
- Create: `tests/save.gd`
- Modify: `tools/run_checks.ps1` — нет (имена `save` уже в `$Tests`)

**Interfaces:**
- Consumes: ничего.
- Produces: `SaveSystem extends Node`:
  - `@export var save_path: String = "user://save.json"`
  - `func save(payload: Dictionary) -> bool`
  - `func load_state() -> Dictionary`
  - `func clear_save() -> void`
  - `func has_save() -> bool`

- [ ] **Step 1: Написать падающий тест `tests/save.gd`**

Каркас по образцу проекта: `extends SceneTree`, `_initialize()`, `_check(ok, label, detail)`, итог `quit(1 if _failures.size() > 0 else 0)` (образец: `tests/smoke.gd:14-57`).

```gdscript
const _TMP_PATH := "user://save_test.json"
# Перед тестом: FileAccess.delete_absolute / DirAccess.remove_absolute(_TMP_PATH) — чистая отправная точка.
# 1) has_save() == false на старте
# 2) save({ "points": 42, "equipped": "auto" }) == true; has_save() == true
# 3) load_state() == { "points": 42, "equipped": "auto" } (полный круг)
# 4) clear_save(); has_save() == false
# 5) load_state() на отсутствующем файле == {} (не крашится)
# 6) ПОВРЕЖДЁННЫЙ файл: записать в _TMP_PATH строку "{ not valid json"; load_state() == {} и тест жив
# 7) save() при невозможности записи (путь на «директорию») == false
```

- [ ] **Step 2: Прогнать, убедиться что падает**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 save`
Expected: `FAIL` — `FATAL: ...` в `_initialize` (нет файла/скрипта) либо `[FAIL]`-маркеры.

- [ ] **Step 3: Реализовать `scripts/save_system.gd`**

`class_name SaveSystem`, `extends Node`. JSON: `JSON.stringify` / `JSON.parse_string` (в Godot 4 возвращает `null` при ошибке — `null` трактуем как `{}`). Запись через `FileAccess.open(save_path, FileAccess.WRITE)`; неудача → `false`. Проверять успех открытия и записи. `_init()` НЕ трогает диск; полного жёсткого пути из `user://` в тестах достаточно.

- [ ] **Step 4: Прогнать, убедиться что зелёный**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 save`
Expected: `RESULT: ... 0 failed` и exit 0.

- [ ] **Step 5: Мутация для доказательства «повреждённый файл не роняет»**

Временно убрать ветку обработки ошибки парсинга в `load_state()`, прогнать, вернуть. Expected: тест 6 краснеет; после возврата — снова зелёный. Записать оба прогона в отчёт.

---

## Task 2: Автомат + след снаряда из данных (трек A, параллельно Task 1)

**Files:**
- Modify: `scripts/weapon_data.gd` (+`price`)
- Modify: `tests/weapon_data.gd` (+пин `price = 0` у пистолета)
- Create: `data/weapons/auto.tres`
- Create: `auto.tscn`
- Modify: `scripts/projectile.gd` (+`radius`/`color`)
- Modify: `scripts/pistol.gd` (передача radius/color в снаряд)
- Create: `tests/auto_weapon.gd`
- Modify: `tools/run_checks.ps1` (`$Tests` += `"auto_weapon"`)

**Interfaces:**
- Consumes: `WeaponData` (существующие поля: `damage`, `rounds_per_minute`, `magazine_size`, `reload_time`, `projectile_speed`, `projectile_radius`, `projectile_lifetime`, `projectile_color`, `seconds_between_shots()`, `is_valid()`), `Pistol` (`data`, `projectile_scene`, `_instantiate_projectile()`), `Projectile` (`launch(direction)`, `speed`/`damage`/`lifetime` поля).
- Produces: `WeaponData.price: int = 0`; `Projectile.radius: float = 0.08`, `Projectile.color: Color = Color(0.15, 0.15, 0.15)` (след использует их); `auto.tscn` — сцена `Auto` (root `Node3D`, скрипт `pistol.gd`, `data = auto.tres`, `projectile_scene = res://projectile.tscn`, корпус другого цвета); `data/weapons/auto.tres` значения из Global Constants (временные).

- [ ] **Step 1: Добавить `price` в `WeaponData` и пин в `tests/weapon_data.gd`**

В `weapon_data.gd` после `display_name`: `@export var price: int = 0  # Очки за покупку; 0 = стартовое бесплатное (pistol)`.
В `tests/weapon_data.gd` — ассерт `loaded_tres.price == 0` для `pistol.tres`.

- [ ] **Step 2: Прогнать `weapon_data` — зелёный (падать нечему: поле с дефолтом)**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 weapon_data`
Expected: PASS (дефолт не ломает существующие пины).

- [ ] **Step 3: Создать `data/weapons/auto.tres`**

Формат как `pistol.tres` (скопировать, поменять значения):
`display_name="Auto"`, `damage=15.0`, `rounds_per_minute=300.0`, `magazine_size=36`, `reload_time=1.6`, `projectile_speed=70.0`, `projectile_radius=0.06`, `projectile_lifetime=3.0`, `projectile_color=Color(0.95, 0.75, 0.15)`, `price=300`.
Числа ВРЕМЕННЫЕ (пометить комментарием `; временный баланс владельца 2026-10-10`).

- [ ] **Step 4: Создать `auto.tscn`**

Скопировать структуру `pistol.tscn` (корень Node3D + `Frame`/`Grip`/`FrontSight`/`Muzzle` Marker3D `(0,0,-0.18)`), скрипт `pistol.gd`, `data = auto.tres`, `projectile_scene = res://projectile.tscn`; материалы корпуса — контрастные (`StandardMaterial3D` тёмно-синий корпус, жёлтая рамка), `fire_rate_source` НЕ задан (фолбэк на камеру — как у пистолета).

- [ ] **Step 5: `Projectile.radius` / `Projectile.color` + передача из `pistol.gd`**

В `projectile.gd`: `@export var radius: float = 0.08`, `@export var color: Color = Color(0.15, 0.15, 0.15)`; `_setup_trail()` использует `radius` (вместо литерала 0.08) и `color` (вместо литерала материала).
В `pistol.gd::_instantiate_projectile()` после установки `bullet.speed/damage/lifetime` добавить: если `projectile is Projectile` — `bullet.radius = data.projectile_radius`, `bullet.color = data.projectile_color` (по образцу строк 291-295).

- [ ] **Step 6: Написать `tests/auto_weapon.gd` и добавить в `$Tests`**

Каркас как `tests/weapon.gd` (`_PistolProbe` с `gate_mouse_mode`, `_Log`, `_new_pistol_from_scene` — заимствовать паттерн). Проверки:
- загрузка `auto.tres`: `is_valid()`, `seconds_between_shots()` ≈ 0.2, `magazine_size == 36`, `damage == 15.0`, `price == 300`;
- `auto.tscn` инстанцируется, `Muzzle` существует, `data == auto.tres`;
- выстрел сцены: после `Input.action_press("fire")` (после взведения — освобождение кнопки в начале) `fired` один раз;
- на интервале 0.2 с снаряд стартует из `Muzzle` и летит с `speed == 70.0` (проба `combined` как в weapon.gd);
- снаряд, выпущенный автоматом, несёт `radius == 0.06` и `color == auto.tres.projectile_color` (достать инстанс снаряда из мира; у `Projectile` поля читаются).
В `tools/run_checks.ps1` в `$Tests` после `"weapon"` добавить `"auto_weapon"`.

- [ ] **Step 7: Прогнать `auto_weapon` и полный локальный прогон**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 auto_weapon`
Expected: PASS.
Затем полный: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1`
Expected: 0 failed (старые сьюты не задеты: дефолты полей).

---

## Task 3: GameState + tests/progression.gd (трек A, после Task 1)

**Files:**
- Create: `scripts/game_state.gd`
- Create: `tests/progression.gd`

**Interfaces:**
- Consumes: `SaveSystem.save(payload)/load_state()/clear_save()` (Task 1); `WeaponData.price` (Task 2); `load("res://data/weapons/<id>.tres")`.
- Produces: `GameState extends Node`:
  - `const POINTS_PER_KILL := 10`, `POINTS_PER_WAVE := 50`, `POINTS_PER_CLEAR := 500`
  - `var points: int = 0`
  - `var owned_weapons: PackedStringArray = ["pistol"]`
  - `var equipped_weapon_id: String = "pistol"`
  - `var unlocked_locations: PackedStringArray = ["range"]`
  - `var scene_changer: Callable` — подменяемый в тестах; по умолчанию `get_tree().change_scene_to_file`
  - `func weapon_price(id: String) -> int` (из `WeaponData.price`, отсутствие/битый файл → 0)
  - `func award_points(amount: int) -> void` (отрицательный amount игнорируется)
  - `func can_afford(cost: int) -> bool`
  - `func buy_weapon(id: String) -> bool` — купленное: только экипирует (без списания); не хватает очков: `false`
  - `func equip_weapon(id: String) -> bool` — только из `owned_weapons`
  - `func enter_location(id: String) -> bool` — только из `unlocked_locations`; вызывает `scene_changer`
  - `func return_to_lobby(reason: String) -> void` — загружает `lobby.tscn`
  - `func _persist() -> Dictionary` / `func _restore(saved: Dictionary) -> void` — контракт словаря для SaveSystem
  - после каждого изменения (award/buy/equip) — автосейв через `/root/SaveSystem` если существует (null-safe)

- [ ] **Step 1: Написать падающий `tests/progression.gd`**

Каркас по образцу; в `_initialize()` вручную создать и добавить в `root`: `_save = SaveSystem.new(); _save.save_path = "user://progression_test.json"; root.add_child(_save)`; затем `_gs = GameState.new(); _gs.scene_changer = _fake_changer; root.add_child(_gs)`; в конце `_save.clear_save()`. `_fake_changer` — Callable, складывающая аргументы в `var changed_to: PackedStringArray` (смена сцены НЕ выполняется — голова headless).
Проверки:
- старт: `points == 0`, `owned == ["pistol"]`, `equipped == "pistol"`, `unlocked == ["range"]`;
- `award_points(10)` → 10; `award_points(-5)` → 10 (игнор);
- `can_afford(300)` → false; после `award_points(300)` → true;
- `buy_weapon("auto")`: цена 300 из `WeaponData`, списание (0), `owned` содержит `"auto"`, `equipped == "auto"`;
- повторный `buy_weapon("auto")` при 0 очков → `true` (экипировка бесплатно), очки не ушли в минус;
- `buy_weapon("nope")` (нет файла .tres, price 0) → false;
- `equip_weapon("pistol")` → true; `equip_weapon("auto")` → true; `equip_weapon("nope")` → false;
- `enter_location("range")` → true и `changed_to == ["res://range.tscn"]`;
- `enter_location("secret")` → false, `changed_to` не изменился;
- `return_to_lobby("death")` → `changed_to == ["res://lobby.tscn"]`;
- автосейв: после `award_points(50)` словарь `_save.load_state()` содержит `points == 50` и `equipped` (круг через диск).

- [ ] **Step 2: Прогнать `progression` — FAIL (нет файлов/скрипта)**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 progression`
Expected: FAIL.

- [ ] **Step 3: Реализовать `scripts/game_state.gd`**

`class_name GameState`, `extends Node`. `_ready()`: восстановление из `SaveSystem` при наличии (`_restore(load_state())`), только для полей, присутствующих в словаре. `scene_changer` по умолчанию — `Callable(get_tree(), "change_scene_to_file")` с присваиванием в `_init()`. Словарь `_persist()`: `{"points": points, "owned_weapons": [...], "equipped_weapon_id": ..., "unlocked_locations": [...]}`. Подписи — из Interfaces. Меню приобретения читает цену через `weapon_price(id)`.

- [ ] **Step 4: Прогнать `progression` — PASS**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 progression`
Expected: PASS.

- [ ] **Step 5: Мутация «забыть автосейв»**

Временно убрать вызов автосейва из `award_points`, прогнать, вернуть. Expected: ассерт «круг через диск» краснеет → возврат → зелёный. Записать в отчёт.

---

## Task 4: Взаимодействие — ShopPoint, DoorPoint, `_try_interact` (трек A, после Task 3)

**Files:**
- Create: `scripts/shop_point.gd`
- Create: `scripts/door_point.gd`
- Modify: `scripts/player.gd` (добавить `_try_interact()` и вызов из `_unhandled_input` на `interact`; гейт ввода по `InputGate`)
- Create: `tests/interact.gd`
- Modify: `tools/run_checks.ps1` (`$Tests` += `"interact"`)

**Interfaces:**
- Consumes: `GameState` (Task 3), `InputGate`, действие `interact`, слой 6.
- Produces:
  - `ShopPoint extends Area3D`: `@export var weapon_id: String = "auto"`; `_ready()`: `collision_layer = 1 << 5` (слой 6), `collision_mask = 1 << 1` (игрок), `monitoring = true`, `add_to_group("interactable")`; `interact(player: Node) -> bool`: через `/root/GameState` (null-safe: `false`) — `buy_weapon(weapon_id)`; сигнал `interacted(ok: bool)`.
  - `DoorPoint extends Area3D`: `@export var location_id: String = "range"`; слои/группа как у ShopPoint; `interact(player: Node) -> bool`: `GameState.enter_location(location_id)` (null-safe: `false`).
  - `player.gd::_try_interact() -> bool`: ближайший узел группы `"interactable"` в радиусе `_INTERACT_RANGE := 2.5` от `global_position`, у которого `has_method("interact")`; вызов; вызывается из `_unhandled_input` при `event.is_action_pressed("interact")` И `InputGate.is_play_input_allowed(_mouse_mode_for_play_input())`.
  - Публичные геттеры для тестов: у `player.gd` — `func nearest_interactable() -> Node` (используется `_try_interact` и тестом).

- [ ] **Step 1: Написать падающий `tests/interact.gd` + добавить в `$Tests`**

Мир по образцу `tests/weapon.gd::_new_world()`; компоненты:
- `_gs = GameState.new()` + `_save` (как в Task 3) добавлены в `root`;
- `ShopPoint` (цена 300, очков 0) на `(0,0,-3)`, `DoorPoint` на `(0,0,-6)`;
- `Player` из `player.tscn` с пробой `_PlayerProbe` (переопределяет `_mouse_mode_for_play_input` → CAPTURED) на `(0,0,0)`.
Проверки:
- `shop.interact(player)` при 0 очков → `false`, `owned == ["pistol"]`, `_gs.points == 0`;
- `_gs.award_points(300)`; `shop.interact(player)` → `true`, `equipped == "auto"`;
- `door.interact(player)` → `true` и `changed_to` получил `res://range.tscn` (scene_changer подменён);
- `player.nearest_interactable()` на дистанции 3.0 до shop → shop; после переноса shop на `(0,0,-10)` (вне 2.5) → `null`;
- прямой вызов `player._try_interact()` при зажатой клавише-заглушке не нужен: проверяется приватный маршрут через `Input.action_press("interact")` + ожидание кадра, с пробой гейта: при `gate_mouse_mode = MOUSE_MODE_VISIBLE` вызов `_try_interact` ничего не делает (`collision` прекондишен: гейт).

- [ ] **Step 2: Прогнать `interact` — FAIL**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 interact`
Expected: FAIL.

- [ ] **Step 3: Реализовать `shop_point.gd`, `door_point.gd`, `_try_interact`**

Как в Interfaces. `nearest_interactable()` — итерация `get_tree().get_nodes_in_group("interactable")`, фильтр `is_inside_tree()` и `global_position.distance_to(self.global_position) <= _INTERACT_RANGE`; при равенстве — любой (порядок списка не контракт). `_unhandled_input` — по образцу существующих обработчиков (строки 146-166 player.gd), `interact`-ветка только при зажатом событии нажатия.

- [ ] **Step 4: Прогнать `interact` — PASS**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 interact`
Expected: PASS.

---

## Task 5: Смерть → лобби + очки за убийство (трек A, после Task 4)

**Files:**
- Modify: `scripts/player.gd` (`take_damage`: смерть → `return_to_lobby`, fallback на `_respawn(true)`)
- Modify: `scripts/enemy_contact.gd` (смерть врага → `GameState.award_points(POINTS_PER_KILL)`)
- Modify: `tests/enemies.gd` (РЕГРЕССИЯ: секции респавна игрока; новый ассерт начисления очков)
- Modify: `tests/interact.gd` — нет; автосейв круга уже в Task 3.

**Interfaces:**
- Consumes: `GameState.return_to_lobby(reason)`, `GameState.award_points(amount)`, `GameState.POINTS_PER_KILL`.
- Produces: контракт «смерть игрока → `GameState.return_to_lobby('death')`; при отсутствии `/root/GameState` (headless-тест без автозагрузки) — прежний респавн `_respawn(true)`»; «уничтоженный враг начисляет 10 очков через GameState, null-safe».

- [ ] **Step 1: Изменить контракт в `player.gd`**

В `take_damage` (текущее: `died.emit()` → `_respawn(true)`, строки ~104-107): после `died.emit()`:
```gdscript
var gs := get_node_or_null("/root/GameState") as GameState
if gs != null:
    gs.return_to_lobby("death")
else:
    _respawn(true)  # fallback: headless-проверки и сцены без автозагрузки
```
Комментарий — про контракт «смерть возвращает в лобби» (Фаза 3), fallback для тестов.

- [ ] **Step 2: Обновить регрессионные секции `tests/enemies.gd`**

Найти секции, проверяющие смерть игрока и «смерть лечит респавном» (≈ строки 290-410: «Здоровье игрока», включая мутацию `_respawn(false)`). Правки:
- тесты «смерть → `_respawn(true)`» переписываются: добавление в root пробного `GameState` (с подменённым `scene_changer`), смерть вызывает `return_to_lobby("death")` — проверить reason;
- поведение без GameState: смерть → респавн на месте (fallback) — сохранить прежние ассерты в ОТДЕЛЬНОЙ секции с прекондишеном «GameState в root нет»;
- «падение за карту не лечит» — контракт не менялся, не трогать.
Отчёт обязан перечислить изменённые строки файла.

- [ ] **Step 3: Начисление очков за убийство врага**

В `enemy_contact.gd` в обработчике смерти (обесцвечивание/`queue_free`): `var gs := get_node_or_null("/root/GameState"); if gs != null: gs.award_points(int(gs.POINTS_PER_KILL))`. nullptr-безопасно, поток: однократно (смерть строго один раз).
В `tests/enemies.gd` — секция «очки за убийство»: мир с врагом + игроком + `GameState` в root; убить врага (как в существующих секциях смерти врага, ≈ строки 580-640); `points == 10`.

- [ ] **Step 4: Прогнать `enemies` — PASS (с регрессией)**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 enemies`
Expected: PASS. Прогнать полный сьют — 0 failed.

---

## Task 6: Сцена лобби + автозагрузки + главная сцена (ассемблинг)

**Files:**
- Create: `lobby.tscn`
- Modify: `project.godot` (`[autoload]` GameState/SaveSystem; `run/main_scene` → uid lobby)
- Modify: `tests/smoke.gd` (секция загрузки `lobby.tscn`: узлы/проводка)
- NOTE: `GameState`/`SaveSystem` в `project.godot` появляются ТОЛЬКО здесь (после всех задач), чтобы ранние тесты не зависели от автозагрузки.

**Interfaces:**
- Consumes: `player.tscn`, `shop_point.gd`, `door_point.gd`, `range_target.gd` + `hurtbox.gd` (мишени), `scripts/game_state.gd`, `scripts/save_system.gd`, слои 1/2/6, action `interact`.
- Produces: `lobby.tscn` — сцена `lobby.gd` НЕ требуется (навмеш не нужен — врагов нет); структура:
  - `Lobby` Node3D: `WorldEnvironment` (sky, как `range.tscn`), `DirectionalLight3D` (тени), `Floor` StaticBody3D слой 1 (комната ~20×12), 2-3 стены, пол верхней гранью `y = 0`;
  - `Player` (инстанс `player.tscn`) на спавне `(0,0,0)`;
  - `ShopPoint` (`weapon_id = "auto"`) у стены; `DoorPoint` (`location_id = "range"`) на дальней стене; оба слой 6 (задаёт скрипт);
  - Тест-стенд: 3 мишени по образцу `range.tscn` (StaticBody3D слой 4 + `Hurtbox` zone 0 + `range_target.gd`) на дистанциях 5/8/12 м от спавна (DPS-проверка автомата и пистолета);

- [ ] **Step 1: Создать `lobby.tscn`**

По образцу `range.tscn` (без NavigationRegion3D и врага). Сверить слои: пол слой 1, мишени слой 4 (бит `1<<2` в tscn), хитбоксы задают слой в `hurtbox.gd::_ready()`.

- [ ] **Step 2: Добавить `[autoload]` и сменить главную сцену**

В `project.godot`:
```
[autoload]
GameState="*res://scripts/game_state.gd"
SaveSystem="*res://scripts/save_system.gd"
```
`run/main_scene` → `uid` файла `lobby.tscn` (генерация уида: через Godot-экспорт или зарегистрировать uid в `.uid`-файле сцены — конвенция репозитория: у сцен есть `.uid`-файлы). Убедиться, что `--import` (который делает `run_checks.ps1`) не вычищает ключи — после правки прогнать `weapon_data` и проверить `git diff project.godot`.

- [ ] **Step 3: Расширить `tests/smoke.gd` секцией лобби**

По образцу существующей секции main.tscn: `load("res://lobby.tscn")`, инстанс, `root.add_child`, `await physics_frame`; ассерты: корень есть, `Player` есть, пол на слое 1, `ShopPoint` в группе `"interactable"` и на слое 6, `DoorPoint` в группе и на слое 6, три мишени с хитбоксами `zone == 0`, `dir`. Секция main.tscn остаётся нетронутой.

- [ ] **Step 4: Прогнать `smoke` и полный сьют**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 smoke`
Expected: PASS.
Run: полный `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1`
Expected: `0 passed-вариант: RESULT: 0 failed`, exit 0. **Список тестов: smoke, movement, input_actions, input_gate, weapon_data, integrity, weapon, auto_weapon, projectile, enemies, waves (SKIP), save, progression, interact — 0 fails.**

- [ ] **Step 5: Ручная проверка владельцем (не субагентом)**

Запуск `E:\Godot\Godot_v4.7.2-stable_win64.exe --path .` — лобби открывается, персонаж ходит, E у точки покупки списывает 0 (нет очков), через `GameState`-отладку владелец подтверждает начисление за убийство в `range.tscn` (дверь), смерть возвращает в лобби. Ограничение честно фиксируется: headless-среда не даёт синтетический ввод/скриншоты — ручной круг на владельце.

---

## Инварианты (не ломать)

- Игрок никогда не выпадает из мира; респавн на точке старта при падении — без восстановления здоровья.
- Навмеш сцены запечён в рантайме и непуст (`range.tscn` — `range_scene.gd` не трогаем).
- «Враг доходит до игрока на расстояние касания» — данные/сцены врага не меняются (кроме начисления очков при смерти).
- В консоли движка нет errors/предупреждений при прогонах.
- Коллизии: `interactable` (слой 6) НЕ в маске снарядов (`projectile` маска `1|3` — не менять).

## Что НЕ входит в Фазу 3 (открыто/позже)

- Волны/спавн/босс/летающий враг — Фаза 4; `POINTS_PER_WAVE`/`POINTS_PER_CLEAR` — API готов, начисление — Фаза 4.
- Улучшения оружия и «прокачка» — Фаза 6/бэклог; HUD (счёт в углу, полоса, экраны) — Фаза 5.
- Выбор оружия в лобби из арсенала — пока только покупка/экипировка через точку (повторное нажатие на купленное = экипировка).
- `Sfx` (спека §6.1) — зонтик звука, Фаза 7A/6; синглтон не создаём (YAGNI).