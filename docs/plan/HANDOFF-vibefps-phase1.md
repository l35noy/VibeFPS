# HANDOFF — VibeFPS, Phase 1 complete

Paste this whole document to the model taking over. Everything it needs is on
disk at the paths below; read them before acting.

---

## 1. What this project is

A small 3D FPS in **Godot 4.7.2** (GDScript, Jolt Physics) at `E:\projects\VibeFPS`,
built as a Vibe Coding exercise. Russian-language project docs.

Working method, and it is the whole point of this project: a small working
system → check it → stabilise it → extend. Nothing is considered done until it
has been verified.

Engine path (do not duplicate it anywhere else):
`E:\Godot\Godot_v4.7.2-stable_win64.exe`

---

## 2. Read these first, in this order

| What | Path |
|---|---|
| Design spec (architecture, collision layers, all balance values) | `C:\Users\serhio\.opencode\plan\2026-10-07-vibefps-foundation-design.md` |
| Phase 0 plan (done) | `C:\Users\serhio\.opencode\plan\2026-10-07-vibefps-foundation-plan.md` |
| Phase 1 plan (done) | `C:\Users\serhio\.opencode\plan\2026-10-07-vibefps-phase1-plan.md` |
| **Ledger — rulings, corrections, lessons, deferred items** | `C:\Users\serhio\.opencode\plan\sdd\2026-10-07-vibefps-phase1-plan\progress.md` |
| Ledger, Phase 0 | `C:\Users\serhio\.opencode\plan\sdd\2026-10-07-vibefps-foundation-plan\progress.md` |
| Repo copy of the Phase 0 plan | `E:\projects\VibeFPS\docs\superpowers\plans\2026-10-07-vibefps-foundation.md` |
| Project's own rules | `E:\projects\VibeFPS\PROJECT.md` and `CHECKLIST.md` |

**The ledger is the memory.** It records every ruling, every plan correction and
every deferred item, with the cost of getting each one wrong. Read it in full.

---

## 3. Current state

`git log`: `8ccc2cd` on `main`, branch of a
direct-to-main workflow the owner chose deliberately — there is no worktree.

Automated suite:

```
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1
→ RESULT: 8 passed, 0 failed, 4 skipped, exit 0
```

8 checks: smoke, movement (68 assertions), input_actions, input_gate,
weapon_data, integrity (21 assertions), projectile, weapon.
4 SKIP: enemies, waves, save, progression — not started yet.

Built and verified: FPS player controller (move with `move_toward`
acceleration and air control, look, jump, sprint, kill-plane respawn), input
gate, `WeaponData` resource, projectile + hurtbox, pistol (magazine, reload,
rate limit), a shooting range with three targets, player visible geometry with
working shadows, explicit collision layers (incl. main.tscn Floor and player
mask, guarded by an integrity check), explicit frame-mode keys in
project.godot.

Not built: enemies, waves, boss, locations, lobby, points, shops, save, HUD,
audio, outlines.

### Uncommitted in the working tree — the owner commits, nobody else

```
 M .gitignore  M CHECKLIST.md  M PROJECT.md  M main.tscn  M player.gd
 M player.tscn  M project.godot  M tests/integrity.gd  M tests/movement.gd
```

Post-Phase-1 fix-up (acceleration/air-control, scene layers + integrity check,
frame-mode keys, Godot-path single source, CHECKLIST sync) — recorded in the
Phase 1 ledger, section "Post-Phase-1 fix-up".
Owner action pending: `git rm --cached .vscode/settings.json` (agents may not
run git mutations).

---

## 4. Non-negotiable process rules

**Never run `git commit` or `git add`.** The project owner commits personally.
This was decided by the owner after the controller committed twice without
permission. Leaving changes unstaged is correct, not an oversight.

**PowerShell execution policy rejects bare script execution.** Verified
2026-10-07: every scope reports `Undefined` (the old "Restricted at every
scope" diagnosis was wrong), but the effective default still rejects the bare
`.\tools\run_checks.ps1` form with `PSSecurityException`. `pwsh -File` also
works (effective `RemoteSigned`), but the canonical form is the one below —
do not fork the contract:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 [filter]
```

There is no bash on this machine. Use PowerShell.

**To read a harness's printed assertions directly**, use `Start-Process` with
`-RedirectStandardOutput`/`-RedirectStandardError` and read the files back.
PowerShell 5.1's `2>&1` does not reliably capture Godot's output.

---

## 5. The verification discipline — this is the core of the project

**Every check must be proven able to fail.** A check that passes for the wrong
reason is broken and must be tightened. Asserting that a check is green is not
verification; mutating the code to make it red and restoring it byte-identical
(SHA-256 before and after) is. Every completed task in both phases carries at
least one such recorded mutation.

**A suite where everything SKIPs proves nothing.** It exits 0 and is
indistinguishable from a suite that ran and passed. Phase 0 burned three fix
rounds and two reviews on a runner whose PASS branch was unreachable, because
every run was `0 passed, 11 skipped` and nobody fed it a real check. Any
verification of the runner must include at least one case that actually executes.

**Script-level mutation does not validate scene wiring.** This is the most
important lesson and it cost two real bugs. `tests/projectile.gd` builds its
world in code, so it was **green while the projectile was fundamentally broken
in the actual game** — it died on the player's own body after one tick (camera
inside the capsule, `CharacterBody3D` defaults to layer 1 world), and the
targets' bodies sat on a bitmask that matched the projectile's mask so **no
damage was applied at all**. Both were found only by shooting in the running
game, not by reading code or by any automated check.

Anything that wires nodes together in a scene needs a check that loads that
scene. That gap is still open — see §8.

**Expect the plan to be wrong; verify its claims.** Fourteen corrections have
been made across two phases. Implementers caught essentially all of them. The
most recent was the controller's own: it read `collision_layer = 4` in a `.tscn`
as layer 4 when the value is a **bitmask** — `4` is `100` in binary, bit 2, i.e.
layer 3 `enemy_body`, which was already correct. The prescribed fix
(`collision_layer = 3`) would have produced layers 1+2 and **caused** the very
defect it was meant to remove. The implementer applied the edit, checked the
semantics, found it broke things, and reverted it instead of complying. Do that.

**`_ready()` is not synchronous.** A node added to the tree reports ready on a
later main-loop pass. Checks that construct nodes must wait for
`is_node_ready()`.

---

## 6. Architecture you must not break

Collision layers, defined in `project.godot` and load-bearing:

| # | Name | Holds |
|---|---|---|
| 1 | `world` | level geometry, `StaticBody3D` |
| 2 | `player_body` | the player's `CharacterBody3D` |
| 3 | `enemy_body` | enemy `CharacterBody3D` |
| 4 | `enemy_hurtbox` | `Hurtbox` `Area3D` |
| 5 | `projectile` | `Projectile` `Area3D` |
| 6 | `interactable` | doors, shop points |
| 7 | `player_hurtbox` | the player's `Hurtbox` |

Projectile mask is `1 | 4`: it must **not** match enemy bodies, only world
geometry and hurtboxes. `Hurtbox` holds no health state — it emits
`damage_taken(amount)` and nothing else; health belongs to whoever owns it.
`Hurtbox.damage_multiplier` is the lever Phase 2 uses for the boss weak spot
(×2), so its contract is fixed now: multiply at application time.

Autoloads planned but **not yet implemented**: `GameState` (points, unlocked
locations, owned weapons, and it owns scene transitions), `SaveSystem`
(`user://save.json`), `Sfx`.

**Input seam, used twice on purpose.** `player.gd` and `pistol.gd` each define
`_mouse_mode_for_play_input()` — the single reader of `Input.mouse_mode` for
permission purposes. Headless cannot capture the cursor, so checks override
this seam with a subclass instead of faking a capture. Do not consolidate
unless a third consumer appears.

`Pistol.reset_for_scene_change()` exists specifically for Phase 3: without it a
half-full magazine survives a trip to the lobby and every trip costs the player
free rounds. It is a contract for future code, not dead code.

---

## 7. Balance values already approved — do not re-litigate

Pistol: damage 30, 120 rpm, magazine 10, reload 1.2 s, projectile speed 40 m/s,
infinite reserve. Player 100 HP. Contact enemy 50 HP, 10 damage. Flying 40 HP.
Boss 600 HP with a ×2 weak spot. Location 1 waves: 10 contact / 20 contact /
15 contact + 5 flying / boss. Score: 10 per enemy, 50 per wave, 500 per clear
(~1200 per full clear). Points reward, enemies spawn ≥12 m from the player,
10 s between waves.

Projectile speed is **finite** by design: at 40 m/s a shot crosses 15 m in
0.375 s, which is the window that lets both the player and enemies dodge.

---

## 8. Open items carried forward — these are decisions, not cleanups

**Thin hurtboxes.** `Area3D` overlap is discrete. At 40 m/s and 120 Hz a
projectile crosses exactly 1/3 m per tick, so a hurtbox thinner than that is
passed over between samples, and no tuning of the projectile fixes it — that
would need `ShapeCast3D`, which the spec forbids. Test targets are all ≥0.5 m.
A contact enemy capsule is 0.8 m across and survives; thin body parts or small
flying enemies may not. **Phase 2 decision:** accept a minimum hurtbox width as
a rule, or move to `ShapeCast3D` and revisit the prohibition.

**`range.tscn` has no check.** Nothing in the suite would catch a regression of
the target layers back to the hurtbox bit. Deferred because `range.tscn` is
replaced wholesale in Phase 2 when real locations arrive — but if Phase 2 keeps
it, close the gap.

**The stock capture harness cannot frame the player.** `tests/capture.gd` puts
the camera at y=1.7, inside the 0–1.8 capsule, so the body never appears in
frame. A capture harness that can frame the player is owed to Phase 6.

**Esc unverified in the running game.** Keyboard input does not reach the Godot
window in this environment (four injection methods confirmed injected yet
ignored; mouse works). The gate is covered by `tests/weapon.gd` and
`tests/input_gate.gd`, but nobody has observed it live.

**`main.tscn` geometry is untouched** while `run/main_scene` points at
`range.tscn`. Its only change is the explicit `Floor collision_layer = 1`
(fix-up, guarded by an integrity check). `tests/integrity.gd` depends on
main.tscn's exact 20×20 platform. Reverting the main scene is one line.

---

## 9. What to do next: Phase 2

Phase 2 is enemies. **It needs its own plan written before any code** — one
plan per subsystem, as with Phases 0 and 1. Its spec sections are 6.2, 6.3,
7.3, 7.4 and 9.9 of the design spec.

Scope: player and enemy health, contact damage, the contact enemy
(`CharacterBody3D` + `NavigationAgent3D`, baked navmesh, moves toward the
player), the flying enemy (hovers at range, fires projectiles), the boss (one
phase, one telegraphed area attack, ×2 weak spot via `damage_multiplier`),
spawning, waves, and the first location scene.

Open questions Phase 2 must settle — the spec leaves them open:
- **Hurtbox minimum width** (see §8). Decide this before the first enemy, not
  after it fails.
- Whether the enemy body or its hurtbox is the authoritative hit volume, now
  that `Hurtbox` deliberately holds no state.
- Whether a burst of projectiles into one hurtbox should stack damage. At the
  projectile level one shot is one `damage_taken` event; two separate bullets
  correctly emit twice. That decision belongs to the enemy's owner.

Carry the verification discipline into it unchanged. The two bugs that reached
Phase 1 green were both found by playing, not by checking — that will get worse
as the systems multiply, not better.

---

## 10. Ledger rulings — read before deciding anything

`C:\Users\serhio\.opencode\plan\sdd\2026-10-07-vibefps-phase1-plan\progress.md`
holds every ruling with what it costs if wrong, including:

- the owner's decision to work directly on `main` with no worktree
- the controller's violation, committing twice without permission, recorded as a
  process violation and not as a justified workaround
- fourteen plan corrections, with the bitmask error being the controller's own
- the blind spot in the class-cache staleness check (a cache stale in content
  but newer than every source is not detected)
- every deferred minor, so nothing is silently discarded