> **Назначение:** Отчёт по задаче фазы.

# Task 7 report — Directional light shadows

## Change made

Single line added to the existing `DirectionalLight3D` node in `main.tscn`. Nothing else touched.

`git diff -- main.tscn`:

```diff
diff --git a/main.tscn b/main.tscn
index 38033a6..54bba66 100644
--- a/main.tscn
+++ b/main.tscn
@@ -46,3 +46,4 @@ shape = SubResource("BoxShape3D_floor")

 [node name="DirectionalLight3D" type="DirectionalLight3D" parent="." unique_id=670527287]
 transform = Transform3D(0.707107, -0.408248, 0.57735, 0, 0.707107, 0.707107, -0.707107, -0.5, 0.5, 0, 10, 0)
+shadow_enabled = true
```

Exactly one added line, zero removed, zero modified. `light_energy` is not present in the node and was not added; the `transform` is byte-identical.

## Automated suite

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
```

Exit code 0. No `[WARN]` lines. `$Tests` was not modified.

## Capture run

PowerShell 5.1 `2>&1` did not surface Godot's output as expected, so `Start-Process` with `-RedirectStandardOutput`/`-RedirectStandardError` was used. Engine exit code 0, stderr empty.

```
Godot Engine v4.7.2.stable.official.ed1daf0bf
D3D12 12_0 - Forward+ - Using Device #0: NVIDIA - NVIDIA GeForce RTX 5070

=== visual capture ===
mouse_mode=2
SHOT 00 spawn            2560x1438 avg=(0.433,0.541,0.589) -> C:/Users/serhio/AppData/Roaming/Godot/app_userdata/VibeFPS/captures/00_spawn.png
SHOT 01 look_up          2560x1438 avg=(0.186,0.428,0.519) -> .../01_look_up.png
SHOT 02 look_down        2560x1438 avg=(0.628,0.653,0.669) -> .../02_look_down.png
SHOT 03 walk_forward     2560x1438 avg=(0.377,0.477,0.520) -> .../03_walk_forward.png
SHOT 04 sprint           2560x1438 avg=(0.218,0.293,0.322) -> .../04_sprint.png
SHOT 05 strafe_right     2560x1438 avg=(0.218,0.293,0.322) -> .../05_strafe_right.png
SHOT 06 jump_rise        2560x1438 avg=(0.218,0.293,0.322) -> .../06_jump_rise.png
SHOT 07 jump_fall        2560x1438 avg=(0.218,0.293,0.322) -> .../07_jump_fall.png
SHOT 08 walk_off_edge    2560x1438 avg=(0.265,0.345,0.377) -> .../08_walk_off_edge.png
SHOT 09 after_fall       2560x1438 avg=(0.218,0.293,0.322) -> .../09_after_fall.png
final pos=(12.79259, -23.20025, 0.0)
=== done ===
```

Requested paths:

- jump_rise: `C:\Users\serhio\AppData\Roaming\Godot\app_userdata\VibeFPS\captures\06_jump_rise.png`
- spawn: `C:\Users\serhio\AppData\Roaming\Godot\app_userdata\VibeFPS\captures\00_spawn.png`

## Visual inspection — NOT confirmed

I opened and looked at `06_jump_rise.png`. **I cannot confirm a shadow under the player. There is no player visible in that frame at all, and the floor is not in view.** Honest description of what is in the image: a blue-to-pale sky gradient occupying roughly the top 58% of the frame, then the sky's dark brown `ground_horizon`/`ground_bottom` band, and nothing else. There is no floor surface, no player, no shadow, and no gap.

I cross-checked the neighbouring frames to make sure this was not a bad read of a compressed image:

- `00_spawn.png` — the floor is visible as a large uniform light-gray plane with a clean straight far edge. No shadow anywhere on it.
- `02_look_down.png` — the camera is pitched down at the floor; the plane fills the frame and is completely uniform. No shadow.
- `03_walk_forward.png` — floor visible, uniformly lit. No shadow.

So the requirement "a shadow under the player, separated from the player by a gap" is not satisfied by the captures, and the reason is structural, not a failure of the one-line change:

1. `player.tscn` contains only a `CollisionShape3D` (capsule, for physics) and a `Camera3D`. There is **no `MeshInstance3D`**, so the player has no visible geometry and casts no shadow. A collision shape is never rendered.
2. The camera is first-person, mounted inside the player at y=1.7, so the player's body would not be in frame even if it had a mesh.
3. In `jump_rise` the camera pitch is level (the harness last set `_camera.rotation.x` back toward level before walking), so at 18 physics frames into a ~5 m/s jump the floor surface is not in the frustum at all. Frames 04 through 07 all share `avg=(0.218,0.293,0.322)`, identical to the millisecond, which is consistent with "sky plus sky-ground band only" across sprint/strafe/jump — the player had walked off the platform before the jump and was falling over the void.

The only shadow-casting geometry in the scene is the floor box itself, which cannot cast a visible shadow onto itself here (its top face is uniformly facing the light).

The change itself is correct and does what the brief asks at the engine-property level: `shadow_enabled = true` is set on the light, the scene loads cleanly with no errors or warnings, and physics behaviour is unchanged (suite is green, final capture position identical to expectations). What I cannot do is produce the requested *visual proof*, because there is nothing in the scene for that shadow to fall from. Producing it would require adding a visible mesh to the player, which is outside this task's Files list.

## Decisions the brief left open

- Whether to verify the visual criterion at all given it is unobtainable. I chose to run the capture, inspect the images, and report the negative result rather than editing `player.tscn`, `tests/capture.gd`, or the light's other properties to manufacture a visible shadow. The brief explicitly forbade touching those files.
- I did not add `light_energy` or any other property to the light node.
- I did not add to or reorder `$Tests` in `tools/run_checks.ps1`.

## Working tree state

`git status --short`:

```
 M main.tscn
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
```

`main.tscn` is modified and unstaged. The other modifications and untracked files were already present before I started — I did not touch them. `git diff --cached --stat` is empty: **nothing is staged.**

**I did not run `git add` and did not run `git commit`. The change is left in the working tree, unstaged, for the project owner to commit. No `.uid` files were created or deleted.**