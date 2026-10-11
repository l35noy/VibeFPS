# Task 4 Brief: Взаимодействие — ShopPoint, DoorPoint, `_try_interact` (трек A, после Task 3)

Проект VibeFPS (Godot 4.7.2 stable, GDScript, Jolt). Рабочий каталог: `E:\projects\VibeFPS`.
Фаза 3 «Лобби». Готово: SaveSystem (T1), Автомат (T2), GameState (T3 — интерфейс см. ниже). Твоя задача — механика взаимодействия: точки покупки/двери (слой 6 `interactable`, action `interact` = E уже в project.godot) и обработка E у игрока.

**Contract (обязательно):**
- НЕ коммитить; никаких субагентов; проверки — только `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 <фильтр>` (Godot headless; напрямую godot не запускать).
- В рабочем дереве НЕзакоммиченные чужие правки — НЕ откатывать, НЕ трогать: в т.ч. `player.gd` (владелец добавил перевод строки в конец) — работаешь ПОВЕРХ, `player.gd` — ТВОЙ ФАЙЛ НА ИЗМЕНЕНИЕ (только добавление, см. ниже).
- Полный отчёт: `C:\Users\serhio\.opencode\plan\sdd\2026-10-10-vibefps-phase3-lobby\task-4-report.md`; финальное сообщение — короткий статус.
- Кириллица в файлах — UTF-8 (норма); консоль PowerShell может моджибакетить — только отображение.

## Files
- Create: `scripts/shop_point.gd`
- Create: `scripts/door_point.gd`
- Modify: `scripts/player.gd` — добавить `_try_interact()` и маршрут из `_unhandled_input` (существующий код движения/огня НЕ менять)
- Create: `tests/interact.gd`
- Modify: `tools/run_checks.ps1` (`$Tests` += `"interact"` после `"progression"`)

## Потребляемые интерфейсы (Task 3 — читать scripts/game_state.gd)
`GameState`: `buy_weapon(id: String) -> bool`, `enter_location(id: String) -> bool`, `equip_weapon(id: String) -> bool`, `award_points(amount)`, `points`, `owned_weapons`, `equipped_weapon_id`, `unlocked_locations`. Получение: `get_node_or_null("/root/GameState")` — null-safe в тестах без автозагрузки.
`InputGate` (scripts/input_gate.gd) — `is_play_input_allowed(mouse_mode)`. В player.gd есть приватный `_mouse_mode_for_play_input()` (используется существующими обработчиками движения/огня — заимствовать тот же вызов).

## Производимые интерфейсы
- `script shop_point.gd`: `class_name ShopPoint`, `extends Area3D`.
  - `@export var weapon_id: String = "auto"`
  - `_ready()`: `collision_layer = 1 << 5` (слой 6), `collision_mask = 1 << 1` (игрок), `monitoring = true`, `add_to_group("interactable")`.
  - `func interact(player: Node) -> bool`: `var gs := get_node_or_null("/root/GameState") as GameState; if gs == null: return false; var ok := gs.buy_weapon(weapon_id); interacted.emit(ok); return ok`.
  - `signal interacted(ok: bool)`.
- `script door_point.gd`: `class_name DoorPoint`, `extends Area3D`.
  - `@export var location_id: String = "range"`; те же слой/маска/группа в `_ready()`.
  - `func interact(player: Node) -> bool`: `var gs := get_node_or_null("/root/GameState") as GameState; if gs == null: return false; return gs.enter_location(location_id)`.
- `player.gd`:
  - `const _INTERACT_RANGE := 3.5` (**R2 из ledger: 3.5, а не 2.5** — ревьюер и тест опираются на это значение).
  - `func nearest_interactable() -> Node`: минимум по `get_tree().get_nodes_in_group("interactable")`, фильтр `is_inside_tree()` и `global_position.distance_to(self.global_position) <= _INTERACT_RANGE`; нет → null. (Если у узла нет global_position — Area3D имеет; при отсутствии метода — пропустить.)
  - `func _try_interact() -> bool`: `var target := nearest_interactable(); if target == null or not target.has_method("interact"): return false; return bool(target.call("interact", self))`.
  - В `_unhandled_input(event)`: ДОБАВИТЬ ветку `if event.is_action_pressed("interact") and InputGate.is_play_input_allowed(_mouse_mode_for_play_input()): _try_interact(); get_viewport().set_input_as_handled()` — по образцу существующих обработчиков (строки ~146-166). Существующие ветки (move/jump/sprint/fire/pause) не трогать.

## Step 1: Написать падающий тест `tests/interact.gd` + добавить `"interact"` в `$Tests` (TDD RED)

Мир по образцу `tests/weapon.gd::_new_world()` (пол + игрок; координаты точные):
- в `_initialize()`: тестовый сейв `_save` (SaveSystem, `user://interact_test.json`, clear в конце), `_gs = GameState.new()` + `_gs.scene_changer = _fake_changer` (складывает в `changed_to: PackedStringArray`), `_save` ПЕРЕД `_gs` в root;
- `_shop = ShopPoint.new(); _shop.weapon_id = "auto"; _shop.position = Vector3(0, 0, -3); root.add_child(_shop)` — ДО добавления игрока;
- `_door = DoorPoint.new(); _door.location_id = "range"; _door.position = Vector3(0, 0, -6); root.add_child(_door)`;
- `_player` — инстанс из `player.tscn` с пробой `_PlayerProbe` (переопределяет `_mouse_mode_for_play_input` → CAPTURED), позиция `(0, 0, 0)`.
Проверки:
- `_shop.interact(_player)` при `points == 0` → false, `owned_weapons == ["pistol"]`, `points == 0`;
- `_gs.award_points(300)`; `_shop.interact(_player)` → true; `equipped_weapon_id == "auto"`;
- `_door.interact(_player)` → true; `changed_to` содержит `"res://range.tscn"`;
- `_player.nearest_interactable()` при `_shop` на (0,0,-3): дистанция 3.0 ≤ 3.5 → `_shop` (**R2**);
- перенести `_shop.position = Vector3(0, 0, -10)` (дистанция 10 > 3.5) → `nearest_interactable() == null` (дверь на -6: 6.0 > 3.5 — тоже вне радиуса);
- гейт ввода: у пробы `set_gate_mouse_mode(MOUSE_MODE_VISIBLE)` → `Input.action_press("interact")` + `await physics_frame` → НИКАКОГО effects (покупка не сработала: `points` без изменений); вернуть CAPTURED → `Input.action_release("interact")`, нажать снова + кадр → эффект есть (покупка второй раз — экипировка: `equipped_weapon_id` остаётся "auto", `points` не упал ниже 0).
(Если полный ввод-маршрут через `Input.action_press` капризен в headless — покрыть гейт прямым вызовом `_try_interact()` при `MOUSE_MODE_VISIBLE`: вызов не должен ничего изменить. Зафиксируй в тесте подход комментарием.)

## Step 2: Прогнать `interact` — FAIL
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 interact` → FAIL (нет файлов).

## Step 3: Реализовать `shop_point.gd`, `door_point.gd`, `_try_interact` в `player.gd`
По «Производимые интерфейсы» дословно. `nearest_interactable()` — публичный (нужен тесту). `_unhandled_input` — только ДОБАВЛЕНИЕ ветки; существующие строки не менять; порядке веток — interact после остальных действий ввода (или до — без разницы; главное не ломать).

## Step 4: Прогнать `interact` — PASS
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 interact` → PASS. Затем полный сьют: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1` → 0 failed.

## TDD Evidence (в отчёте)
RED → GREEN → мутация (где осмысленна: например, временно убрать группу `add_to_group("interactable")` у ShopPoint → `_try_interact` не находит → красный → вернуть). Команды + выводы.

## Инварианты проекта (не ломать)
- Слой 6 в маску снарядов НЕ добавлять (`projectile` маска `1|3`).
- `interact` (E) гейтится InputGate: свободный курсор — взаимодействие выключено.
- Существующие тесты movement/weapon/enemies остаются зелёными без правок.