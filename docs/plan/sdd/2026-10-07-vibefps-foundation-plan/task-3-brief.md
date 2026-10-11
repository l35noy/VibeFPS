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

