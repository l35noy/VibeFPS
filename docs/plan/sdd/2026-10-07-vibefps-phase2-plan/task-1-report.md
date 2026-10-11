# Task 1 report — EnemyData: ресурс характеристик врага

**Status:** DONE
**Date:** 2026-10-08
**Branch:** main, working tree only — no `git add` / `git commit` performed (project rule: the owner commits personally).

---

## 1. What I implemented

| File | Kind | Content |
|---|---|---|
| `scripts/enemy_data.gd` | new (26 lines) | `class_name EnemyData extends Resource`, `enum EnemyKind { CONTACT, FLYING, BOSS }`, 7 `@export` fields, `is_valid()` |
| `data/enemies/contact.tres` | new (13 lines) | `EnemyData` instance: `display_name = "Contact"`, `max_health = 50.0`, `contact_damage = 10.0`, `move_speed = 6.0`, `spawn_interval = 1.5`, `color = Color(0.8, 0.25, 0.25, 1)`, `kind = 0` |
| `tests/enemies.gd` | new (108 lines) | first check file of Phase 2 — 11 assertions, `_bail()` precondition, `quit(1)` on any failure |

`scripts/enemy_data.gd` is the brief's Produces block **copied verbatim** (class header, enum + its Russian "why" comment, all 7 exported fields with their comments), plus `is_valid()` exactly as specified:
`max_health > 0.0 and contact_damage > 0.0 and move_speed > 0.0 and spawn_interval > 0.0`.
The only text I added beyond the brief is the Russian `##`-doc above `is_valid()` (mirrors `scripts/weapon_data.gd`'s doc style, explains *why* the method exists). Line continuation `\` formatting matches `scripts/weapon_data.gd`.

`data/enemies/contact.tres` is byte-for-byte the brief's Step 4 block.

`tests/enemies.gd` is structured and worded after `tests/weapon_data.gd` (the brief's named style reference): `extends SceneTree`, one section per topic, `[PASS]`/`[FAIL]` per assertion with a `detail` argument, `_failures: PackedStringArray` + `_checks` counter, `_finish()`, `_bail()` for preconditions, `quit(1 if _failures.size() > 0 else 0)`.

### Assertions in `tests/enemies.gd` (11)

Section "contact.tres must load as an EnemyData":
1. `res is EnemyData` (detail prints the resolved script path)

Section "the values the design fixes for the contact enemy":
2. `max_health == 50.0`
3. `contact_damage == 10.0`
4. `move_speed == 6.0`
5. `spawn_interval == 1.5`
6. `kind == EnemyData.EnemyKind.CONTACT`

Section "is_valid() can answer false, so is_valid() == true means something":
7. `data.is_valid()` is true
8–11. one `_is_valid_rejects({...})` probe per term of `is_valid()`'s condition (`max_health`, `contact_damage`, `move_speed`, `spawn_interval` each set to `0.0` on a throwaway `EnemyData.new()`), so dropping any single term from the implementation turns exactly one red.

`display_name` and `color` are **not** asserted — the brief's assertion list omits them and no Phase 2 consumer reads them yet. See "Concerns".

---

## 2. Ruling applied — the defective invariant was NOT implemented

The brief's last bullet asked for `max_health / contact_damage == 10.0` with tolerance 0.0001. Per the controller's ruling (and the pre-flight ledger's T1 DEFECT entry) that assertion is omitted entirely from `tests/enemies.gd` — no trace of it, no tolerance constant, no `_close()` helper.

Spec authority, verified in `docs/superpowers/specs/2026-10-07-vibefps-foundation-design.md`:

- **§7.2 Игрок** — "Здоровье: 100. Контактный урон врага: 10 → **10 попаданий до смерти**" ⇒ 100 / 10 = 10. This is the **player** invariant.
- **§7.3 Враги** — table row "Контактный | 50 | 10" ⇒ the contact enemy is 5 hits, not 10.

So the "10 hits" number is `player.max_health / contact.tres.contact_damage` and belongs to Task 2, where `player.max_health` exists. Task 1 keeps `contact_damage == 10.0` (assertion 3), which is the half that *is* the enemy's own.

---

## 3. TDD evidence

### RED — test written first, implementation absent

```
PS E:\projects\VibeFPS> powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 enemies
importing project (class cache missing or stale) ...
enemies        FAIL  (exit code 1)
    Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org
    SCRIPT ERROR: Parse Error: Could not find type "EnemyData" in the current scope.
       at: GDScript::reload (res://tests/enemies.gd:38)
    SCRIPT ERROR: Parse Error: Identifier "EnemyData" not declared in the current scope.
       at: GDScript::reload (res://tests/enemies.gd:39)
    SCRIPT ERROR: Parse Error: Cannot infer the type of "probe" variable because the value doesn't have a set type.
       at: GDScript::reload (res://tests/enemies.gd:39)
    SCRIPT ERROR: Parse Error: Could not find type "EnemyData" in the current scope.
       at: GDScript::reload (res://tests/enemies.gd:75)
    SCRIPT ERROR: Parse Error: Could not find type "EnemyData" in the current scope.
       at: GDScript::reload (res://tests/enemies.gd:77)
    SCRIPT ERROR: Parse Error: Cannot infer the type of "data" variable because the value doesn't have a set type.
       at: GDScript::reload (res://tests/enemies.gd:77)
    SCRIPT ERROR: Parse Error: Identifier "EnemyData" not declared in the current scope.
       at: GDScript::reload (res://tests/enemies.gd:91)
    ERROR: Failed to load script "res://tests/enemies.gd" with error "Parse error".
       at: load (modules/gdscript/gdscript_resource_format.cpp:46)

RESULT: 0 passed, 1 failed, 0 skipped
EXITCODE=1
```

Matches the brief's Step 2 expectation exactly (`enemies FAIL`, `enemy_data.gd` missing, exit code 1).

### GREEN — after creating the two implementation files

```
PS E:\projects\VibeFPS> powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 enemies
importing project (class cache missing or stale) ...
enemies        PASS

RESULT: 1 passed, 0 failed, 0 skipped
EXITCODE=0
```

(The runner prints a passing check's own stdout only on failure, so the per-assertion listing for the green run is reproduced verbatim in the mutation section below, where the same 11 assertions are printed with 10 PASS.)

---

## 4. Mutation proof

Mutation: `data/enemies/contact.tres`, `contact_damage = 10.0` → `5.0`. Nothing else touched.

**SHA-256 before mutation**

```
PS> (Get-FileHash -LiteralPath 'E:\projects\VibeFPS\data\enemies\contact.tres' -Algorithm SHA256).Hash
15F99A774C75B82CB613C7746BC50C1934D2E2FCABFF72AD185E2CEAF67FF423
```

**Command + output with the mutation in place**

```
PS E:\projects\VibeFPS> powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 enemies
importing project (class cache missing or stale) ...
enemies        FAIL  (exit code 1)
    Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org
    === enemies ===
    -- res://data/enemies/contact.tres must load as an EnemyData
      [PASS] contact.tres is an EnemyData (script=res://scripts/enemy_data.gd)
    -- the values the design fixes for the contact enemy
      [PASS] max_health is 50.0 (got 50.0000)
      [FAIL] contact_damage is 10.0 (got 5.0000)
      [PASS] move_speed is 6.0 (got 6.0000)
      [PASS] spawn_interval is 1.5 (got 1.5000)
      [PASS] kind is EnemyData.EnemyKind.CONTACT (got 0)
    -- is_valid() can answer false, so is_valid() == true means something
      [PASS] contact.tres reports itself valid
      [PASS] a zero max health is rejected
      [PASS] a zero contact damage is rejected
      [PASS] a zero move speed is rejected
      [PASS] a zero spawn interval is rejected
    === RESULT: 11 checks, 1 failed ===
      FAILURE: contact_damage is 10.0 (got 5.0000)

RESULT: 0 passed, 1 failed, 0 skipped
EXITCODE=1
```

The run fails on **exactly the contact_damage assertion** — `11 checks, 1 failed`, the single `[FAIL]` being `contact_damage is 10.0`. Every other assertion stays green, which is the point: the check localises the break instead of going wholesale red. (Note that `contact.tres reports itself valid` correctly stays green: `5.0 > 0.0`, so the mutation is a balance edit, not an invalid resource — `is_valid()` is not supposed to catch it.)

Mutated-file hash for contrast:

```
PS> (Get-FileHash -LiteralPath 'E:\projects\VibeFPS\data\enemies\contact.tres' -Algorithm SHA256).Hash
A8C399173FF586B711A7B0B16359AD47059169228F32F8FE8A3EDAE146E85A87
```

**Restore + verification**

```
PS E:\projects\VibeFPS> (Get-FileHash -LiteralPath 'E:\projects\VibeFPS\data\enemies\contact.tres' -Algorithm SHA256).Hash
SHA256_AFTER_RESTORE=15F99A774C75B82CB613C7746BC50C1934D2E2FCABFF72AD185E2CEAF67FF423
MATCHES_BEFORE=True

PS E:\projects\VibeFPS> powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 enemies
importing project (class cache missing or stale) ...
enemies        PASS

RESULT: 1 passed, 0 failed, 0 skipped
EXITCODE=0
```

**Summary of the three hashes**

| State | SHA-256 of `data/enemies/contact.tres` |
|---|---|
| before mutation | `15F99A774C75B82CB613C7746BC50C1934D2E2FCABFF72AD185E2CEAF67FF423` |
| mutated (`contact_damage = 5.0`) | `A8C399173FF586B711A7B0B16359AD47059169228F32F8FE8A3EDAE146E85A87` |
| after restore | `15F99A774C75B82CB613C7746BC50C1934D2E2FCABFF72AD185E2CEAF67FF423` — **identical to before** |

The mutation cycle was run twice end-to-end during this task (once while normalising the file's trailing newline, once for the recorded hash pair above); both times the restore returned the file to the same hash and to green.

---

## 5. Full suite — no regressions

```
PS E:\projects\VibeFPS> powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1
smoke          PASS
movement       PASS
input_actions  PASS
input_gate     PASS
weapon_data    PASS
integrity      PASS
weapon         PASS
projectile     PASS
enemies        PASS
waves          [SKIP]  (tests\waves.gd not present)
save           [SKIP]  (tests\save.gd not present)
progression    [SKIP]  (tests\progression.gd not present)

RESULT: 9 passed, 0 failed, 3 skipped
EXITCODE=0
```

Phase 1's 8 checks still pass; `enemies` flipped from `[SKIP]` to `PASS` purely by the existence of `tests/enemies.gd`. `tools/run_checks.ps1` was **not** touched.

---

## 6. Files changed

Authored (the task's diff):

- `scripts/enemy_data.gd` — new, 26 lines, UTF-8 no BOM, LF
- `data/enemies/contact.tres` — new, 13 lines, UTF-8 no BOM, LF
- `tests/enemies.gd` — new, 108 lines, UTF-8 no BOM, LF

Engine-generated, unavoidable byproducts of the import pass that `run_checks.ps1` itself runs (it re-imports whenever a new `.gd`/`.tres` is newer than the class cache):

- `scripts/enemy_data.gd.uid` — `uid://dgkw7if5i2gs0`
- `tests/enemies.gd.uid` — `uid://vncihflucue0`

These match the repo convention (all 18 existing `.gd` files have a tracked `.uid`; the owner should commit them). No `.uid` was generated for `contact.tres`, consistent with `data/weapons/pistol.tres`, which also has none.

`git status --porcelain` shows no modified tracked file (`git diff HEAD --stat` is empty). The only other untracked entry is the pre-existing `.opencode/`, which was already there before this task.

---

## 7. Self-review of my own diff

Read all three files end to end after the green run. Findings, all resolved or noted:

1. **Missing trailing newline** — the `write` tool left all three files without a final LF, while every file in the repo ends with one. Fixed by appending a single `0x0A` to each and re-verifying PASS. All three files are LF-only (`crlf=0`), matching `.gitattributes` (`* text=auto eol=lf`) and the pre-existing files.
2. **Language split** — English comments in `tests/enemies.gd`, Russian in `scripts/enemy_data.gd`. This matches the project, where all four existing `tests/*.gd` are English and `scripts/*.gd` are Russian; the brief's Russian comments were copied verbatim into the script as instructed.
3. **Red-phase failure mode** — `tests/enemies.gd` references `EnemyData` statically, so the RED state is a parse error rather than a named assertion failure. That is deliberate: `tests/weapon_data.gd` (the brief's style reference) does the same, and the brief's Step 2 explicitly predicts "ошибка парсинга/загрузки". (`tests/projectile.gd` prefers `load()`-by-path for a different reason — its scripts do not exist at all yet and it still needs to run the rest — which does not apply here.)
4. **Float comparisons are exact `==`**, not tolerance-based, and that is sound: 50.0, 10.0, 6.0 and 1.5 are all exactly representable in binary64, and both the `.tres` and the `%.4f` output agree. The tolerance helper was dropped together with the defective invariant, which was its only user.
5. **`_probe`/`_is_valid_rejects` type safety** — `probe.set(key, value)` is used exactly as in `tests/weapon_data.gd`; every key passed is a real exported property of `EnemyData`, so no silent `set()` failure. Verified green.
6. **No new GDScript warnings** — the mutation dump prints the whole captured stdout+stderr and shows no warning lines from my scripts, and no parser error.
7. **`kind` collision with the script default** — `contact.tres` writes `kind = 0` and the script default is also `EnemyKind.CONTACT`, so assertion 6 cannot distinguish "written in the `.tres`" from "fell back to the default". Same inherent limit as `projectile_color` in `tests/weapon_data.gd`, which documents it as pinning the script default. Accepted, not worked around.
8. **No unrelated edits** — no tracked file changed; `tools/run_checks.ps1`, `PROJECT.md`, and all Phase 1 files untouched.

---

## 8. Concerns

- **`display_name` and `color` are shipped in `contact.tres` but unasserted.** The brief's assertion list omits them, so I did not invent assertions for them; consequence: a future balance/readout edit to `"Contact"` or the colour in `contact.tres` turns nothing red. Cheap to add if the controller wants the data fully pinned — `weapon_data.gd` does assert `display_name` on `pistol.tres`. Left as-is to keep the test exactly to brief.
- **Four assertions beyond the brief's list.** The brief asked only for "`is_valid()` истинна"; I added one rejection probe per term of `is_valid()`'s condition. Rationale: the style reference `tests/weapon_data.gd` states this explicitly in its header ("The negative halves are asserted too… Without those, a method hardcoded to return 0.5 and true would sail through"), and `is_valid()` is part of *this* task's authored implementation, so testing it belongs here. Without them, `is_valid()` returning a hardcoded `true` would pass this check. Flagging it so the reviewer can see exactly what came from the brief and what I added — 7 assertions are the brief's, 4 are mine.
- **Two extra files in the working tree** (`scripts/enemy_data.gd.uid`, `tests/enemies.gd.uid`) beyond the three named in the task, both written by Godot's import pass invoked from `run_checks.ps1`. Not authorable-around and consistent with repo convention; noted in §6 for the owner to commit.
- **No git mutations performed**, as required.