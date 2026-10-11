# Task 1 Report — Single entry point for checks (`tools/run_checks.ps1`)

**Status:** DONE_WITH_CONCERNS
**Commit:** `199272905a8967945e11486bea2fc72960555bdf` (`1992729`) on `main`
**Readiness criterion:** `.\tools\run_checks.ps1` exits 0 — MET.

---

## 1. What I created

| File | Action |
|---|---|
| `tools/run_checks.ps1` | Created |
| `docs/superpowers/specs/2026-10-07-vibefps-foundation-design.md` | Created (byte-identical copy of `C:\Users\serhio\.opencode\plan\2026-10-07-vibefps-foundation-design.md`, 21114 bytes) |
| `docs/superpowers/plans/2026-10-07-vibefps-foundation.md` | Created (byte-identical copy of `C:\Users\serhio\.opencode\plan\2026-10-07-vibefps-foundation-plan.md`, 38654 bytes) |

Nothing else was touched. `git status` is clean after the commit. `project.godot`,
`player.gd`, `main.tscn`, `player.tscn` and all `tests/*.gd` are untouched.

Note on the docs: both source files in `~/.opencode/plan/` are stored with their
Cyrillic text double-encoded (UTF-8 bytes re-read as CP1251, e.g. "Р•РґРёРЅР°СЏ"
for "Годная"). I copied the bytes verbatim as the brief instructs rather than
silently re-encoding them — re-encoding is a content decision that belongs to the
plan owner, not to this task. Flagging it so it is not mistaken for a copy bug.

## 2. Exact `$Tests` array and filter logic

```powershell
$GodotBin = "E:\Godot\Godot_v4.7.2-stable_win64.exe"
$Tests = @("smoke", "movement", "input_actions", "input_gate", "integrity",
           "weapon", "projectile", "enemies", "waves", "save", "progression")
```

Used verbatim from the brief, order preserved (`smoke` first because it guards
scene integrity and must fail before anything else; `progression` last).
This string appears exactly once in the script — no duplicate engine path.

Filter logic:

- `$Filter = $args[0]` when an argument is present, else `''`.
- A test participates when `$Filter` is empty **or** the test name contains
  `$Filter` as a case-insensitive substring. Implemented with
  `$name.IndexOf($Filter, [System.StringComparison]::OrdinalIgnoreCase) -lt 0`
  → `continue` (explicit ordinal, not the locale-sensitive default, so the
  behaviour does not change with the machine's locale).
- A filter matching nothing is **not** an error: 0 executed, exit 0. Filtering
  is a selection mechanism, not a claim that the selection was non-empty.
- `tests/capture.gd` and `tests/diagnose.gd` are deliberately absent from
  `$Tests` (documented in a comment in the script).

Per-test status:

- File `tests\<name>.gd` absent → `[SKIP]`. Never a pass, never a failure.
- Present → run, `$LASTEXITCODE`-equivalent (`$proc.ExitCode`) `0` = `PASS`,
  anything else = `FAIL`, with the whole captured output printed under the line.
- Additional tightening, described in §4.

Script exits `1` if `FAIL > 0`, else `0`. Godot binary is checked up front;
if missing the script prints the path and exits `1` without running anything.

Working directory: the script computes `$RepoRoot` from `$PSScriptRoot/..` and
`Push-Location`s there, so `--path .` and the file-existence check resolve
against the repo regardless of the caller's cwd. Verified by invoking the script
from `C:\Users\serhio\AppData\Local\Temp\opencode`.

## 3. How I captured stderr, and why this is correct

I used `Start-Process -NoNewWindow -Wait -PassThru` with
`-RedirectStandardOutput` / `-RedirectStandardError` into two temp files, then
read both back with `[System.IO.File]::ReadAllText` and concatenate.

Why this approach:

- PowerShell here is **5.1.26100.1**. The `2>&1` merge on a native invocation is
  exactly the failure mode the task warned about, so I did not rely on it.
- `Start-Process` with two distinct redirect files keeps the streams separate
  and lossless, and `-PassThru` gives a real `ExitCode` without depending on
  `$LASTEXITCODE`, which is unreliable when the call is made from a script block.
- Measured behaviour of Godot 4.7.2 stable under `--headless`: the engine banner
  and all `print()` output — including `[FAIL]` lines — go to **stdout**, and
  stderr was empty (0 bytes) on the smoke run. Capturing only stderr would have
  produced an empty buffer and a runner that cannot be debugged. Capturing both
  and concatenating is correct for either distribution.
- Temp files are deleted before each run and in a `finally` block.

**Direct evidence that `[FAIL]` lines reach my output** (not silently dropped):
I temporarily created `tests/weapon.gd` as a deliberately failing check, ran the
suite, and observed:

```
weapon         FAIL  (exit code 1)
    Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org
    === probe: deliberately failing check ===
      [PASS] this check should not be mistaken for a failure
      [FAIL] deliberate failure line one
      [FAIL] deliberate failure line two
    === RESULT: 3 checks, 2 failed ===
...
RESULT: 0 passed, 1 failed, 10 skipped
=== SCRIPT EXITCODE=1 ===
```

Both `[FAIL]` lines appear verbatim and the script exits 1. The probe file was
deleted immediately afterwards and is not part of the commit.

I also confirmed the runner drives the **real** existing check correctly: with a
throwaway copy of the script whose array had `headless_smoke` prepended, the
actual 31-check `tests/headless_smoke.gd` reported `PASS`, exit 0. That temp
copy was deleted and no committed file was altered.

## 4. Tightening a check that would pass for the wrong reason

The brief's rule ("exit code defines the status") has a hole: a check that
prints a failed assertion but forgets `quit(1)` exits 0 and reads as `PASS`.
That is a pass for the wrong reason, so I added a one-directional guard:

```powershell
$reportedFailure = $output -match '(?m)^\s*\[FAIL\]'
if ($code -eq 0 -and -not $reportedFailure) { PASS } else { FAIL }
```

It can only turn PASS into FAIL, never the reverse, so a genuinely clean check
cannot be made to fail. Verified both directions:

- Reports `[FAIL]` but `quit(0)` → `FAIL ([FAIL] marker in output but exit code 0)`, exit 1. **Before** the fix this returned `PASS` — a live false-pass.
- Clean check with two `[PASS]` lines → `PASS`, exit 0 (no false failure).

**The `(?m)` flag is load-bearing.** My first version used `'^\s*\[FAIL\]'` with
no multiline flag; in .NET regex `^` then anchors to the start of the entire
captured string, and since Godot's engine banner always comes first, the pattern
never matched. The probe above is what caught it — a probe run alone would have
shipped a runner that false-passes every failing check.

## 5. Actual output of the two verification commands

### `.\tools\run_checks.ps1`

```
smoke          [SKIP]  (tests\smoke.gd not present)
movement       [SKIP]  (tests\movement.gd not present)
input_actions  [SKIP]  (tests\input_actions.gd not present)
input_gate     [SKIP]  (tests\input_gate.gd not present)
integrity      [SKIP]  (tests\integrity.gd not present)
weapon         [SKIP]  (tests\weapon.gd not present)
projectile     [SKIP]  (tests\projectile.gd not present)
enemies        [SKIP]  (tests\enemies.gd not present)
waves          [SKIP]  (tests\waves.gd not present)
save           [SKIP]  (tests\save.gd not present)
progression    [SKIP]  (tests\progression.gd not present)

RESULT: 0 passed, 0 failed, 11 skipped
=== EXITCODE=0 (expect 0) ===
```

### `.\tools\run_checks.ps1 smok`

```
smoke          [SKIP]  (tests\smoke.gd not present)

RESULT: 0 passed, 0 failed, 1 skipped
=== EXITCODE=0 (expect 0) ===
```

Also verified: `smok` and `SMOK` select identically (case-insensitive); a
non-matching filter yields no rows and exit 0; invoking from an unrelated cwd
works; and with the engine path temporarily pointed at a nonexistent file the
script printed `Godot binary not found: ...` and exited 1 without running
anything.

## 6. Concerns — the brief's Step 3 expectation cannot hold today

Step 3 expects `smoke ... PASS` and `RESULT: 1 passed, 0 failed, 9 skipped`.
That expectation is unreachable at this point in the plan, for two independent
reasons. **Both are defects in the brief, not in the runner.**

**(a) `tests/smoke.gd` does not exist and is not supposed to yet.**
The repo's only check is `tests/headless_smoke.gd`. The plan's Task 2 file list
(l. 112–115) is: create `tests/smoke.gd`, create `tests/movement.gd`, create
`tests/integrity.gd`, **delete `tests/headless_smoke.gd`** — the split into
`smoke`/`movement`/`integrity` is Task 2's work, not Task 1's. Mapping
`$Tests` entry `smoke` to `res://tests/smoke.gd` therefore SKIPs today and
starts passing in Task 2 Step 5, which expects `3 passed, 0 failed, 8 skipped`
— internally consistent with my behaviour and inconsistent with Step 3's.
Creating `tests/smoke.gd` here was not an option: Task 1's file list does not
include it, and it would collide with Task 2.

**(b) Step 3's arithmetic is self-inconsistent.** `$Tests` has 11 entries, so a
clean state is `1 passed + 10 skipped`, never `9 skipped`. `1 + 9 = 10 ≠ 11`.

**Consequently the readiness criterion passes vacuously today** (exit 0 with
zero checks executed). That is the correct, load-bearing SKIP semantic you asked
me to preserve — but it does mean "all green" carries no signal until Task 2
lands. I verified the runner is not merely green-but-broken by exercising the
real `headless_smoke.gd` through it (§3) and by driving it through both failure
modes (§3, §4). Once `tests/smoke.gd` exists in Task 2, the `1 passed` line
becomes real.

**Execution policy (environment, needs a decision).** This machine has
`Get-ExecutionPolicy` `Restricted` at every scope, so a bare `.\tools\run_checks.ps1`
fails with `PSSecurityException` before the script ever runs. I did **not**
change any machine or user policy — that is outside the task's file scope and is
an environment change. All verification above was run as:

```
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 [<filter>]
```

If the documented `.\tools\run_checks.ps1` form must work verbatim, someone has
to run `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` (or the repo needs
a documented bypass invocation). Flagging rather than deciding unilaterally.

## 7. Judgement calls the brief left open

1. **11 entries in `$Tests`, brief says 9 skipped** — kept the array verbatim as instructed; the count in the brief is wrong.
2. **`tests/smoke.gd` absent** — implemented the literal `res://tests/$name.gd` mapping and let it SKIP, rather than inventing a rename or an alias. Renaming would have broken Task 2's `git rm tests/headless_smoke.gd`.
3. **Filter matching nothing** — exit 0, not an error. An empty result is a valid selection.
4. **Missing engine** — prints the path and exits 1, per the brief; I also print a `RESULT:` line so the output stays parseable.
5. **Added the `[FAIL]`-marker guard** — the brief specifies exit code only. A false-passing runner would undermine every later task's verification, so I tightened it one-directionally. This is the one place I deliberately exceeded the brief's letter; §4 documents it.
6. **Filter matching** — `Ordinal`/`OrdinalIgnoreCase` rather than culture-sensitive comparison, for locale-stable behaviour.
7. **`Push-Location` to the repo root** — the brief says tests run "from the repository root"; deriving it from `$PSScriptRoot` makes that true regardless of caller cwd.
8. **Temp-file names** — fixed names under `[System.IO.Path]::GetTempPath()`, deleted before each run and in `finally`, so repeated runs don't read stale output.
9. **Docs copied byte-for-byte** — no re-encoding of the mojibake source (§1).
10. **Verification via probe files** — three throwaway scripts were created and deleted purely to test the runner. No probe survived into the commit; `git status` is clean.

---

# Fix round: closing the two residual unbounded waits

Commit `035b8a0` — "fix: bound the post-kill wait and drain redirected streams on success".
Scope: `tools/run_checks.ps1` only, +14/-2. No other file touched.

Both edits close the same defect class as commit 8e40d1d: a wait that can hang.
That runner is the single gate all six remaining Phase 0 tasks verify through, so
an unbounded wait in it is a hung session for whoever is driving it, not a
localised annoyance.

## Edit 1 — post-kill wait bounded (Fix A)

`Kill()` returns void under .NET Framework, so the kill's success cannot be
checked. The parameterless `$proc.WaitForExit()` that followed it would block
forever if the kill ever failed to terminate the process — reintroducing exactly
the hang `$CheckTimeoutMs` was added to prevent, one line later. Now bounded:

    $null = $proc.WaitForExit(5000)

The surrounding try/catch is intact, so "already gone between the timeout and the
kill" is still swallowed silently.

**The `$null =` assignment is load-bearing and was found by verification, not by
reading.** The bounded overload returns `bool`; the parameterless one returns
`void`. As a bare statement, `$proc.WaitForExit(5000)` therefore wrote a stray
`True` onto the runner's stdout ahead of the FAIL line — the first timed-out run
printed it, and a bare `$proc.WaitForExit()` cannot leak it, so the bug only
appears on the path this commit is fixing. Caught on verification 2 and fixed
before commit.

## Edit 2 — redirected streams drained on the success path (Fix B)

`WaitForExit(ms)` returns as soon as the process is gone; it does not wait for
redirected streams to reach EOF. The output files were then read on the
assumption that `Start-Process` had already flushed them. That works today and
is incidental — the standard guidance is that a bounded wait leaves unread
buffered output behind. A parameterless `$proc.WaitForExit()` now follows the
successful bounded wait, before the output files are read:

    if ($timedOut) {
        try { $proc.Kill(); $null = $proc.WaitForExit(5000) } catch { }
    } else {
        $proc.WaitForExit()
    }

It is an `else`, not a trailing statement, so the success-path drain can never
become a new unbounded wait on the timeout path.

Untouched, as instructed: the `$Tests` array and order, `$CheckTimeoutMs`, the
`[FAIL]`-marker guard with its `(?m)` flag and one-directional PASS→FAIL logic,
SKIP behaviour, the missing-Godot pre-check, the RESULT line format, the
temp-file naming scheme, and all pre-existing comments.

## Verification

### 1. Full suite

    > powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1
    smoke          [SKIP]  (tests\smoke.gd not present)
    movement       [SKIP]  (tests\movement.gd not present)
    input_actions  [SKIP]  (tests\input_actions.gd not present)
    input_gate     [SKIP]  (tests\input_gate.gd not present)
    integrity      [SKIP]  (tests\integrity.gd not present)
    weapon         [SKIP]  (tests\weapon.gd not present)
    projectile     [SKIP]  (tests\projectile.gd not present)
    enemies        [SKIP]  (tests\enemies.gd not present)
    waves          [SKIP]  (tests\waves.gd not present)
    save           [SKIP]  (tests\save.gd not present)
    progression    [SKIP]  (tests\progression.gd not present)

    RESULT: 0 passed, 0 failed, 11 skipped
    EXITCODE=0

All 11 listed checks SKIP because none of their `.gd` files exist yet — the
declared-up-front list doing exactly what the header comment says it does.
Exit 0.

### 2. Hanging check is killed (throwaway `tests/weapon.gd`, `while true: pass` in `_initialize()`)

    > powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 weapon
    weapon         FAIL  (timed out after 120 s)
        Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org
        === throwaway: hanging forever ===

    RESULT: 0 passed, 1 failed, 0 skipped
    EXITCODE=1
    ELAPSED_SEC=120,2
    GODOT_PROCESSES=0

Expected FAIL text, RESULT line printed, exit 1, no stray `True` (this is the
run that exposed it before the `$null =` fix — see Edit 1), no surviving Godot
process, and wall clock at the 120 s budget rather than unbounded. An earlier
attempt to compare against HEAD produced a corrupted script (a `Set-Content
-NoNewline` in the comparison harness flattened the newlines); it was discarded,
the file restored by byte copy, and the comparison redone with `Out-File`.

### 3. Output capture on the success path (throwaway `tests/projectile.gd`)

Printed five lines including one `[FAIL]` marker, then `quit(0)` — so the only
thing that can fail it is the marker guard, and the only thing at risk is
truncated output.

    > powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 projectile
    projectile     FAIL  (exit code )
        Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org
        === throwaway projectile check ===
          [PASS] alpha
          [FAIL] beta deliberately failing
          [PASS] gamma
        === throwaway projectile check done ===

    RESULT: 0 passed, 1 failed, 0 skipped
    EXITCODE=1
    GODOT_PROCESSES=0

Reported FAIL, and all five of its own print lines are present — including the
trailing "done" line, the one that would be lost if the buffers were read before
EOF. That is the Fix B regression guard.

Note the blank in `(exit code )`: `$proc.ExitCode` is `$null` here, not a real
exit code. Re-run against the pre-edit HEAD version of the script produced
byte-identical output, so this is pre-existing and not a regression from this
commit — see Concerns below.

### 4. Cleanliness

    > git status --short
    (clean)

Only `tools/run_checks.ps1` is in commit `035b8a0` (+14/-2). `Get-ChildItem
[System.IO.Path]::GetTempPath() -Filter 'vibefps_check_*'` → 0 leftovers;
`Get-Process -Name 'Godot*'` → 0 processes. Both throwaway probe files deleted;
`tests/` is back to `capture.gd`, `diagnose.gd`, `headless_smoke.gd` (+ `.uid`s).

## Concerns

1. **`$proc.ExitCode` reads back as `$null`, so the exit-code contract is not
   actually discriminating on this machine.** Verification 3 shows the reason
   string rendering as `(exit code )`. In PowerShell 5.1 a `Start-Process
   -PassThru` handle does not always yield a usable `ExitCode` once the process
   has exited, and `$null -ne 0` is true, so a check is reported FAIL with an
   empty reason. Confirmed pre-existing (identical output from HEAD), and left
   alone as out of scope. But the practical consequence is that the `[FAIL]`
   marker guard, not the exit code, is what currently catches failures — so the
   `(?m)` guard and its one-directional logic are load-bearing, not belt-and-
   braces, and should not be relaxed. Worth a follow-up: `$proc.Refresh()` or
   reading `ExitCode` via `Get-Process`/`WaitForExit()` on a retained handle.
2. **Both fixes are unobservable on a machine where `Start-Process` always
   flushes promptly.** Verification 3 proves Fix B does not *break* capture; it
   cannot prove the pre-fix code was truncating anything, because on this
   hardware it was not. The change is justified by the documented semantics of
   the overloads, not by an observed failure here.

---

# Fix round: PASS was unreachable — the runner could never report a pass

Commit `4052e59` — "fix: cache the process handle so a passing check can report PASS".
Scope: `tools/run_checks.ps1` only, +9/−0. Nothing else changed.

## The defect

A check that passed was reported as FAIL:

    movement       FAIL  (exit code )
    RESULT: 0 passed, 1 failed, 0 skipped

`$proc.ExitCode` read back as `$null`, so `$code -eq 0` was false and the
PASS branch at the verdict step was dead code. The runner could not report
PASS at all — only FAIL or SKIP. The reason string rendered as `(exit code )`
with an empty number, which is the visible symptom of `$null`.

This survived two prior reviews for one reason: every run so far had been
all-SKIP. No file named in `$Tests` existed yet, so no check had ever
actually executed through the runner. The suite had never once exercised a
passing check, a failing check, or a real 31-assertion suite end to end.
The runner's central claim — exit code 0 means passed — had never been
tested.

Root cause: `Start-Process -PassThru` without `-Wait` returns a Process
object whose `ExitCode` is not populated once the process has exited, because
the process handle was never retained. Touching `.Handle` before the process
exits pins it; `ExitCode` then reads correctly.

## The fix

One statement added between the `Start-Process` call and the existing
`WaitForExit`:

    # Cache the process handle BEFORE the process exits. Start-Process -PassThru
    # without -Wait hands back a Process whose ExitCode reads back as $null once
    # the process is gone, because the handle was never retained; touching .Handle
    # here pins it. Without this, `$code -eq 0` is false for every check and the
    # PASS branch is unreachable -- the runner reports a green check as FAIL.
    # The $null = is required: .Handle returns an IntPtr that would otherwise
    # print into the runner's output.
    $null = $proc.Handle

The `$null =` matters for the same reason `$null = $proc.WaitForExit(5000)`
did in the previous round: `.Handle` returns an `IntPtr`, and as a bare
statement PowerShell writes it to the runner's stdout.

Untouched: the `$Tests` array and order, `$CheckTimeoutMs` and the timeout
budget, the `[FAIL]`-marker guard with its `(?m)` flag and one-directional
PASS→FAIL logic, SKIP behaviour, the missing-Godot pre-check, the RESULT line
format, temp-file naming, both bounded waits, and all existing comments.

## Verification

### 1. PASS is reachable (throwaway `tests/movement.gd`, two `[PASS]` lines, `quit(0)`)

    > powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 movement
    movement       PASS

    RESULT: 1 passed, 0 failed, 0 skipped
    EXITCODE=0

The case that had never run before the fix. Pre-fix this same check produced
`FAIL (exit code )` / `0 passed, 1 failed` / exit 1. No stray `IntPtr` printed.

### 2. FAIL on exit code alone (throwaway `tests/weapon.gd`, `quit(1)`, no `[FAIL]` marker)

    > powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 weapon
    weapon         FAIL  (exit code 1)
        Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org
        === throwaway failing check ===
          [PASS] everything looked fine
          quitting with 1

    RESULT: 0 passed, 1 failed, 0 skipped
    EXITCODE=1

Deliberately carries no `[FAIL]` marker, so the exit code is the sole
discriminator — this is the regression guard against "fixing" the problem by
loosening the marker guard. Note the reason now renders `exit code 1` with a
real number; pre-fix it was `exit code ` with nothing.

### 3. Timeout still works (throwaway `tests/projectile.gd`, `while true: pass`)

    > powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 projectile
    projectile     FAIL  (timed out after 120 s)
        Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org
        === throwaway: hanging forever ===

    RESULT: 0 passed, 1 failed, 0 skipped
    EXITCODE=1
    ELAPSED_SEC=120,2
    GODOT_PROCESSES=0

Killed at the 120 s budget rather than blocking, RESULT still printed, no
surviving Godot process. The handle cache does not disturb the timeout or
kill paths.

### 4. The real check passes end to end (throwaway `tests/enemies.gd`, a copy of `tests/headless_smoke.gd`)

    > powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 enemies
    enemies        PASS

    RESULT: 1 passed, 0 failed, 0 skipped
    EXITCODE=0
    HEADLESS_SMOKE_UNMODIFIED=True

The runner suppresses captured output on PASS, so to confirm the *real* suite
ran — and not a trivially short script — the same script was also invoked
directly with output captured:

    EXITED=True EXITCODE=0
      [WARN] display server cannot capture the mouse; mouse look assertions skipped
      [WARN] display server cannot recapture the mouse; recapture assertion skipped
    === RESULT: 31 checks, 0 failed, 2 warnings ===
    CHECK_LINES=31
    WARN_LINES=2
    FAIL_LINES=0

31 checks, 0 failed, 2 warnings — the expected shape. `headless_smoke.gd` was
SHA-256 hashed before and after to confirm it was neither modified nor
deleted; only the `enemies.gd` copy was thrown away.

### 5. Full suite and cleanliness

    > powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1
    ... 11 x [SKIP] (tests\<name>.gd not present) ...
    RESULT: 0 passed, 0 failed, 11 skipped
    EXITCODE=0

    > git status --short
     M tools/run_checks.ps1        (before commit; clean after)

    TEMP_LEFTOVERS=0   PROBE_TEMP_LEFTOVERS=0   GODOT_PROCESSES=0

All four throwaway probe files deleted. `tests/` back to `capture.gd`,
`diagnose.gd`, `headless_smoke.gd` (+ `.uid`s).

## Concerns

1. **The `[FAIL]` marker guard must stay.** It was the only thing catching
   failures while the exit code was dead, and it is still the second line of
   defence. Verification 2 exists to keep it honest.
2. **This class of bug was invisible to the runner's own green runs.** An
   all-SKIP suite exits 0, which is indistinguishable from a suite that ran
   and passed. Until real `tests/*.gd` files land, the runner's PASS path has
   now been proven only by throwaway probes — the first genuine check added
   in a later phase should be treated as the real end-to-end proof.
3. **Both fixes in this and the previous round were unobservable before they
   were made.** The bounded waits and the EOF drain are justified by the
   documented overload semantics, not by a reproduced failure on this
   hardware. That pattern — code correct by reading, unproven by running —
   is what let the PASS defect through two reviews.
