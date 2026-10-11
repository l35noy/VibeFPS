> **Назначение:** Отчёт по задаче фазы.

# Task 2 report: split monolithic smoke harness by subsystem

**Status:** DONE
**Commit:** `a1be5c08b4357b422d2a276beaa6f1467ebed75f` — `test: split monolithic smoke harness by subsystem`
**Files changed:** `tests/smoke.gd`, `tests/movement.gd`, `tests/integrity.gd` (new), `tests/headless_smoke.gd` + `tests/headless_smoke.gd.uid` (deleted via `git rm`). No other file was touched.

---

## 1. Baseline

Ran the original harness before touching anything, to fix the reference numbers:

```
$ & "E:\Godot\Godot_v4.7.2-stable_win64.exe" --headless --path . --script res://tests/headless_smoke.gd
...
=== RESULT: 31 checks, 0 failed, 2 warnings ===
EXITCODE=0
```

Per-section counts measured from that baseline run:

| section | checks |
|---|---|
| `_test_scene_setup` | 3 |
| `_test_sky_background` | 3 |
| `_test_idle` | 3 |
| `_test_walk_forward` | 2 |
| `_test_strafe` | 1 |
| `_test_sprint` | 1 |
| `_test_jump` | 4 |
| `_test_jump_height` | 2 |
| `_test_jump_action_event` | 4 |
| `_test_fall_off_edge` | 1 |
| `_test_fall_recovery` | 4 |
| `_test_mouse_look` | 0 (2 assertions never reached headless — see §4) |
| `_test_mouse_uncaptured` | 2 (1 assertion never reached headless — see §4) |
| `_test_no_stuck_velocity` | 1 |
| **total** | **31** |

Two checks in the original are only counted on their failure path: `WorldEnvironment has no Environment resource` (appends to `_failures`, bumps `_checks`, returns early) and the `_test_mouse_look` / `_test_mouse_uncaptured` `cam == null` guards (which append a failure without bumping `_checks`). They are carried over byte-identically, so they do not change the 31.

---

## 2. Check-to-file map

### `tests/smoke.gd` — 6 checks

| check | source |
|---|---|
| Floor node exists | `_test_scene_setup` |
| WorldEnvironment exists | `_test_scene_setup` |
| Camera3D exists and is current | `_test_scene_setup` |
| background_mode is BG_SKY (2) | `_test_sky_background` |
| environment has a Sky resource | `_test_sky_background` |
| sky has a sky_material | `_test_sky_background` |

Also carried over (not a check): the `[WARN] camera sits below expected eye height` diagnostic and the `WorldEnvironment has no Environment resource` early-return failure path.

### `tests/movement.gd` — 20 checks

| check | source |
|---|---|
| player is on floor after settling | `_test_idle` |
| vertical velocity zero while idle | `_test_idle` |
| player did not fall through floor | `_test_idle` |
| walk distance ~5m | `_test_walk_forward` |
| still on floor after walking | `_test_walk_forward` |
| strafing moves along X | `_test_strafe` |
| sprint meaningfully faster than walk | `_test_sprint` |
| on floor before jump | `_test_jump` |
| player left the floor after jump | `_test_jump` |
| upward velocity applied | `_test_jump` |
| player landed back on floor | `_test_jump` |
| jump produced measurable height | `_test_jump_height` |
| returned to floor after apex test | `_test_jump_height` |
| on floor before action jump | `_test_jump_action_event` |
| player left the floor after action jump | `_test_jump_action_event` |
| action jump applied upward velocity | `_test_jump_action_event` |
| landed back on floor after action jump | `_test_jump_action_event` |
| yaw unchanged while mouse uncaptured | `_test_mouse_uncaptured` |
| pitch unchanged while mouse uncaptured | `_test_mouse_uncaptured` |
| horizontal velocity zeroed after release | `_test_no_stuck_velocity` |

Order is exactly the brief's Step 1 order: idle → walk → strafe → sprint → jump → jump height → action jump, then the mouse block, then the release check. The settling/landing state is shared inside this file exactly as it was in the monolith.

Helpers duplicated into this file: `_check`, `_warn`, `_ensure_mouse_capture`, `_physics_frames`, `_key_event`.

### `tests/integrity.gd` — 5 checks

| check | source |
|---|---|
| player did not fall out of the world | `_test_fall_off_edge` |
| player respawned near the spawn point after falling out of world | `_test_fall_recovery` |
| respawned player is on the floor again | `_test_fall_recovery` |
| respawned player is at platform height | `_test_fall_recovery` |
| velocity zeroed on respawn | `_test_fall_recovery` |

Helpers duplicated into this file: `_check`, `_warn`, `_physics_frames`. These two checks are carried over verbatim, including the `y > -50.0` threshold, the `Vector3(1000, 50, 1000)` drop point and the 600-frame respawn wait. Task 6 is expected to rewrite the first one; nothing here pre-empts that.

### Total: 6 + 20 + 5 = **31** — no check was dropped.

---

## 3. Verification — actual output

### 3.1 The runner

```
$ powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1
smoke          PASS
movement       PASS
input_actions  [SKIP]  (tests\input_actions.gd not present)
input_gate     [SKIP]  (tests\input_gate.gd not present)
integrity      PASS
weapon         [SKIP]  (tests\weapon.gd not present)
projectile     [SKIP]  (tests\projectile.gd not present)
enemies        [SKIP]  (tests\enemies.gd not present)
waves          [SKIP]  (tests\waves.gd not present)
save           [SKIP]  (tests\save.gd not present)
progression    [SKIP]  (tests\progression.gd not present)

RESULT: 3 passed, 0 failed, 8 skipped
RUNNER_EXITCODE=0
```

### 3.2 Each harness run directly

`--headless --path . --script res://tests/<name>.gd` (all exit 0):

**smoke.gd** — `6 checks, 0 failed, 0 warnings`
```
-- scene setup
  [PASS] Floor node exists
  [PASS] WorldEnvironment exists
  [PASS] Camera3D exists and is current
-- sky: environment must render the sky, not a black clear color
  [PASS] background_mode is BG_SKY (2) (got 2)
  [PASS] environment has a Sky resource
  [PASS] sky has a sky_material
=== RESULT: 6 checks, 0 failed, 0 warnings ===
```

**movement.gd** — `20 checks, 0 failed, 2 warnings`
```
-- idle: ...            [PASS] on floor after settling / vertical velocity zeroed (vy=0.000) / did not fall through floor (y=0.000)      (3)
-- walk forward         [PASS] walk distance ~5m (got 5.00 m) / still on floor after walking                                                    (2)
-- strafe right         [PASS] strafing moves along X (dx=2.50)                                                                                (1)
-- sprint               [PASS] walk=5.00 m, sprint=9.00 m -> sprint meaningfully faster than walk                                                (1)
-- jump (Space key)     [PASS] on floor before jump / left the floor / upward velocity applied (vy=4.35) / landed back on floor             (4)
-- jump apex            apex=1.297 m -> [PASS] measurable height / returned to floor after apex test                                             (2)
-- jump (action)        [PASS] on floor before / left the floor / upward velocity (vy=4.35) / landed back on floor                                (4)
-- mouse look           [WARN] display server cannot capture the mouse; mouse look assertions skipped                                           (0 checks)
-- mouse uncaptured     [PASS] yaw unchanged (dyaw=0.0000) / pitch unchanged (dpitch=0.0000)                                                     (2)
                        [WARN] display server cannot recapture the mouse; recapture assertion skipped                                         (0 checks)
-- release check        [PASS] horizontal velocity zeroed after release (v=0.000, 0.000)                                                          (1)
=== RESULT: 20 checks, 0 failed, 2 warnings ===
```

**integrity.gd** — `5 checks, 0 failed, 0 warnings`
```
-- fall off edge        y after 2s of falling = 30.32 -> [PASS] player did not fall out of the world                                            (1)
-- fall recovery        y after fall = 0.00, respawned=true -> [PASS] respawned near spawn / on the floor / at platform height (y=0.00) /
                        velocity zeroed on respawn (v=0.000, 0.000, 0.000)                                                                       (4)
=== RESULT: 5 checks, 0 failed, 0 warnings ===
```

Every `[PASS]` line above is textually identical to the corresponding line in the original baseline run, including the measured values. The only numeric drift is `y after 2s of falling` (30.32 vs 30.48 in the monolith) — expected, because in the monolith that check ran after ~700 prior physics frames of jump/walk state and now runs on a freshly spawned body; the value is diagnostic print output, not an assertion, and it sits far above the `-50.0` threshold either way.

### 3.3 Deletion and working tree

```
$ git rm tests/headless_smoke.gd tests/headless_smoke.gd.uid
rm 'tests/headless_smoke.gd'
rm 'tests/headless_smoke.gd.uid'

$ git ls-files tests
tests/capture.gd
tests/capture.gd.uid
tests/diagnose.gd
tests/diagnose.gd.uid
tests/integrity.gd
tests/movement.gd
tests/smoke.gd

$ Test-Path tests\headless_smoke.gd      -> False
$ Test-Path tests\headless_smoke.gd.uid  -> False
$ git status --short                     -> (empty)
```

`tests/capture.gd` and `tests/diagnose.gd` were not touched. Re-running the suite after the deletion produced the same `3 passed, 0 failed, 8 skipped` / exit 0, and Godot did not recreate `headless_smoke.gd`.

---

## 4. The two mouse-look warnings

Both warnings originate in the source file and both are carried over unchanged into `movement.gd`:

1. `_test_mouse_look` → `[WARN] display server cannot capture the mouse; mouse look assertions skipped`. Headless `DisplayServer` reports `display=headless` and refuses `MOUSE_MODE_CAPTURED` (`mouse_mode=0`, `CAPTURED=2`), so `_ensure_mouse_capture()` returns false and the three assertions behind it (yaw responds, pitch clamps on downward motion, pitch clamps on upward motion) never run. They are **not** counted and **not** failures.
2. `_test_mouse_uncaptured` → `[WARN] display server cannot recapture the mouse; recapture assertion skipped`. Its two preceding assertions — yaw unchanged while uncaptured, pitch unchanged while uncaptured — run and pass (they only need `MOUSE_MODE_VISIBLE`, which headless accepts); only the trailing "yaw rotates again once recaptured" assertion is skipped.

So `_warn()` plus the `_warnings: PackedStringArray` counter were duplicated into `movement.gd`, and the `RESULT` line reports the warning count there. The brief pins this state as intentional and says Task 4 (`InputGate`) removes the dependency on the display server.

These two warnings are the source-file behaviour the brief told me to leave for Task 4/Task 6, and I left them exactly as they were. I did not weaken them further, and I did not add a substitute assertion.

---

## 5. Decisions the brief left open

1. **`smoke.gd` adds `main.tscn` to the tree — deviation from brief Step 2, evidence-based.**
   Step 2 says to instantiate "into root **without** adding it to the tree". I implemented that first and it is broken in two ways on 4.7.2:
   - `Camera3D.global_position` off-tree hits `Condition "!is_inside_tree()" is true. Returning: Transform3D()` (`scene/3d/node_3d.cpp:649`) and yields identity, so the carried-over eye-height diagnostic fires as `[WARN] camera sits below expected eye height (0.00)` on a scene that is in fact correct at y=1.7. A warning that cannot distinguish a broken camera from a working one is exactly the "passes for the wrong reason" class this task's constraints forbid.
   - Not freeing/entering the tree leaks `2 x JoltShape3D`, `2 x JoltBody3D` RIDs plus renderer storage on exit.

   So `smoke.gd` does `root.add_child(world)` + `await physics_frame`, matching the monolith. It still asserts nothing about simulation, and its output is now 6 checks / 0 failed / **0 warnings** with no engine errors. (`cam.current` happens to answer correctly off-tree in 4.7.2, but it is not worth relying on that next to the `global_position` failure.)

2. **No `_check(packed != null, "main.tscn loads")` — deviation from the brief's Step 2 snippet, deliberate.**
   The brief's snippet shows that assertion *after* the `if packed == null: quit(1); return` guard, which makes it provably always-true: an assertion that can never fail is a check passing for the wrong reason. Keeping the total at the original 31 was the higher-priority requirement, so `smoke.gd` keeps the original's `FATAL: cannot load res://main.tscn` + `quit(1)` guard (which the brief's own prose requires) and adds no assertion. Net effect: 31 checks, same as before the split, with the failure path still exit code 1 + a `FATAL` line the runner reports as FAIL. If the reviewer prefers the literal snippet, adding the line back is a one-liner and makes the total 32.

3. **The `RESULT` line is the 3-argument form in all three files**, i.e. `%d checks, %d failed, %d warnings`, not the 2-argument form printed in the brief. Reason: the brief also requires the ending to be *identical* in all three files, and `movement.gd` must report its two warnings. Keeping one single ending shape across all three satisfies that requirement; `_warnings` is declared in all three so no file carries an unread member variable. `smoke.gd` and `integrity.gd` legitimately print `0 warnings`.

4. **`const FLOOR_EXTENT := 10.0` was not carried over.** It is declared at line 7 of `headless_smoke.gd` and referenced nowhere in the repo (verified by grep across the whole tree). It is dead code, so it was dropped rather than duplicated into three files.

5. **No `.uid` files were created for the three new scripts.** `.gd.uid` files are written by the editor's filesystem scan, not by a headless `--script` run, so none appeared and I did not hand-fabricate them. `capture.gd.uid` / `diagnose.gd.uid` exist only because those files were previously opened in the editor. First editor open will produce three untracked `.uid` files; they are harmless and were left out to keep this commit to the brief's Files list.

6. **Git recorded `movement.gd` as a rename of `headless_smoke.gd` (76% similarity).** That is rename detection, not a partial commit: the tree result is exactly the six intended paths (2 deleted, 3 added, 1 rename), confirmed by `git ls-files tests` and `git status --short` above.

7. **Execution-order note.** `integrity.gd` runs its drop tests on a freshly spawned player rather than after ~700 frames of jump/walk, since the scene-integrity checks it inherited are no longer ahead of it in the same process. Both tests set absolute positions and the spawn transform is captured in `Player._ready()`, so the outcomes are identical (verified above).

---

## 6. Constraints honoured

- Each file is a standalone `extends SceneTree` script; each ends `quit(0)` on success and `quit(1)` on failure. No shared module — `_check` and friends are duplicated verbatim.
- `project.godot`, `player.gd`, `player.tscn`, `main.tscn`, `tools/run_checks.ps1`, `tests/capture.gd`, `tests/diagnose.gd` were not modified (`git status --short` is empty and the commit touches only `tests/`).
- `tools/run_checks.ps1` `$Tests` was not touched and not reordered.
- No temp files, no leftover scratch scripts, no engine cache changes committed.