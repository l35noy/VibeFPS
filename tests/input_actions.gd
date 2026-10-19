extends SceneTree

## Проверка InputMap для VibeFPS.
## Проверяет, что действия fire / pause / interact / reload / inventory,
## объявленные в project.godot, существуют и привязаны к нужным клавишам.
## Читает ProjectSettings только через InputMap и не инстанцирует сцены.
## Запуск: godot --headless --path . --script res://tests/input_actions.gd
##         .\tools\run_checks.ps1 input_actions

var _failures: PackedStringArray = []
var _warnings: PackedStringArray = []
var _checks := 0


func _check(ok: bool, label: String, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  [PASS] %s %s" % [label, detail])
	else:
		_failures.append("%s %s" % [label, detail])
		print("  [FAIL] %s %s" % [label, detail])


func _warn(label: String) -> void:
	_warnings.append(label)
	print("  [WARN] %s" % label)


func _initialize() -> void:
	print("=== Действия ввода (InputMap) ===")
	for action in ["fire", "pause", "interact"]:
		_check(InputMap.has_action(action), "действие %s существует" % action)
		_check(InputMap.action_get_events(action).size() > 0,
			"действие %s имеет как минимум одно событие" % action)

	var fire := InputMap.action_get_events("fire")
	_check(fire.size() > 0
			and fire[0] is InputEventMouseButton
			and (fire[0] as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT,
		"fire привязано к левой кнопке мыши")

	# 4194305 — это KEY_ESCAPE в физических скан-кодах Godot (не зависящих от раскладки)
	var pause := InputMap.action_get_events("pause")
	_check(pause.size() > 0
			and pause[0] is InputEventKey
			and (pause[0] as InputEventKey).physical_keycode == 4194305,
		"pause привязано к клавише Escape")

	var interact := InputMap.action_get_events("interact")
	_check(interact.size() > 0
			and interact[0] is InputEventKey
			and (interact[0] as InputEventKey).physical_keycode == 69,
		"interact привязано к клавише E")

	# 82 — KEY_R в физических кодах клавиш Godot. Перезарядка обязана быть physical,
	# чтобы работать независимо от активной раскладки клавиатуры в ОС.
	_check(InputMap.has_action("reload"), "действие reload существует")
	var reload := InputMap.action_get_events("reload")
	_check(reload.size() > 0, "действие reload имеет как минимум одно событие")
	_check(reload.size() > 0
			and reload[0] is InputEventKey
			and (reload[0] as InputEventKey).physical_keycode == 82,
		"reload привязано к физической клавише R (82)")
	_check(reload.size() > 0
			and reload[0] is InputEventKey
			and (reload[0] as InputEventKey).keycode == 0,
		"reload использует только физический код (не зависит от раскладки)")

	# 73 — KEY_I в физических кодах клавиш Godot для инвентаря.
	_check(InputMap.has_action("inventory"), "действие inventory существует")
	var inventory := InputMap.action_get_events("inventory")
	_check(inventory.size() > 0, "действие inventory имеет как минимум одно событие")
	_check(inventory.size() > 0
			and inventory[0] is InputEventKey
			and (inventory[0] as InputEventKey).physical_keycode == 73,
		"inventory привязано к физической клавише I (73)")
	_check(inventory.size() > 0
			and inventory[0] is InputEventKey
			and (inventory[0] as InputEventKey).keycode == 0,
		"inventory использует только физический код (не зависит от раскладки)")

	print("=== РЕЗУЛЬТАТ: %d проверок, %d провалено ===" % [_checks, _failures.size()])
	for f in _failures:
		print("  ОШИБКА: %s" % f)
	quit(1 if _failures.size() > 0 else 0)