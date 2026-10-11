# Task 6 — Report: Replacing a test that passed for the wrong reason

**Status: DONE**
**File changed: `tests/integrity.gd` only.** Nothing else was touched. Nothing was staged or committed.

---

## 1. Why the old assertion could not fail

The removed check was:

```gdscript
func _test_fall_off_edge(player: CharacterBody3D) -> void:
	player.global_position = Vector3(1000, 50, 1000)
	player.velocity = Vector3.ZERO
	await _physics_frames(240)
	var y := player.global_position.y
	_check(y > -50.0, "player did not fall out of the world", "(y=%.2f)" % y)
```

Three independent reasons it was unfalsifiable:

1. **There was nothing to fall through.** The only collision geometry in the
   project is the `Floor` StaticBody3D in `main.tscn` — a single 20×20×1 box
   spanning x,z ∈ [-10, 10], y ∈ [-1, 0]. The player was teleported to
   `(1000, 50, 1000)`, which is ~1400 m of empty space away from any surface.
   With the player's collision mask set to 0, with the floor deleted from
   `main.tscn`, with the physics engine replaced by a stub — the assertion
   `y > -50.0` still held. The check measured "gravity is roughly 9.8 m/s²",
   which is the engine's job, not the project's.
2. **The budget was far too small to reach the threshold anyway.** 240 physics
   frames at `physics_ticks_per_second = 120` is 2.0 s. Free fall from y = 50
   covers `0.5 × 9.8 × 2² = 19.6 m`, ending at y ≈ 30.4. To cross y = -50 takes
   `sqrt(2 × 100 / 9.8) = 4.52 s` = 543 frames. The observed window ended 80 m
   above the asserted bound. The test would have needed to wait 4.5× longer
   *just to become capable of failing*, and even then only if geometry were
   placed under the spawn point — which no version of the test did.
3. **It could not distinguish a working kill plane from a broken one.** The name
   and the message ("must NOT sink through world", "did not fall out of the
   world") describe the kill-plane behaviour, but the code never observed a
   kill plane. A `fall_limit` of +1000, a kill plane that never fires, a world
   with no collision whatsoever — all green.

The old harness was therefore evidence of nothing, which is exactly what a
project rule ("a test that passes for the wrong reason is broken") exists to
prevent. It was removed.

---

## 2. What the new file does

`tests/integrity.gd` now runs **16 checks** in three groups plus two harness
preconditions. Structure:

```
=== VibeFPS world integrity test ===
    display=headless  Input.mouse_mode=0 (CAPTURED=2)
    floor top y=0.0, off-platform threshold y=-1.0, kill plane y=-50.0
  [PASS] precondition: the gate probe is installed on the scene Player
  [PASS] precondition: sprint speed is high enough to cross the platform fast
-- sprint traverse: 15 m across the real floor must not sink through it
  [PASS] precondition: the player settles on the floor (y=0.001)
    start=(-9.00, 0.00, 0.00)  end=(6.00, 0.00, 0.00)
    travelled 15.00 m at sprint, lowest y = 0.001 (stand height 0.001)
  [PASS] sprint input really drove the player across the platform (15.00 m; ...)
  [PASS] sprinting across the floor never sank through it (min_y=0.001, threshold -1.0)
  [PASS] player is still standing on the floor after the sprint traverse (y=0.001)
-- ordinary fall off the platform edge: the kill plane must stay quiet
  [PASS] precondition: the player settles on the floor (y=0.001)
    travelled 27.00 m off the +X edge, lowest y = -3.716 (kill plane -50.0)
    largest single-tick jump 0.103 m (teleport threshold 1.0 m)
    final pos=(18.00, -3.72, 0.00), on_floor=false, vy=-8.412
  [PASS] the sprint really carried the player off the platform (27.00 m, ended at x=18.00)
  [PASS] precondition: the player really fell below platform height (min_y=-3.716)
  [PASS] precondition: that fall never reached the kill plane (min_y=-3.716 > -50.0; ...)
  [PASS] kill plane does NOT fire on an ordinary fall off the platform (largest single-tick jump 0.103 m; ...)
  [PASS] the player is still airborne over the void, not respawned on the floor (on_floor=false, vy=-8.412)
-- fall recovery: falling past the kill plane respawns at spawn
    y after fall = 0.00, respawned=true
  [PASS] player respawned near the spawn point after falling out of world
  [PASS] respawned player is on the floor again
  [PASS] respawned player is at platform height (y=0.00)
  [PASS] velocity zeroed on respawn (v=0.000, 0.000, 0.000)
=== RESULT: 16 checks, 0 failed, 0 warnings ===
```

Exit code 0. Zero `[WARN]` lines (harness `_warnings` count 0; stderr empty).

### Harness precondition: the input gate

**This was not in the brief and it is load-bearing.** Headless cannot capture
the cursor, so `Input.mouse_mode` stays `MOUSE_MODE_VISIBLE` for the whole run
and `player.gd`'s `InputGate.is_play_input_allowed()` denies every movement
action. A sprint traverse driven through that gate would not move the player
*at all* — `velocity.x/z` are forced to 0 in `_physics_process` — and would sail
straight through a "never sank through the floor" assertion for exactly the wrong
reason the old check did. That would have been a straight repeat of the defect
this task exists to fix.

The fix follows the precedent already established in `tests/movement.gd`: the
scene's `Player` node gets its script swapped (before `add_child`, so `_ready`
runs on the probe) for a one-method subclass that answers
`_mouse_mode_for_play_input()` with an explicit `MOUSE_MODE_CAPTURED`. Only the
mouse-mode *value* — which the headless display server physically cannot
produce — comes from the harness. Gravity, `move_and_slide`, the kill plane, the
collision shape, the exports and `main.tscn`'s floor are all the real thing.

On top of that, **every** traverse asserts the distance it actually covered
(`travelled > 12.0`, `travelled > 15.0 and left_the_platform`). If the probe ever
failed to open the gate, those assertions go red rather than silently passing the
floor check.

---

## 3. Assertion-by-assertion: what it proves and what turns it red

### Group A — `_test_sprint_traverse_no_tunnelling` (4 checks)

Settle at `(-9, 1.0, 0)` for 60 physics frames, then hold `move_right` +
`sprint` for 200 frames (1.67 s × 9 m/s = 15 m, ending at `x = +6`, comfortably
inside the platform footprint `[-10, 10]`), sampling `min_y` every tick.

| Assertion | Proves | Catches |
|---|---|---|
| `player.is_on_floor()` after settling | The player is actually resting on real floor geometry, so the traverse starts on a surface | Floor missing / `CollisionShape3D` removed from `main.tscn` |
| `travelled > 12.0` | The harness really drove 15 m of sprint — the traverse is not vacuously green because nothing moved | Any input regression, or the gate probe failing to open the gate |
| `min_y > -1.0` | The player never got underneath the slab while sprinting at 9 m/s across it | **`collision_mask = 0`**; collision layers broken; floor deleted; tunnelling at sprint speed (a tick that crosses the 1 m slab in one step shows up immediately as `min_y` dropping) |
| `player.is_on_floor()` after the traverse | The player is still supported at the end, not merely above the slab | Any of the above, caught from the other side |

`-1.0` is the underside of the floor box, so `min_y > -1.0` means "never left
the slab", not "never went below the top face".

### Group B — `_test_kill_plane_quiet_on_edge_fall` (6 checks)

The negative half. Sprint past the +X edge and fall into the void for 360
frames. This is normal gameplay, not falling out of the world: the platform is
20 m across, the kill plane is 50 m down, so a fall from platform height
**cannot** reach it. Therefore no respawn may occur.

| Assertion | Proves | Catches |
|---|---|---|
| `travelled > 15.0 and pos.x > 10.0` | The sprint really carried the player off the platform | Gate/input regression — without this the rest could pass by never leaving |
| `min_y < -1.0` | The player really fell below platform height (min_y = -3.716) | A check that cannot go green by accident: if nothing fell, the silence below would prove nothing |
| `min_y > fall_limit` | That fall never reached the kill plane (reads the live `player.fall_limit`, so it stays correct if the value is tuned) | Makes the silence assertion meaningful; states why silence is the *correct* outcome here |
| `max_step < 1.0` | **No respawn fired** during the ordinary fall | **`fall_limit` set high enough to trigger on a normal short fall**; a kill plane that fires on the first frame off the platform |
| `not is_on_floor() and velocity.y < 0.0` | The player is still airborne over the void at x = +18, not standing respawned at spawn | Independent second signal for the same regression — a respawn that happened to land on the last frame would still be caught by `max_step` |

**How the respawn is detected, and why not by proximity to the spawn point:**
my first attempt used `min distance to spawn`, mirroring the existing
`_test_fall_recovery`. It failed immediately on a *correct* build:

```
[FAIL] kill plane does NOT fire on an ordinary fall off the platform (closest to spawn 0.00 m)
```

The reason is that the sprint path from `x = -9` to `x = +18` passes straight
**through** the spawn point at `x = 0` while standing on the floor — closest
approach reads 0.00 m with no respawn at all. Proximity cannot distinguish
"walked past the spawn" from "teleported to the spawn". Instead the check
watches for the *teleport*: the largest single-tick position change. A respawn
is a discontinuity in position; falling is continuous. At 120 Hz the fastest
legitimate tick is `sqrt(9.0² + 9.2²) / 120 ≈ 0.11 m` (observed: 0.103 m), so a
1.0 m threshold has ~9× margin while remaining far below any respawn distance.

### Group C — `_test_fall_recovery` (4 checks — preserved)

The brief did not name this as defective, and it is not: it teleports to
`(0, 5, 40)`, which is **outside** the 20×20 floor footprint in `z` (floor is
`z ∈ [-10, 10]`), so the player really does free-fall through empty space,
crosses the kill plane after ~402 of the 600 frames budgeted, and must be
brought back. Kept, with two small improvements:

- the spawn point is read from the live `player._spawn_transform` rather than
  hardcoded `Vector3.ZERO`, so the check follows the scene if the spawn moves;
- the height assertion now uses the shared `_OFF_PLATFORM_Y = -1.0` constant
  instead of a bare `-1.0` literal.

It now also gains a new property: because Group B asserts the kill plane must
**not** fire during an ordinary fall, Group C is no longer the only thing
standing between a missing kill plane and a green suite. Together they bracket
the kill plane from both sides.

---

## 4. Verification runs

### 4.1 Full suite — green

```
> powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1

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
EXITCODE=0
```

Exactly `RESULT: 5 passed, 0 failed, 6 skipped`, exit 0, no `[WARN]`. Re-run
after every subsequent edit in this task; the final state above is the state on
disk now. `$Tests` in `tools/run_checks.ps1` was not touched.

### 4.2 Direct run of `tests/integrity.gd`

```
EXITCODE=0
===== STDOUT =====        (full output as reproduced in section 2)
===== STDERR =====        (empty)
[WARN] occurrences in captured output: count=0
```

**Check count: 16**, 0 failed, 0 warnings.

### 4.3 MUTATION RUN A — collision mask zeroed (proves the tunnelling check can fail)

`player.gd` was temporarily mutated by inserting `collision_mask = 0` at the top
of `_ready()`, so the player body cannot collide with the floor at all.

| | SHA-256 of `player.gd` |
|---|---|
| before mutation | `B98D7D01244ACE93FB1C52F991982B0BEBE8F5D857DDF626F7E8950E2CDFC08B` |
| while mutated | `04AE656E58E0DCBF43BF50194EBA24DF6E05A4D2C8ADC54ECF770E7CE6A27CE1` |
| after restore | `B98D7D01244ACE93FB1C52F991982B0BEBE8F5D857DDF626F7E8950E2CDFC08B` |

**Before == after → the restore is byte-identical.** (Restored by `Copy-Item`
from a byte copy taken *before* the mutation, so the restore is a bit-for-bit
copy rather than a re-typed edit.)

```
integrity      FAIL  (exit code 1)
  ...
  [FAIL] precondition: the player settles on the floor (y=-0.245)
    start=(-9.00, -0.25, 0.00)  end=(6.00, -22.99, 0.00)
    travelled 15.00 m at sprint, lowest y = -22.091 (stand height -0.245)
  [PASS] sprint input really drove the player across the platform (15.00 m; ...)
  [FAIL] sprinting across the floor never sank through it (min_y=-22.091, threshold -1.0)
  [FAIL] player is still standing on the floor after the sprint traverse (y=-22.986)
  ...
=== RESULT: 16 checks, 8 failed, 0 warnings ===

RESULT: 0 passed, 1 failed, 0 skipped
EXITCODE=1
```

The tunnelling check went red exactly as designed: the player fell from y = 0
to y = -22.09 during a 15 m sprint that should never have left the floor, and
the runner exited 1. **The old check would have stayed green under this
mutation**, which is the defect being fixed.

The other 5 red assertions are collateral from the same mutation and are all
correct: with no collisions the player also falls out of the world in Group B
(a 52.172 m single-tick teleport = the kill plane firing), fails to settle in
Group C, and keeps a residual `-2.450` vertical velocity after respawn because
there is no floor to stop it. The green assertion
`sprint input really drove the player across the platform (15.00 m)` confirms
the harness itself was unaffected by the mutation — only the world was broken.

After restore: `integrity PASS`, `RESULT: 1 passed, 0 failed, 0 skipped`, exit 0.

### 4.4 MUTATION RUN B — kill plane raised (proves the negative check can fail)

`player.gd` was temporarily mutated to `fall_limit: float = -2.0`, a plane that
fires on an ordinary short fall off the platform.

| | SHA-256 of `player.gd` |
|---|---|
| before mutation | `B98D7D01244ACE93FB1C52F991982B0BEBE8F5D857DDF626F7E8950E2CDFC08B` |
| while mutated | `D0897C7C55DA298A23DEB0BC5F28CC882E1057E080BB8A083D460DFB8BCA3B53` |
| after restore | `B98D7D01244ACE93FB1C52F991982B0BEBE8F5D857DDF626F7E8950E2CDFC08B` |

**Before == after → byte-identical.**

```
integrity      FAIL  (exit code 1)
    floor top y=0.0, off-platform threshold y=-1.0, kill plane y=-2.0
  -- sprint traverse: ...
  [PASS] sprinting across the floor never sank through it (min_y=0.001, threshold -1.0)
  -- ordinary fall off the platform edge: the kill plane must stay quiet
    travelled 11.10 m off the +X edge, lowest y = -1.960 (kill plane -2.0)
    largest single-tick jump 15.946 m (teleport threshold 1.0 m)
    final pos=(2.10, 0.00, 0.00), on_floor=true, vy=0.000
  [FAIL] the sprint really carried the player off the platform (11.10 m, ended at x=2.10)
  [PASS] precondition: the player really fell below platform height (min_y=-1.960)
  [PASS] precondition: that fall never reached the kill plane (min_y=-1.960 > -2.0; ...)
  [FAIL] kill plane does NOT fire on an ordinary fall off the platform (largest single-tick jump 15.946 m; ...)
  [FAIL] the player is still airborne over the void, not respawned on the floor (on_floor=true, vy=0.000)
=== RESULT: 16 checks, 3 failed, 0 warnings ===

RESULT: 0 passed, 1 failed, 0 skipped
EXITCODE=1
```

The kill-plane negative check went red: the player fell 1.96 m off the platform,
the kill plane fired, and `_respawn()` teleported them 15.946 m back to spawn
mid-fall, ending the window standing safely on the floor at `x = 2.10`. Runner
exit 1.

Note the **selectivity**: the entire tunnelling group stayed green under this
mutation (the player never leaves the floor there, so a raised kill plane is
invisible to it), and Group C stayed green (a kill plane that fires *too
eagerly* still respawns the player who falls from y = 5). The two groups fail
for different reasons and only for their own reason — they are not aliases of
each other.

After restore: `integrity PASS`, `RESULT: 1 passed, 0 failed, 0 skipped`, exit 0.
Final on-disk `player.gd` verified back to `B98D7D01...` and grepped to confirm
`fall_limit: float = -50.0` and no `collision_mask` line remain.

### 4.5 Working tree

```
> git status --short
 M player.gd
 M project.godot
 M tests/integrity.gd
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

> git diff --cached --name-only
(nothing staged)

> git log -1 --oneline
ed35408 build: add single-command test runner and split harness by subsystem
```

`player.gd`, `project.godot`, `tests/movement.gd`, `tools/run_checks.ps1` and all
untracked paths were **already** in this state before I started (captured in my
first command of the session). `tests/integrity.gd` is the only entry that is
newly modified by this task. Nothing staged, nothing committed, no `.uid` file
created or deleted (the nine `.uid` files listed are the pre-existing set).

---

## 5. Decisions the brief left open

1. **The brief's tunnelling traverse was arithmetically impossible, so I
   changed it.** Step 2 specifies starting at `(0, 1.0, 0)`, sprinting
   `move_right` for 360 frames and asserting `min_y > -1.0`. At 9 m/s for 3 s
   that is 27 m of travel: the player leaves the floor's `x = +10` edge after
   ~2.07 s and free-falls for the remaining 0.93 s, reaching
   **y ≈ -17.4**. `min_y > -1.0` is therefore **false in a correct game** — the
   brief's literal assertion would have shipped a permanently red suite. I kept
   the brief's *intent* (a long high-speed traverse across the real floor that
   catches tunnelling) and made it satisfiable: start at `x = -9.0` (9 m from
   the near edge), sprint `move_right` for **200** frames = 15 m, ending at
   `x = +6.0` — inside the platform with 4 m of margin. This still covers three
   quarters of the floor width at full sprint speed and catches all four target
   regressions.
   The "run off the edge" behaviour the brief wanted to cover is not lost — it
   is now Group B's explicit subject, where a fall off the edge is precisely
   what the test is *for*.
2. **The kill-plane negative is a sprint off the edge, not a jump to 3 m.**
   Step 3's phrasing ("the player jumps from the edge of the platform to a
   height of 3 m") describes a jump that lands back on the floor and never falls
   off at all, or a teleport into the void that is not what the wording says.
   I implemented the unambiguous reading: normal gameplay, sprint off the edge,
   fall 3.7 m into the void, and the kill plane must stay silent. That is
   strictly stronger — it also exercises the floor's side face at 9 m/s — and it
   is what the mutation test in 4.4 actually exercises.
3. **Respawn is detected by teleport, not by spawn proximity** (section 3).
   My first implementation used proximity and was red on a *correct* build,
   because the sprint path crosses the spawn point. This is worth flagging
   because it means the pre-existing `_test_fall_recovery` only works by
   accident of geometry: its 600-frame loop is in the void at `z = 40` and
   never passes through the spawn, so proximity is valid there. It is not
   safe to reuse that idiom in a test that moves horizontally through spawn.
4. **The input-gate probe.** Not in the brief; required, as explained in
   section 2. It is the established pattern from `tests/movement.gd`, it is
   confined to this harness file, and the travel assertions ensure it cannot
   silently produce a green check.
5. **A standing player's origin is at y = 0.0, not y = 0.9.** I initially
   assumed the latter from the capsule height; measurement showed y = 0.001,
   because the `CollisionShape3D` is offset `y = 0.9` with capsule height 1.8,
   so the capsule spans `y = 0.0 .. 1.8` relative to the body origin. The
   comments in the file now state this, and the off-platform threshold `-1.0` is
   the underside of the floor box, which makes "never sank through it"
   unambiguous.
6. **`fall_limit` is read from the live player**, not hardcoded to `-50.0`, so
   the preconditions stay correct if the value is tuned in a later phase.

## 6. Defects observed but NOT fixed (reported, not touched)

None found in game code. Both mutations were injected deliberately and reverted;
`player.gd` is byte-identical to its pre-task state (SHA-256 verified). No
`player.gd`, `main.tscn`, `project.godot`, `tools/run_checks.ps1` or other
harness was modified by this task.

## 7. Commit state

**I did not run `git commit` and I did not run `git add`.** Nothing is staged.
All changes are in the working tree, unstaged, for the project owner to commit.
`git log -1` is still `ed35408`, the commit that was HEAD when I started.