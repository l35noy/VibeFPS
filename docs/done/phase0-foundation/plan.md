> **Назначение:** План фазы (завершённой или в работе).

# VibeFPS — Фаза 0: Фундамент — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Оборотовать проект так, чтобы у каждой будущей подсистемы была своя автопроверка, единая команда запуска проверок, корректный ввод и слои коллизий — до начала боевых систем.

**Architecture:** Фаза 0 не добавляет игровых систем. Она чинит инфраструктуру: единая точка запуска проверок, новые actions ввода, чистая функция `InputGate` вместо размазанных проверок захвата мыши, разбивка монолитного харнесса по подсистемам, починка двух проверок, которые проходят по неверной причине, включение теней.

**Tech Stack:** Godot 4.7.2 stable (`E:\Godot\Godot_v4.7.2-stable_win64.exe`, сборка `4.7.2.stable.official.ed1daf0bf`), GDScript, Jolt Physics, PowerShell, Git.

**Spec:** материалы Фазы 0 доступны в каноне — см. `docs/done/phase0-foundation/design.md`, `docs/done/phase0-foundation/plan.md`. Исторические копии из `docs/superpowers/*` не хранятся в дереве.

## Global Constraints

- Godot: `E:\Godot\Godot_v4.7.2-stable_win64.exe`. Путь хранится в одном месте — `tools/run_checks.ps1`. Других копий пути не создавать.
- Каждая проверка — отдельный файл `tests/*.gd`, наследующий `SceneTree`, запускающийся через `--headless --script`, завершающийся `quit(0)` при успехе и `quit(1)` при провале.
- Файл `tests/capture.gd` и `tests/diagnose.gd` **не** входят в автоматический прогон: первый требует реального рендеринга, второй — ручного запуска.
- Критерий готовности любой задачи: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1` завершается с кодом 0. Плюс минимум один случай, где проверка реально исполняется: прогон, где всё SKIP, завершается кодом 0 и неотличим от прогона, который выполнился и прошёл.
- **Коммиты делает только партнёр.** Ни контроллер, ни субагенты не выполняют `git commit`. Изменения остаются в рабочем дереве, партнёр их просматривает и коммитит сам. Решение партнёра, принятое после того, как контроллер дважды закоммитил без разрешения.
- Проверка, которая проходит по неверной причине, считается неисправной и подлежит ужесточению (правило `CHECKLIST.md`).
- Существующие actions `move_forward`, `move_backward`, `move_left`, `move_right`, `jump`, `sprint` не меняются.
- Игровой код не использует встроенное действие `ui_cancel`.
- Несвязанные изменения в текущую задачу не включаются.
- Слой коллизий `1` = мир. Тела игрока и врагов ставятся на свои слои в Фазе 2; в Фазе 0 достаточно объявить имена слоёв.
- **Политика выполнения PowerShell на этой машине — `Restricted` (все области).** Голый вызов `.\tools\run_checks.ps1` падает с `PSSecurityException` до запуска скрипта. Все проверки в этом плане выполняются формой `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1`. Машинную политику не менять — это решение пользователя.

## Исправления, внесённые по итогам Task 2

Плану изначально было указано неверно; исполнитель отклонился обоснованно, решения ниже приняты как правильные.

1. **Сцена добавляется в дерево.** План требовал инстанцировать `main.tscn` без `root.add_child()`. Вне дерева `Camera3D.global_position` возвращает единичную матрицу (с ошибкой движка `!is_inside_tree()`), проверка высоты глаз срабатывает ложно на `0.00`, а RID'ы Jolt утекают на выходе. Правильно: `root.add_child(world)` + `await physics_frame`, как в исходном харнессе.
2. **Убрана проверка `main.tscn loads`.** План помещал `_check(packed != null, …)` *после* guard'а `if packed == null: quit(1); return`, то есть такая проверка всегда истинна — выполнение сюда не доходит. По правилу «проверка, проходящая по неверной причине, неисправна» такую строку нельзя оставлять. Guard с `FATAL` и `quit(1)` сохраняется.
3. **Строка `RESULT` — трёхаргументная** (`checks, failed, warnings`) во всех трёх файлах, а не двухаргументная: `movement.gd` обязан сообщать свои 2 предупреждения, а все три файла должны завершаться одинаково.
4. **Константа `FLOOR_EXTENT` удалена** — мёртвая, нигде не используется.

## Review Focus

Что спека подразумевает, но не покрывает тестами, и кто этим пострадает:

1. **Игрок умирает в момент смены сцены** — лобби вызывает восстановление здоровья, пока локация ещё выгружается, и здоровье сбрасывается в ноль. Ожидание: при переходе в лобби здоровье равно 100. Закрывается в Фазе 3 (`tests/progression.gd`).
2. **Перезарядка оружия при выходе в лобби и обратно** — магазин остаётся полупустым, и игрок получает бесплатные выстрелы каждый раз. Ожидание: при смене сцены оружие сбрасывается в полный магазин. Закрывается в Фазе 1 (`tests/weapon.gd`).
3. **Повторный `enter_location` для уже открытой локации** — игрок входит дважды, волны начинаются с нуля, очки начисляются дважды. Ожидание: второй вход начинает локацию с первой волны без удвоения очков за зачистку. Закрывается в Фазе 3 (`tests/progression.gd`).
4. **`fire` и `interact` при свободном курсоре** — то же, что уже чинится для движения в Task 5, но эти два actions вводятся позже и могут обойти гейт. Ожидание: при `MOUSE_MODE_VISIBLE` удержание `fire` не порождает выстрел. Закрывается в Фазе 1 (`tests/weapon.gd`).
5. **Повреждённый `user://save.json`** — игра падает на запуске вместо отката к значениям по умолчанию. Ожидание: повреждённый файл не роняет игру, прогресс начинается с нуля с предупреждением в консоли. Закрывается в Фазе 3 (`tests/save.gd`).

Ни одна из этих линий не закрывается в Фазе 0; они закреплены здесь, чтобы не потеряться между фазами.

## Карта владения файлами (Фаза 0)

Фаза 0 выполняется **строго последовательно**. Задачи делят `player.gd`, `project.godot` и `tools/run_checks.ps1`, поэтому параллельный запуск запрещён — он приведёт к сбросу изменений.

| Задача | Файлы во владении |
|---|---|
| 1 | `tools/run_checks.ps1`, документация Фазы 0 (канон `docs/done/phase0-foundation/`) |
| 2 | `tests/smoke.gd`, `tests/movement.gd`, `tests/integrity.gd`, удаление `tests/headless_smoke.gd` |
| 3 | `project.godot`, `tests/input_actions.gd` |
| 4 | `scripts/input_gate.gd`, `tests/input_gate.gd` |
| 5 | `player.gd`, `player.tscn` |
| 6 | `tests/integrity.gd` |
| 7 | `main.tscn` |

---

### Task 1: Единая точка запуска проверок

**Files:**
- Create: `tools/run_checks.ps1`
- (историческое) Спека и план сохранены в каноне: `docs/done/phase0-foundation/design.md`, `docs/done/phase0-foundation/plan.md`

**Interfaces:**
- Consumes: существующий `tests/headless_smoke.gd`, запускаемый как `godot --headless --path . --script res://tests/headless_smoke.gd`, завершающийся `quit(0)` при успехе.
- Produces: команда `.\tools\run_checks.ps1 [<фильтр>]` с кодом возврата 0 (все проверки зелёные) или 1 (хотя бы одна упала). Фильтр — подстрока имени файла без `.gd`, регистронезависимый; пустой фильтр = все проверки.

- [ ] **Step 1: Создать `tools/run_checks.ps1` со списком проверок**

Список `$Tests` — упорядоченный массив имён файлов **без** `.gd`. Первым идёт `smoke`, последним — `progression`: порядок значим, потому что `smoke` отвечает за целостность сцены и должен падать раньше остальных. Файлы, отсутствующие на диске, выводятся как `[SKIP]`, а не как падение, — иначе список нельзя расширять по мере добавления фаз.

```powershell
$GodotBin = "E:\Godot\Godot_v4.7.2-stable_win64.exe"
$Tests = @("smoke", "movement", "input_actions", "input_gate", "integrity",
           "weapon", "projectile", "enemies", "waves", "save", "progression")
```

- [ ] **Step 2: Реализовать тело скрипта**

Поведение, которое шаг фиксирует:

- `$Filter = $args[0]`, если передан. Тест участвует в прогоне, если `$Filter` пуст **или** имя теста содержит `$Filter` как подстроку без учёта регистра.
- Перед прогоном проверяется наличие `$GodotBin`; при отсутствии скрипт печатает путь и завершается кодом 1, ничего не запуская.
- Каждый тест запускается из корня репозитория: `& $GodotBin --headless --path . --script "res://tests/$name.gd"`. Вывод движка (`--headless` пишет в stderr) перенаправляется в `$Output`, чтобы `[FAIL]`-строки теста не терялись; при провале `$Output` печатается целиком.
- Код возврата теста (`$LASTEXITCODE`) определяет статус. `0` = `PASS`, иначе `FAIL`. Отсутствующий файл = `SKIP`.
- В конце печатается строка вида `RESULT: <PASS> passed, <FAIL> failed, <SKIP> skipped`, и скрипт завершается кодом 1, если `FAIL` > 0.

- [ ] **Step 3: Прогнать скрипт на текущем состоянии репозитория**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1`
Expected: `RESULT: 0 passed, 0 failed, 11 skipped`, код возврата 0.

Все 11 имён в `$Tests` дают `SKIP` — на этом шаге ни один из перечисленных
файлов ещё не существует. Существующий `tests/headless_smoke.gd` в список не
входит: его удаляет Task 2, а задачи 2–7 создают `smoke`, `movement`,
`input_actions`, `input_gate`, `integrity` и остальные. Это ожидаемо:
критерий SKIP-семантики в том, что отсутствующий файл не считается ни
успехом, ни провалом. Первый реально исполняемый прогон появится в Task 2.

- [ ] **Step 4: Проверить фильтр**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 smok`
Expected: только тест `smoke` в таблице, тот же результат, код 0.

- [ ] **Step 5: Скопировать спеку и план в репозиторий**

(историческое действие) Копирование документации в `docs/superpowers/*` не производилось в текущем дереве — документация Фазы 0 сохранена в каноне `docs/done/phase0-foundation/`.

- [ ] **Step 6: Закоммитить**

```bash
git add tools/run_checks.ps1 docs/   # НЕ КОММИТИТЬ — коммит делает партнёр
```

---

### Task 2: Разбивка монолитного харнесса по подсистемам

**Files:**
- Create: `tests/smoke.gd`
- Create: `tests/movement.gd`
- Create: `tests/integrity.gd`
- Delete: `tests/headless_smoke.gd`

**Interfaces:**
- Consumes: `res://main.tscn` с узлами `Player`, `Floor`, `WorldEnvironment`; узел `Camera3D` внутри `Player`; actions `move_*`, `jump`, `sprint`.
- Produces: три независимых харнесса. Вспомогательные функции дублируются в каждом файле — намеренно: файлы проверок должны запускаться по отдельности без общего модуля, иначе один сломанный файл уронит все.

- [ ] **Step 1: Определить распределение проверок**

| Файл | Проверки из `headless_smoke.gd` |
|---|---|
| `smoke.gd` | загрузка `main.tscn`, наличие `Player` / `Floor` / `WorldEnvironment`, `Camera3D` существует и `current`, `background_mode == BG_SKY`, у `Environment` задан `sky` и `sky_material` |
| `movement.gd` | приземление и покой, ходьба вперёд ~5 м, стрейф вправо, спринт быстрее ходьбы, прыжок по `InputEventKey`, высота прыжка, прыжок по `InputEventAction`, обзор мышью с клампингом pitch, обзор при свободном курсоре, отсутствие остаточного скольжения |
| `integrity.gd` | падение с высоты 50 не проваливает мир; respawn после падения ниже kill-plane возвращает на точку старта |

Сценарий приземления и проверка высоты прыжка делят состояние с `movement.gd` и должны идти в нём же, в порядке: приземление → ходьба → стрейф → спринт → прыжок → высота → action-прыжок.

- [ ] **Step 2: Создать `tests/smoke.gd`**

Шаблон харнесса, общий для всех трёх файлов:

```gdscript
extends SceneTree

## Проверка целостности сцены. Запуск:
##   .\tools\run_checks.ps1 smoke

var _failures: PackedStringArray = []
var _checks := 0

func _check(ok: bool, label: String, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  [PASS] %s %s" % [label, detail])
	else:
		_failures.append("%s %s" % [label, detail])
		print("  [FAIL] %s %s" % [label, detail])
```

Завершение — во всех трёх файлах одинаковое:

```gdscript
	print("=== RESULT: %d checks, %d failed ===" % [_checks, _failures.size()])
	quit(1 if _failures.size() > 0 else 0)
```

Загрузка сцены в `smoke.gd` — инстанцирование `main.tscn` в `root` без добавления в дерево, поскольку `smoke.gd` проверяет только наличие узлов и настройки ресурса:

```gdscript
var packed: PackedScene = load("res://main.tscn")
var world: Node3D = packed.instantiate()
_check(packed != null, "main.tscn loads")
```

При `packed == null` скрипт печатает `FATAL` и завершается кодом 1 до любых обращений к узлам.

- [ ] **Step 3: Создать `tests/movement.gd`**

Сцена добавляется в дерево: `root.add_child(world)`, затем `await physics_frame`. Проверки используют `await _physics_frames(n)`, где `n` — число кадров физики; при 120 Гц это `n / 120` секунд. Значения ожиданий из `headless_smoke.gd` сохраняются без изменений: ходьба 5.00 м при 120 кадрах, стрейф `dx > 1.5`, спринт `> walk * 1.3`, высота прыжка `> 0.2` м, pitch в пределах ±89°.

Проверки обзора мышью переносятся **вместе с их предупреждением**: если `Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)` не даёт `Input.MOUSE_MODE_CAPTURED` (headless не умеет захватывать), проверки пропускаются с `[WARN]` и не считаются провалом. Это состояние зафиксировано здесь намеренно и устраняется в Task 4 через `InputGate`, после чего проверка обзора перестаёт зависеть от дисплейного сервера.

- [ ] **Step 4: Создать `tests/integrity.gd`**

Две проверки переносятся из `headless_smoke.gd` без изменений на этом шаге: падение с `y=50` и respawn после падения с `(0, 5, 40)`. Task 6 перепишет первую из них — здесь она нужна только чтобы файл существовал и был зелёным.

- [ ] **Step 5: Прогнать все три файла**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1`
Expected: `smoke`, `movement`, `integrity` — `PASS`; остальные `SKIP`; итог `RESULT: 3 passed, 0 failed, 8 skipped`, код 0. Общее число проверок в `movement.gd` должно совпасть с исходным харнессом минус проверки целостности сцены и не уменьшиться.

- [ ] **Step 6: Удалить `tests/headless_smoke.gd` вместе с `.uid`**

Run: `git rm tests/headless_smoke.gd tests/headless_smoke.gd.uid`
Expected: файл удалён, Godot не создаёт его заново.

- [ ] **Step 7: Прогнать повторно и закоммитить**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1`
Expected: код 0, `smoke` / `movement` / `integrity` зелёные.

```bash
git add tests/   # НЕ КОММИТИТЬ — коммит делает партнёр
```

---

### Task 3: Actions огня, паузы и взаимодействия

**Files:**
- Modify: `project.godot` — секция `[input]`
- Create: `tests/input_actions.gd`

**Interfaces:**
- Consumes: существующая секция `[input]` с `move_*`, `jump`, `sprint`.
- Produces: actions `fire` (ЛКМ, `MOUSE_BUTTON_LEFT`), `pause` (Esc, `physical_keycode == 4194305`), `interact` (E, `physical_keycode == 69`) в `ProjectSettings`. Плюс имена слоёв `1`–`7` в секции `[layer_names]` с ключом `3d_physics/layer_N`.

- [ ] **Step 1: Написать падающую проверку `tests/input_actions.gd`**

Проверяется через `InputMap`, без запуска сцены — поэтому тест не инстанцирует `main.tscn`:

```gdscript
extends SceneTree

func _initialize() -> void:
	print("=== input actions ===")
	for action in ["fire", "pause", "interact"]:
		_check(InputMap.has_action(action), "action %s exists" % action)
		_check(InputMap.action_get_events(action).size() > 0,
			"action %s has at least one event" % action)

	var fire := InputMap.action_get_events("fire")
	_check(fire[0] is InputEventMouseButton
		and (fire[0] as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT,
		"fire is bound to left mouse button")

	var pause := InputMap.action_get_events("pause")
	_check(pause[0] is InputEventKey
		and (pause[0] as InputEventKey).physical_keycode == 4194305,
		"pause is bound to Escape")

	var interact := InputMap.action_get_events("interact")
	_check(interact[0] is InputEventKey
		and (interact[0] as InputEventKey).physical_keycode == 69,
		"interact is bound to E")

	print("=== RESULT: %d checks, %d failed ===" % [_checks, _failures.size()])
	quit(1 if _failures.size() > 0 else 0)
```

Ключевые коды: `4194305` — `KEY_ESCAPE` в физической раскладке, тот же код, что уже используется у существующего `sprint` (`4194325` — `KEY_SHIFT`). Для `fire` поле `button_index` равно `MOUSE_BUTTON_LEFT` (1), в `Object(InputEventMouseButton, …)` сериализуется как `button_index=1`.

- [ ] **Step 2: Убедиться, что проверка падает**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 input_actions`
Expected: `FAIL` на `action fire exists` и код возврата 1.

- [ ] **Step 3: Добавить три actions в `project.godot`**

В секцию `[input]`, после существующего `sprint`, добавить блоки в формате, уже принятом в файле (`physical_keycode`, `location=0`, `echo=false`, `script=null`):

- `fire` — единственное событие `Object(InputEventMouseButton, … button_index=1, pressed=false, location=0, echo=false, script=null)`
- `pause` — `physical_keycode=4194305`
- `interact` — `physical_keycode=69`

- [ ] **Step 4: Объявить имена слоёв коллизий**

Добавить в `project.godot` секцию:

```ini
[layer_names]

3d_physics/layer_1="world"
3d_physics/layer_2="player_body"
3d_physics/layer_3="enemy_body"
3d_physics/layer_4="enemy_hurtbox"
3d_physics/layer_5="projectile"
3d_physics/layer_6="interactable"
3d_physics/layer_7="player_hurtbox"
```

Имена слоёв нужны заранее, чтобы `main.tscn` и `player.tscn` могли ссылаться на них по имени, а не по «голому» числу. Объявление не меняет поведение коллизий — тела остаются `1/1` до Фазы 2.

- [ ] **Step 5: Прогнать и закоммитить**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 input_actions`
Expected: все 9 проверок `PASS`, код 0.

```bash
git add project.godot tests/input_actions.gd   # НЕ КОММИТИТЬ — коммит делает партнёр
```

---

### Task 4: InputGate — чистая функция разрешения ввода

**Files:**
- Create: `scripts/input_gate.gd`
- Create: `tests/input_gate.gd`

**Interfaces:**
- Produces: `class_name InputGate extends RefCounted` со статическим методом
  `static func is_play_input_allowed(mouse_mode: int) -> bool`,
  возвращающим `true` только при `mouse_mode == Input.MOUSE_MODE_CAPTURED` (`2`).
  Метод — **чистая функция одного аргумента**: не читает `Input`, не обращается к сцене. Это делает её тестируемой без дисплейного сервера, что закрывает дефект D2.

- [ ] **Step 1: Написать падающую проверку `tests/input_gate.gd`**

Проверка вызывает функцию напрямую, подставляя значения `mouse_mode`, а не пытаясь захватить мышь:

```gdscript
extends SceneTree

func _initialize() -> void:
	print("=== input gate ===")
	_check(InputGate.is_play_input_allowed(Input.MOUSE_MODE_CAPTURED),
		"input allowed when mouse captured", "(mode=%d)" % Input.MOUSE_MODE_CAPTURED)
	for mode in [Input.MOUSE_MODE_VISIBLE, Input.MOUSE_MODE_CONFINED,
			Input.MOUSE_MODE_CONFINED_HIDDEN, Input.MOUSE_MODE_HIDDEN]:
		_check(not InputGate.is_play_input_allowed(mode),
			"input denied when mouse mode is %d" % mode)

	print("=== RESULT: %d checks, %d failed ===" % [_checks, _failures.size()])
	quit(1 if _failures.size() > 0 else 0)
```

Проверяются **все четыре** не-CAPTURED режима, а не только `VISIBLE`. `MOUSE_MODE_HIDDEN` особенно коварен: курсор не виден, но и не захвачен — ввод при нём тоже обязан быть отключён, иначе игрок бегает при невидимом курсоре.

- [ ] **Step 2: Убедиться, что проверка падает**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 input_gate`
Expected: ошибка загрузки `res://scripts/input_gate.gd` — класс `InputGate` не найден, код возврата 1.

- [ ] **Step 3: Создать `scripts/input_gate.gd`**

```gdscript
class_name InputGate
extends RefCounted

## Разрешён ли игровой ввод.
## Зависит только от переданного режима мыши, чтобы проверяться без
## дисплейного сервера: headless не умеет захватывать курсор.


static func is_play_input_allowed(mouse_mode: int) -> bool:
	return mouse_mode == Input.MOUSE_MODE_CAPTURED
```

- [ ] **Step 4: Прогнать и закоммитить**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 input_gate`
Expected: 5 проверок `PASS`, код 0.

```bash
git add scripts/input_gate.gd tests/input_gate.gd   # НЕ КОММИТИТЬ — коммит делает партнёр
```

---

### Task 5: Гашение ввода и захват курсора по Esc

**Files:**
- Modify: `player.gd`
- Modify: `player.tscn` — только если нужен узел для захвата фокуса окна
- Modify: `tests/movement.gd` — убрать зависимость проверок обзора от дисплейного сервера

**Interfaces:**
- Consumes: `InputGate.is_play_input_allowed(mouse_mode)` из Task 4; actions `fire`, `pause`, `interact` из Task 3.
- Produces: `player.gd` гасит обзор мышью, движение, прыжок, спринт и огонь при `Input.mouse_mode != Input.MOUSE_MODE_CAPTURED`. Захват курсора переключается только action `pause`; ЛКМ захват не переключает. При возврате фокуса окну курсор захватывается обратно.

- [ ] **Step 1: Заменить `_unhandled_input` в `player.gd`**

Новая структура `_unhandled_input(event: InputEvent) -> void`:

- Если `event is InputEventMouseMotion` **и** `InputGate.is_play_input_allowed(Input.mouse_mode)` — текущая логика `rotate_y` / клампинг `Camera3D.rotation.x` на ±89°.
- Если `event.is_action_pressed("pause")` — вызов `_toggle_mouse_capture()`.
- Если `event.is_action_pressed("jump")` **и** ввод разрешён — `_jump_queued = true`.
- Обработка `InputEventMouseButton` с `MOUSE_BUTTON_LEFT` **удаляется полностью**. В `_unhandled_input` она больше не встречается ни в каком виде — это дефект D3.

Проверка ввода на `jump` обязана идти до `_jump_queued = true`: сейчас `event.is_action_pressed("jump")` не гасится, и при свободном курсоре персонаж прыгает.

- [ ] **Step 2: Оградить движение и прыжок в `_physics_process`**

В `_physics_process` после вычисления гравитации и до чтения `Input.get_vector`:

```gdscript
var play_input_allowed := InputGate.is_play_input_allowed(Input.mouse_mode)
```

Далее `_jump_queued` обрабатывается **только** при `play_input_allowed`. Блок чтения `Input.get_vector` и вычисления `current_speed` выполняется при `play_input_allowed`; иначе `velocity.x` и `velocity.z` устанавливаются в `0.0`. Это устраняет остаточное скольжение при отпущенных клавишах и не даёт персонажу ехать при свободном курсоре (дефект D4).

- [ ] **Step 3: Добавить возврат захвата по фокусу окна**

В `_ready()` подключить сигнал `get_tree().root.focus_entered` к методу `_on_focus_entered`, который при `Input.mouse_mode == Input.MOUSE_MODE_VISIBLE` выполняет `Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)`. Метод отключается в `_exit_tree` через `get_tree().root.focus_entered.disconnect(...)` с проверкой `is_connected` — иначе повторный вход в сцену лобби/локации упадёт на «signal already connected».

- [ ] **Step 4: Написать проверки гашения ввода в `tests/movement.gd`**

Тест не может захватить мышь в headless, поэтому проверяется не режим, а то, что гашение действительно происходит. Добавить сценарий: перевести `Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)`, зафиксировать позицию игрока, нажать `move_forward` и `jump` через `Input.action_press`, подождать 60 кадров физики, затем проверить, что позиция по X/Z не изменилась более чем на 0.01 и `player.is_on_floor()` осталось истинным. Вернуть `MOUSE_MODE_CAPTURED` в конце сценария.

Дополнительно проверяется сама функция: `InputGate.is_play_input_allowed(Input.MOUSE_MODE_VISIBLE)` возвращает `false`. Это защищает от регрессии, при которой гейт снова начнут читать `Input.mouse_mode` напрямую в нескольких местах.

- [ ] **Step 5: Упростить проверки обзора в `tests/movement.gd`**

Проверки обзора мышью больше не зависят от `_ensure_mouse_capture()`. Вместо предупреждения при невозможности захвата — прямая проверка: при `MOUSE_MODE_VISIBLE` отправка `InputEventMouseMotion` с `relative = Vector2(100, 0)` **не** меняет `player.rotation.y`; при `MOUSE_MODE_CAPTURED` — меняет. Если headless не может установить `CAPTURED`, проверка для `VISIBLE` всё равно выполняется и должна пройти; проверка для `CAPTURED` при невозможности захвата помечается `[WARN]`. Цель шага — убрать `[WARN]` о невозможности захвата из вывода чистого прогона и перестать считать инвариант обзора непроверяемым.

- [ ] **Step 6: Прогнать и закоммитить**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1`
Expected: `smoke`, `movement`, `input_actions`, `input_gate`, `integrity` — `PASS`; `RESULT: 5 passed, 0 failed, 6 skipped`; код 0. В выводе `movement` не должно быть строк `[WARN]`.

```bash
git add player.gd player.tscn tests/movement.gd   # НЕ КОММИТИТЬ — коммит делает партнёр
```

---

### Task 6: Починка проверки, проходящей по неверной причине

**Files:**
- Modify: `tests/integrity.gd`

**Interfaces:**
- Consumes: kill-plane игрока в `player.gd` (`fall_limit = -50.0`), геометрия пола в `main.tscn` (слой 1, верхняя грань на `y = 0.0`).
- Produces: две проверки, каждая из которых способна упасть при соответствующей поломке. Текущая проверка `y > -50.0` после 2 с с высоты 50 удаляется.

- [ ] **Step 1: Почему текущая проверка не работает**

`_test_fall_off_edge` помещает игрока в `(1000, 50, 1000)` — там нет пола, и за 2 с свободного падения при гравитации по умолчанию он опускается до `y ≈ 30.5`. Условие `y > -50.0` выполняется всегда: провалиться сквозь **мир** проверка не может обнаружить, даже если бы коллизии были сломаны полностью, потому что под точкой `(1000, …)` геометрии нет и падать не через что. Проверка зелёная по построению.

- [ ] **Step 2: Заменить на проверку туннелирования**

Новая проверка «быстрое движение не проваливает пол»:

1. Поставить игрока в `(0, 1.0, 0)`, обнулить `velocity`, дождаться 60 кадров физики — он должен оказаться на полу.
2. Зафиксировать `start_y = player.global_position.y`.
3. Нажать `sprint` и `move_right` одновременно, дать отработать 360 кадрам физики (3 с при 120 Гц, ход 9 м/с пронесёт игрока через край платформы).
4. На каждом кадре обновлять `min_y = minf(min_y, player.global_position.y)`.
5. Отпустить клавиши.
6. Проверка: `min_y > -1.0` — игрок не провалился сквозь пол за всё время движения.

Эта проверка падает, если тело игрока перестанет сталкиваться со слоем 1, если пол исчезнет из сцены, если появится туннелирование на скорости спринта, и если kill-plane сработает на нормальном падении с края платформы. Все четыре поломки — реальные регрессии, а не артефакты теста.

- [ ] **Step 3: Заменить проверку respawn на отрицательную**

Вместо проверки «respawn происходит» добавить проверку «respawn **не** происходит при падении в пределах kill-plane»: игрок прыгает с края платформы на высоту 3 м (фактическое падение заведомо выше `-50`), и проверяется, что он **не** вернулся к точке старта. Затем отдельно проверяется, что падение с `y = 5` в пустоте за 600 кадров **приводит** к возврату.

- [ ] **Step 4: Прогнать и убедиться, что проверки падают при поломке**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 integrity`
Expected: оба файла зелёные, код 0.

Затем временно выставить в `player.gd` `fall_limit = -2.0` и прогнать `.\tools\run_checks.ps1 integrity` — проверка respawn должна упасть. Вернуть `fall_limit = -50.0` и убедиться, что прогон снова зелёный. Это обязательный шаг: он доказывает, что проверка способна падать, а не что она зелёная по построению.

- [ ] **Step 5: Прогнать всё и закоммитить**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1`
Expected: код 0, `RESULT: 5 passed, 0 failed, 6 skipped`.

```bash
git add tests/   # НЕ КОММИТИТЬ — коммит делает партнёрintegrity.gd
```

---

### Task 7: Тени направленного света

**Files:**
- Modify: `main.tscn` — узел `DirectionalLight3D`

**Interfaces:**
- Consumes: существующий `DirectionalLight3D` в `main.tscn` без теней.
- Produces: `shadow_enabled = true`. Тени включают затенение пола и стен, делая читаемой высоту персонажа над полом и границы платформы при прыжке.

- [ ] **Step 1: Включить тени в `main.tscn`**

В узле `[node name="DirectionalLight3D" …]` добавить строку `shadow_enabled = true`. Больше ничего в узле не менять — `light_energy`, `transform` и прочие настройки остаются как есть.

- [ ] **Step 2: Прогнать автопроверки**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1`
Expected: код 0. Тени не влияют на физику, поэтому все проверки остаются зелёными.

- [ ] **Step 3: Захватить кадры из движка**

Тени — визуальное изменение, поэтому требуется визуальная верификация (`CHECKLIST.md`, правило о визуальных проверках).

Run: `& "E:\Godot\Godot_v4.7.2-stable_win64.exe" --path . --script res://tests/capture.gd`
Expected: в выводе строки `SHOT …` для кадров `spawn`, `jump_rise`, `jump_fall`, записанные в `user://captures`. На кадре `jump_rise` под персонажем должна быть видна тень, отделённая от него по высоте — это доказывает, что тени работают.

- [ ] **Step 4: Закоммитить**

```bash
git add main.tscn   # НЕ КОММИТИТЬ — коммит делает партнёр
```

---

## Завершение Фазы 0

Фаза закрыта, когда:

- `.\tools\run_checks.ps1` завершается кодом 0, все 5 существующих проверок зелёные, `[WARN]` в выводе отсутствует.
- Проверка туннелирования проверена на падение при искусственно сломанном kill-plane (Task 6, шаг 4).
- Обзор мышью при свободном курсоре не поворачивает камеру, а движение, прыжок и огонь при свободном курсоре не срабатывают.
- Захват курсора переключается по Esc, ЛКМ стрельбе не мешает.
- Actions `fire`, `pause`, `interact` объявлены, имена слоёв 1–7 объявлены.
- Кадры из `capture.gd` показывают работающие тени.

После закрытия Фазы 0 `CHECKLIST.md` обновляется: раздел 1B отмечается по факту проверок, дефекты D1–D7 переносятся в «Исправлено», D8 остаётся открытым по принятому решению оставить абсолютный путь.

## Что дальше

Фазы 1–5 оформляются отдельными планами — по одной на подсистему, каждая со своим набором задач. Общий каркас уже зафиксирован в спецификации (разделы 6–11). Очередность фаз и параллелизм внутри них не меняются: Фаза 1 (оружие) последовательна, Фаза 3 допускает параллелизм «лобби ∥ сохранение», и карта владения файлами фиксируется до запуска параллельной фазы.