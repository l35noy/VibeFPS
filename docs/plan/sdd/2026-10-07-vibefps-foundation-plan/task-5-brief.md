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

