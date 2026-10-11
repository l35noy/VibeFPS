# Task 4 Report: Взаимодействие — ShopPoint, DoorPoint, `_try_interact` (трек A)

**Дата:** 2026-10-10
**Статус:** DONE

## What was implemented

- **`scripts/shop_point.gd`** (new): `class_name ShopPoint`, `extends Area3D`.
  - `signal interacted(ok: bool)`, `@export var weapon_id: String = "auto"`.
  - `_ready()`: `collision_layer = 1 << 5` (слой 6), `collision_mask = 1 << 1` (игрок),
    `monitoring = true`, `add_to_group("interactable")`.
  - `interact(player: Node) -> bool`: null-safe `get_node_or_null("/root/GameState")`,
    `gs.buy_weapon(weapon_id)`, `interacted.emit(ok)`. Параметр `player` не используется —
    помечен `@warning_ignore("unused_parameter")` (сигнатура дословно по брифингу).
- **`scripts/door_point.gd`** (new): `class_name DoorPoint`, `extends Area3D`.
  - `@export var location_id: String = "range"`; те же слой/маска/группа.
  - `interact(player: Node) -> bool`: `gs.enter_location(location_id)` через scene_changer.
- **`scripts/player.gd`** (только добавления, diff-проверен):
  - `const _INTERACT_RANGE := 3.5` (**R2 из ledger — 3.5, не 2.5**; комментарий фиксирует требование).
  - `func nearest_interactable() -> Node` (публичный): минимум по `get_nodes_in_group("interactable")`,
    фильтры `node is Node3D` и `is_inside_tree()`, дистанция ≤ `_INTERACT_RANGE`; иначе `null`.
  - `func _try_interact() -> bool`: `target.has_method("interact")` guard, `bool(target.call("interact", self))`.
  - В `_unhandled_input` ДОБАВЛЕНА ветка
    `elif event.is_action_pressed("interact") and InputGate.is_play_input_allowed(_mouse_mode_for_play_input()): _try_interact(); get_viewport().set_input_as_handled()`.
    Существующие ветки (move/jump/sprint/fire/pause) не тронуты; владельческая правка
    (перевод строки в конце файла) сохранилась.
- **`tests/interact.gd`** (new): миры по брифингу (SaveSystem на `user://interact_test.json`,
  `GameState` с именем `GameState` для `/root/GameState`, fake scene changer, пол, shop на `(0,0,-3)`,
  door на `(0,0,-6)`, игрок из `player.tscn` с `_PlayerProbe` на `(0,0,0)`). 39 проверок:
  контракты классов (class_name, extends, экспорты-String, слой/маска/monitoring/группа),
  покупка (отказ при 0 очков → award 300 → покупка + экипировка), дверь (changed_to содержит
  `res://range.tscn`), радиус (shop на 3.0 найден / shop на 10 и door на 6 — null, **R2**),
  гейт ввода (свободный курсор — нажатие E без эффектов; захват — нажатие даёт эффект: экипировка без списания).
- **`tools/run_checks.ps1`**: `"interact"` добавлен в `$Tests` после `"progression"`.

## TDD Evidence

### RED
Команда: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 interact`
```
interact       FAIL  (exit code 1)
    SCRIPT ERROR: Parse Error: Could not find type "ShopPoint" in the current scope.
    SCRIPT ERROR: Parse Error: Could not find type "DoorPoint" in the current scope.
    ...
RESULT: 0 passed, 1 failed, 0 skipped
```
(классы отсутствуют — тест не парсится).

### GREEN
После реализации трёх скриптов:
```
interact       PASS
RESULT: 1 passed, 0 failed, 0 skipped
```

### Мутация
Убрал `add_to_group("interactable")` из `ShopPoint._ready()`:
```
interact       FAIL
      [FAIL] ShopPoint joins the interactable group
      [FAIL] the shop at 3.0 m is found (the range is 3.5, not 2.5) (got null)
      [FAIL] the same press reaches the shop once the cursor is captured (got 0 signals)
RESULT: 0 passed, 3 failed, 0 skipped
```
Вернул строку → `interact PASS`.

### Полный сьют (один раз в конце)
```
smoke PASS, movement PASS, input_actions PASS, input_gate PASS, weapon_data PASS,
integrity PASS, weapon PASS, auto_weapon PASS, projectile PASS, enemies PASS,
waves [SKIP] (tests\waves.gd not present), save PASS, progression PASS, interact PASS
RESULT: 13 passed, 0 failed, 1 skipped
```
(`waves` — существующий pre-existing skip: файла нет.)

## Files changed

- `scripts/shop_point.gd` (new) + `scripts/shop_point.gd.uid` (generated)
- `scripts/door_point.gd` (new) + `scripts/door_point.gd.uid` (generated)
- `scripts/player.gd` (modified — только добавления)
- `tests/interact.gd` (new) + `tests/interact.gd.uid` (generated)
- `tools/run_checks.ps1` (modified — `$Tests` += `"interact"`)

Не коммитил; чужие неправки не трогал.

## Self-review findings / Concerns

1. **Порядок гейт-проверки vs проверка радиуса.** Бриф перечисляет проверку гейта ПОСЛЕ
   переноса shop на `(0,0,-10)`; без возврата shop на место гейт-проверка была бы пустой
   (цели в радиусе нет). Вернул `_shop.position = (0,0,-3)` перед гейт-проверкой — в отчёте
   зафиксировано комментарием в тесте.
2. **`InputEventAction` дедуплицируется.** Прямой `Input.parse_input_event(InputEventAction)`
   для второго нажатия той же уже «зажатой» action не доходит до `_unhandled_input`
   (первый `InputEventAction` подтверждён инструментальным DEBUG как неработающий второй press,
   дал 0 сигналов). Тест использует честный маршрут: key event (keycode+physical, как в movement.gd)
   + `Input.flush_buffered_events()` (синхронная доставка, паттерн движения из `_test_queued_jump_...`)
   + release между нажатиями. Это аппаратный/инжекционный артефакт, а не дефект `player.gd`;
   реальная клавиатура шлёт один press. Фолбэк из брифа (прямой `_try_interact()`) не понадобился.
3. **`_INTERACT_RANGE=3.5` проверяется поведенчески**: shop на дистанции 3.0 находится, door на 6.0 — нет.
4. **Warnings**: у `interact(player: Node)` параметр не используется — `@warning_ignore("unused_parameter")`,
   сигнатура «дословно» по брифингу сохранена.
5. **YAGNI**: тест проверяет только поведение + контракты, которые будут нужны lobby.tscn
   (class_name/сигнал/экспорты/слой/группа) — тот же паттерн, что и `tests/weapon.gd::_test_contracts()`.
   Лишний `_action_event` помощник удалён перед финальным прогоном.
6. **Вывод без шума**: никаких DEBUG-принтов не осталось (grep подтвердил).