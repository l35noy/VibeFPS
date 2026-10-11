> **Назначение:** Бриф задачи фазы.

# Task 3 Brief: GameState + tests/progression.gd (трек A, после Task 1 и Task 2)

Проект VibeFPS (Godot 4.7.2 stable, GDScript, Jolt). Рабочий каталог: `E:\projects\VibeFPS`.
Фаза 3 «Лобби». Готово: SaveSystem (Task 1 — `scripts/save_system.gd`, интерфейс см. ниже), Автомат (Task 2 — `WeaponData.price`, `data/weapons/auto.tres` price=300). Твоя задача — глобальное состояние: очки, покупка/экипировка оружия, открытые локации, переходы между сценами, автосейв.

**Contract (обязательно):**
- НЕ коммитить (`git add`/`commit` не делать) — коммитит владелец.
- Никаких субагентов — вся работа сам; ревью делает контроллер после отчёта.
- Проверки — ТОЛЬКО командой: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 <фильтр>` (Godot headless; напрямую godot не запускать).
- В рабочем дереве НЕзакоммиченные чужие правки — НЕ откатывать, НЕ трогать (владельца: pistol.tscn/player.gd/project.godot; DOC-CLEANUP: scripts/pistol.gd, tests/weapon.gd; документы). Твой дифф — только твои файлы.
- Полный отчёт: `C:\Users\serhio\.opencode\plan\sdd\2026-10-10-vibefps-phase3-lobby\task-3-report.md`; финальное сообщение — короткий статус.
- Кириллица в файлах — UTF-8 (норма); консоль PowerShell может моджибакетить — только отображение.

## Files
- Create: `scripts/game_state.gd`
- Create: `tests/progression.gd`
- Modify: `tools/run_checks.ps1` — НЕ нужно (имя `progression` уже есть в `$Tests`).

## Потребляемые интерфейсы (уже в проекте — читать файлы)
- `SaveSystem` (scripts/save_system.gd): `@export save_path`, `save(payload: Dictionary) -> bool`, `load_state() -> Dictionary`, `clear_save() -> void`, `has_save() -> bool`. В тестах инстанцируешь вручную (см. ниже).
- `WeaponData` (scripts/weapon_data.gd): поле `price: int` (0 = стартовое бесплатное); загрузка по id: `load("res://data/weapons/%s.tres" % id)`.
- Заготовки данных: `data/weapons/pistol.tres` (price=0, дефолт), `data/weapons/auto.tres` (price=300).

## Производимый интерфейс: `GameState` (class_name GameState, extends Node)
- `const POINTS_PER_KILL := 10`, `const POINTS_PER_WAVE := 50`, `const POINTS_PER_CLEAR := 500` (спека §7.5: убийство 10, волна 50, зачистка 500 — волны/зачистка начнут начисляться в Фазе 4, константы готовы уже здесь).
- `var points: int = 0`
- `var owned_weapons: PackedStringArray = ["pistol"]`
- `var equipped_weapon_id: String = "pistol"`
- `var unlocked_locations: PackedStringArray = ["range"]`
- `var scene_changer: Callable` — подменяемый в тестах; **по умолчанию присваивается в `_ready()`, НЕ в `_init()`** (в `_init()` `get_tree()` может быть null при ручном `GameState.new()` + `add_child`): `scene_changer = Callable(get_tree(), "change_scene_to_file")`.
- `func weapon_price(id: String) -> int` — из `WeaponData.price`; отсутствие/битый файл → 0.
- `func award_points(amount: int) -> void` — отрицательный amount игнорируется.
- `func can_afford(cost: int) -> bool`
- `func buy_weapon(id: String) -> bool`:
  - уже куплено (в `owned_weapons`) → ТОЛЬКО `equip_weapon(id)` без списания, вернуть true;
  - `can_afford(weapon_price(id))` ложно → false, ничего не меняется;
  - иначе: `points -= price`, добавить в `owned_weapons`, `equipped_weapon_id = id`, автосейв, true.
- `func equip_weapon(id: String) -> bool` — только если id в `owned_weapons`; автосейв; иначе false.
- `func enter_location(id: String) -> bool` — только если id в `unlocked_locations`; вызывает `scene_changer.call("res://<id>.tscn")`; иначе false (смену сцены НЕ вызывать).
  - Маппинг id → сцена: `"range"` → `"res://range.tscn"` (временный бой через дверь лобби; настоящая локация — Фаза 4). Словарь маппинга — приватный.
- `func return_to_lobby(reason: String) -> void` — `scene_changer.call("res://lobby.tscn")` (reason пока не используется, параметр для будущих экранов).
- `func _persist() -> Dictionary` — `{"points": points, "owned_weapons": [...], "equipped_weapon_id": ..., "unlocked_locations": [...]}`.
- `func _restore(saved: Dictionary) -> void` — применить только присутствующие ключи; типы проверить безопасно.
- Автосейв после КАЖДОГО мутатора (award_points/buy_weapon/equip_weapon): `var ss := get_node_or_null("/root/SaveSystem"); if ss != null and ss.has_method("save"): ss.save(_persist())` — null-safe (тесты/сцены без автозагрузки).
- `_ready()`: `var ss := get_node_or_null("/root/SaveSystem"); if ss != null: _restore(ss.load_state())`.

## Step 1: Написать падающий тест `tests/progression.gd` (TDD RED)

Каркас по образцу `tests/save.gd`/`tests/smoke.gd` (`extends SceneTree`, `_check`, `quit(1 if _failures.size() > 0 else 0)`). В `_initialize()`:
1) удалить тестовый сейв-файл (чистый старт): `user://progression_test.json`;
2) `_save = SaveSystem.new(); _save.save_path = "user://progression_test.json"; root.add_child(_save)` (ПЕРЕД GameState — порядок важен для `_ready()`);
3) `_gs = GameState.new(); _gs.scene_changer = _fake_changer; root.add_child(_gs)`; `_fake_changer` — Callable, складывающая аргумент в `var changed_to: PackedStringArray` (СМЕНЫ СЦЕН НЕ ВЫПОЛНЯТЬ — headless);
4) в конце `_save.clear_save()`.

Проверки (все — из плана, значения точные):
- старт: `points == 0`, `owned_weapons == ["pistol"]`, `equipped_weapon_id == "pistol"`, `unlocked_locations == ["range"]`;
- `award_points(10)` → `points == 10`; `award_points(-5)` → `points == 10` (игнор);
- `can_afford(300)` → false; после `award_points(300)` → `can_afford(300)` true;
- `buy_weapon("auto")`: цена 300 через `weapon_price`, списание → `points == 10`, `owned_weapons` содержит `"auto"`, `equipped_weapon_id == "auto"`;
- повторный `buy_weapon("auto")` при 10 очках → true (экипировка), `points` НЕ ушёл в минус (== 10), `owned_weapons.size() == 2`;
- `buy_weapon("nope")` (нет .tres → price 0 → не хватает? `can_afford(0)` true — ОСТОРОЖНО: файла нет, но price=0 → это дешёвая покупка несуществующего оружия? НЕТ: для несуществующего id проверь, что `.tres` реально грузится; `weapon_price("nope") == 0` и `buy_weapon("nope")` должен вернуть false, если ресурс отсутствует — реши проверкой `load()` на null в `buy_weapon`; зафиксируй это поведение в тесте);
- `equip_weapon("pistol")` → true; `equip_weapon("auto")` → true; `equip_weapon("nope")` → false;
- `enter_location("range")` → true и `changed_to == ["res://range.tscn"]`;
- `enter_location("secret")` → false, `changed_to` НЕ изменился (size без изменений);
- `return_to_lobby("death")` → `changed_to == [..., "res://lobby.tscn"]`;
- автосейв-круг: после `award_points(50)` → `_save.load_state()` содержит `points == 50` и корректный `equipped_weapon_id`.
- (для `buy_weapon("nope")` решение фиксируй в тесте ДО просмотра реализации — как ожидаемое поведение: «нельзя купить несуществующее оружие»).

## Step 2: Прогнать `progression` — FAIL (нет файлов/скрипта)
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 progression` → FAIL.

## Step 3: Реализовать `scripts/game_state.gd`
По «Производимый интерфейс» (дословно сигнатуры). Комментарий на русском о временном статусе чисел. `buy_weapon` для несуществующего ресурса → false (проверка `load()` до списания). Хранилище сцен: приватный словарь `{"range": "res://range.tscn"}`; `enter_location` использует его (нет записи → false).

## Step 4: Прогнать `progression` — PASS
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 progression` → PASS.

## Step 5: Мутация «забыть автосейв»
Временно убрать вызов автосейва из `award_points`, прогнать → ассерт «круг через диск» краснеет; вернуть → зелёный. Команда+вывод в отчёт.

## TDD Evidence (в отчёте)
RED → GREEN → мутация — команды + выводы.

## Инварианты проекта (не ломать)
- Напрямую `change_scene_to_file` в игровых сценах — запрещено (спека §6.1): в этой задаче переходы ТОЛЬКО через `scene_changer`.
- Очки/покупки НЕ трогают врагов и оружие-код (только читают `.tres`).
- `user://save.json` (боевой путь) не используется — только `user://progression_test.json`.
- В repair-кейсах: `_restore` не должен падать на битых/частичных словарях.