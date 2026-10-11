> **Назначение:** Отчёт по задаче фазы.

# Task 3 Report — fire / pause / interact actions + collision layer names

**Status: DONE**
**Nothing was committed.** No `git commit`, no `git add`, no staging. All changes are left in the working tree for the project owner.

---

## 1. Files changed

| File | Change |
|---|---|
| `project.godot` | Modified — three actions appended to `[input]`, new `[layer_names]` section |
| `tests/input_actions.gd` | Created — new InputMap harness |

No other file was touched. `player.gd`, `main.tscn`, `player.tscn`, `tools/run_checks.ps1`, `tests/smoke.gd`, `tests/movement.gd`, `tests/integrity.gd` are untouched. `$Tests` in the runner was not added to or reordered.

---

## 2. Exact action entries added to `project.godot`

Appended to the `[input]` section, immediately after the existing `sprint` block, in the same serialization the file already uses (`"deadzone": 0.5`, one-element `events` array, `resource_local_to_scene`/`resource_name`/`device`/`window_id`/modifier booleans, `script=null`):

```ini
fire={
"deadzone": 0.5,
"events": [Object(InputEventMouseButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"button_mask":0,"position":Vector2(0, 0),"global_position":Vector2(0, 0),"factor":1.0,"button_index":1,"canceled":false,"pressed":false,"double_click":false,"script":null)
]
}
pause={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194305,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
interact={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":69,"key_label":0,"unicode":101,"location":0,"echo":false,"script":null)
]
}
```

Notes on field values:

- `fire` uses the full `InputEventMouseButton` property set (`button_mask`, `position`, `global_position`, `factor`, `canceled`, `double_click`) rather than the abbreviated shape shown in the brief. Godot round-trips both, but the editor's own serialization is the full set, so this keeps the file byte-identical to what the editor would write and avoids a spurious whole-file reformat on the next save. `button_index=1` is `MOUSE_BUTTON_LEFT`, exactly as the brief requires.
- `pause`: `physical_keycode=4194305` (`KEY_ESCAPE`). `unicode=0` matches the existing `sprint` entry, which also binds a non-printable physical key.
- `interact`: `physical_keycode=69` (`KEY_E`). `unicode=101` is `'e'`, matching how the existing letter bindings (`move_forward` unicode=119, `move_left` unicode=97, …) carry the printable character alongside the physical code. `physical_keycode` is what the test asserts, so `unicode` is informational only.
- `keycode=0` on all three, i.e. physical-only binding, consistent with every pre-existing action. This matters for non-QWERTY layouts.

The six pre-existing actions (`move_forward`, `move_backward`, `move_left`, `move_right`, `jump`, `sprint`) are byte-for-byte unchanged.

## 3. Layer-names section

Added between `[input]` and `[physics]` (Godot writes `[layer_names]` in alphabetical section order, so this is where the editor would put it):

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

Names are exactly as the brief specifies. This is **naming only** — no collision behaviour changed. Every body in the project remains on default layer 1 with the default mask until Phase 2. No node, scene, or `.tscn` file was moved to a different layer in this task.

## 4. Test assertion list — `tests/input_actions.gd`

Standalone `extends SceneTree` script. Reads `InputMap` directly; **does not** load or instantiate `main.tscn`. Contains a verbatim copy of the `_check` helper and the `_failures` / `_checks` declarations from `tests/smoke.gd` (per instruction, no shared module was extracted). `_warnings` / `_warn` were copied alongside for consistency with the other harnesses; they are unused by this check and emit no output.

Nine assertions, each of which can fail:

1. `action fire exists` — `InputMap.has_action("fire")`
2. `action fire has at least one event` — `InputMap.action_get_events("fire").size() > 0`
3. `action pause exists`
4. `action pause has at least one event`
5. `action interact exists`
6. `action interact has at least one event`
7. `fire is bound to left mouse button` — event 0 `is InputEventMouseButton` **and** `button_index == MOUSE_BUTTON_LEFT`
8. `pause is bound to Escape` — event 0 `is InputEventKey` **and** `physical_keycode == 4194305`
9. `interact is bound to E` — event 0 `is InputEventKey` **and** `physical_keycode == 69`

Terminates with `quit(1 if _failures.size() > 0 else 0)` after printing `=== RESULT: %d checks, %d failed ===` and echoing each failure.

**Deviation from the brief snippet, deliberate:** the brief's three binding assertions index `fire[0]` / `pause[0]` / `interact[0]` unconditionally. With no actions present (the pre-implementation state) that is an out-of-bounds index on an empty array, which aborts the script with a runtime error instead of reporting the intended `FAIL` lines and `quit(1)`. Each binding assertion is therefore short-circuited with `size() > 0 and …` first. This only ever converts a hard crash into a recorded failure; it cannot make a bad binding pass. Result: the pre-implementation run reports all nine assertions as `FAIL` and exits 1 cleanly, which is what the brief's Step 2 asks for.

## 5. Verification

### Step A — check fails before implementation

`powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 input_actions` (run with `tests/input_actions.gd` written, `project.godot` not yet edited):

```
input_actions  FAIL  (exit code 1)
      [FAIL] action fire exists
      [FAIL] action fire has at least one event
      [FAIL] action pause exists
      [FAIL] action pause has at least one event
      [FAIL] action interact exists
      [FAIL] action interact has at least one event
      [FAIL] fire is bound to left mouse button
      [FAIL] pause is bound to Escape
      [FAIL] interact is bound to E
    === RESULT: 9 checks, 9 failed ===

RESULT: 0 passed, 1 failed, 0 skipped
EXIT=1
```

### Step B — full suite after implementation

`powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1`:

```
smoke          PASS
movement       PASS
input_actions  PASS
input_gate     [SKIP]  (tests\input_gate.gd not present)
integrity      PASS
weapon         [SKIP]  (tests\weapon.gd not present)
projectile     [SKIP]  (tests\projectile.gd not present)
enemies        [SKIP]  (tests\enemies.gd not present)
waves          [SKIP]  (tests\waves.gd not present)
save           [SKIP]  (tests\save.gd not present)
progression    [SKIP]  (tests\progression.gd not present)

RESULT: 4 passed, 0 failed, 7 skipped
EXIT=0
```

Matches the required result exactly, exit 0.

**Explicit confirmation on the three pre-existing harnesses:** `smoke` PASS, `movement` PASS, `integrity` PASS after the `project.godot` edit. The edit did not disturb them. The `integrity` harness in particular loads and re-saves `project.godot` content, and it still passes.

### Step C — deliberate failure proves the check is not vacuous

Temporarily changed `pause`'s binding from `physical_keycode=4194305` to `4194306` (Escape+1, a key that exists but is not Escape):

`powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 input_actions`:

```
input_actions  FAIL  (exit code 1)
      [PASS] action fire exists
      [PASS] action fire has at least one event
      [PASS] action pause exists
      [PASS] action pause has at least one event
      [PASS] action interact exists
      [PASS] action interact has at least one event
      [PASS] fire is bound to left mouse button
      [FAIL] pause is bound to Escape
      [PASS] interact is bound to E
    === RESULT: 9 checks, 1 failed ===
      FAILURE: pause is bound to Escape

RESULT: 0 passed, 1 failed, 0 skipped
EXIT=1
```

Exactly one assertion flipped — the keycode equality is genuinely read from the live `InputMap`, not inferred from the action's existence. Restored `4194305` and re-ran the full suite: back to `RESULT: 4 passed, 0 failed, 7 skipped`, exit 0.

### Step D — working tree

`git status --short`:

```
 M project.godot
?? tests/input_actions.gd
?? tests/integrity.gd.uid
?? tests/movement.gd.uid
?? tests/smoke.gd.uid
```

Only `project.godot` (modified) and `tests/input_actions.gd` (new) are mine. `git diff --cached --stat` is empty — nothing staged. `git log --oneline -1` still reads `ed35408 build: add single-command test runner and split harness by subsystem` — the pre-existing HEAD, so I created no commit.

The three `.uid` files are untracked artifacts Godot 4.4+ generates for `.gd` scripts; `smoke`/`movement`/`integrity` had already produced theirs in earlier work and they were present in `git status` before I started. They are not mine to delete and not mine to commit. `tests/input_actions.gd.uid` has not been generated yet — Godot will write one the first time the script is opened in the editor; it is not produced by the `--script` headless path. Flagging so the owner is not surprised by it at commit time.

## 6. Decisions the brief left open

1. **Full `InputEventMouseButton` serialization for `fire`.** The brief abbreviated it as `button_index=1, pressed=false, location=0, echo=false`. `location` and `echo` are `InputEventKey` fields and do not exist on `InputEventMouseButton`, so the abbreviated form was carried over loosely. Wrote the editor's real full property set instead. `button_index=1` — the value the test asserts — is unchanged.
2. **`unicode=101` on `interact`.** The brief specified only `physical_keycode=69`. Added the printable character to match the existing letter-action convention in the file. Inert for the test and for physical-key input.
3. **`size() > 0` short-circuit on the three binding assertions.** Explained in section 4. Required to satisfy the brief's own Step 2 expectation.
4. **Section placement of `[layer_names]`.** Inserted between `[input]` and `[physics]` to match Godot's alphabetical section ordering, so a future editor save does not reorder the file.
5. **No assertions on layer names.** The brief's test scope is bindings only, and the runner must report a specific pass count. `layer_names` is verified by the `integrity` harness's project-settings round-trip; adding checks here would have changed the expected totals. The names were transcribed verbatim from the brief and verified visually against them.