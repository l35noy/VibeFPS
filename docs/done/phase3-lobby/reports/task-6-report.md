> **Назначение:** Отчёт по задаче фазы.

# Task 6 Report: Сцена лобби + автозагрузки + главная сцена (ассемблинг, ПОСЛЕДНЯЯ задача)

**Status:** DONE_WITH_CONCERNS
**Date:** 2026-10-10
**Project:** VibeFPS (Godot 4.7.2 stable, GDScript, Jolt)

Concern (одно, важное): автозагрузки зарегистрированы **без префикса `*`**,
вопреки буквальному тексту брифа (`*res://...`). Префикс `*` и `class_name
GameState`/`SaveSystem` взаимоисключающи — движок падает на парсинге (доказано
эмпирически ниже). Без `*` выполнены ОБА контракта: узел в `/root/GameState` и
`class_name` как тип. Подробности в разделе «Ключевое решение».

## What I implemented

### 1. `lobby.tscn` (новый) — сцена лобби
Заголовок: `uid="uid://l0bby5c7n2v4m"`, `format=3`, `load_steps=28`. Без
`NavigationRegion3D` и без врага, `lobby.gd` нет (навмешу негде жить). Состав:

- `Lobby` (Node3D) — корень;
- `WorldEnvironment` (Environment с `ProceduralSkyMaterial`/`Sky`, `BG_SKY`);
- `DirectionalLight3D` (тени включены);
- `Floor` (StaticBody3D, **слой 1**) — комната 12×20, центр `(0, -0.5, -8)`,
  верхняя грань `y = 0` (игрок стоит на нуле);
- 3 стены: `BackWall` (`z = -18`), `LeftWall` (`x = -6`), `RightWall` (`x = 6`),
  все StaticBody3D слой 1;
- `ShopPoint` (`scripts/shop_point.gd`, `weapon_id = "auto"`) — `(5, 0, 0)`, у
  правой стены, 5 м от спавна; меш + триггер-коллайдер (слой/группа ставит скрипт
  в `_ready`);
- `DoorPoint` (`scripts/door_point.gd`, `location_id = "range"`) — `(0, 0, -17.5)`
  на дальней стене;
- Тест-стенд — 3 мишени ровно как в `range.tscn`: тело StaticBody3D **слой 4**
  (`<<2`), хитбокс `Hurtbox` **zone 0** (=> слой 4 в `_ready`), скрипт
  `range_target.gd`. Дистанции от спавна: `TargetNear` 5 м `(0, 0, -5)`,
  `TargetMid` 8 м `(-3, 0, -7.416)`, `TargetFar` 12 м `(4, 0, -11.314)`
  (смещения по x, чтобы дальняя не стояла за ближней);
- `Player` — инстанс `res://player.tscn` на `(0, 0, 0)`.

### 2. `project.godot` — автозагрузки + главная сцена
```ini
[application]
run/main_scene="uid://l0bby5c7n2v4m"   # uid lobby.tscn

[autoload]

GameState="res://scripts/game_state.gd"
SaveSystem="res://scripts/save_system.gd"
```
Добавлен **только** блок `[autoload]` и изменён `run/main_scene`. §1A-ключи
владельца (`run/max_fps`, `window/vsync/vsync_mode`, `scaling_3d/scale`) не
возвращены и не тронуты (проверено `git diff`; см. «Инварианты»).

### 3. `tests/smoke.gd` — секция лобби
Добавлен `await _test_lobby()` (строка 52) и функция `_test_lobby()` (строки
87–153). Секция `main.tscn` выше не тронута. Ассерты: `lobby.tscn` грузится;
инстанс — Node3D; `Player` есть; `Floor` на слое 1; `ShopPoint` в группе
`"interactable"` и на слое 6; `DoorPoint` в группе и на слое 6; три мишени
`TargetNear/Mid/Far` с `Hurtbox.zone == 0`.

### 4. `tests/progression.gd`, `tests/interact.gd`, `tests/enemies.gd` — R10-фикс
В каждый тест добавлен хелпер `_drop_autoloads()` и вызов в начале
`_initialize()`: удалить из `/root` узлы автозагрузок `GameState`/`SaveSystem`,
которые движок ставит даже в `--script`-режиме. Подробности — в разделе R10.

## Ключевое решение: автозагрузка без `*` (отклонение от брифа)

### Противоречие в брифе
Бриф Step 2 требует `GameState="*res://scripts/game_state.gd"` (с `*`), а в Files
и «Потребляемых интерфейсах» называет `scripts/game_state.gd (class_name
GameState)` и требует использовать `GameState`/`SaveSystem` как типы (это делают
`tests/enemies.gd`: `class _RecordingGameState extends GameState`, и все три теста:
`var _gs: GameState`). В Godot это несовместимо.

### Эмпирическое доказательство (свежее, воспроизведено в этой задаче)
С `*`-формой (`powershell ... run_checks.ps1 smoke`), после удаления
`.godot/global_script_class_cache.cfg`:
```
SCRIPT ERROR: Parse Error: Class "GameState" hides an autoload singleton.
   at: GDScript::reload (res://scripts/game_state.gd:1)
ERROR: Failed to load script "res://scripts/game_state.gd" with error "Parse error".
ERROR: Failed to create an autoload, script 'res://scripts/game_state.gd' is not compiling.
   at: _create_autoload (editor/settings/editor_autoload_settings.cpp:340)
SCRIPT ERROR: Parse Error: Class "SaveSystem" hides an autoload singleton.
   at: GDScript::reload (res://scripts/save_system.gd:1)
ERROR: Failed to create an autoload, script 'res://scripts/save_system.gd' is not compiling.
```
Т.е. с `*` автозагрузки **вообще не создаются** (скрипты не компилируются), а
`tests/progression.gd`/`interact.gd`/`enemies.gd` не спарсятся (используют
`GameState` как тип). После отката на форму без `*` — всё чисто.

### Почему без `*` корректно
Из исходников движка (`main.cpp`, `gdscript_analyzer.cpp`), проверено в прошлой
сессии: все записи `[autoload]` инстанциируются и добавляются в `/root` под
своим именем; флаг `is_singleton` (это и есть `*`) влияет **только** на
добавление глобальной константы-синглтона и на этот самый parse-error. Значит
форма без `*`:

- по-прежнему даёт узлы `/root/GameState` и `/root/SaveSystem` — ровно те пути,
  которые читает продакшн-код (`player.gd`, `enemy_contact.gd`,
  `scripts/shop_point.gd`, `scripts/door_point.gd` — все через
  `get_node_or_null("/root/GameState")`);
- не конфликтует с `class_name GameState`/`SaveSystem`, так что объявления типов
  (`var _gs: GameState`, `... extends GameState`) компилируются.

Никакой продакшн-код не обращается к автозагрузкам по глобальному имени-синглтону
— только по пути `/root/...`, так что потеря глобальной константы ни на что не
влияет. Форма без `*` — единственная, удовлетворяющая и брифу (узел в `/root`),
и тестам (тип `GameState`).

### Отвергнутая альтернатива: скрипт-обёртка
Пробовал `scripts/game_state_autoload.gd` / `scripts/save_system_autoload.gd`
(обёртка `extends "res://scripts/...gd"`, автозагрузка указывает на обёртку).
Не помогло: конфликт **по имени**, а не по пути скрипта — автозагрузка всё равно
называется `GameState`, а `class_name GameState` из подключаемого скрипта
всё равно виден. Обёртки и их `.uid` удалены (в `git status` не фигурируют).

## R10: автозагрузки vs тестовые инстансы (интеграционный риск)

### Эмпирика ДО фикса (движок ДОБАВЛЯЕТ автозагрузки и в `--script`)
Полный сьют после регистрации автозагрузок (с `*` был сломан парсинг; поэтому
фактический замер делался на форме без `*`, где парсинг проходит, но узлы
конфликтуют):
```
smoke          PASS
... (все до enemies) ...
enemies        FAIL  (exit code 1)     -> 40 failed
progression    FAIL  (exit code 1)     -> 9 failed
interact       FAIL  (exit code 1)     -> 9 failed
```
Механика поломки (корневая причина, а не симптом):
1. Тесты сами делают `_save.name = "SaveSystem"` / `gs.name = "GameState"` и
   `root.add_child(...)`. Поскольку автозагрузка с таким именем уже есть, движок
   переименовывает тестовый узел (`SaveSystem2`/`GameState2`), и
   `get_node_or_null("/root/GameState")` / `.../SaveSystem` резолвится в
   **автозагрузку**, а не в тестовый инстанс.
2. Автозагрузка `SaveSystem.save_path == "user://save.json"`, поэтому автосейв
   GameState шёл в **продакшн-файл**, а не в `user://*_test.json`: тест читал с
   диска свой изолированный файл и получал `null`.
3. Автозагрузка `GameState._ready()` восстанавливала `points` из чужого
   `user://save.json`, поэтому «points start at 0» падало (получалось 20/80 в
   зависимости от накопленного).
4. В `enemies.gd` пробный `_RecordingGameState` с именем `"GameState"`
   переименовывался, `root.get_node_or_null("GameState")` возвращал автозагрузку,
   а её `scene_changer` — настоящий `change_scene_to_file`. Смерть игрока тянула
   реальную смену сцены на `lobby.tscn`, что добавляло **второго** узла в группу
   `"player"` → падали прекондишены «в группе ровно один узел» (навигация, тир).

### Выбранное решение (разрешено брифом: «в начале теста удалить автозагрузку из root и добавить свой инстанс»)
В каждом из трёх тестов — хелпер:
```gdscript
## ... автозагрузки GameState/SaveSystem движок ставит в /root даже в --script.
## Удалить их, чтобы /root/GameState и /root/SaveSystem принадлежали харнессу,
## как до появления автозагрузок. Immediate free (не queue_free): имена должны
## освободиться ДО add_child тестовых узлов ниже.
func _drop_autoloads() -> void:
    for autoload_name in ["GameState", "SaveSystem"]:
        var node := root.get_node_or_null(autoload_name)
        if node != null:
            root.remove_child(node)
            node.free()
```
Вызов — первой строкой `_initialize()` (в `enemies.gd` — после `print`).

Смысл проверок НЕ менялся — восстановлено ровно исходное поведение «в root нет
автозагрузок», под которое тесты Tasks 3–5 и писались. `save.gd` не тронут:
он создаёт `SaveSystem` **без имени** (коллизии нет) и GameState не использует —
он проходил и до, и после.

### Эмпирика ПОСЛЕ фикса
```
progression    PASS
interact       PASS
enemies        PASS
```
Затем полный сьют — зелёный (см. ниже).

### Важно: загрязнение `user://save.json` устранено
Сломанные прогоны (до фикса) реально создали продакшн-файл
`%APPDATA%\Godot\app_userdata\VibeFPS\save.json` с содержимым, накопленным
тестами: `{"equipped_weapon_id":"auto","owned_weapons":["pistol","auto"],"points":80,...}`
(mtime 10.10.2026 15:32). Это НЕ пользовательский сейв (начался с нуля,
накоплен прогонами). Файл **удалён** — инвариант «`user://save.json` не должен
появляться от прогонов тестов» восстановлен и подтверждён после финального
полного прогона (`save.json` отсутствует).

## TDD Evidence

### RED — smoke-секция лобби до `lobby.tscn`
Команда: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 smoke`
(с `lobby.tscn`, временно отложенным в сторону):
```
smoke          FAIL  (exit code 1)
    -- lobby: scene assembly
      [FAIL] res://lobby.tscn loads
    === RESULT: 7 checks, 1 failed, 0 warnings ===
```
### GREEN — после создания `lobby.tscn`
```
smoke          PASS
RESULT: 1 passed, 0 failed, 0 skipped
```

### RED — тесты под автозагрузки (до `_drop_autoloads`)
Полный сьют показал: `enemies FAIL (40 failed)`, `progression FAIL (9 failed)`,
`interact FAIL (9 failed)` (см. раздел R10 выше; полный вывод зафиксирован в
сессии). Ключевые строки:
```
[FAIL] precondition: в /root нет GameState — смерть ниже идёт по fallback-ветке
[FAIL] precondition: пробный GameState резолвится как /root/GameState
[FAIL] precondition: в группе "player" ровно этот узел — в группе 2 узлов
[FAIL] points start at 0 (got 20)
[FAIL] autosave after buy/equip persisted points == 10 (got <null>)
[FAIL] precondition: the player starts with no points (got 80)
```

### GREEN — после `_drop_autoloads` (три теста + полный сьют)
```
progression    PASS
interact       PASS
enemies        PASS
```
Полный сьют (финальный, авторитетный):
```
smoke          PASS
movement       PASS
input_actions  PASS
input_gate     PASS
weapon_data    PASS
integrity      PASS
weapon         PASS
auto_weapon    PASS
projectile     PASS
enemies        PASS
waves          [SKIP]  (tests\waves.gd not present)
save           PASS
progression    PASS
interact       PASS

RESULT: 13 passed, 0 failed, 1 skipped
```

## Инварианты — проверено

- **`range.tscn` / `scripts/range_scene.gd` не менялись**: `git status --short
  range.tscn scripts/range_scene.gd` пусто.
- **Слой 6 не попал в маску снарядов**: `scripts/projectile.gd` не тронут этой
  задачей; `projectile`/`auto_weapon`/`weapon` зелёные.
- **§1A-ключи владельца не возвращены и не удалены**: `git diff project.godot`
  показывает удаления `run/max_fps`, `window/vsync/vsync_mode`, `scaling_3d/scale`
  (это правка владельца) — эти строки остались удалёнными, я их не трогал.
  После прогона `run_checks.ps1 weapon_data` (импорт) diff не изменился: `--import`
  §1A-строки не трогает.
- **`user://save.json` не создаётся прогонами**: удалён (был создан сломанными
  прогонами), после финального полного прогона отсутствует.
- **Смена главной сцены не ломает тесты**: тесты грузят сцены явно; полный сьют
  зелёный.

## Files changed

| File | Change |
|------|--------|
| `lobby.tscn` | Новый: сцена лобби (uid `uid://l0bby5c7n2v4m`, `format=3`). |
| `project.godot` | `run/main_scene` → uid lobby; новый блок `[autoload]` (GameState/SaveSystem, без `*`). |
| `tests/smoke.gd` | +`await _test_lobby()` (52) и функция `_test_lobby()` (87–153). |
| `tests/progression.gd` | +`_drop_autoloads()` (79–84) и вызов (89) в `_initialize`. |
| `tests/interact.gd` | +`_drop_autoloads()` (157–162) и вызов (190) в `_initialize`. |
| `tests/enemies.gd` | +`_drop_autoloads()` (1953–1958) и вызов (1963) в `_initialize`. |

Удалены артефакты отвергнутой альтернативы: `scripts/game_state_autoload.gd.uid`,
`scripts/save_system_autoload.gd.uid` (сами `.gd` были удалены в прошлой сессии).

## Self-review findings / Concerns

- **[Concern, главное] Автозагрузки без `*`.** Отклонение от буквы брифа Step 2
  обосновано выше и доказано эмпирически. Бриф сам требует `class_name GameState`
  и `*`-автозагрузку, что в Godot невозможно. Выбран вариант, сохраняющий оба
  наблюдаемых контракта (`/root/GameState`, тип `GameState`). Если владелец
  предпочитает буквальный `*` — тогда придётся отказаться от `class_name` в этих
  двух скриптах и переписать три теста на работу с синглтонами (несовместимо с
  `GameState.new()`/`extends GameState`, т.е. переписывание смысла тестов, что
  бриф запрещает).
- **R10 выбран паттерном «удалить автозагрузку из root»**, а не «взять
  существующую». Для `enemies.gd` это единственный работающий вариант: тест
  требует именно ОТСУТСТВИЯ `/root/GameState` (fallback-контракт смерти) в
  нескольких секциях. Для progression/interact удаление точно восстанавливает
  исходное поведение. Оба варианта явно разрешены брифом.
- **`_drop_autoloads` использует `remove_child` + `free()`** (немедленно), а не
  `queue_free()`: имя должно освободиться до `root.add_child(_save)`/`gs` ниже,
  иначе движок снова переименует тестовый узел.
- **`save.gd` намеренно не тронут** — не был затронут (прошёл), не в списке
  условно правимых файлов брифа.
- **`tests/progression.gd` и `tests/interact.gd` — untracked** (новые файлы Фазы 3,
  ещё не коммичены), поэтому в `git diff --stat` их нет; правки внесены внутрь них.
- **`tests/movement.gd` изредка флакует, и это НЕ от Task 6.** В двух прогонах
  полного сьюта упал ровно один ассерт движения — в одном прогоне «yaw changed on
  horizontal mouse motion», в другом «left mouse button reaches the fire action»
  (оба — про доставку `Input.parse_input_event` + `flush_buffered_events`, оба
  соседних ассерта зелёные). `tests/movement.gd` не входит в правки Task 6 и не
  трогает лобби/автозагрузки. Проверено: и **с** автозагрузками, и **без** них
  (временно удалял блок `[autoload]` через edit-tool) `movement` прошёл 10/10 в
  изоляции — значит, флак не связан с автозагрузками, а зависит от нагрузки
  машины при последовательном прогоне. Финальный полный прогон — зелёный.
- **Осторожно с PowerShell-правкой `project.godot`**: промежуточная попытка
  вырезать `[autoload]` через `-replace '(?s)...'` задела остаток файла (dotall
  `.*` съел секции ниже), что дало ложный «movement 6/6 FAIL». Файл восстановлен
  из побайтовой копии; `git hash-object project.godot` == `e884017...` — совпадает
  с корректным состоянием (проверено).

## Ручная проверка владельцем (НЕ выполнена здесь)
Проверки только headless. Владельцу при запуске игры проверить: лобби
открывается как главная сцена; персонаж ходит/прыгает; E у `ShopPoint` при 0
очков не покупает; `DoorPoint` ведёт в `range.tscn` (временный бой); убийство
врага даёт 10 очков; смерть возвращает в лобби.
