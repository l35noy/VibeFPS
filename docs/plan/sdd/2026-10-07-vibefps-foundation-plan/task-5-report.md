# Task 5 report — input gating and cursor capture on Esc

Project: `E:\projects\VibeFPS` (Godot 4.7.2, GDScript, Jolt Physics)
Files modified: `player.gd`, `tests/movement.gd`. Nothing else.
`player.tscn` was **not** modified — the focus-recapture signal needs no node.
**No `git add`, no `git commit`.** All changes are left unstaged in the working tree.

---

## 1. The finding that shaped the whole task

Under `--headless` the capture the design depends on is not merely hard to observe, it is
**impossible to produce**:

```
PROBE initial mouse_mode=0
PROBE right after set=0        # Input.set_mouse_mode(MOUSE_MODE_CAPTURED)
PROBE after process_frame=0
PROBE after physics_frame=0
PROBE display=headless has_mouse=false
```

`DisplayServer` reports `headless` and has no `FEATURE_MOUSE`, `Input.set_mouse_mode()` is a
silent no-op, and `Input.mouse_mode` stays `VISIBLE (0)` for the entire run even for one frame
after the call. Consequences:

* Any check that asserts "the cursor is captured" can only ever skip itself — the two `[WARN]`
  lines the old harness printed came exactly from that.
* Any check that needs **allowed** play input cannot rely on `Input.mouse_mode == CAPTURED`
  either, because that value is unreachable. Gating movement on `Input.mouse_mode` without a way
  to supply the mode would have failed every existing locomotion check.

So the gate needed exactly one seam, and the harness needed to supply the one value headless
cannot produce. `InputGate.is_play_input_allowed()` was not touched, and the rule itself is not
re-implemented anywhere.

---

## 2. `player.gd` — before / after

### 2.1 `_unhandled_input`

Before:

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:      # rule inlined, read twice below
			return
		var motion := event as InputEventMouseMotion
		rotate_y(-motion.relative.x * mouse_sensitivity)
		_camera.rotation.x = clampf(
			_camera.rotation.x - motion.relative.y * mouse_sensitivity,
			deg_to_rad(-89.0), deg_to_rad(89.0))
	elif event.is_action_pressed("ui_cancel"):                # built-in action, not "pause"
		_toggle_mouse_capture()
	elif event.is_action_pressed("jump"):
		_jump_queued = true                                   # no gate at all (defect D4)
	elif event is InputEventMouseButton and event.pressed:   # defect D3
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			_toggle_mouse_capture()
```

After:

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	# ЛКМ здесь намеренно не обрабатывается: он принадлежит действию fire,
	# которое выстрел реализует на следующей фазе. Захват курсора
	# переключается только действием pause (Esc).
	if event is InputEventMouseMotion:
		if not InputGate.is_play_input_allowed(_mouse_mode_for_play_input()):
			return
		var motion := event as InputEventMouseMotion
		rotate_y(-motion.relative.x * mouse_sensitivity)
		_camera.rotation.x = clampf(
			_camera.rotation.x - motion.relative.y * mouse_sensitivity,
			deg_to_rad(-89.0),
			deg_to_rad(89.0)
		)
	elif event.is_action_pressed("pause"):
		_toggle_mouse_capture()
	elif event.is_action_pressed("jump"):
		# Проверка разрешения идёт до постановки в очередь: при свободном
		# курсоре персонаж не прыгает.
		if InputGate.is_play_input_allowed(_mouse_mode_for_play_input()):
			_jump_queued = true
```

Three branch types remain: mouse motion, `pause`, `jump`. The whole
`InputEventMouseButton` branch is gone — there is no `MOUSE_BUTTON_LEFT`, no
`InputEventMouseButton` token anywhere in `player.gd` (asserted by a check, see §4.6).
`ui_cancel` is gone as well; the game no longer uses any built-in action for capture.

### 2.2 `_physics_process`

Before:

```gdscript
func _physics_process(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta

	if _jump_queued:                       # consumed with no permission check
		_jump_queued = false
		if is_on_floor():
			velocity.y = jump_velocity

	var input_dir := Input.get_vector(...)          # always read
	var direction := (transform.basis * Vector3(...)).normalized()
	var current_speed := speed
	if Input.is_action_pressed("sprint") and input_dir != Vector2.ZERO:
		current_speed *= sprint_multiplier
	velocity.x = direction.x * current_speed
	velocity.z = direction.z * current_speed
	move_and_slide()
	if global_position.y < fall_limit:
		_respawn()
```

After:

```gdscript
func _physics_process(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta

	var play_input_allowed := InputGate.is_play_input_allowed(_mouse_mode_for_play_input())

	# Очередь прыжка съедается всегда, но поднимает персонаж только пока ввод
	# разрешён: прыжок, разрешённый до отпускания курсора, не должен сработать
	# после него.
	if _jump_queued:
		_jump_queued = false
		if play_input_allowed and is_on_floor():
			velocity.y = jump_velocity

	if play_input_allowed:
		var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

		var current_speed := speed
		if Input.is_action_pressed("sprint") and input_dir != Vector2.ZERO:
			current_speed *= sprint_multiplier

		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		# Горизонтальная скорость обнуляется явно, а не остаётся от прошлого
		# кадра: иначе персонаж едет по инерции при свободном курсоре.
		velocity.x = 0.0
		velocity.z = 0.0

	move_and_slide()

	if global_position.y < fall_limit:
		_respawn()
```

Gravity, `move_and_slide()` and the kill plane stay unconditional, so a denied player still
falls, lands, slides and respawns (`tests/integrity.gd` depends on that and still passes).

### 2.3 New: the single place the mouse mode is read for the gate

```gdscript
func _mouse_mode_for_play_input() -> int:
	return Input.mouse_mode
```

The design said the gate must be evaluated against `Input.mouse_mode`, and headless cannot
produce a captured value, so the *value source* is one overridable method instead of three
inlined reads. No test-only flag, counter or override switch exists in the game code — only a
normal virtual method, plus the comment above it explaining why.

### 2.4 New: capture restored on window focus (brief step 3)

```gdscript
func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)   # kept, unchanged
	set_spawn_transform()
	_connect_focus_recapture()

func _exit_tree() -> void:
	_disconnect_focus_recapture()

func _connect_focus_recapture() -> void:
	var window := get_tree().root
	if window != null and not window.focus_entered.is_connected(_on_focus_entered):
		window.focus_entered.connect(_on_focus_entered)

func _disconnect_focus_recapture() -> void:
	var window := get_tree().root if is_inside_tree() else null
	if window != null and window.focus_entered.is_connected(_on_focus_entered):
		window.focus_entered.disconnect(_on_focus_entered)

func _on_focus_entered() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
```

`Window.focus_entered` already exists, so `player.tscn` needed no new node. The
`is_connected` guard is on **both** ends — connect and disconnect — so re-entering the
lobby/location scene cannot raise "signal already connected".

---

## 3. Where a permission check now lives (complete list)

| # | Site | Code | What it gates |
|---|------|------|----------------|
| 1 | `_unhandled_input`, `InputEventMouseMotion` branch | `if not InputGate.is_play_input_allowed(_mouse_mode_for_play_input()): return` | yaw + pitch |
| 2 | `_unhandled_input`, `jump` branch | `if InputGate.is_play_input_allowed(...): _jump_queued = true` | queueing a jump |
| 3 | `_physics_process`, top | `var play_input_allowed := InputGate.is_play_input_allowed(_mouse_mode_for_play_input())` | feeds 4 and 5 |
| 4 | `_physics_process`, jump consume | `if play_input_allowed and is_on_floor(): velocity.y = jump_velocity` | the second half of the jump queue |
| 5 | `_physics_process`, movement | `if play_input_allowed:` … `else: velocity.x = 0.0; velocity.z = 0.0` | movement **and** sprint (sprint is only read inside the allowed branch) |

`Input.mouse_mode` is read in exactly three places, none of them a permission decision:

* `_mouse_mode_for_play_input()` — the gate's value source (the only source, see §2.3);
* `_toggle_mouse_capture()` — a capture state machine, it must read the real mode;
* `_on_focus_entered()` — checks whether the cursor was left visible.

The two permission decisions outside `_physics_process` and the value they consult are all
funnelled through `InputGate.is_play_input_allowed()`. The rule is written once, in Task 4.

---

## 4. `tests/movement.gd` — assertions and how each one can fail

The harness loads `res://main.tscn`, takes the scene's real `Player` node, and swaps its
script **before** the node enters the tree for a 14-line subclass of `player.gd`:

```gdscript
class _PlayerProbe extends "res://player.gd":
	var gate_mouse_mode: int = Input.MOUSE_MODE_CAPTURED
	var capture_toggles: int = 0

	func _mouse_mode_for_play_input() -> int:
		return gate_mouse_mode          # the only thing the harness supplies

	func _toggle_mouse_capture() -> void:
		capture_toggles += 1            # spy
		super()
```

Real node, real exports, real collision shape, real `player.gd` movement/look/jump logic,
real `InputGate`. Only the mouse mode value comes from the harness. The swap happens before
`root.add_child(world)`, so `@onready`/`_ready` run on the probe script and the camera is
still wired. Every check states the mode it needs up front, so no check depends on order.

Assertion count went from **20 checks / 2 warnings** to **52 checks / 0 warnings**.

### 4.1 `_test_gate_harness` — the harness itself is under test (6)

* `player.get_script() == _PlayerProbe` — the swap actually happened.
* harness can drive `gate_mouse_mode` — the seam is writable.
* `Input.mouse_mode == MOUSE_MODE_VISIBLE` — **precondition guard**: if a future engine can
  capture headless, this fails and the harness must be rethought. It documents *why* the
  probe exists instead of hiding it.
* unmodified `player.tscn` instance answers `_mouse_mode_for_play_input() == Input.mouse_mode`
  — closes the hole where the probe could be lying: the game's own implementation still reads
  the engine's mode.
* `InputGate.is_play_input_allowed(CAPTURED) == true`, `... (VISIBLE) == false` — the brief's
  explicit regression guard against the rule drifting.

### 4.2 Locomotion (unchanged in substance, now run with the gate open) (17)

idle / walk / strafe / sprint / jump / jump height / jump-action-event / release check. Each
keeps its original tolerance (`walk ~5 m`, `strafe dx > 1.5`, `sprint > walk * 1.3`,
`apex > 0.2 m`, `|vx| < 0.01`). They can fail exactly as before — and now they *also* prove
the allowed path of the gate is real, which is what makes the denied half meaningful.

### 4.3 `_test_mouse_look` (3) and `_test_mouse_uncaptured` (4)

`_ensure_mouse_capture()` and both `[WARN]`s are deleted. The captured case is driven by the
probe instead of the OS: yaw must change, pitch must clamp at ±89°.
The uncaptured case sends a motion with **both axes non-zero** (`Vector2(200, 50)`) and
asserts yaw and pitch are unchanged, then restores capture and asserts *both* change again.
The two-sided axis choice matters: with a horizontal-only event the pitch could not change
even with the gate wide open, which would have made that assertion pass for the wrong reason.

### 4.4 `_test_play_input_denied_while_uncaptured` (7) — brief step 4

Positive control first, same input, gate open: 60 physics frames at 120 Hz with
`move_forward` + `sprint` must move **4.50 m** (5 m/s × 1.8 × 0.5 s). Without this the denied
half would pass even if the harness could not drive input at all.
Then the position is reset, the floor is re-asserted, the gate is set to `VISIBLE`, and the
identical input runs again:

* XZ displacement `<= 0.01 m` (measured: 0.0000; with the gate broken: 4.5004)
* `|vx| < 0.01 and |vz| < 0.01` — the no-coasting invariant (broken: 6.7060, 6.0024)
* `is_on_floor()` — no jump (broken: off floor)
* `|vy| < 0.01` — no upward velocity at all (broken: 0.2633)

### 4.5 `_test_queued_jump_not_fired_after_release` (5) — the "both halves" requirement

With the gate open, a real jump event is sent, then:

* `Input.flush_buffered_events()` — necessary, because Godot accumulates parsed events and
  dispatches them at the start of the next main-loop iteration. Without the flush, the jump
  never reaches `_unhandled_input` before the cursor is released, and the whole check would
  pass for the wrong reason.
* **`jump was queued while the cursor was captured`** — reads `player._jump_queued` and
  *requires it to be true*. This is the assertion that makes the rest falsifiable: it fails
  if the queue was never filled, so the following checks cannot pass vacuously.
* gate set to `VISIBLE`, then 60 physics frames: the queue must be consumed
  (`not _jump_queued`), the player must still be on the floor, and `vy <= 0.01`.

### 4.6 `_test_capture_toggle_binding` (4) and `_test_player_source_contract` (5)

The spy makes capture toggling observable, which it otherwise is not headless:

* `pause` action event must increment the toggle counter (was 0 on the old `ui_cancel` wiring).
* LMB press must **not** increment it — and must reach the `fire` action instead
  (`Input.is_action_pressed("fire")`), releasing it clears the action.
* source contract on `player.gd`: no `ui_cancel`, no `InputEventMouseButton`,
  `InputGate.is_play_input_allowed(` appears at least twice, and
  `_mouse_mode_for_play_input() -> int` is defined exactly once — so the gate value cannot be
  quietly re-inlined in several places.

---

## 5. Verification

### 5.1 Required full run — `RESULT: 5 passed, 0 failed, 6 skipped`, exit 0, zero `[WARN]`

```
$ powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1
smoke          PASS
movement       PASS
input_actions  PASS
input_gate     PASS
integrity      PASS
weapon         [SKIP]  (tests\weapon.gd not present)
projectile     [SKIP]  (tests\projectile.gd not present)
enemies        [SKIP]  (tests\enemies.gd not present)
waves          [SKIP]  (tests\waves.gd not present)
save           [SKIP]  (tests\save.gd not present)
progression    [SKIP]  (tests\progression.gd not present)

RESULT: 5 passed, 0 failed, 6 skipped
RUN_EXIT=0
WARN lines in full output: 0
```

### 5.2 Direct run of `tests/movement.gd` with Godot

```
$ E:\Godot\Godot_v4.7.2-stable_win64.exe --headless --path . --script res://tests/movement.gd
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

=== VibeFPS movement test ===
    display=headless  Input.mouse_mode=0 (CAPTURED=2)
-- gate harness: the probe is live and player.gd gates on Input.mouse_mode
  [PASS] scene Player runs the harness probe script 
  [PASS] harness can drive the gate mode 
  [PASS] precondition: headless really cannot capture the cursor (mouse_mode=0)
  [PASS] player.gd gates on the engine's own Input.mouse_mode 
  [PASS] gate allows play input while the cursor is captured 
  [PASS] gate denies play input while the cursor is free 
-- idle (captured): should settle on floor and stop moving
  [PASS] player is on floor after settling 
  [PASS] vertical velocity zero while idle (vy=0.000)
  [PASS] player did not fall through floor (y=0.000)
-- walk forward (W) for 1s
  [PASS] walk distance ~5m (got 5.00 m)
  [PASS] still on floor after walking 
-- strafe right (D) for 0.5s, should move on X
  [PASS] strafing moves along X (dx=2.50)
-- sprint (Shift+W) should be faster than walk
    walk=5.00 m, sprint=9.00 m
  [PASS] sprint meaningfully faster than walk 
-- jump (Space key event): leaves floor and lands again
  [PASS] on floor before jump 
  [PASS] player left the floor after jump 
  [PASS] upward velocity applied (vy=4.35)
  [PASS] player landed back on floor 
-- jump apex height measurement
    apex=1.297 m above ground
  [PASS] jump produced measurable height 
  [PASS] returned to floor after apex test 
-- jump (non-key InputEventAction): gamepad/virtual input must also jump
  [PASS] on floor before action jump 
  [PASS] player left the floor after action jump 
  [PASS] action jump applied upward velocity (vy=4.35)
  [PASS] landed back on floor after action jump 
-- mouse look (captured): yaw and pitch respond and clamp
  [PASS] yaw changed on horizontal mouse motion (dyaw=-1.7168)
  [PASS] pitch clamped within +-89 deg (pitch=-89.00 deg)
  [PASS] pitch clamped on upward motion too (pitch=89.00 deg)
-- mouse uncaptured: mouse motion must NOT rotate the camera
  [PASS] yaw unchanged while mouse uncaptured (dyaw=0.0000)
  [PASS] pitch unchanged while mouse uncaptured (dpitch=0.0000)
  [PASS] yaw rotates again once mouse is recaptured (dyaw=2.8496)
  [PASS] pitch rotates again once mouse is recaptured (dpitch=-1.5533)
-- input gating: a free cursor denies move, sprint and jump
  [PASS] on floor before the gating check 
    captured: moved 4.50 m
  [PASS] captured cursor moves the player with the same input (moved 4.50 m)
  [PASS] back on floor before the denied half 
    uncaptured: moved 0.0000 m
  [PASS] free cursor does not move the player (moved 0.0000 m)
  [PASS] horizontal velocity zeroed while input is denied, no coasting (v=0.0000, 0.0000)
  [PASS] free cursor does not jump the player 
  [PASS] vertical velocity zeroed while input is denied (vy=0.0000)
-- queued jump: allowed before release, must not fire after it
  [PASS] on floor before the queued jump 
  [PASS] jump was queued while the cursor was captured 
  [PASS] the queued jump is consumed, not left hanging 
  [PASS] the queued jump does not fire after the cursor is released 
  [PASS] no upward velocity after the cursor is released (vy=0.000)
-- capture toggle: pause toggles it, left mouse button must not
  [PASS] pause action toggles mouse capture (toggles=1)
  [PASS] left mouse button reaches the fire action 
  [PASS] left mouse button does NOT toggle mouse capture (toggles=0)
  [PASS] releasing left mouse button clears the fire action 
-- source contract: old capture wiring must stay out of player.gd
  [PASS] player.gd is readable (4546 bytes)
  [PASS] player.gd does not use the built-in ui_cancel action 
  [PASS] player.gd has no InputEventMouseButton branch 
  [PASS] player.gd asks InputGate for permission in both input paths (call sites=3)
  [PASS] player.gd reads Input.mouse_mode for the gate in exactly one method 
-- release check: no residual horizontal velocity after input release
  [PASS] horizontal velocity zeroed after release (v=0.000, 0.000)

=== RESULT: 52 checks, 0 failed, 0 warnings ===
EXITCODE=0
```

Machine-checked on that same output: lines containing `[WARN]` = **0**, lines containing
`[FAIL]` = **0**, engine `WARNING` lines = **0** (the only match for the substring "WARNING"
is the harness's own `0 warnings` in the RESULT line). Previously: 20 checks, 2 warnings.

### 5.3 Deliberate failure A — `InputGate.is_play_input_allowed` forced to `return true`

The file was backed up first (`scripts/` is untracked, so git cannot restore it) and restored
from that copy afterwards; SHA-256 `1AB4864D…9F60` confirmed identical before and after.

```
$ powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 movement
movement       FAIL  (exit code 1)
      [FAIL] gate denies play input while the cursor is free 
      [FAIL] yaw unchanged while mouse uncaptured (dyaw=2.8496)
      [FAIL] pitch unchanged while mouse uncaptured (dpitch=-1.5533)
      [FAIL] free cursor does not move the player (moved 4.5004 m)
      [FAIL] horizontal velocity zeroed while input is denied, no coasting (v=6.7060, 6.0024)
      [FAIL] free cursor does not jump the player 
      [FAIL] vertical velocity zeroed while input is denied (vy=0.2633)
      [FAIL] the queued jump does not fire after the cursor is released 
      [FAIL] no upward velocity after the cursor is released (vy=0.182)
    === RESULT: 52 checks, 9 failed, 0 warnings ===
RESULT: 0 passed, 1 failed, 0 skipped
RUN_EXIT=1
```

9 assertions fail, exit 1. Note the interesting detail: the jump *is* still queued while the
gate is open, so `_jump_queued` still reads true and only the "does not fire after release"
half fails — the check isolates the second half of the queue as intended.

### 5.4 Deliberate failure B — LMB capture branch re-added to `player.gd`

```
$ powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 movement
movement       FAIL  (exit code 1)
      [FAIL] left mouse button does NOT toggle mouse capture (toggles=1)
      [FAIL] player.gd has no InputEventMouseButton branch 
    === RESULT: 52 checks, 2 failed, 0 warnings ===
RESULT: 0 passed, 1 failed, 0 skipped
RUN_EXIT=1
```

Both the behavioural spy and the source contract catch the regression. `player.gd` was
restored from a backup copy, SHA-256 `B98D7D01…CF08B` confirmed identical, and the full suite
returned to `RESULT: 5 passed, 0 failed, 6 skipped`, exit 0.

### 5.5 Two real bugs this process caught (both in the harness, both fixed)

* Reusing one `InputEventMouseMotion` object for two dispatches produced `dyaw=0.0000` on the
  recaptured leg: Godot accumulates parsed input and `accumulate()` folds values into the
  queued event **in place**, so the second send was not reproducible. Fixed with a fresh
  `_mouse_motion_event()` per dispatch, documented in the helper.
* The pitch-unchanged assertion originally used a horizontal-only event and could never fail
  (a Y-only clamp is what moves pitch). Tightened to `Vector2(200, 50)` in both directions,
  and the tightened assertion was then re-proven to fail in mutation A.

### 5.6 Working tree

```
$ git status --short
 M player.gd
 M project.godot
 M tests/movement.gd
 M tools/run_checks.ps1
?? scripts/
?? tests/input_actions.gd
?? tests/input_actions.gd.uid
?? tests/input_gate.gd
?? tests/input_gate.gd.uid
?? tests/integrity.gd.uid
?? tests/movement.gd.uid
?? tests/smoke.gd.uid

$ git diff --cached --name-only      # (empty — nothing staged)
$ git log --oneline -2
ed35408 build: add single-command test runner and split harness by subsystem
1651dce +тесты чеклист проект
```

Only `player.gd` and `tests/movement.gd` are new modifications; `project.godot`,
`tools/run_checks.ps1`, `scripts/` and the other harnesses were already dirty/untracked from
Tasks 3 and 4 before I started. `git diff --stat` for my two files:
`player.gd | 82 +-`, `tests/movement.gd | 339 +-`. **Nothing staged, nothing committed.**

---

## 6. Decisions the brief left open

1. **How the gate gets its value.** The brief writes `InputGate.is_play_input_allowed(Input.mouse_mode)`
   inline, which is unreachable under headless (proved in §1). I extracted a single
   `_mouse_mode_for_play_input()` method that returns `Input.mouse_mode` and is the *only*
   reader of it for permission purposes; the harness overrides just that method. This keeps
   "every permission decision goes through `InputGate`" true, avoids re-implementing the rule,
   and puts no test-only flag or counter in the game code. The subclass also spies on
   `_toggle_mouse_capture()` — an ordinary virtual override, not production instrumentation.
2. **Jump in the denied-input check.** The brief says press `jump` with `Input.action_press`.
   That cannot work: the player reads jump in `_unhandled_input`, and `Input.action_press()`
   only sets InputMap state, never delivering an event. I send a real `InputEventKey` for the
   jump half (and keep `action_press` for move/sprint, which *is* read via
   `Input.get_vector`). This strengthens the check rather than weakening it — with
   `action_press`, the jump assertion would have passed without ever being exercised.
3. **Queued-jump test needs a synchronous flush.** Godot buffers parsed input until the next
   main-loop iteration, which is *before* the next physics step, so there is no signal between
   "event delivered" and "queue consumed". `Input.flush_buffered_events()` gives the harness
   that window; without it the "was it queued?" assertion fails (it did, before the fix).
4. **`_on_focus_entered` condition.** Implemented literally as the brief specifies:
   recapture only when the mode is exactly `MOUSE_MODE_VISIBLE`, so a `CONFINED` mode set by
   anything else is not fought. It reads `Input.mouse_mode` directly, which is correct there:
   it is a capture-state decision, not a play-input permission decision.
5. **`fire` is not consumed yet.** LMB now reaches the `fire` action and nothing in
   `player.gd` handles it (checked: an LMB press raises `Input.is_action_pressed("fire")`).
   The weapon that consumes it is Phase 1 work and must apply
   `InputGate.is_play_input_allowed(player._mouse_mode_for_play_input())` itself before firing.
   `interact` is likewise untouched here. Noted so the requirement is not silently lost.
6. **`player.tscn` untouched** — the focus signal needs no node.
7. **Language.** `player.gd` comments in Russian, matching `scripts/input_gate.gd`;
   `tests/movement.gd` comments in English, matching the other harnesses.

## 7. Not done / out of scope

No file outside `player.gd` and `tests/movement.gd` was modified. `project.godot`,
`tools/run_checks.ps1`, `scripts/input_gate.gd`, `scripts/`, `tests/smoke.gd`,
`tests/integrity.gd`, `tests/input_actions.gd`, `tests/input_gate.gd` are byte-identical to
how I found them. No `.uid` file was created, deleted or edited.