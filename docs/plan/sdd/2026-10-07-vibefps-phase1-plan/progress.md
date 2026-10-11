# SDD ledger — Phase 1: Оружие и снаряды

Plan: C:\Users\serhio\.opencode\plan\2026-10-07-vibefps-phase1-plan.md
Spec: C:\Users\serhio\.opencode\plan\2026-10-07-vibefps-foundation-design.md
Workspace: C:\Users\serhio\.opencode\plan\sdd\2026-10-07-vibefps-phase1-plan\
Branch: main. Partner commits; neither controller nor agents run git commit/git add.

Baseline: 11541c8 (Phase 0 committed by partner). Suite at baseline: 5 passed, 6 skipped.

## Phase 0 carry-over

The stale-class-cache defect found in Phase 1 Task 1 was a defect in the Phase 0 runner fix: the import pass fired only when the cache file was ABSENT, so a cache that existed but omitted a new class_name left the script unresolvable and the check died at parse instead of reporting its own failure. Fixed in Phase 1 before Task 2, because Task 2 adds Hurtbox/Projectile and Task 3 adds Pistol — each would have hit it.

## Tasks

Task 1: WeaponData — complete (UNCOMMITTED)
Task 2: Projectile + Hurtbox — in progress
Task 3: complete (UNCOMMITTED). scripts/pistol.gd + tests/weapon.gd
  Controller verification: full suite 8 passed / 0 failed / 4 skipped, exit 0, no [WARN]. Reviewed pistol.gd: try_fire order is checks -> instantiate -> decrement -> cooldown -> signals; reload restart refused without touching the timer; rate limit in seconds via _process; input gate via InputGate; reset_for_scene_change present as the Phase 4 contract. 126 assertions.
  Launch is called AFTER add_child — correct and load-bearing: Projectile._ready() disables its own processing, so a launch() before entering the tree would be overwritten and the projectile would hang motionless.

Ruling: the plan described projectile.tscn as a child MeshInstance3D with no CollisionShape3D. An Area3D with no shape detects nothing, so that projectile would have flown through walls and the hit check would have been green for the wrong reason. Plan corrected before Task 5 dispatch. Thirteenth plan correction, and the first about engine behaviour rather than wording.

Ruling: Review Focus item 3 is only PARTIALLY closed. Area3D overlap is discrete: at 40 m/s and 120 Hz a projectile crosses exactly 1/3 m per tick, so a hurtbox thinner than that is passed over between samples and no edit to the projectile fixes it — that needs ShapeCast3D, which the brief forbids. The Task 2 implementer made every test target at least 0.5 m wide. A contact enemy capsule is 0.8 m across and survives, but thin body parts or small flying enemies may not. Carried to Phase 2 as an open decision: accept a minimum hurtbox width as a rule, or move to ShapeCast3D and revisit the prohibition.

Ruling: agent deviated by asserting reload timing in wall-clock seconds rather than "144 physics frames" (true only at exactly 120 fps) and by putting the rate limit in try_fire() rather than can_fire(). Accepted. A frame-count assertion encodes the frame rate into the contract; and "may I fire" (permission) is genuinely a different question from "am I off cooldown" (a timer).

Task 3: harness trap for future tasks — `_ready()` is NOT synchronous. A node added to the tree reports ready on a later main-loop pass, so the first four pistols under test read current_mag() == 0. Checks must wait for `is_node_ready()`.

Task 3: agent added two rules the brief left open — an empty magazine auto-starts a reload (required to make Review Focus item 1 reproducible) and reloading a full magazine is refused. Both pinned by assertions. Accepted.

Ruling: two `_mouse_mode_for_play_input()` seams now exist, one in player.gd and one in pistol.gd. Behaviour is correct in game, but a test must override both to exercise a full firing scenario. Not consolidating now — YAGNI. Revisit if a third consumer appears.
Task 4: complete (UNCOMMITTED). player.tscn + scripts/player_body_material.tres
  Controller verification: opened the apex-jump frame myself — white capsule airborne, distinct blurred shadow on the floor below-right, separated by a clear gap. This closes the Phase 0 deferral: shadows were enabled but unprovable, and are now provable.
  Diff confirmed: BodyMesh MeshInstance3D, CapsuleMesh radius 0.4 height 1.8, offset y=0.9 matching the CollisionShape3D. Material albedo 0.82 white, metallic_specular 0.0, matching the floor. No outlines, as instructed. Nothing committed, nothing staged; HEAD still 11541c8.
Task 5: complete (UNCOMMITTED). pistol.tscn, projectile.tscn, range.tscn, scripts/range_target.gd, player.tscn + player.gd wiring, project.godot main_scene.
  Controller verification: full suite 8 passed / 0 failed / 4 skipped, exit 0, no [WARN]. Range scene wired, run/main_scene now uid://jyplrr3l.

Ruling — CONTROLLER ERROR, corrected by the implementer. I diagnosed a race in range.tscn: target bodies set to `collision_layer = 4` looked like they were on the hurtbox layer while the projectile's mask is `1 | 4`, so body_entered and area_entered would both fire and `_spent` would swallow the damage. The reasoning about the failure mode was right, but my proposed fix was WRONG. `collision_layer` in a .tscn is a BITMASK, not a layer number: `4` is binary 100, bit 2, which is layer 3 `enemy_body` — already correct per spec 6.3. Layer 4 would be written `8`. Projectile mask `1|4` = bitmask 9; target body 4 AND 9 = 0, so body_entered cannot fire at all. My fix (`collision_layer = 3`) would have produced bitmask 011 = layers 1+2, and since the projectile mask contains layer 1, it would have MATCHED and reproduced the exact defect I was trying to remove. The implementer applied the edit, verified the semantics, and reverted it rather than complying. Fourteenth plan correction, and the first one that was mine rather than the plan's.

The implementer also proved the failure mode is real and deterministic: forcing a target body onto the genuine hurtbox layer produced damage on 0 of 6 shots, with body_entered reliably winning on Godot 4.7.2 / Jolt. So the defect was absent, not latent.

Task 5: two real bugs found by SHOOTING, not by reading code. (a) The projectile died on the player's own body after one tick — the camera sits inside the player capsule and CharacterBody3D defaults to layer 1 world; fixed with Player.collision_layer = 2. (b) The target bodies were first set to `collision_layer = 3`, which is layers 1+2 — the projectile's mask matched them and no damage was applied at all. BOTH were green on tests/projectile.gd, because that harness builds its world in code and never goes through a scene with a player. Recorded as the phase's most important lesson: a check that constructs its own world validates the script and not the wiring. Scene-level wiring needs scene-level checks.

Ruling: main.tscn left untouched despite being in the brief's Files list. tests/integrity.gd depends on its exact 20x20 platform (sprints off the +X edge and must fall), and range.tscn's floor and walls cannot satisfy that; repointing only smoke.gd would have split four harnesses across two scenes. Accepted. Reverting run/main_scene is one line.

Ruling: range.tscn is covered by NO check in run_checks.ps1, so nothing in the suite would catch a regression of the target layers back to the hurtbox bit. A check reading the loaded range.tscn target collision_layers would close it. Deferred: range.tscn arrives fully in Phase 2 when locations replace the test range, so a check written now would be thrown away. Cost if wrong: a silent regression of the layer split survives until Phase 2 notices.

Task 5: one manual item NOT verified — Esc. Keyboard input does not reach the Godot window in this environment (four injection methods confirmed injected yet ignored, while mouse input works). The implementer did not substitute another trigger. The gate itself is covered by tests/weapon.gd and tests/input_gate.gd; the running-game observation is not claimed.

Task 5: targets staggered off the centre line (0 / +3 / -5 m in X). On a single line of fire the near target physically blocked the mid and far ones — shots aimed at the far target landed on the near one.

=== PHASE 1 COMPLETE (UNCOMMITTED) ===
  8 checks green: smoke, movement, input_actions, input_gate, weapon_data, integrity, projectile, weapon. 4 SKIP (enemies, waves, save, progression).
  Assertion counts: smoke 6, movement 52, input_actions 9, input_gate 5, weapon_data 20, integrity 16, projectile 75, weapon 126 = 309 assertions.

## Deferred minors

(none yet)

## Rulings

Ruling: Phase 1 runs Task 4 in parallel with Task 2. Task 4 touches only player.tscn and a new material .tres; Task 2 touches scripts/ and tests/. No file overlap, and the runner was hardened for concurrent runs with per-process unique temp files, so two simultaneous runs cannot contaminate each other. Revisit if either task reports a conflict.

Ruling: Task 4's acceptance criterion required a frame the stock tests/capture.gd cannot produce — the camera sits at y=1.7, inside the 0..1.8 capsule, so the body never appears in frame during a jump. The implementer did NOT edit capture.gd (outside its scope), instead using throwaway probe scripts outside res:// to get a frame containing both body and shadow, then a control with the mesh removed to prove the shadow came from the new geometry. Accepted. Cost if wrong: the stock capture harness still cannot self-demonstrate shadows, so the next visual task hits the same wall. A capture harness able to frame the player is owed to Phase 6.

Ruling: Task 4 reported tests/projectile.gd failing 5 of 75 checks while running parallel to Task 2. Not a Task 4 regression — that harness does not load player.tscn; smoke, movement and integrity all pass individually. Recorded because concurrent suites interleave in the output and the failure belonged to the other task's in-flight work.

Ruling: the Phase 1 plan's brief snippets were wrong three times in ways only the implementing agent could catch. Step order put the mandatory red run before the step that registers the name in $Tests; Get-ChildItem -LiteralPath with -Include silently filters nothing on PowerShell 5.1 (returned all 172 repo files, so any edit anywhere would have forced an import); and the prescribed stale-cache reproduction (write [] into the cache) makes the cache the newest file in the repo, so an mtime-based rule reads it as fresh — the real staleness was reproduced by backdating the cache's mtime. Eighth, ninth and tenth plan corrections. The implementer caught all three and corrected them; the pattern from Phase 0 continues.

Ruling: residual blind spot accepted. A cache that is stale in CONTENT but newer than every source is not detected, because detecting it would require parsing every .gd. Unreachable from normal work — a class enters the cache only via an import that runs after the source exists. Cost if wrong: a hand-edited cache can silently hide a class until the next import.

Task 1: complete — controller verification: full suite 6 passed / 0 failed / 6 skipped exit 0. Real-scenario test of the runner fix: a new class_name script created after the cache triggered re-import and registered the class; removing the file triggered re-import again. Probe files deleted, tree clean.

## Post-Phase-1 fix-up ("подправить то что имеется" — owner's request, executed after HANDOFF)

Baseline re-verified by lead before work: 8 passed / 0 failed / 4 skipped, exit 0, tree clean (owner had committed Phase 1).

Ruling: the HANDOFF's claim "PowerShell execution policy is Restricted at every scope" is WRONG in diagnosis, RIGHT in prescription. Empirical check: every scope reports Undefined; the effective default (Restricted) is what rejects bare `.\tools\run_checks.ps1`. Canonical command `powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 [filter]` verified working (input_gate PASS); bare invocation and no-Bypass invocation verified failing (PSSecurityException / UnauthorizedAccess). Also verified: `pwsh -NoProfile -File` works (effective RemoteSigned). One canonical form kept — pwsh form deliberately not adopted, to avoid forking the contract. Cost if wrong: none; the prescription was already correct.

Ruling: CHECKLIST "Известные problema" list was stale — 5 of 9 items (ЛКМ, ui_cancel, input gating, shadows, fall-through check) were already fixed in Phases 0–1 and never moved to "Исправлено"; item 5 (layers) was partially fixed. Verified each claim against code before touching anything (verdicts with file:line). Cost if wrong: fixing already-fixed items would have churned working code; trusting the stale list would have hidden the 3 genuinely open items.

Completed (all UNCOMMITTED, owner commits):
- Movement acceleration + air control (was checklist item 4, the only actual behaviour defect): `player.gd` gains `@export ground_acceleration = 20.0` and `@export air_control = 0.4`, `move_toward` accumulation replaces direct assignment; braking reuses the same mechanism (target zero). `tests/movement.gd` 52 → 68 assertions; red baseline captured first (4 new checks failed on old code); 8 mutations, all with SHA-256 identical before/after (CD747…63F7), incl. nuclear mutations for precondition checks M7/M8 — accepted and documented as such.
- Scene wiring gap (HANDOFF §8 "range.tscn has no check" analogue for main.tscn): `Floor collision_layer = 1` explicit, player `collision_mask = 1` explicit, new layer regression check in `tests/integrity.gd` 16 → 21 assertions; mutation = flip Floor layer 1→2 → new check FAILs first → restore byte-identical (800CF3…4B77).
- Frame-mode keys (checklist item 7): `run/max_fps=0`, `window/vsync/vsync_mode=1`, `rendering/scaling_3d/scale=1.0` explicit in project.godot with `;` comments — agent caught that ConfigFile rejects `#` comments (parse error) before it escaped; keys survive `--import` (SHA-256 before/after). ACCEPTED RISK: editor may strip them again on UI save; fallback documented — they are engine defaults, behaviour identical without them.
- Godot path single source (decision D8): `$GodotBin` in tools/run_checks.ps1 is the only live copy; PROJECT.md:56 now points at the canon; `.vscode/settings.json` added to .gitignore. OWNER ACTION PENDING: `git rm --cached .vscode/settings.json` (agents may not run git mutations). Historical docs/superpowers/* copies deliberately untouched (protocols).
- CHECKLIST.md synced: 9 → 0 known problems, "Исправлено" 4 → 13 items, grep sweep for stale references outside the rewritten block found nothing needing edits.

Concurrency incident (recorded because it cost a restoration): the two parallel agents' Godot processes raced on project.godot — one agent's editor/import saved a stale settings snapshot over the other's freshly added keys (full revert to git state mid-run). Agent detected it by SHA-256, restored, lead re-verified after both agents finished. Lesson: even with per-process temp files (runner), project.godot itself is SHARED MUTABLE STATE during concurrent runs — don't add settings to project.godot from two tasks at once, and always re-verify keys after any parallel phase.

Parallelism ruling: Phase-1 ledger allowed Task4 ∥ Task2 on disjoint files. This run: acceleration (player.gd, tests/movement.gd) ∥ layers+keys (main.tscn, player.tscn, tests/integrity.gd, project.godot) — disjoint ownership held, no cross-blame failures; lead ran an independent control suite after both returned: 8/0/4 exit 0.

Ledger/verification discipline applied unchanged: every new/pinned check carries a mutation proof with SHA-256 round-trip; no git mutations anywhere; all runs via canonical command.

=== FIX-UP COMPLETE (UNCOMMITTED) === Full suite 8 passed / 0 failed / 4 skipped, exit 0. integrity 21 assertions, movement 68, total unchanged elsewhere (309 → 309+16+5=330).