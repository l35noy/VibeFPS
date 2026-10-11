# Re-review package — Phase 2 Task 5, fix round 1

FIX_BASE: working tree as reviewed conceptually pre-fix (task-5 state). Fix files: enemy_contact.tscn (target_desired_distance 1.0→0.5), range.tscn (override node deleted), tests/enemies.gd (pin 1.0→0.5).

## git status --short
 M player.gd
 M player.tscn
 M range.tscn
 M scripts/hurtbox.gd
?? .opencode/
?? data/enemies/
?? enemy_contact.tscn
?? scripts/enemy_contact.gd
?? scripts/enemy_contact.gd.uid
?? scripts/enemy_data.gd
?? scripts/enemy_data.gd.uid
?? scripts/range_scene.gd
?? scripts/range_scene.gd.uid
?? tests/enemies.gd
?? tests/enemies.gd.uid

---

## enemy_contact.tscn (full)
[gd_scene load_steps=7 format=3]

[ext_resource type="Script" path="res://scripts/enemy_contact.gd" id="1_script"]
[ext_resource type="Resource" path="res://data/enemies/contact.tres" id="2_data"]
[ext_resource type="Script" path="res://scripts/hurtbox.gd" id="3_hurtbox"]

[sub_resource type="CapsuleShape3D" id="CapsuleShape3D_body"]
radius = 0.4
height = 1.8

[sub_resource type="CapsuleShape3D" id="CapsuleShape3D_hurtbox"]
radius = 0.4
height = 1.8

[sub_resource type="CapsuleMesh" id="CapsuleMesh_enemy"]
radius = 0.4
height = 1.8

[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_enemy"]
albedo_color = Color(0.8, 0.25, 0.25, 1)

[node name="ContactEnemy" type="CharacterBody3D"]
script = ExtResource("1_script")
data = ExtResource("2_data")

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.9, 0)
shape = SubResource("CapsuleShape3D_body")

[node name="Hurtbox" type="Area3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.9, 0)
script = ExtResource("3_hurtbox")
detects_contact = true

[node name="CollisionShape3D" type="CollisionShape3D" parent="Hurtbox"]
shape = SubResource("CapsuleShape3D_hurtbox")

[node name="Mesh" type="MeshInstance3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.9, 0)
mesh = SubResource("CapsuleMesh_enemy")
material_override = SubResource("StandardMaterial3D_enemy")

; Два числа, и путать их опасно: это РАЗНЫЕ пороги с разными смыслами.
;   path_desired_distance = 1.0 — «следующая точка пути засчитана пройденной,
;     можно брать следующую». Остаётся дефолтом движка. От него зависит
;     РАЗМОРОЗКА врага, и размораживает его не он, а смещение навмеша:
;     запечённая поверхность лежит на 2 * cell_height выше геометрии, пока это
;     смещение меньше порога, индекс точки пути не сдвигается никогда и враг
;     стоит при вполне достижимом навмеше. Порог стоит оставить ЗАПАСОМ больше
;     любого cell_height, который встретится в сценах (у тира 0.25 → 0.5).
;   target_desired_distance = 0.5 — «до цели достаточно близко, можно
;     останавливаться». Вот это число задаёт РАДИУС, на котором враг встаёт у
;     игрока, и поэтому оно не может быть дефолтом 1.0: контактный урон ловится
;     пересечением двух хитбоксов (спека §6.3 — тела проходят друг сквозь
;     друга, касание ловится зонами), а у капсул врага и игрока радиус 0.4 м,
;     то есть касание начинается строго ближе 0.8 м. При стоп-дистанции 1.0 м
;     враг доходил до игрока, останавливался в метре и молчал: навмеш есть, путь
;     пройден, здоровье игрока полно, и это неотличимо от «враг стоит и думает».
;     Замер в тире: 720 тиков (6 с) вплотную — ноль тиков контакта, HP игрока
;     100.0 из 100.0. 0.5 м даёт запас 0.3 м до границы касания.
;     Неравенство «стоп-дистанция < сумма радиусов хитбоксов» проверяется в
;     tests/enemies.gd: в «Проводке сцены» (враг в тире) и здесь, пином на 0.5.
[node name="NavigationAgent3D" type="NavigationAgent3D" parent="."]
path_desired_distance = 1.0
target_desired_distance = 0.5

---

## range.tscn (full)
[gd_scene load_steps=24 format=3 uid="uid://jyplrr3l"]

[ext_resource type="PackedScene" path="res://player.tscn" id="1_player"]
[ext_resource type="Script" path="res://scripts/range_target.gd" id="2_target_script"]
[ext_resource type="Script" path="res://scripts/hurtbox.gd" id="3_hurtbox_script"]
[ext_resource type="Script" path="res://scripts/range_scene.gd" id="4_range_script"]
[ext_resource type="PackedScene" path="res://enemy_contact.tscn" id="5_enemy_scene"]

[sub_resource type="ProceduralSkyMaterial" id="ProceduralSkyMaterial_range"]
sky_top_color = Color(0.083611436, 0.55883366, 0.7163719, 1)
sky_horizon_color = Color(0.620054, 0.7175465, 0.7465719, 1)
ground_bottom_color = Color(0.24614578, 0.16089359, 0.11945697, 1)
ground_horizon_color = Color(0.620054, 0.7175465, 0.7465719, 1)

[sub_resource type="Sky" id="Sky_range"]
sky_material = SubResource("ProceduralSkyMaterial_range")

[sub_resource type="Environment" id="Environment_range"]
background_mode = 2
background_energy_multiplier = 0.5
sky = SubResource("Sky_range")

[sub_resource type="BoxMesh" id="BoxMesh_floor"]
size = Vector3(26, 1, 46)

[sub_resource type="BoxShape3D" id="BoxShape3D_floor"]
size = Vector3(26, 1, 46)

[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_floor"]
albedo_color = Color(0.8217887, 0.82178867, 0.82178867, 1)
metallic_specular = 0.0

[sub_resource type="BoxMesh" id="BoxMesh_wall_back"]
size = Vector3(26, 4, 1)

[sub_resource type="BoxShape3D" id="BoxShape3D_wall_back"]
size = Vector3(26, 4, 1)

[sub_resource type="BoxMesh" id="BoxMesh_wall_side"]
size = Vector3(1, 4, 46)

[sub_resource type="BoxShape3D" id="BoxShape3D_wall_side"]
size = Vector3(1, 4, 46)

[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_wall"]
albedo_color = Color(0.588, 0.643, 0.686, 1)
metallic_specular = 0.0

[sub_resource type="BoxMesh" id="BoxMesh_target"]
size = Vector3(1, 2, 0.6)

[sub_resource type="BoxShape3D" id="BoxShape3D_target"]
size = Vector3(1, 2, 0.6)

[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_target_near"]
albedo_color = Color(0.878, 0.376, 0.216, 1)
metallic_specular = 0.0

[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_target_mid"]
albedo_color = Color(0.298, 0.643, 0.325, 1)
metallic_specular = 0.0

[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_target_far"]
albedo_color = Color(0.239, 0.451, 0.831, 1)
metallic_specular = 0.0

; Навмеш тира. Значения, отличные от дефолтов, записаны здесь явно и каждое с
; причиной — потому что все три меняют то, КУДА враг придёт, а не как он там
; будет выглядеть:
;   cell_height = 0.25 — запечённая поверхность сетки ложится на 2 * cell_height
;     выше геометрии (пол здесь с верхней гранью на y = 0), а первая точка пути —
;     это позиция агента, привязанная к сетке, то есть ровно на этом смещении
;     выше пяток. Пока смещение не меньше path_desired_distance агента (1.0),
;     индекс точки пути не сдвигается никогда и враг стоит на месте при вполне
;     достижимом навмеше. Отсюда 0.25 (смещение 0.5) — вдвое меньше порога.
;     Мельче 0.25 смысла нет: Godot предупреждает, что сетка с cell_height
;     меньше, чем у карты навигации проекта (там 0.25), даёт ошибки растеризации
;     на краях полигонов. Правило проверяется в tests/enemies.gd,
;     «Проводка сцены» — там видны и смещение, и порог.
;   geometry_parsed_geometry_type = 1 (только коллайдеры). Дефолт — 2, «и то и
;     другое», и он читает ещё и меши: меши лежат на GPU, и их чтение в bake
;     перекладывает геометрию обратно на CPU, о чём Godot прямо предупреждает
;     («blocks the rendering»). Коллайдеры у тира есть у каждого препятствия,
;     поэтому меши в bake не нужны.
;   geometry_collision_mask = 5 — слои 1 (мир) и 3 (мишени). Дефолт — все слои
;     (0xFFFFFFFF), и в навмеш попадало бы всё, что окажется под регионом,
;     включая динамические тела. Мишени обязаны быть в сетке: без них враг вёл
;     бы сквозь мишень, упирался бы в неё телом и соскальзывал.
;
; ИМЕНА СВОЙСТВ ЗДЕСЬ ЧЕРЕЗ ПОДЧЕРКИВАНИЕ, а не через слэш: NavigationMesh
; регистрирует их как `geometry_parsed_geometry_type`, и строка
; `geometry/parsed_geometry_type = 1` молча игнорируется загрузчиком — навмеш
; остаётся с дефолтами, сцена выглядит настроенной, а bake делает не то.
[sub_resource type="NavigationMesh" id="NavigationMesh_range"]
cell_height = 0.25
geometry_collision_mask = 5
geometry_parsed_geometry_type = 1

[node name="Range" type="Node3D"]
script = ExtResource("4_range_script")

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Environment_range")

[node name="DirectionalLight3D" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.707107, -0.408248, 0.57735, 0, 0.707107, 0.707107, -0.707107, -0.5, 0.5, 0, 10, 0)
shadow_enabled = true

[node name="NavigationRegion3D" type="NavigationRegion3D" parent="."]
navigation_mesh = SubResource("NavigationMesh_range")

[node name="Floor" type="StaticBody3D" parent="NavigationRegion3D"]
position = Vector3(0, -0.5, -1)

[node name="Mesh" type="MeshInstance3D" parent="NavigationRegion3D/Floor"]
mesh = SubResource("BoxMesh_floor")
surface_material_override/0 = SubResource("StandardMaterial3D_floor")

[node name="CollisionShape3D" type="CollisionShape3D" parent="NavigationRegion3D/Floor"]
shape = SubResource("BoxShape3D_floor")

[node name="BackWall" type="StaticBody3D" parent="NavigationRegion3D"]
position = Vector3(0, 2, -23.5)

[node name="Mesh" type="MeshInstance3D" parent="NavigationRegion3D/BackWall"]
mesh = SubResource("BoxMesh_wall_back")
surface_material_override/0 = SubResource("StandardMaterial3D_wall")

[node name="CollisionShape3D" type="CollisionShape3D" parent="NavigationRegion3D/BackWall"]
shape = SubResource("BoxShape3D_wall_back")

[node name="LeftWall" type="StaticBody3D" parent="NavigationRegion3D"]
position = Vector3(-12.5, 2, -1)

[node name="Mesh" type="MeshInstance3D" parent="NavigationRegion3D/LeftWall"]
mesh = SubResource("BoxMesh_wall_side")
surface_material_override/0 = SubResource("StandardMaterial3D_wall")

[node name="CollisionShape3D" type="CollisionShape3D" parent="NavigationRegion3D/LeftWall"]
shape = SubResource("BoxShape3D_wall_side")

[node name="RightWall" type="StaticBody3D" parent="NavigationRegion3D"]
position = Vector3(12.5, 2, -1)

[node name="Mesh" type="MeshInstance3D" parent="NavigationRegion3D/RightWall"]
mesh = SubResource("BoxMesh_wall_side")
surface_material_override/0 = SubResource("StandardMaterial3D_wall")

[node name="CollisionShape3D" type="CollisionShape3D" parent="NavigationRegion3D/RightWall"]
shape = SubResource("BoxShape3D_wall_side")

[node name="TargetNear" type="StaticBody3D" parent="NavigationRegion3D"]
position = Vector3(0, 0, -4)
collision_layer = 4
collision_mask = 1
script = ExtResource("2_target_script")

[node name="Mesh" type="MeshInstance3D" parent="NavigationRegion3D/TargetNear"]
position = Vector3(0, 1, 0)
mesh = SubResource("BoxMesh_target")
surface_material_override/0 = SubResource("StandardMaterial3D_target_near")

[node name="CollisionShape3D" type="CollisionShape3D" parent="NavigationRegion3D/TargetNear"]
position = Vector3(0, 1, 0)
shape = SubResource("BoxShape3D_target")

[node name="Hurtbox" type="Area3D" parent="NavigationRegion3D/TargetNear"]
position = Vector3(0, 1, 0)
script = ExtResource("3_hurtbox_script")

[node name="CollisionShape3D" type="CollisionShape3D" parent="NavigationRegion3D/TargetNear/Hurtbox"]
shape = SubResource("BoxShape3D_target")

[node name="TargetMid" type="StaticBody3D" parent="NavigationRegion3D"]
position = Vector3(3, 0, -7.4)
collision_layer = 4
collision_mask = 1
script = ExtResource("2_target_script")

[node name="Mesh" type="MeshInstance3D" parent="NavigationRegion3D/TargetMid"]
position = Vector3(0, 1, 0)
mesh = SubResource("BoxMesh_target")
surface_material_override/0 = SubResource("StandardMaterial3D_target_mid")

[node name="CollisionShape3D" type="CollisionShape3D" parent="NavigationRegion3D/TargetMid"]
position = Vector3(0, 1, 0)
shape = SubResource("BoxShape3D_target")

[node name="Hurtbox" type="Area3D" parent="NavigationRegion3D/TargetMid"]
position = Vector3(0, 1, 0)
script = ExtResource("3_hurtbox_script")

[node name="CollisionShape3D" type="CollisionShape3D" parent="NavigationRegion3D/TargetMid/Hurtbox"]
shape = SubResource("BoxShape3D_target")

[node name="TargetFar" type="StaticBody3D" parent="NavigationRegion3D"]
position = Vector3(-5, 0, -13.1)
collision_layer = 4
collision_mask = 1
script = ExtResource("2_target_script")

[node name="Mesh" type="MeshInstance3D" parent="NavigationRegion3D/TargetFar"]
position = Vector3(0, 1, 0)
mesh = SubResource("BoxMesh_target")
surface_material_override/0 = SubResource("StandardMaterial3D_target_far")

[node name="CollisionShape3D" type="CollisionShape3D" parent="NavigationRegion3D/TargetFar"]
position = Vector3(0, 1, 0)
shape = SubResource("BoxShape3D_target")

[node name="Hurtbox" type="Area3D" parent="NavigationRegion3D/TargetFar"]
position = Vector3(0, 1, 0)
script = ExtResource("3_hurtbox_script")

[node name="CollisionShape3D" type="CollisionShape3D" parent="NavigationRegion3D/TargetFar/Hurtbox"]
shape = SubResource("BoxShape3D_target")

[node name="Enemy" parent="." instance=ExtResource("5_enemy_scene")]
position = Vector3(9, 0, -19.5)

; Переопределений агента здесь намеренно нет. Стоп-дистанция, на которой враг
; встаёт у игрока (target_desired_distance = 0.5), задана в самой сцене врага,
; enemy_contact.tscn: это свойство ВРАГА, а не свойство места, где его поставили,
; и любая сцена с контактным врагом обязана получать рабочий контакт из коробки.
; Тир только проверяет это (tests/enemies.gd, «Проводка сцены»), не чинит.

[node name="Player" parent="." instance=ExtResource("1_player")]

---

## tests/enemies.gd — pins around target_desired_distance (all lines matching the pin context)
121: ## target_desired_distance из сцены врага (enemy_contact.tscn). Живёт в харнессе
127: ## target_desired_distance — «до цели достаточно близко, можно останавливаться».
131: const _NAV_TARGET_DISTANCE := 0.5
1031: 	# 1.0) пересмотрено: стоп-дистанция 1.0 м больше радиуса контакта двух
1037: 			and absf(float(scene_agent.get("target_desired_distance")) - 0.5) < _HEALTH_EPS,
1038: 		"target_desired_distance агента равен 0.5 м: стоп-дистанция меньше радиуса контакта хитбоксов",
1040: 			float(scene_agent.get("target_desired_distance")) if scene_agent != null else -1.0))
1055: 	var stop_limit := _NAV_TARGET_DISTANCE + 0.1
1057: 		stop_limit = float(scene_agent.get("target_desired_distance")) + 0.1
1137: 		"враг остановился у цели: дистанция ≤ target_desired_distance + 0.1",
1474: 	# target_desired_distance от цели. Если стоп-дистанция больше радиуса
1481: 	var stop_at := 0.0 if agent == null else float(agent.get("target_desired_distance"))
1484: 		"стоп-дистанция врага меньше радиуса контакта двух хитбоксов — контактный урон возможен",
1528: 		# стоп-дистанция велика.

---

## Fix report section (tail of task-5-report.md)
# Fix round 1 — контактный урон починен в корне, а не в тире

**Статус:** DONE
**Дата:** 2026-10-09
**Причина:** собственный finding §8.1 — правка была сделана как переопределение экземпляра в
`range.tscn`, и любая будущая сцена с контактным врагом наследовала тот же тупик. Правление
контроллера: чинить в корне.

## F1. Что изменилось

| Файл | Изменение |
|---|---|
| `enemy_contact.tscn` | `NavigationAgent3D/target_desired_distance`: `1.0` → **`0.5`**. `path_desired_distance` остался `1.0`. Русский комментарий «почему» рядом с узлом |
| `range.tscn` | Удалён узел-переопределение `[node name="NavigationAgent3D" parent="Enemy" index="3"]` и его комментарий. Вместо них — комментарий: переопределений здесь намеренно нет, порог задаёт сцена врага |
| `tests/enemies.gd` | Пин `target_desired_distance == 1.0` → `== 0.5` (с пояснением, почему пересмотрено). Фолбэк-константа `_NAV_TARGET_DISTANCE`: `1.0` → `0.5` с переписанным комментарием. Пин `path_desired_distance == 1.0` **не тронут** |

Итог: `range.tscn` больше не содержит ни одного свойства агента. Значение живёт в одном месте —
сцене врага — и любая сцена получает рабочий контакт из коробки.

### Комментарий в `enemy_contact.tscn` (ключевое)

```
; Два числа, и путать их опасно: это РАЗНЫЕ пороги с разными смыслами.
;   path_desired_distance = 1.0 — «следующая точка пути засчитана пройденной…». Остаётся
;     дефолтом движка. От него зависит РАЗМОРОЗКА врага, и размораживает его не он,
;     а смещение навмеша: запечённая поверхность лежит на 2 * cell_height выше
;     геометрии… Порог стоит оставить ЗАПАСОМ больше любого cell_height, который
;     встретится в сценах (у тира 0.25 → 0.5).
;   target_desired_distance = 0.5 — «до цели достаточно близко, можно останавливаться».
;     Вот это число задаёт РАДИУС, на котором враг встаёт у игрока… у капсул врага и
;     игрока радиус 0.4 м, то есть касание начинается строго ближе 0.8 м. При
;     стоп-дистанции 1.0 м враг доходил до игрока, останавливался в метре и молчал…
;     Замер в тире: 720 тиков (6 с) вплотную — ноль тиков контакта, HP игрока 100.0
;     из 100.0. 0.5 м даёт запас 0.3 м до границы касания.
```

Комментарий намеренно разделяет два порога, потому что их постоянно можно спутать: в прошлом
решении именно путаница «дефолт движка = правильно» и породила баг.

## F2. Перерешение Task 4 — что именно изменилось

Принятое на ревью Task 4 решение было: `target_desired_distance` и `path_desired_distance` оставить
равными дефолту движка (1.0 и 1.0), потому что 0.5 — пережиток Godot 3 из плана.

**Пересмотрено ровно одно число из двух:**

* `target_desired_distance` 1.0 → **0.5**. Обоснование новое и измеренное: 1.0 м больше радиуса
  контакта двух хитбоксов (0.8 м), то есть это число физически исключает контактный урон.
* `path_desired_distance` **остаётся 1.0** — решение Task 4 в силе полностью. Заморозка врага задаётся
  не им, а смещением навмеша `2 * cell_height`; у тира это 0.5 при пороге 1.0 (запас вдвое),
  и это проверяется отдельным утверждением.

Пин в `tests/enemies.gd` (раздел «Навигация») переписан, а не просто молча переставлен на новое
значение: в нём теперь стоит причина («стоп-дистанция меньше радиуса контакта хитбоксов») и ожидаемое
значение в сообщении об ошибке, чтобы следующий читатель увидел, что 0.5 — это вычисленная величина,
а не вкус.

Фолбэк `_NAV_TARGET_DISTANCE` (используется, только если узла агента в сцене нет) обновлён на 0.5
вместе с комментарием: оставить там 1.0 было бы «правдой для мира, которого не существует».

## F3. Покрывающие проверки (почему баг не вернётся)

Три независимых заслона, все доказаны красным в этом раунде:

1. **Пин на сцене врага** — `target_desired_distance агента равен 0.5 м` (раздел «Навигация», грузит
   `enemy_contact.tscn` напрямую).
2. **Арифметика на собранной сцене** — `стоп-дистанция врага меньше радиуса контакта двух хитбоксов`
   (раздел «Проводка сцены», читает значение у экземпляра **внутри `range.tscn`**).
3. **Поведение на собранной сцене** — `враг из тира дошёл до игрока и нанёс контактный урон` (наблюдение,
   а не вычисление).

Заслоны 2 и 3 намеренно стоят на уровне **собранной** сцены, а не только сцены врага: именно они
ловят переопределение, спрятанное в экземпляре, — см. мутацию F5.2.

## F4. Мутации (обе — на финальном состоянии файлов)

### F5.1 Откат корневой правки в `enemy_contact.tscn`

```diff
  path_desired_distance = 1.0
- target_desired_distance = 0.5
+ target_desired_distance = 1.0
```

```
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 enemies
```

```
=== RESULT: 159 checks, 3 failed ===
      FAILURE: target_desired_distance агента равен 0.5 м: стоп-дистанция меньше радиуса контакта хитбоксов (got 1.0000, expected 0.5000)
      FAILURE: стоп-дистанция врага меньше радиуса контакта двух хитбоксов — контактный урон возможен (got 1.000 м при радиусе контакта 0.800 м = 0.400 + 0.400)
      FAILURE: враг из тира дошёл до игрока и нанёс контактный урон — здоровье игрока упало (за 720 тиков (6.0 с) ни одного тика; HP игрока 100.0 из 100.0)
RESULT: 0 passed, 1 failed, 0 skipped
```

Покраснели ровно три утверждения — новый пин плюс оба заслона «Проводки сцены», как и требовалось.
Пин `path_desired_distance == 1.0` остался зелёным: мутация его не трогала, и это подтверждает, что
два порога проверяются независимо.

| SHA-256 `enemy_contact.tscn` | |
|---|---|
| до мутации | `02469C5D704A5384FBF79BC3D6F3C96D2FD5E16AB920903EF284348AA207D142` |
| после восстановления | `02469C5D704A5384FBF79BC3D6F3C96D2FD5E16AB920903EF284348AA207D142` |

### F5.2 Возвращённое переопределение в `range.tscn` не может спрятать поломку

`enemy_contact.tscn` в этот момент **правильный** (0.5). В `range.tscn` добавлено обратно
переопределение экземпляра со значением 1.0 — то есть ровно тот обход, который был до этого раунда:

```
=== RESULT: 159 checks, 2 failed ===
      FAILURE: стоп-дистанция врага меньше радиуса контакта двух хитбоксов — контактный урон возможен (got 1.000 м при радиусе контакта 0.800 м = 0.400 + 0.400)
      FAILURE: враг из тира дошёл до игрока и нанёс контактный урон — здоровье игрока упало (за 720 тиков (6.0 с) ни одного тика; HP игрока 100.0 из 100.0)
RESULT: 0 passed, 1 failed, 0 skipped
```

Это и есть требуемое доказательство: переопределение в сцене-месте **не может** ни спрятать, ни тихо
сломать корневую правку, потому что «Проводка сцены» читает значение у экземпляра в `range.tscn`.
Пин `target_desired_distance == 0.5` здесь остался зелёным — он грузит `enemy_contact.tscn` напрямую
и по назначению не видит переопределение экземпляра. Разделение намеренное: пин сторожит сцену врага,
заслоны «Проводки сцены» сторожит собранный мир.

| SHA-256 `range.tscn` | |
|---|---|
| до мутации | `72952AEDB7455B1F9010C93C42280B77D65B3A1BD74380B4EC10E9EF19BCA21C` |
| после восстановления | `72952AEDB7455B1F9010C93C42280B77D65B3A1BD74380B4EC10E9EF19BCA21C` |

Мутации из первого раунда (слой мишени в `range.tscn`, удаление bake из `scripts/range_scene.gd`)
не воспроизводились: `range.tscn` изменился только удалением переопределения,
`scripts/range_scene.gd` не тронут, `tests/enemies.gd` — только пин и одна константа. Старые
доказательства остаются действительными для неизменённых частей.

## F5. Прогоны

Фокус:

```
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 enemies
enemies        PASS
RESULT: 1 passed, 0 failed, 0 skipped
```

Число проверок **не изменилось: 159** (дельта 0). Пины переписывались, а не добавлялись:
`target_desired_distance` был один и стал один; `_NAV_TARGET_DISTANCE` — константа, не проверка.
Ни одно утверждение не добавлено и не удалено.

Полный набор:

```
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
```

## F6. Повторная ручная проверка на исправленном состоянии

Путь к движку прочитан из `tools\run_checks.ps1` регуляркой и не дублировался; вспомогательный
скрипт лежит вне репозитория (`%TEMP%\opencode\vibefps_manual.ps1`).

```powershell
$GodotBin = ([regex]::Match((Get-Content .\tools\run_checks.ps1 -Raw), '\$GodotBin\s*=\s*"([^"]+)"')).Groups[1].Value
Start-Process -FilePath $GodotBin -ArgumentList '--path','.' -WorkingDirectory E:\projects\VibeFPS -PassThru
```

45 с работы игры, игрок неподвижен (ввод в этой среде не отдаётся):

```
===== STDOUT =====
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org
D3D12 12_0 - Forward+ - Using Device #0: NVIDIA - NVIDIA GeForce RTX 5070

[player] погиб — респавн на точке появления, здоровье восстановлено до 100.0
[player] погиб — респавн на точке появления, здоровье восстановлено до 100.0
[player] погиб — респавн на точке появления, здоровье восстановлено до 100.0
[player] погиб — респавн на точке появления, здоровье восстановлено до 100.0
===== STDERR =====
(пусто)
```

Контактный урон работает после переноса правки в `enemy_contact.tscn` — то есть поведение больше не
зависит от того, где задано число. 4 смерти за 45 с, цикл ≈ 11 с. `stderr` пуст: bake без
предупреждений. Наблюдения, не изменившиеся с первого раунда, остаются в силе, включая ограничения
среды (нет захвата ввода, нет снимка экрана).

## F7. Опасения после fix round 1

1. ~~**[Средняя] Правка не в корне~~ — закрыто.** `target_desired_distance = 0.5` теперь в
   `enemy_contact.tscn`, переопределение из `range.tscn` удалено, три заслона доказаны красным.
2. **[Низкая, без изменений] Перекрытие капсул на 0.3 м** при стоп-дистанции 0.5 м видно глазом.
   Следует из спеки §6.3; альтернатив в моих файлах нет (`player.tscn` не мой).
3. **[Низкая, без изменений] Пистолет стреляет один раз без ввода при старте** — `pistol.gd`, не мой
   файл, не расследовано.
4. **[Инфо] Замечание к формулировке ревью Task 4 сохраняется:** «оставить 1.0, потому что 0.5 —
   пережиток Godot 3». Для `path_desired_distance` это верно и решено в его пользу. Для
   `target_desired_distance` — нет: там 1.0 физически исключает контактный урон, и это измерено.
   Решение принято не «на вкус», а по неравенству, которое теперь стоит в тесте.
5. **[Низкая] `enemy_contact.tscn` теперь несёт комментарий `;`.** Как и в `range.tscn`, он переживёт
   чтение, но будет потерян при пересохранении из редактора. Обоснование продублировано в
   `tests/enemies.gd` рядом с пином, который редактор не сожрёт.

## F8. Контрольные числа fix round 1

| | |
|---|---|
| `enemies` | **159 проверок, 0 failed** (дельта 0 к первому раунду) |
| Полный набор | **9 passed / 0 failed / 3 skipped** |
| SHA-256 `enemy_contact.tscn` | `02469C5D704A5384FBF79BC3D6F3C96D2FD5E16AB920903EF284348AA207D142` |
| SHA-256 `range.tscn` | `72952AEDB7455B1F9010C93C42280B77D65B3A1BD74380B4EC10E9EF19BCA21C` |
| SHA-256 `tests/enemies.gd` | `5764BD3F7D06F450A8AC326B2D3BFD2C62835DF05DA2886ADEC9EE71D74F4205` |
| SHA-256 `scripts/range_scene.gd` (не менялся в этом раунде) | `951B8DDD612C39E79B50EF53C5889B6BACA803244B37D93F8B907A66A5632B0B` |
