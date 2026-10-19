extends SceneTree

## Проверка шлюза ввода (InputGate) для VibeFPS.
## В headless-режиме DisplayServer не может захватывать мышь, поэтому проверка
## не обращается к Input.mouse_mode напрямую, а передаёт режим мыши
## в чистую функцию InputGate.is_play_input_allowed().
## Запуск: godot --headless --path . --script res://tests/input_gate.gd
##         .\tools\run_checks.ps1 input_gate

var _failures: PackedStringArray = []
var _checks := 0


func _check(ok: bool, label: String, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  [PASS] %s %s" % [label, detail])
	else:
		_failures.append("%s %s" % [label, detail])
		print("  [FAIL] %s %s" % [label, detail])


func _initialize() -> void:
	print("=== Шлюз ввода (InputGate) ===")
	_check(InputGate.is_play_input_allowed(Input.MOUSE_MODE_CAPTURED),
		"ввод разрешён при захваченном курсоре (CAPTURED)", "(mode=%d)" % Input.MOUSE_MODE_CAPTURED)
	# Все четыре незахваченных режима: VISIBLE, CONFINED, CONFINED_HIDDEN, HIDDEN.
	# При скрытом (HIDDEN), но не захваченном курсоре ввод также должен быть запрещён.
	for mode in [Input.MOUSE_MODE_VISIBLE, Input.MOUSE_MODE_CONFINED,
			Input.MOUSE_MODE_CONFINED_HIDDEN, Input.MOUSE_MODE_HIDDEN]:
		_check(not InputGate.is_play_input_allowed(mode),
			"ввод запрещён при режиме мыши %d" % mode)

	print("=== РЕЗУЛЬТАТ: %d проверок, %d провалено ===" % [_checks, _failures.size()])
	for f in _failures:
		print("  ОШИБКА: %s" % f)
	quit(1 if _failures.size() > 0 else 0)