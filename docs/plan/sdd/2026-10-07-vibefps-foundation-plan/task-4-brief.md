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

