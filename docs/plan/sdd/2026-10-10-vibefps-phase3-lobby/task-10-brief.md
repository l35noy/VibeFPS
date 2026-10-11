# Task 10: Инвентарь (клавиша I, кнопки+мышь) + смена оружия у игрока

**Status:** ready
**Date:** 2026-10-10
**Проект:** VibeFPS (Godot 4.7.2 stable, GDScript, Jolt)

## Решения владельца
- Инвентарь — **панель с кнопками, выбор МЫШЬЮ** (курсор на время инвентаря отпускается).
- **Смена оружия у игрока — да**: выбранное купленное оружие реально в руках, можно вернуться к пистолету.
- Доступно **везде** (прикреплено к персонажу, как HUD из Task 9).
- Клавиша — **физическая I**.

## Фактический API (не переизобретать)
- `scripts/game_state.gd` (автозагрузка `/root/GameState`): `points`, `owned_weapons: PackedStringArray`,
  `equipped_weapon_id: String`, `weapon_price(id) -> int`, `buy_weapon(id) -> bool`, `equip_weapon(id) -> bool`,
  `signal points_changed(points: int)`, `const _LOCATION_SCENES`, `_load_weapon(id)` (`res://data/weapons/%s.tres`).
  Сигнала смены экипировки НЕТ — добавить.
- `player.gd` (в КОРНЕ репо): `signal weapon_changed(weapon: Node)`, `func current_weapon() -> Node`,
  `@onready var _pistol: Pistol = get_node_or_null("Pistol") as Pistol`, `_ready()` вызывает
  `Input.set_mouse_mode(CAPTURED)` и эмитит `weapon_changed.emit(_pistol)`. Ввод гейтится
  `InputGate.is_play_input_allowed(_mouse_mode_for_play_input())`; игровой ввод разрешён только при `CAPTURED`.
  Функции `_toggle_mouse_capture()` (Esc) и `_on_focus_entered()` существуют.
- `scripts/ui.gd` (`CanvasLayer`, ребёнок `player.tscn`): HUD, `bind(player, weapon, game_state)`,
  `_find_weapon()` → `player.current_weapon()`. `ui.tscn` — его сцена.
- Оружие: `pistol.tscn` / `auto.tscn` (корень `auto.tscn` назван `Auto`), оба на `scripts/pistol.gd`
  (`class_name Pistol`), данные — `res://data/weapons/{pistol,auto}.tres`.

## A. Действие `inventory`
`project.godot [input]`: действие `inventory`, привязано к **физической** I
(`physical_keycode = 73`, `keycode = 0`), deadzone 0.5 (кодировкой как остальные биндинги).

## B. Инвентарь
- Новый узел панели в player-attached UI: `InventoryPanel` (Control, скрыт) в `ui.tscn` +
  `scripts/inventory.gd`. (Допустимо расширить `ui.gd`, но отдельный узел предпочтительнее.)
- Открытие/закрытие по действию `inventory` (физическая I). **Обработку НЕ гейтить** `InputGate`:
  инвентарь надо открыть при захваченном курсоре (панель — UI-действие, как pause).
- При открытии: `Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)` — это САМО гасит движение/обзор/
  прыжок/огонь/E через существующий `InputGate`, отдельно ничего гейтить не нужно. Панель видима,
  кнопки построены по `GameState.owned_weapons`.
- Кнопки: по одной на купленное оружие; подпись — `WeaponData.display_name` (грузить
  `res://data/weapons/<id>.tres`; нет ресурса → запасное имя = id). Текущее экипированное помечено.
- Клик по кнопке → `GameState.equip_weapon(id)` → закрыть панель (курсор снова `CAPTURED`).
- `_exit_tree`: если панель открыта — закрыть и вернуть `CAPTURED` (курсор не залипает при смене сцены).
- Null-safe: нет `/root/GameState` → панель пуста/скрыта, без ошибок.

## C. Смена оружия у игрока (`player.gd`)
- Единый источник «id → сцена»: `_WEAPON_SCENES := {"pistol": "res://pistol.tscn", "auto": "res://auto.tscn"}`
  в `game_state.gd` (рядом с `_LOCATION_SCENES`) + публичный хелпер `weapon_scene_path(id) -> String`.
- `game_state.gd`: `signal equipped_changed(weapon_id: String)`; испускать в `equip_weapon` и в `buy_weapon`
  (в обеих ветках, где меняется `equipped_weapon_id`). Автосейв не менять.
- `player.gd`: `func apply_equipped_weapon()` — по `GameState.equipped_weapon_id` заменить узел-слот
  (`name == "Pistol"`) нужной сценой, **сохранив трансформ руки** старого узла; обновить `_pistol`;
  испустить `weapon_changed.emit(_pistol)`. Вызывать в `_ready()` (до эмита стартового состояния) и по
  `GameState.equipped_changed`. Без `/root/GameState` (тесты) — остаётся дефолтный `Pistol`, ничего не меняется.
- Не трогать `pistol.tscn`/`auto.tscn`. HUD пере-привяжет патроны по `weapon_changed` (уже готово в Task 9).

## Проверки
- **TDD**: новый `tests/inventory.gd` (красный → зелёный): кнопки по `owned_weapons`; выбор экипирует;
  `I` переключает панель; своп узла оружия pistol↔auto с корректными данными (`current_weapon()`);
  null-safe без GameState.
- `tests/input_actions.gd`: ассерт `inventory` существует, ≥1 событие, `InputEventKey.physical_keycode == 73`.
- `tools/run_checks.ps1`: добавить `inventory` в `$Tests`. `CHECKLIST.md` — обновить.
- Полный сьют: `0 failed`, `waves` `[SKIP]`, `user://save.json` НЕ создаётся.

## Инварианты
- `range.tscn`/`range_scene.gd` — не менять; без прямых `change_scene_to_file` вне `GameState`; не коммитить.

## Files
- Modify: `project.godot`, `scripts/game_state.gd`, `scripts/player.gd`, `scripts/ui.gd` (если нужно), `ui.tscn`,
  `tests/input_actions.gd`, `tools/run_checks.ps1`, `CHECKLIST.md`.
- New: `scripts/inventory.gd` (+`.uid`), `tests/inventory.gd` (+`.uid`).

## Отчёт
`task-10-report.md`. НЕ коммитить.
