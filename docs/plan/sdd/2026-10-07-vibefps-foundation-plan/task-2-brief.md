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
git add tests/
git commit -m "test: split monolithic smoke harness by subsystem"
```

---

