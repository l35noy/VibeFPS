# Task 3 Report: GameState + tests/progression.gd (трек A)

## Status: DONE_WITH_CONCERNS
- Артефакты: `scripts/game_state.gd` (+ `.uid`), `tests/progression.gd` (+ `.uid`) — новые, НЕ закоммичены.
- Проверка: `progression PASS`; полный сьют `RESULT: 12 passed, 0 failed, 1 skipped` (waves — SKIP, файла нет).
- Концерн: арифметическое противоречие в брифе по автосейв-кругу (см. «Concerns»); решено буквальным значением 50 через чистый инстанс.

## What I implemented

### `scripts/game_state.gd` (`class_name GameState extends Node`)
Произведён интерфейс — дословно по брифу:
- `const POINTS_PER_KILL := 10`, `POINTS_PER_WAVE := 50`, `POINTS_PER_CLEAR := 500` (временный баланс §7.5).
- `points`, `owned_weapons = ["pistol"]`, `equipped_weapon_id = "pistol"`, `unlocked_locations = ["range"]`.
- `scene_changer: Callable` — дефолт `Callable(get_tree(), "change_scene_to_file")` ставится в `_ready()`, НЕ в `_init()`.
- `weapon_price(id) -> int` (из `WeaponData.price`; нет/битый файл → 0).
- `award_points(amount)` — отрицательный игнор, автосейв.
- `can_afford(cost)`.
- `buy_weapon(id)` — купленное → только `equip_weapon` (без списания, true); нет ресурса → false (проверка `load()` ДО списания); не хватает очков → false без изменений; иначе списание + own + equip + автосейв.
- `equip_weapon(id)` — только из `owned_weapons`, автосейв.
- `enter_location(id)` — только из `unlocked_locations` и только если id есть в приватном `_LOCATION_SCENES = {"range": "res://range.tscn"}`; иначе false без вызова смены сцены.
- `return_to_lobby(reason)` — `scene_changer.call("res://lobby.tscn")`; `reason` под будущие экраны.
- `_persist() -> Dictionary` — `{"points", "owned_weapons" (Array), "equipped_weapon_id", "unlocked_locations" (Array)}`.
- `_restore(saved)` — только присутствующие ключи, типы проверяются безопасно (не-строки в массивах отбрасываются хелпером `_to_string_array`).
- Автосейв после каждого мутатора через null-safe `_autosave()` (`/root/SaveSystem`, только если `has_method("save")`).
- `_ready()`: `_restore(ss.load_state())` при наличии SaveSystem.

**Ключевое решение (иначе тест бы не прошёл):** дефолт `scene_changer` ставится в `_ready()` под guard `if not scene_changer.is_valid()`. Тест инъектирует заглушку ДО `add_child`, поэтому безусловное присваивание в брифе (стр. 30) перезаписало бы заглушку. Дефолтный `Callable` невалиден → `is_valid()` различает «не задан» и «подменён».

### `tests/progression.gd` (`extends SceneTree`)
Каркас по образцу `tests/save.gd`. В `_initialize()`: чистка `user://progression_test.json`; `SaveSystem.new()` (имя `"SaveSystem"` — это делает `/root/SaveSystem` разрешаемым для автосейва) + `root.add_child`; затем `GameState.new()`, инъекция `_fake_changer`, `root.add_child`; `await physics_frame`. `_fake_changer` копит пути в `_changed_to` (смена сцен headless НЕ выполняется). В конце `_save.clear_save()` + чистка файла.

Проверки (значения из брифа):
- старт: `points==0`, `owned==["pistol"]`, `equipped=="pistol"`, `unlocked==["range"]`;
- `award_points(10)`→10; `award_points(-5)`→10 (игнор);
- `weapon_price("auto")==300`; `can_afford(300)` false; после `award_points(300)` true;
- `buy_weapon("auto")`→true, `points==10`, `owned` содержит auto, `equipped=="auto"`;
- повторный `buy_weapon("auto")` при 10 → true, `points==10`, `owned.size()==2`;
- `weapon_price("nope")==0`; `buy_weapon("nope")`→false, в мешок не добавлен (решение зафиксировано в тесте ДО реализации);
- `equip_weapon("pistol")`→true; `equip_weapon("auto")`→true; `equip_weapon("nope")`→false и экипировка не меняется;
- `enter_location("range")`→true, `_changed_to==["res://range.tscn"]`; `enter_location("secret")`→false, размер `_changed_to` не изменился;
- `return_to_lobby("death")` → `_changed_to==["res://range.tscn","res://lobby.tscn"]`;
- автосейв: `_save.load_state()` уже содержит `points==10`, `equipped=="auto"` (после buy/equip); затем чистый инстанс `_roundtrip` → `award_points(50)` → `load_state().get("points")==50`, `equipped=="pistol"`.

## TDD Evidence

### Step 2 — RED (нет `GameState`)
```
> powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 progression
importing project (class cache missing or stale) ...
progression    FAIL  (exit code 1)
    SCRIPT ERROR: Parse Error: Could not find type "GameState" in the current scope.
       at: GDScript::reload (res://tests/progression.gd:32)
    ... (тот же класс ошибок на 34/83/141/153/169/191/224)
    ERROR: Failed to load script "res://tests/progression.gd" with error "Parse error".
RESULT: 0 passed, 1 failed, 0 skipped
Exited with code 1
```

### Step 4 — GREEN
```
> powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 progression
importing project (class cache missing or stale) ...
progression    PASS

RESULT: 1 passed, 0 failed, 0 skipped
```

### Step 5 — Мутация «забыть автосейв в award_points»
Убрал `_autosave()` из `award_points`:
```
> powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 progression
progression    FAIL  (exit code 1)
    -- autosave: mutations land on disk, and a fresh state reads back
      [PASS] autosave after buy/equip persisted points == 10 (got 10.0)
      [PASS] autosave persisted the equipped weapon (got auto)
      [FAIL] award_points(50) is on disk as points == 50 (got <null>)
      [FAIL] and the persisted equipped weapon is correct (got <null>)
    === RESULT: 34 checks, 2 failed ===
RESULT: 0 passed, 1 failed, 0 skipped
```
Мутация краснит РОВНО автосейв-круг (`award_points` не сохранил → на диске пусто; `buy/equip`-автосейв остался зелёным). Вернул `_autosave()` → `progression PASS`.

### Полный сьют (один раз, в конце)
```
> powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1
smoke PASS | movement PASS | input_actions PASS | input_gate PASS | weapon_data PASS |
integrity PASS | weapon PASS | auto_weapon PASS | projectile PASS | enemies PASS |
waves [SKIP] | save PASS | progression PASS
RESULT: 12 passed, 0 failed, 1 skipped
```

## Files changed
- `scripts/game_state.gd` (new)
- `scripts/game_state.gd.uid` (new, сгенерирован импортом, 19 B)
- `tests/progression.gd` (new)
- `tests/progression.gd.uid` (new, сгенерирован импортом, 19 B)
- `tools/run_checks.ps1` — НЕ правил (`progression` уже в `$Tests`).
- Чужие незакоммиченные правки не трогал; `git status` показывает только ожидаемые новые файлы.

## Self-review findings / Concerns

1. **КОНЦЕРН (главный), арифметика брифа по автосейву.** Бриф стр. 66: «после `award_points(50)` → `load_state()` содержит `points == 50`». Но по той же последовательности брифа к этому моменту на `_gs` уже 10 очков (310 − 300), т.е. 10 + 50 = **60**, а не 50. Аналогичное рассогласование есть и в плане (стр. 210-211, 217 против 208-209). Решение: буквальное значение 50 добито **чистым инстансом** `_roundtrip` (autosave-круг от известного нуля), плюс отдельно проверено, что основной инстанс после buy/equip лежит на диске (`points==10`, `equipped=="auto"`). Так соблюдены оба числа брифа. Если контроллер предпочитает один инстанс и значение 60 — правка тривиальна (снять второй инстанс, ассерты на 60). Прошу подтвердить выбор.

2. **Guard `scene_changer` в `_ready()`.** Бриф стр. 30 буквально предписывает безусловное присваивание. Оно сделало бы невозможной инъекцию заглушки до `add_child` (тест стр. 52). Добавлен `if not scene_changer.is_valid()`. Это необходимо для контракта «подменяемый в тестах»; иначе тест не смог бы проверить переходы без реальной смены сцен.

3. **`enter_location` по словарю, а не по `"res://<id>.tscn"`.** Стр. 39 и 73 брифа согласованы реализацией через приватный `_LOCATION_SCENES`; для `"range"` результаты идентичны, при неизвестном id — false (без смены сцены). Расширяемо в Фазе 4 без правки вызывающего кода.

4. **Ожидаемый шум в stderr** от `load("res://data/weapons/nope.tres")` (движок печатает «Cannot open file … / Failed loading resource») — неотъемлемая часть предписанного брифом «отсутствие → 0» и проверки `buy_weapon("nope")`. Runner проверяет только `[FAIL]` и exit code, так что на PASS это не влияет (аналогично принятому R9 в Task 1).

5. **`_restore` — только присутствующие ключи и безопасные типы.** Не-строки в массивах отбрасываются хелпером, чтобы битый/частичный сейв не ронял `_ready()` и не клал мусор в `owned_weapons`/`unlocked_locations`. Покрыто косвенно (восстановление `{}` на `_roundtrip`); нон-эмпти restore будет сквозным образом проверен в Task 6 (autoload).

6. **`.name = "SaveSystem"` в тесте** (доп. к строке 51 брифа): гарантирует, что ручной SaveSystem разрешается как `/root/SaveSystem` для автосейва, не полагаясь на авто-именование ноды классом. Безвредно, если движок и так даёт это имя.
