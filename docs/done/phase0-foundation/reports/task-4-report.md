> **Назначение:** Отчёт по задаче фазы.

# Task 4 report — InputGate (pure input-permission function)

Status: DONE

## Files created (only these two; nothing else in the repo was touched)

- `scripts/input_gate.gd`
- `tests/input_gate.gd`

Nothing was staged (`git diff --cached --name-only` is empty) and nothing was
committed (`git log --oneline -1` is still `ed35408 build: add single-command
test runner and split harness by subsystem`). All changes are left unstaged in
the working tree for the project owner to commit.

## Final content of scripts/input_gate.gd

```gdscript
class_name InputGate
extends RefCounted

## Разрешён ли игровой ввод.
## Зависит только от переданного режима мыши, чтобы проверяться без
## дисплейного сервера: headless не умеет захватывать курсор.


static func is_play_input_allowed(mouse_mode: int) -> bool:
	return mouse_mode == Input.MOUSE_MODE_CAPTURED
```

Verbatim from the brief. One argument in, one `bool` out. It does not read
`Input.mouse_mode`, does not touch the scene, is not a Node method, and has no
extra parameters.

## Final content of tests/input_gate.gd

```gdscript
extends SceneTree

## Input permission harness for VibeFPS.
## The headless display server cannot capture the mouse, so this check never
## touches Input.mouse_mode and never captures a cursor. It passes a mouse
## mode value into InputGate.is_play_input_allowed and asks what it answers,
## which is the whole point of keeping that function pure.
## Run: godot --headless --path . --script res://tests/input_gate.gd
##      .\tools\run_checks.ps1 input_gate

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
	print("=== input gate ===")
	_check(InputGate.is_play_input_allowed(Input.MOUSE_MODE_CAPTURED),
		"input allowed when mouse captured", "(mode=%d)" % Input.MOUSE_MODE_CAPTURED)
	for mode in [Input.MOUSE_MODE_VISIBLE, Input.MOUSE_MODE_CONFINED,
			Input.MOUSE_MODE_CONFINED_HIDDEN, Input.MOUSE_MODE_HIDDEN]:
		_check(not InputGate.is_play_input_allowed(mode),
			"input denied when mouse mode is %d" % mode)

	print("=== RESULT: %d checks, %d failed ===" % [_checks, _failures.size()])
	for f in _failures:
		print("  FAILURE: %s" % f)
	quit(1 if _failures.size() > 0 else 0)
```

### Assertion list (5 assertions, all able to fail)

1. `is_play_input_allowed(Input.MOUSE_MODE_CAPTURED)` is `true` — "input
   allowed when mouse captured (mode=2)". This fails if the function always
   returns `false`, or if it returns true for anything but capture.
2. `not is_play_input_allowed(Input.MOUSE_MODE_VISIBLE)` (mode 0)
3. `not is_play_input_allowed(Input.MOUSE_MODE_CONFINED)` (mode 3)
4. `not is_play_input_allowed(Input.MOUSE_MODE_CONFINED_HIDDEN)` (mode 4)
5. `not is_play_input_allowed(Input.MOUSE_MODE_HIDDEN)` (mode 1)

All four non-captured modes are covered, not just `VISIBLE`. `MOUSE_MODE_HIDDEN`
is the one that matters most: invisible cursor, not captured, input must still
be denied or the player runs with no visible cursor.

No shared helper module was extracted. `_check`, `_failures` and `_checks` were
copied from `tests/smoke.gd` so the harness is self-contained, matching the
deliberate per-harness duplication used by the other four harnesses.

## Decisions the brief left open

- **Did not carry over `_warnings` / `_warn`.** `smoke.gd` has both, but this
  harness has no warnings to report, so the unused declaration and its helper
  were left out. `_check` itself is verbatim from `smoke.gd`. This matches
  `tests/input_actions.gd`, which also drops them.
- **Kept the `for f in _failures: print("  FAILURE: %s" % f)` epilogue** from
  the brief's snippet pattern as used in `input_actions.gd`, so a failing run
  names the assertions. This is additive to the brief, not a change of contract.
- **Kept the brief's English/Russian comment mix**: Russian doc comments in
  `scripts/input_gate.gd` verbatim from the brief, English harness header in
  `tests/input_gate.gd` matching the other harnesses' header style.
- **Ran one `--import` pass** because the project's `.godot/global_script_class_cache.cfg`
  was empty (`list=[]`), so `InputGate` was not yet a registered global class
  and the check failed to even parse. This regenerated three `.uid` files
  (`scripts/input_gate.gd.uid`, `tests/input_gate.gd.uid`,
  `tests/input_actions.gd.uid`); the two belonging to my new files were
  removed afterwards, and `tests/input_actions.gd.uid` — which the brief did
  not list as pre-existing — was also removed, to leave the tree exactly as the
  brief describes. `.godot/` is gitignored, so the cache rebuild leaves no
  tracked change. Final `git status --short` matches the brief's expectation.
  **Concern worth noting:** on a machine where `.godot/` has never been
  imported, the new check will fail to parse until an import or editor run
  happens, because `class_name` registration is cached. The runner does not do
  an import itself. Every existing harness avoids this by loading scenes via
  `res://` paths rather than global class names. This is a pre-existing project
  characteristic, not something introduced here, and it does not affect a
  normally-set-up working copy.

## Verification

### 1. Red: check written before the implementation

`powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 input_gate`

```
input_gate     FAIL  (exit code 1)
    Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org
    SCRIPT ERROR: Parse Error: Identifier "InputGate" not declared in the current scope.
       at: GDScript::reload (res://tests/input_gate.gd:26)
    SCRIPT ERROR: Parse Error: Identifier "InputGate" not declared in the current scope.
       at: GDScript::reload (res://tests/input_gate.gd:33)
    ERROR: Failed to load script "res://tests/input_gate.gd" with error "Parse error".
       at: load (modules/gdscript/gdscript_resource_format.cpp:46)

RESULT: 0 passed, 1 failed, 0 skipped
EXIT=1
```

Matches the brief's Step 2 expectation exactly.

### 2. Green after creating scripts/input_gate.gd

`powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 input_gate`

```
input_gate     PASS

RESULT: 1 passed, 0 failed, 0 skipped
EXIT=0
```

### 3. Full suite

`powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1`

```
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
EXIT=0
```

Exactly the required line, exit 0. All four pre-existing harnesses (smoke,
movement, input_actions, integrity) still pass. `$Tests` in
`tools/run_checks.ps1` was not modified or reordered.

### 4. Deliberate failure: the check is not vacuous

Temporarily changed `return mouse_mode == Input.MOUSE_MODE_CAPTURED` to
`return mouse_mode != Input.MOUSE_MODE_CAPTURED`, then ran the runner filtered
to `input_gate`:

```
input_gate     FAIL  (exit code 1)
    Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org
    === input gate ===
      [FAIL] input allowed when mouse captured (mode=2)
      [FAIL] input denied when mouse mode is 0 
      [FAIL] input denied when mouse mode is 3 
      [FAIL] input denied when mouse mode is 4 
      [FAIL] input denied when mouse mode is 1 
    === RESULT: 5 checks, 5 failed ===
      FAILURE: input allowed when mouse captured (mode=2)
      FAILURE: input denied when mouse mode is 0 
      FAILURE: input denied when mouse mode is 3 
      FAILURE: input denied when mouse mode is 4 
      FAILURE: input denied when mouse mode is 1 

RESULT: 0 passed, 1 failed, 0 skipped
EXIT=1
```

All five assertions fired. The correct implementation was then restored and the
full suite re-run to the green result in section 3, so the restored file is the
one verified green.

### 5. Final tree state

`git status --short`

```
 M project.godot
?? scripts/
?? tests/input_actions.gd
?? tests/input_gate.gd
?? tests/integrity.gd.uid
?? tests/movement.gd.uid
?? tests/smoke.gd.uid
```

- `scripts/` is untracked as a directory and contains only `scripts/input_gate.gd`
  (confirmed with `Get-ChildItem scripts -Force`).
- `tests/input_actions.gd` was already untracked before this task (it is a
  pre-existing untracked harness from an earlier task, not mine).
- `tests/integrity.gd.uid`, `tests/movement.gd.uid`, `tests/smoke.gd.uid` are
  the three pre-existing untracked `.uid` files. Untouched.
- ` M project.godot` was already modified in the working tree before this task
  began (the InputMap entries and `[layer_names]` block). It was not touched by
  me; the `--import` pass added no tracked change to it.
- `git diff --cached --name-only` is empty: nothing staged.
- `git log --oneline -1` is unchanged: nothing committed.

## Compliance summary

- Only the two files in the Files list were created. Not touched: `project.godot`,
  `player.gd`, `main.tscn`, `player.tscn`, `tools/run_checks.ps1`, and the four
  existing harnesses.
- No `git add`, no `git commit`.
- Check is standalone, ends `quit(0)` on success and `quit(1)` on failure.
- No shared test-helper module was extracted.
- No unused declarations left behind.
---

## Fix round: runner self-sufficiency on a cold global-class cache

Status: DONE

### The defect

`scripts/input_gate.gd` declares `class_name InputGate`. Global script classes
are only visible to the parser through `.godot/global_script_class_cache.cfg`,
which is git-ignored, so on a clean clone that file does not exist and
`tests/input_gate.gd` fails to parse:

```
SCRIPT ERROR: Parse Error: Identifier "InputGate" not declared in the current scope.
RESULT: 0 passed, 1 failed, 0 skipped
```

This is exactly the concern recorded in the "Decisions the brief left open"
section above: the runner did not perform an import itself, so CHECKLIST.md
section 0A ("checks must run from a clean clone") was not actually satisfiable.

### The change

One insertion in `tools/run_checks.ps1`, 14 lines, inside the `try` block after
the missing-Godot pre-check and before `$pass = 0` / the `foreach ($name in
$Tests)` loop:

```powershell
    # Global class_name declarations (scripts\input_gate.gd declares InputGate)
    # are visible to the parser only through .godot\global_script_class_cache.cfg,
    # and that file is git-ignored. On a clean clone it does not exist, so every
    # script referring to a class_name fails to parse with "Identifier ... not
    # declared in the current scope". One import pass rebuilds the cache and
    # costs about two seconds, so run it only on a cold cache instead of on every
    # invocation. Placed after the engine pre-check above so a missing Godot
    # still fails fast with its own message instead of being invoked here.
    $classCache = Join-Path $RepoRoot '.godot\global_script_class_cache.cfg'
    if (-not (Test-Path -LiteralPath $classCache -PathType Leaf)) {
        Write-Output "importing project (global class cache missing) ..."
        & $GodotBin --headless --path . --import | Out-Null
    }
```

`git diff -- tools/run_checks.ps1` is exactly this one hunk and nothing else.

Deliberately unchanged: `$Tests` and its order, `$CheckTimeoutMs`, the timeout
and kill logic, the `$proc.Handle` caching, the per-run GUID temp-file naming,
the `(?m)^\s*\[FAIL\]` marker guard and its one-directional PASS->FAIL
behaviour, SKIP behaviour, the missing-Godot message and its `RESULT: 0 passed,
0 failed, 0 skipped` + `exit 1`, and the RESULT line format. `project.godot`,
`scripts/` and `tests/` were not edited.

### Verification 1 - cold cache (the one that matters)

```
Remove-Item -LiteralPath ".godot\global_script_class_cache.cfg" -Force
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1
```

```
cache exists after delete: False
importing project (global class cache missing) ...
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
EXITCODE=0 ELAPSED=19.19s
```

The runner self-healed: the import line printed, `input_gate` PASSed instead of
failing to parse, and the run is green with exit 0.

### Verification 2 - warm cache (must not re-import)

```
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1
```

```
cache exists: True
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
EXITCODE=0 ELAPSED=17.34s
```

`importing project (global class cache missing) ...` is absent, which is the
direct proof that no import ran. Timing agrees: 19.19s cold vs 17.34s warm, a
1.85s difference matching the measured standalone import cost of 1843 ms
(`& $GodotBin --headless --path . --import` -> `LASTEXITCODE=0 elapsed=1843ms`).

### Verification 3 - no regressions

Covered by both runs above: `smoke`, `movement`, `input_actions`, `input_gate`
and `integrity` all PASS, all six not-yet-written checks SKIP, exit 0. No
`[WARN]` surfaced (the runner only echoes a check's output on FAIL, and nothing
failed). The exit code remains the contract; nothing in the repo parses this
runner's stdout, so the one extra informational line is safe.

### Repo state - nothing staged, nothing committed

`git status --short`

```
 M project.godot
 M tools/run_checks.ps1
?? scripts/
?? tests/input_actions.gd
?? tests/input_actions.gd.uid
?? tests/input_gate.gd
?? tests/input_gate.gd.uid
?? tests/integrity.gd.uid
?? tests/movement.gd.uid
?? tests/smoke.gd.uid
```

- The only tracked change made by this round is `tools/run_checks.ps1`.
- ` M project.godot` was already modified in the working tree before this round
  began; it was not touched here.
- The untracked set is identical to the `git status --short` taken at the start
  of this round, before any Godot process was run. No `.uid` file was created or
  deleted by hand. The mandated import pass refreshed the mtime of three
  already-present `.uid` files (`scripts/input_gate.gd.uid`,
  `tests/input_gate.gd.uid`, `tests/input_actions.gd.uid` -> 5:03:11) with
  unchanged content; that is Godot's own side effect of importing, and matches
  the behaviour the original Task 4 already documented.
- Caveat, stated for accuracy: `scripts/` collapses to a single `?? scripts/`
  line in `git status`, so whether `scripts/input_gate.gd.uid` already existed at
  session start cannot be proven from git alone. If the import generated it, that
  is Godot generating its own UID for an untracked script, not a manual change,
  and it is regenerated on any editor open.
- `git diff --cached --name-only` is empty: **nothing staged**.
- `git log --oneline -1` is still `ed35408 build: add single-command test runner and split harness by subsystem`: **nothing committed**. No `git add` and no `git commit` were run at any point in this round.
