# Task 2 Review Package — Автомат + след снаряда из данных
Base: b7ad7c5 (HEAD; project policy: no commits by implementers — working-tree state)
NOTE: diff по scripts/pistol.gd содержит ДО-существующие DOC-CLEANUP правки (только комментарии, уже одобрены) — фокус на строках передачи radius/color.

=== git diff -U10 (modified tracked files of this task) ===
diff --git a/scripts/pistol.gd b/scripts/pistol.gd
index 726bf14..705dad8 100644
--- a/scripts/pistol.gd
+++ b/scripts/pistol.gd
@@ -12,21 +12,21 @@ extends Node3D
 ## 1. ╨Я╨╛╤А╤П╨┤╨╛╨║ ╨▓╨╜╤Г╤В╤А╨╕ `try_fire()`: ╤Б╨╜╨░╤З╨░╨╗╨░ ╨┐╤А╨╛╨▓╨╡╤А╨║╨╕, ╨┐╨╛╤В╨╛╨╝ ╨╕╨╜╤Б╤В╨░╨╜╤Ж╨╕╤А╨╛╨▓╨░╨╜╨╕╨╡
 ##    ╤Б╨╜╨░╤А╤П╨┤╨░, ╨╕ ╤В╨╛╨╗╤М╨║╨╛ ╨┐╨╛╤В╨╛╨╝ ╤Г╨╝╨╡╨╜╤М╤И╨╡╨╜╨╕╨╡ ╨╝╨░╨│╨░╨╖╨╕╨╜╨░. ╨Ю╨▒╤А╨░╤В╨╜╤Л╨╣ ╨┐╨╛╤А╤П╨┤╨╛╨║ ╤Б╤К╨╡╨┤╨░╨╡╤В
 ##    ╨┐╨░╤В╤А╨╛╨╜ ╨╜╨░ ╨┐╤А╨╛╨▓╨░╨╗╨╕╨▓╤И╨╡╨╝╤Б╤П ╨╕╨╜╤Б╤В╨░╨╜╤Ж╨╕╤А╨╛╨▓╨░╨╜╨╕╨╕ тАФ ╨╕╨│╤А╨╛╨║ ╤В╨╡╤А╤П╨╡╤В ╨┐╤Г╨╗╤О, ╨║╨╛╤В╨╛╤А╤Г╤О
 ##    ╨╜╨╡ ╤Б╤В╤А╨╡╨╗╤П╨╗. ╨Я╤А╨╛╨╝╨░╤Е╨╜╤Г╤В╤М╤Б╤П ╨╝╨╛╨╢╨╜╨╛ ╨╗╨╡╨│╨║╨╛: ╤Б╤Ж╨╡╨╜╨░ ╨╜╨╡ ╨╜╨░╨╖╨╜╨░╤З╨╡╨╜╨░, ╤Б╤Ж╨╡╨╜╨░ ╤Г╨║╨░╨╖╤Л╨▓╨░╨╡╤В
 ##    ╨╜╨╡ ╨╜╨░ ╤В╨╛╤В ╤Г╨╖╨╡╨╗.
 ## 2. ╨Я╨╡╤А╨╡╨╖╨░╤А╤П╨┤╨║╤Г ╨╜╨╡╨╗╤М╨╖╤П ╨┐╨╡╤А╨╡╨╖╨░╨┐╤Г╤Б╤В╨╕╤В╤М. ╨Я╨╡╤А╨╡╨╖╨░╨┐╤Г╤Б╨║ ╤Б╨▒╤А╨░╤Б╤Л╨▓╨░╨╡╤В ╤В╨░╨╣╨╝╨╡╤А, ╨░
 ##    ╨╖╨╜╨░╤З╨╕╤В ╨╕╨│╤А╨╛╨║, ╨╜╨░╨╢╨╕╨╝╨░╤П ╨┐╨╡╤А╨╡╨╖╨░╤А╤П╨┤╨║╤Г ╨╜╨░ ╨┐╤Г╤Б╤В╨╛╨╝ ╨╝╨░╨│╨░╨╖╨╕╨╜╨╡, ╨╛╤В╨║╨╗╨░╨┤╤Л╨▓╨░╨╡╤В ╨╡╤С
 ##    ╨▒╨╡╤Б╨║╨╛╨╜╨╡╤З╨╜╨╛. ╨Я╨╛╤Н╤В╨╛╨╝╤Г `start_reload()` ╨╛╤В╨║╨░╨╖╤Л╨▓╨░╨╡╤В, ╨║╨╛╨│╨┤╨░ ╨┐╨╡╤А╨╡╨╖╨░╤А╤П╨┤╨║╨░ ╤Г╨╢╨╡
 ##    ╨╕╨┤╤С╤В, ╨╕ ╨╜╨╡ ╤В╤А╨╛╨│╨░╨╡╤В ╤В╨░╨╣╨╝╨╡╤А.
 ## 3. ╨в╨╡╨╝╨┐ ╤Б╤В╤А╨╡╨╗╤М╨▒╤Л тАФ ╤Н╤В╨╛ ╤Б╨╡╨║╤Г╨╜╨┤╤Л (`data.seconds_between_shots()`), ╨░ ╨╜╨╡
-##    ╨║╨░╨┤╤А╤Л. 120 ╨▓╤Л╤Б╤В╤А./╨╝╨╕╨╜ ╤Н╤В╨╛ ╨╛╨┤╨╕╨╜ ╨▓╤Л╤Б╤В╤А╨╡╨╗ ╨╖╨░ 0.5 ╤Б ╨┐╤А╨╕ ╨╗╤О╨▒╨╛╨╣ ╤З╨░╤Б╤В╨╛╤В╨╡ ╨║╨░╨┤╤А╨╛╨▓;
+##    ╨║╨░╨┤╤А╤Л. 150 ╨▓╤Л╤Б╤В╤А./╨╝╨╕╨╜ ╤Н╤В╨╛ ╨╛╨┤╨╕╨╜ ╨▓╤Л╤Б╤В╤А╨╡╨╗ ╨╖╨░ 0.4 ╤Б ╨┐╤А╨╕ ╨╗╤О╨▒╨╛╨╣ ╤З╨░╤Б╤В╨╛╤В╨╡ ╨║╨░╨┤╤А╨╛╨▓;
 ##    ╤Б╤З╤С╤В╤З╨╕╨║ ╨║╨░╨┤╤А╨╛╨▓ ╨╜╨░ 240 ╨У╤Ж ╨┐╤А╨╡╨▓╤А╨░╤В╨╕╨╗ ╨▒╤Л ╨┐╨╕╤Б╤В╨╛╨╗╨╡╤В ╨▓ ╨░╨▓╤В╨╛╨╝╨░╤В.
 ## 4. `_process`, ╨░ ╨╜╨╡ ╤Д╨╕╨╖╨╕╤З╨╡╤Б╨║╨╕╨╣ ╤В╨╕╨║: ╤Б╤В╤А╨╡╨╗╤М╨▒╨░ тАФ ╨╕╨│╤А╨╛╨▓╨╛╨╡ ╨┤╨╡╨╣╤Б╤В╨▓╨╕╨╡ ╤Б ╤З╨░╤Б╤В╨╛╤В╨╛╨╣
 ##    ╨║╨░╨┤╤А╨╛╨▓ ╤А╨╡╨╜╨┤╨╡╤А╨░, ╨░ ╨╜╨╡ ╤З╨░╤Б╤В╤М ╤Д╨╕╨╖╨╕╤З╨╡╤Б╨║╨╛╨╣ ╤Б╨╕╨╝╤Г╨╗╤П╤Ж╨╕╨╕. ╨в╨░╨╣╨╝╨╡╤А╤Л ╨┐╤А╨╕ ╤Н╤В╨╛╨╝ ╨▓╤Б╤С
 ##    ╤А╨░╨▓╨╜╨╛ ╨▓ ╤Б╨╡╨║╤Г╨╜╨┤╨░╤Е, ╨┐╨╛╤Н╤В╨╛╨╝╤Г ╨┐╤А╨░╨▓╨╕╨╗╨╛ ╤В╨╡╨╝╨┐╨░ ╨╛╤В ╨▓╤Л╨▒╨╛╤А╨░ ╤Д╤Г╨╜╨║╤Ж╨╕╨╕ ╨╜╨╡ ╨╖╨░╨▓╨╕╤Б╨╕╤В.
 ## 5. ╨У╨╡╨╣╤В ╨▓╨▓╨╛╨┤╨░ ╤В╨╛╤В ╨╢╨╡, ╤З╤В╨╛ ╤Г ╨┤╨▓╨╕╨╢╨╡╨╜╨╕╤П: ╨┤╨╡╨╣╤Б╤В╨▓╨╕╨╡ `fire` ╨╜╨╡ ╨┤╨╛╨╗╨╢╨╜╨╛ ╨╛╨▒╤Е╨╛╨┤╨╕╤В╤М
 ##    ╨╡╨│╨╛, ╨╕╨╜╨░╤З╨╡ ╨┐╨╕╤Б╤В╨╛╨╗╨╡╤В ╤Б╤В╤А╨╡╨╗╤П╨╡╤В ╨┐╤А╨╕ ╨╛╤В╨┐╤Г╤Й╨╡╨╜╨╜╨╛╨╝ ╨║╤Г╤А╤Б╨╛╤А╨╡, ╨┐╨╛╨║╨░ ╨╛╤Б╤В╨░╨╗╤М╨╜╨╛╨╣
 ##    ╨┐╨╡╤А╤Б╨╛╨╜╨░╨╢ ╤Б╤В╨╛╨╕╤В.
 ## 6. ╨Я╤Г╤Б╤В╨╛╨╣ ╨╝╨░╨│╨░╨╖╨╕╨╜ ╨╜╨░╤З╨╕╨╜╨░╨╡╤В ╨┐╨╡╤А╨╡╨╖╨░╤А╤П╨┤╨║╤Г ╤Б╨░╨╝. ╨Ш╨│╤А╨╛╨║ ╨╜╨╡ ╨╛╨▒╤П╨╖╨░╨╜ ╨┐╨╛╨╝╨╜╨╕╤В╤М ╨┐╤А╨╛ R,
 ##    ╨░ ╨║╨╜╨╛╨┐╨║╨░ ╨╛╨│╨╜╤П ╨▓ ╤В╨╛╤В ╨╢╨╡ ╨║╨░╨┤╤А ╨╜╨╡ ╨┤╨╛╨╗╨╢╨╜╨░ ╨╜╨╕ ╨▓╤Л╤Б╤В╤А╨╡╨╗╨╕╤В╤М, ╨╜╨╕ ╤Б╨▒╤А╨╛╤Б╨╕╤В╤М
 ##    ╤В╨░╨╣╨╝╨╡╤А ╨┐╨╡╤А╨╡╨╖╨░╨│╤А╤Г╨╖╨║╨╕.
@@ -280,26 +280,28 @@ func _instantiate_projectile() -> Node3D:
 		return null
 	var instance := projectile_scene.instantiate()
 	var projectile := instance as Node3D
 	if projectile == null or not projectile.has_method("launch"):
 		# ╨б╤Ж╨╡╨╜╨░ ╨╜╨╡ ╤Б╨╜╨░╤А╤П╨┤╨░. ╨а╨░╨╜╨╜╨╕╨╣ ╨▓╤Л╤Е╨╛╨┤: ╤Г╨╖╨╡╨╗ ╨╜╨╡ ╨▓ ╨┤╨╡╤А╨╡╨▓╨╡, ╨╕ queue_free() ╨┤╨╗╤П
 		# ╨╜╨╡╨│╨╛ ╨╜╨╡╨┤╨╛╤Б╤В╤Г╨┐╨╡╨╜.
 		if instance != null:
 			instance.free()
 		return null
 	# ╨е╨░╤А╨░╨║╤В╨╡╤А╨╕╤Б╤В╨╕╨║╨╕ ╨┐╤А╨╕╤Е╨╛╨┤╤П╤В ╨╕╨╖ ╨┤╨░╨╜╨╜╤Л╤Е ╨╛╤А╤Г╨╢╨╕╤П, ╨░ ╨╜╨╡ ╨╕╨╖ ╨╖╨╜╨░╤З╨╡╨╜╨╕╨╣ ╤Б╤Ж╨╡╨╜╤Л: ╨╛╨┤╨╜╨╛
-	# ╨╝╨╡╤Б╤В╨╛, ╨╛╤В╨║╤Г╨┤╨░ ╨▒╨╡╤А╤С╤В╤Б╤П ╤Г╤А╨╛╨╜ ╨╕ ╤Б╨║╨╛╤А╨╛╤Б╤В╤М ╨┐╤Г╨╗╨╕.
+	# ╨╝╨╡╤Б╤В╨╛, ╨╛╤В╨║╤Г╨┤╨░ ╨▒╨╡╤А╤Г╤В╤Б╤П ╤Г╤А╨╛╨╜, ╤Б╨║╨╛╤А╨╛╤Б╤В╤М ╨┐╤Г╨╗╨╕ ╨╕ ╨▓╨╜╨╡╤И╨╜╨╕╨╣ ╨▓╨╕╨┤ ╤Б╨╜╨░╤А╤П╨┤╨░.
 	if projectile is Projectile:
 		var bullet := projectile as Projectile
 		bullet.speed = data.projectile_speed
 		bullet.damage = data.damage
 		bullet.lifetime = data.projectile_lifetime
+		bullet.radius = data.projectile_radius
+		bullet.color = data.projectile_color
 	var muzzle := _muzzle()
 	# ╨в╨╛╤З╨║╨░ ╤Б╤В╨░╤А╤В╨░ ╨╕ ╨╜╨░╨┐╤А╨░╨▓╨╗╨╡╨╜╨╕╨╡ тАФ ╨┤╨▓╨░ ╤А╨░╨╖╨╜╤Л╤Е ╤Г╨╖╨╗╨░ (╤Б╨╝. _spawn_point()).
 	var spawn := _spawn_point()
 	# ╨Я╨╡╤А╨╡╨┤╨╜╤П╤П ╨╛╤Б╤М ╨╕╤Б╤В╨╛╤З╨╜╨╕╨║╨░, ╨░ ╨╜╨╡ ╨╛╤Б╤М ╨╝╨╕╤А╨░: ╨┐╨╕╤Б╤В╨╛╨╗╨╡╤В ╨┐╨╛╨▓╨╛╤А╨░╤З╨╕╨▓╨░╨╡╤В╤Б╤П ╨▓╨╝╨╡╤Б╤В╨╡ ╤Б
 	# ╨╕╨│╤А╨╛╨║╨╛╨╝, ╨╕ ╤Б╨╜╨░╤А╤П╨┤ ╨┤╨╛╨╗╨╢╨╡╨╜ ╤Г╤Е╨╛╨┤╨╕╤В╤М ╤В╤Г╨┤╨░, ╨║╤Г╨┤╨░ ╨╛╨╜ ╨╜╨░╨┐╤А╨░╨▓╨╗╨╡╨╜. ╨з╨╕╤В╨░╨╡╤В╤Б╤П ╨╛╨┤╨╕╨╜
 	# ╤А╨░╨╖ тАФ ╨┐╨╛╤Б╨╗╨╡ ╤Н╤В╨╛╨│╨╛ ╨╜╨░╨┐╤А╨░╨▓╨╗╨╡╨╜╨╕╨╡ ╤Г ╤Б╨╜╨░╤А╤П╨┤╨░ ╤Б╨▓╨╛╤С.
 	var direction := -muzzle.global_transform.basis.z
 	muzzle.add_child(projectile)
 	# ╨Ю╤В╨▓╤П╨╖╨║╨░ ╨╛╤В ╤В╤А╨░╨╜╤Б╤Д╨╛╤А╨╝╨░ ╤А╨╛╨┤╨╕╤В╨╡╨╗╤П тАФ ╨▓╤В╨╛╤А╨░╤П ╤З╨░╤Б╤В╤М ╤Д╨╕╨║╤Б╨░ SHOOT-1 (╨┐╨╡╤А╨▓╨░╤П, ╨▓╤Л╤И╨╡,
 	# ╤Н╤В╨╛ ╤В╨╛╤З╨║╨░ ╤Б╤В╨░╤А╤В╨░). ╨г Node3D ╨╝╨╕╤А╨╛╨▓╨╛╨╣ ╤В╤А╨░╨╜╤Б╤Д╨╛╤А╨╝ = global(╤А╨╛╨┤╨╕╤В╨╡╨╗╤П) * local,
diff --git a/scripts/projectile.gd b/scripts/projectile.gd
index 5b790e2..726b059 100644
--- a/scripts/projectile.gd
+++ b/scripts/projectile.gd
@@ -24,30 +24,38 @@ signal hit_something(target: Node)
 
 ## ╨б╨║╨╛╤А╨╛╤Б╤В╤М ╨▓ ╨╝/╤Б. ╨Ъ╨╛╨╜╨╡╤З╨╜╨░╤П: ╤Б╨╝. ╨┐╤Г╨╜╨║╤В 1 ╨▓╤Л╤И╨╡.
 @export var speed: float = 40.0
 ## ╨б╨║╨╛╨╗╤М╨║╨╛ ╤Г╤А╨╛╨╜╨░ ╨╜╨░╨╜╨╛╤Б╨╕╤В ╨╛╨┤╨╜╨╛ ╨┐╨╛╨┐╨░╨┤╨░╨╜╨╕╨╡. ╨е╨╕╤В╨▒╨╛╨║╤Б ╨┐╤А╨╕╨╝╨╡╨╜╤П╨╡╤В ╤Б╨▓╨╛╨╣
 ## `damage_multiplier` тАФ ╨╝╨╜╨╛╨╢╨╕╤В╨╡╨╗╤М ╨╢╨╕╨▓╤С╤В ╤Г ╤Ж╨╡╨╗╨╕, ╨░ ╨╜╨╡ ╤Г ╤Б╨╜╨░╤А╤П╨┤╨░.
 @export var damage: float = 30.0
 ## ╨з╨╡╤А╨╡╨╖ ╤Б╨║╨╛╨╗╤М╨║╨╛ ╤Б╨╡╨║╤Г╨╜╨┤ ╤Б╨╜╨░╤А╤П╨┤ ╨╕╤Б╤В╨╡╨║╨░╨╡╤В, ╨╡╤Б╨╗╨╕ ╨╜╨╕ ╨▓╨╛ ╤З╤В╨╛ ╨╜╨╡ ╨┐╨╛╨┐╨░╨╗. ╨б╤В╤А╨░╤Е╨╛╨▓╨║╨░ ╨╛╤В
 ## ╤Б╨╜╨░╤А╤П╨┤╨░, ╤Г╨╗╨╡╤В╨╡╨▓╤И╨╡╨│╨╛ ╨▓ ╨┐╤Г╤Б╤В╨╛╤В╤Г ╨╜╨░ ╤И╤Г╨╝ ╨▓ ╨┐╤А╨╕╨╗╨╛╨╢╨╡╨╜╨╕╨╕.
 @export var lifetime: float = 3.0
 
+## ╨а╨░╨┤╨╕╤Г╤Б ╤И╨╗╨╡╨╣╤Д╨░ ╨▓ ╨╝╨╡╤В╤А╨░╤Е. ╨Я╤А╨╕╤Е╨╛╨┤╨╕╤В ╨╕╨╖ ╨┤╨░╨╜╨╜╤Л╤Е ╨╛╤А╤Г╨╢╨╕╤П
+## (WeaponData.projectile_radius): ╤Б╨╗╨╡╨┤ ╨┐╨╛╨║╨░╨╖╤Л╨▓╨░╨╡╤В, ╨│╨┤╨╡ ╨╗╨╡╤В╨╕╤В ╨┐╤Г╨╗╤П, ╨┐╨╛╤Н╤В╨╛╨╝╤Г
+## ╨╡╨│╨╛ ╤А╨░╨╖╨╝╨╡╤А ╨╛╨▒╤П╨╖╨░╨╜ ╨┐╨╛╨▓╤В╨╛╤А╤П╤В╤М ╤А╨░╨╖╨╝╨╡╤А ╤Б╨╜╨░╤А╤П╨┤╨░.
+@export var radius: float = 0.08
+## ╨ж╨▓╨╡╤В ╤И╨╗╨╡╨╣╤Д╨░. ╨Я╤А╨╕╤Е╨╛╨┤╨╕╤В ╨╕╨╖ ╨┤╨░╨╜╨╜╤Л╤Е ╨╛╤А╤Г╨╢╨╕╤П (WeaponData.projectile_color):
+## ╤Б╨╗╨╡╨┤ ╨┤╨╡╨╗╨░╨╡╤В ╨╛╤А╤Г╨╢╨╕╨╡ ╤Г╨╖╨╜╨░╨▓╨░╨╡╨╝╤Л╨╝ ╨╜╨░ ╨│╨╗╨░╨╖ тАФ ╨╢╤С╨╗╤В╤Л╨╣ ╨░╨▓╤В╨╛╨╝╨░╤В ╨╜╨╡ ╤Б╨┐╤Г╤В╨░╤В╤М ╤Б
+## ╤Б╨╡╤А╤Л╨╝ ╨┐╨╕╤Б╤В╨╛╨╗╨╡╤В╨╛╨╝.
+@export var color: Color = Color(0.15, 0.15, 0.15)
+
 ## ╨б╨╗╨╛╨╣ 5 тАФ `projectile`.
 const _COLLISION_LAYER := 1 << 4
 ## ╨Ь╨░╤Б╨║╨░ 1 | 4: ╨╝╨╕╤А╨╛╨▓╨░╤П ╨│╨╡╨╛╨╝╨╡╤В╤А╨╕╤П (╤Б╨╗╨╛╨╣ 1) ╨╕ ╤Е╨╕╤В╨▒╨╛╨║╤Б╤Л ╨▓╤А╨░╨│╨░ (╤Б╨╗╨╛╨╣ 4). ╨б╨╗╨╛╤П
 ## ╤Е╨╕╤В╨▒╨╛╨║╤Б╨░ ╨╕╨│╤А╨╛╨║╨░ (7) ╨▓ ╨╝╨░╤Б╨║╨╡ ╨╜╨╡╤В ╨╜╨░╨╝╨╡╤А╨╡╨╜╨╜╨╛: ╨╕╨│╤А╨╛╨║ ╨╜╨╡ ╨┤╨╛╨╗╨╢╨╡╨╜ ╨┐╨╛╨╗╤Г╤З╨░╤В╤М ╤Г╤А╨╛╨╜ ╨╛╤В
 ## ╤Б╨╛╨▒╤Б╤В╨▓╨╡╨╜╨╜╤Л╤Е ╨▓╤Л╤Б╤В╤А╨╡╨╗╨╛╨▓, ╨┐╤А╨╛╤И╨╡╨┤╤И╨╕╤Е ╨╝╨╕╨╝╨╛ ╤Ж╨╡╨╗╨╕.
 const _COLLISION_MASK := (1 << 0) | (1 << 3)
 
 ## ╨Я╤А╨╛╨╖╤А╨░╤З╨╜╨╛╤Б╤В╤М ╤И╨╗╨╡╨╣╤Д╨░ ╨▓ ╨╜╨░╤З╨░╨╗╨╡ ╨┐╨╛╨╗╤С╤В╨░ ╨╕ ╨╡╤С ╨┐╨╛╤В╨╛╨╗╨╛╨║.
 const _TRAIL_PEAK_ALPHA := 0.6
-const _TRAIL_COLOR := Color(0.15, 0.15, 0.15)
 
 ## ╨Э╨░╨┐╤А╨░╨▓╨╗╨╡╨╜╨╕╨╡ ╨╜╨╛╤А╨╝╨░╨╗╨╕╨╖╨╛╨▓╨░╨╜╨╛ ╨╛╨┤╨╕╨╜ ╤А╨░╨╖ ╨╖╨┤╨╡╤Б╤М; ╨┤╨░╨╗╤М╤И╨╡ ╨╛╨╜╨╛ ╤В╨╛╨╗╤М╨║╨╛ ╤З╨╕╤В╨░╨╡╤В╤Б╤П.
 var _direction := Vector3.FORWARD
 var _age := 0.0
 ## ╨б╨╜╨░╤А╤П╨┤ ╨║╨╛╨╜╤З╨╕╨╗╤Б╤П: ╨┐╨╡╤А╨╡╤Б╨╡╤З╨╡╨╜╨╕╤П ╨▒╨╛╨╗╤М╤И╨╡ ╨╜╨╡ ╨╛╨▒╤А╨░╨▒╨░╤В╤Л╨▓╨░╤О╤В╤Б╤П, ╨┤╨░╨╢╨╡ ╨╡╤Б╨╗╨╕ ╨┤╨▓╨╕╨╢╨╛╨║
 ## ╤Г╤Б╨┐╨╡╨╡╤В ╨┐╤А╨╕╤Б╨╗╨░╤В╤М ╨╕╤Е ╨▓ ╤В╨╛╨╝ ╨╢╨╡ ╨┐╤А╨╛╤Е╨╛╨┤╨╡.
 var _spent := false
 var _trail: MeshInstance3D
 var _trail_material: StandardMaterial3D
 
@@ -126,48 +134,62 @@ func _on_body_entered(body: Node3D) -> void:
 ## ╨╖╨┤╨╡╤Б╤М, ╨░ ╨╜╨╡ ╨╗╨╛╨▓╨╕╤В╤М.
 func _spend() -> void:
 	_spent = true
 	set_physics_process(false)
 	set_deferred("monitoring", false)
 	queue_free()
 
 
 ## ╨и╨╗╨╡╨╣╤Д: ╨┤╨╛╤З╨╡╤А╨╜╨╕╨╣ MeshInstance3D, ╨║╨╛╤В╨╛╤А╤Л╨╣ ╨▒╨╗╨╡╨┤╨╜╨╡╨╡╤В ╨┐╨╛ ╨▓╤А╨╡╨╝╨╡╨╜╨╕ ╨╢╨╕╨╖╨╜╨╕.
 ##
-## ╨б╤Ж╨╡╨╜╨░ ╨╝╨╛╨╢╨╡╤В ╨╖╨░╨┤╨░╤В╤М ╨│╨╡╨╛╨╝╨╡╤В╤А╨╕╤О ╨╕ ╤Ж╨▓╨╡╤В ╤И╨╗╨╡╨╣╤Д╨░ ╤Б╨░╨╝╨░ (Task 5 ╨╖╨░╨┤╨░╤С╤В ╨╕╤Е ╨╕╨╖ ╨┤╨░╨╜╨╜╤Л╤Е
-## ╨╛╤А╤Г╨╢╨╕╤П); ╨╡╤Б╨╗╨╕ ╨╡╤С ╨╜╨╡╤В, ╤Б╨╜╨░╤А╤П╨┤ ╨╛╤Б╤В╨░╤С╤В╤Б╤П ╤А╨░╨▒╨╛╤З╨╕╨╝ ╤Б╨░╨╝╨╛╨┤╨╛╤Б╤В╨░╤В╨╛╤З╨╜╤Л╨╝. ╨Ч╨░╤В╤Г╤Е╨░╨╜╨╕╨╡ тАФ
+## ╨Т╨╕╨┤ ╤И╨╗╨╡╨╣╤Д╨░ ╨┐╤А╨╕╤Е╨╛╨┤╨╕╤В ╨╕╨╖ ╨┤╨░╨╜╨╜╤Л╤Е ╨╛╤А╤Г╨╢╨╕╤П (`radius` ╨╕ `color` ╤Н╤В╨╛╨│╨╛ ╤Б╨╜╨░╤А╤П╨┤╨░),
+## ╨░ ╨╜╨╡ ╨╕╨╖ ╨╗╨╕╤В╨╡╤А╨░╨╗╨╛╨▓: ╨╛╤А╤Г╨╢╨╕╨╡ ╤Б ╨┤╤А╤Г╨│╨╕╨╝ `projectile_radius`/`projectile_color`
+## ╨┤╨╛╨╗╨╢╨╜╨╛ ╨╝╨╡╨╜╤П╤В╤М ╤Б╨╗╨╡╨┤ ╨╜╨╡ ╤З╨╡╤А╨╡╨╖ ╨┐╤А╨░╨▓╨║╤Г ╨║╨╛╨┤╨░, ╨░ ╤З╨╡╤А╨╡╨╖ ╤Б╨▓╨╛╨╣ .tres. ╨б╤Ж╨╡╨╜╨░ ╨╝╨╛╨╢╨╡╤В
+## ╨┤╨░╤В╤М ╤Б╨▓╨╛╤О ╨╖╨░╨│╨╛╤В╨╛╨▓╨║╤Г ╤И╨╗╨╡╨╣╤Д╨░ (╤Г╨╖╨╡╨╗ `Trail` ╤Б ╨╝╨╡╤И╨╡╨╝ ╨╕ ╨╝╨░╤В╨╡╤А╨╕╨░╨╗╨╛╨╝), ╨╜╨╛ ╨╡╤С
+## ╨│╨╡╨╛╨╝╨╡╤В╤А╨╕╤П ╨╕ ╤Ж╨▓╨╡╤В ╨╖╨┤╨╡╤Б╤М ╨┐╤А╨╕╨▓╨╛╨┤╤П╤В╤Б╤П ╨║ ╨┤╨░╨╜╨╜╤Л╨╝ ╨╛╤А╤Г╨╢╨╕╤П тАФ ╨╗╨╛╨║╨░╨╗╤М╨╜╨╛╨╣ ╨║╨╛╨┐╨╕╨╡╨╣,
+## ╤З╤В╨╛╨▒╤Л ╨╜╨╡ ╨╝╤Г╤В╨╕╤А╨╛╨▓╨░╤В╤М ╨╛╨▒╤Й╨╕╨╣ ╨┤╨╗╤П ╨▓╤Б╨╡╤Е ╨╕╨╜╤Б╤В╨░╨╜╤Б╨╛╨▓ ╤А╨╡╤Б╤Г╤А╤Б .tscn. ╨Ч╨░╤В╤Г╤Е╨░╨╜╨╕╨╡ тАФ
 ## ╤Г╨╝╨╡╨╜╤М╤И╨╡╨╜╨╕╨╡ `albedo_color.a` ╨║╨░╨╢╨┤╤Л╨╣ ╨║╨░╨┤╤А, ╨░ ╨Э╨Х Tween: Tween ╨┐╤А╨╛╨┤╨╛╨╗╨╢╨░╨╡╤В
 ## ╤А╨░╨▒╨╛╤В╨░╤В╤М ╨╕ ╨┐╨╛╤Б╨╗╨╡ ╨┐╨╛╨┐╨░╨┤╨░╨╜╨╕╤П, ╨░ ╤И╨╗╨╡╨╣╤Д ╨╛╨▒╤П╨╖╨░╨╜ ╤Г╨╝╨╕╤А╨░╤В╤М ╨▓╨╝╨╡╤Б╤В╨╡ ╤Б╨╛ ╤Б╨╜╨░╤А╤П╨┤╨╛╨╝, ╨╕
 ## ╨╕╨╜╨░╤З╨╡ ╨▓ ╨╝╨╡╤Б╤В╨╡ ╨┐╨╛╨┐╨░╨┤╨░╨╜╨╕╤П ╨╛╤Б╤В╨░╨▓╨░╨╗╤Б╤П ╨▒╤Л ╨▓╨╕╤Б╤П╤Й╨╕╨╣ ╨▓ ╨▓╨╛╨╖╨┤╤Г╤Е╨╡ ╨┐╨╛╨╗╤Г╨┐╤А╨╛╨╖╤А╨░╤З╨╜╤Л╨╣ ╤И╨░╤А.
 func _setup_trail() -> void:
 	if _trail == null:
 		for child in get_children():
 			if child is MeshInstance3D:
 				_trail = child
 				break
 	if _trail == null:
 		_trail = MeshInstance3D.new()
 		_trail.name = "Trail"
-		var mesh := SphereMesh.new()
-		mesh.radius = 0.08
-		mesh.height = 0.16
-		_trail.mesh = mesh
 		add_child(_trail)
+	var sphere := _trail.mesh as SphereMesh
+	if sphere == null:
+		sphere = SphereMesh.new()
+		_trail.mesh = sphere
+	elif not sphere.resource_local_to_scene:
+		# ╨Ь╨╡╤И ╨╕╨╖ .tscn тАФ ╤А╨╡╤Б╤Г╤А╤Б, ╨╛╨▒╤Й╨╕╨╣ ╨┤╨╗╤П ╨▓╤Б╨╡╤Е ╨╕╨╜╤Б╤В╨░╨╜╤Б╨╛╨▓ ╤Б╤Ж╨╡╨╜╤Л: ╨║╨╛╨┐╨╕╤П ╨╜╤Г╨╢╨╜╨░,
+		# ╨╕╨╜╨░╤З╨╡ ╨┐╤А╨░╨▓╨║╨░ ╤А╨░╨┤╨╕╤Г╤Б╨░ ╨╖╨┤╨╡╤Б╤М ╨┐╨╛╨╝╨╡╨╜╤П╨╗╨░ ╨▒╤Л ╤Б╨╗╨╡╨┤ ╤Г ╨║╨░╨╢╨┤╨╛╨│╨╛ ╤Б╨╜╨░╤А╤П╨┤╨░.
+		sphere = sphere.duplicate() as SphereMesh
+		_trail.mesh = sphere
+	sphere.radius = radius
+	sphere.height = radius * 2.0
 	var mat := _trail.material_override as StandardMaterial3D
 	if mat == null:
 		mat = StandardMaterial3D.new()
 		_trail.material_override = mat
-		var color := _TRAIL_COLOR
-		color.a = _TRAIL_PEAK_ALPHA
-		mat.albedo_color = color
+	elif not mat.resource_local_to_scene:
+		# ╨в╨░ ╨╢╨╡ ╨┐╤А╨╕╤З╨╕╨╜╨░, ╤З╤В╨╛ ╤Г ╨╝╨╡╤И╨░: ╨╝╨░╤В╨╡╤А╨╕╨░╨╗ .tscn ╨╛╨▒╤Й╨╕╨╣, ╨░ ╤Г ╨║╨░╨╢╨┤╨╛╨│╨╛ ╨╛╤А╤Г╨╢╨╕╤П
+		# ╤Б╨▓╨╛╨╣ ╤Ж╨▓╨╡╤В ╤Б╨╗╨╡╨┤╨░.
+		mat = mat.duplicate() as StandardMaterial3D
+		_trail.material_override = mat
+	var trail_color := color
+	trail_color.a = _TRAIL_PEAK_ALPHA
+	mat.albedo_color = trail_color
 	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
-	if is_zero_approx(mat.albedo_color.a):
-		mat.albedo_color.a = _TRAIL_PEAK_ALPHA
 	_trail_material = mat
 
 
 func _fade_trail() -> void:
 	if _trail_material == null or lifetime <= 0.0:
 		return
 	var color := _trail_material.albedo_color
 	color.a = _TRAIL_PEAK_ALPHA * clampf(1.0 - _age / lifetime, 0.0, 1.0)
 	_trail_material.albedo_color = color
\ No newline at end of file
diff --git a/scripts/weapon_data.gd b/scripts/weapon_data.gd
index 939a931..37d8fdf 100644
--- a/scripts/weapon_data.gd
+++ b/scripts/weapon_data.gd
@@ -1,20 +1,21 @@
 class_name WeaponData
 extends Resource
 
 ## ╨е╨░╤А╨░╨║╤В╨╡╤А╨╕╤Б╤В╨╕╨║╨╕ ╨╛╤А╤Г╨╢╨╕╤П ╨║╨░╨║ ╨┤╨░╨╜╨╜╤Л╨╡.
 ##
 ## ╨Ю╨┤╨╜╨╛ ╨╛╤А╤Г╨╢╨╕╨╡ тАФ ╨╛╨┤╨╕╨╜ ╤А╨╡╤Б╤Г╤А╤Б, ╨╛╨┤╨╜╨░ ╤Б╤В╤А╤Г╨║╤В╤Г╤А╨░ ╨┐╨╛╨╗╨╡╨╣. ╨Я╨╛╨▓╨╡╨┤╨╡╨╜╨╕╨╡ (╨╝╨░╨│╨░╨╖╨╕╨╜,
 ## ╨┐╨╡╤А╨╡╨╖╨░╤А╤П╨┤╨║╨░, ╨╛╨│╨╛╨╜╤М) ╨╢╨╕╨▓╤С╤В ╨▓ ╤Б╨║╤А╨╕╨┐╤В╨╡ ╨╛╤А╤Г╨╢╨╕╤П, ╨░ ╨╜╨╡ ╨╖╨┤╨╡╤Б╤М: ╤А╨╡╤Б╤Г╤А╤Б ╨╜╨╕╤З╨╡╨│╨╛ ╨╜╨╡
 ## ╨╖╨╜╨░╨╡╤В ╨┐╤А╨╛ ╤Г╨╖╨╗╤Л ╤Б╤Ж╨╡╨╜╤Л, ╨┐╨╛╤Н╤В╨╛╨╝╤Г ╨╡╨│╨╛ ╨╝╨╛╨╢╨╜╨╛ ╨┐╤А╨╛╨▓╨╡╤А╨╕╤В╤М headless, ╨╜╨╡ ╤Б╤В╤А╨╛╤П ╨╝╨╕╤А.
 
 @export var display_name: String = "Weapon"
+@export var price: int = 0  # ╨Ю╤З╨║╨╕ ╨╖╨░ ╨┐╨╛╨║╤Г╨┐╨║╤Г; 0 = ╤Б╤В╨░╤А╤В╨╛╨▓╨╛╨╡ ╨▒╨╡╤Б╨┐╨╗╨░╤В╨╜╨╛╨╡ (pistol)
 @export var damage: float = 30.0
 ## ╨Т╤Л╤Б╤В╤А╨╡╨╗╨╛╨▓ ╨▓ ╨╝╨╕╨╜╤Г╤В╤Г. ╨Ш╨╜╤В╨╡╤А╨▓╨░╨╗ ╨╝╨╡╨╢╨┤╤Г ╨▓╤Л╤Б╤В╤А╨╡╨╗╨░╨╝╨╕ = 60 / rounds_per_minute.
 @export var rounds_per_minute: float = 120.0
 @export var magazine_size: int = 10
 @export var reload_time: float = 1.2
 ## ╨б╨║╨╛╤А╨╛╤Б╤В╤М ╤Б╨╜╨░╤А╤П╨┤╨░ ╨▓ ╨╝/╤Б. ╨Ъ╨╛╨╜╨╡╤З╨╜╨░╤П ╤Б╨║╨╛╤А╨╛╤Б╤В╤М ╨╛╨▒╤П╨╖╨░╤В╨╡╨╗╤М╨╜╨░: ╨╕╨│╤А╨╛╨║ ╨╕ ╨▓╤А╨░╨│ ╨╝╨╛╨│╤Г╤В
 ## ╤Г╨║╨╗╨╛╨╜╤П╤В╤М╤Б╤П. ╨Э╨░ 40 ╨╝/╤Б ╤Б╨╜╨░╤А╤П╨┤ ╨┐╨╕╤Б╤В╨╛╨╗╨╡╤В╨░ ╨┐╤А╨╛╨╗╨╡╤В╨░╨╡╤В 15 ╨╝ ╨╖╨░ 0.375 ╤Б, ╨╕ ╤Н╤В╨╛
 ## ╨╛╨║╨╜╨╛, ╨╖╨░ ╨║╨╛╤В╨╛╤А╨╛╨╡ ╤Ж╨╡╨╗╤М ╤Г╤Б╨┐╨╡╨▓╨░╨╡╤В ╨╛╤В╨╛╨╣╤В╨╕. ╨н╤В╨╛ ╨╕╨│╤А╨╛╨▓╨╛╨╡ ╨┐╤А╨░╨▓╨╕╨╗╨╛ ╨╕╨╖ PROJECT.md
 ## ┬з9.8, ╨░ ╨╜╨╡ ╤В╨╡╤Е╨╜╨╕╤З╨╡╤Б╨║╨░╤П ╨┤╨╡╤В╨░╨╗╤М: ╨╝╨│╨╜╨╛╨▓╨╡╨╜╨╜╤Л╨╣ (╤Е╨╕╤В╤Б╨║╨░╨╜) ╨▓╤Л╤Б╤В╤А╨╡╨╗ ╤Н╤В╨╛ ╨╛╨║╨╜╨╛
 ## ╤Г╨▒╨╕╤А╨░╨╡╤В, ╨╕ ╤Г╨║╨╗╨╛╨╜╨╡╨╜╨╕╨╡ ╤Б╤В╨░╨╜╨╛╨▓╨╕╤В╤Б╤П ╨╜╨╡╨▓╨╛╨╖╨╝╨╛╨╢╨╜╤Л╨╝.
diff --git a/tests/weapon_data.gd b/tests/weapon_data.gd
index ece44f6..60909be 100644
--- a/tests/weapon_data.gd
+++ b/tests/weapon_data.gd
@@ -91,20 +91,25 @@ func _initialize() -> void:
 		"(script=%s)" % ("none" if script_res == null else script_res.resource_path))
 	var data := res as WeaponData
 	if data == null:
 		_bail("pistol.tres is not a WeaponData, the field checks below would be meaningless")
 		return
 
 	print("-- the values the design fixes for the pistol")
 	# Each of these turns red on a single field edit in pistol.tres.
 	_check(data.display_name == "Pistol", "display_name is \"Pistol\"",
 		"(got \"%s\")" % data.display_name)
+	# pistol.tres does not set price, so this pins the script default: the
+	# starting weapon is free, every purchasable one (auto) sets an explicit
+	# price in its own .tres.
+	_check(data.price == 0, "price is 0 for the starting weapon",
+		"(got %d)" % data.price)
 	_check(data.damage == 30.0, "damage is 30.0", "(got %.4f)" % data.damage)
 	_check(data.rounds_per_minute == 150.0, "rounds_per_minute is 150.0",
 		"(got %.4f)" % data.rounds_per_minute)
 	_check(data.magazine_size == 18, "magazine_size is 18",
 		"(got %d)" % data.magazine_size)
 	_check(data.reload_time == 1.2, "reload_time is 1.2", "(got %.4f)" % data.reload_time)
 	_check(data.projectile_speed == 70.0, "projectile_speed is 70.0",
 		"(got %.4f)" % data.projectile_speed)
 	_check(data.projectile_radius == 0.08, "projectile_radius is 0.08",
 		"(got %.4f)" % data.projectile_radius)
diff --git a/tools/run_checks.ps1 b/tools/run_checks.ps1
index 275aaae..62a2eae 100644
--- a/tools/run_checks.ps1
+++ b/tools/run_checks.ps1
@@ -39,21 +39,21 @@
 
 $ErrorActionPreference = 'Stop'
 
 # Godot 4.7.2 stable. This is the single supported engine for the project; do
 # not add a second path here, the test contract (exit codes, [FAIL] markers on
 # stdout, --headless flag) is tied to this build.
 $GodotBin = "E:\Godot\Godot_v4.7.2-stable_win64.exe"
 
 # Ordered list of check names, without the .gd extension.
 $Tests = @("smoke", "movement", "input_actions", "input_gate", "weapon_data", "integrity",
-           "weapon", "projectile", "enemies", "waves", "save", "progression")
+           "weapon", "auto_weapon", "projectile", "enemies", "waves", "save", "progression")
 
 # tests\capture.gd needs a real renderer and tests\diagnose.gd is run by hand,
 # so neither belongs here.
 
 $Filter = ''
 if ($args.Count -gt 0 -and $null -ne $args[0]) {
     $Filter = [string]$args[0]
 }
 
 # Godot's --path . is resolved against the process working directory, and the

=== NEW FILES (full contents) ===

--- FILE: data/weapons/auto.tres ---
[gd_resource type="Resource" script_class="WeaponData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/weapon_data.gd" id="1_script"]

; Р’СЂРµРјРµРЅРЅС‹Р№ Р±Р°Р»Р°РЅСЃ РІР»Р°РґРµР»СЊС†Р° (2026-10-10): С‡РёСЃР»Р° РјРѕРіСѓС‚ РїРѕРјРµРЅСЏС‚СЊСЃСЏ РїСЂРё С„РёРЅР°Р»СЊРЅРѕР№
; РЅР°СЃС‚СЂРѕР№РєРµ. РњР°С€РёРЅРЅРѕ РёС… С‡РёС‚Р°СЋС‚ РѕСЂСѓР¶РµР№РЅР°СЏ СЃС†РµРЅР° (auto.tscn) Рё С‚РµСЃС‚
; tests/auto_weapon.gd, Р° РЅРµ РєР°РєРёРµ-Р»РёР±Рѕ С…Р°СЂРґРєРѕРґС‹.

[resource]
script = ExtResource("1_script")
display_name = "Auto"
damage = 15.0
rounds_per_minute = 300.0
magazine_size = 36
reload_time = 1.6
projectile_speed = 70.0
projectile_radius = 0.06
projectile_lifetime = 3.0
projectile_color = Color(0.95, 0.75, 0.15, 1)
price = 300

--- FILE: auto.tscn ---
[gd_scene format=3 uid="uid://c9fj2nkq5vt3m"]

[ext_resource type="Script" uid="uid://bg0d4f8nbbd46" path="res://scripts/pistol.gd" id="1_auto_script"]
[ext_resource type="Resource" path="res://data/weapons/auto.tres" id="2_auto_data"]
[ext_resource type="PackedScene" path="res://projectile.tscn" id="3_auto_projectile"]

[sub_resource type="BoxMesh" id="BoxMesh_auto_frame"]
size = Vector3(0.05, 0.09, 0.3)

[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_auto_frame"]
albedo_color = Color(0.12, 0.16, 0.36, 1)
metallic_specular = 0.0
emission_enabled = true
emission = Color(0.12, 0.16, 0.36, 1)
emission_energy_multiplier = 0.5

[sub_resource type="BoxMesh" id="BoxMesh_auto_grip"]
size = Vector3(0.045, 0.13, 0.07)

[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_auto_grip"]
albedo_color = Color(0.08, 0.11, 0.28, 1)
metallic_specular = 0.0
emission_enabled = true
emission = Color(0.08, 0.11, 0.28, 1)
emission_energy_multiplier = 0.5

[sub_resource type="BoxMesh" id="BoxMesh_auto_sight"]
size = Vector3(0.009, 0.01, 0.03)

[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_auto_sight"]
albedo_color = Color(1, 0.62, 0.12, 1)
metallic_specular = 0.0
emission_enabled = true
emission = Color(1, 0.62, 0.12, 1)
emission_energy_multiplier = 1.5

[node name="Auto" type="Node3D" unique_id=10000100]
script = ExtResource("1_auto_script")
data = ExtResource("2_auto_data")
projectile_scene = ExtResource("3_auto_projectile")

[node name="Frame" type="MeshInstance3D" parent="." unique_id=10000101]
mesh = SubResource("BoxMesh_auto_frame")
surface_material_override/0 = SubResource("StandardMaterial3D_auto_frame")

[node name="Grip" type="MeshInstance3D" parent="." unique_id=10000102]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.1, 0.12)
mesh = SubResource("BoxMesh_auto_grip")
surface_material_override/0 = SubResource("StandardMaterial3D_auto_grip")

[node name="FrontSight" type="MeshInstance3D" parent="." unique_id=10000103]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.05, -0.13)
mesh = SubResource("BoxMesh_auto_sight")
surface_material_override/0 = SubResource("StandardMaterial3D_auto_sight")

[node name="Muzzle" type="Marker3D" parent="." unique_id=10000104]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -0.18)

--- FILE: tests/auto_weapon.gd ---
extends SceneTree

## Auto-weapon harness for VibeFPS: the second weapon (an automatic pistol) is
## the same pistol.gd behaviour driven by a different WeaponData, so this check
## pins the parts that differ -- the data itself, the scene wiring, the shot
## through the real projectile.tscn -- and the projectile visual that has to
## follow the weapon data (radius 0.06, yellow trail) instead of the pistol's
## defaults.
##
## The pattern is borrowed from tests/weapon.gd: a _PistolProbe answers the
## input gate with an explicit mouse mode (headless cannot capture the cursor),
## the shipped auto.tscn geometry is grafted onto the probe, and waits are
## bounded in wall-clock seconds because the weapon's rate limit is the thing
## under test and lives in seconds, not frames.
##
## Run: godot --headless --path . --script res://tests/auto_weapon.gd
##      .\tools\run_checks.ps1 auto_weapon

## Stand-in for pistol.gd, used only by this harness.
class _PistolProbe extends "res://scripts/pistol.gd":
	## Mouse mode the gate is evaluated against instead of Input.mouse_mode.
	var gate_mouse_mode: int = Input.MOUSE_MODE_CAPTURED

	func _mouse_mode_for_play_input() -> int:
		return gate_mouse_mode


## Records what the weapon announces. fired counts shots -- one signal, one
## round, which is what "the auto really shoots" reduces to here; the full
## magazine bookkeeping is already pinned for pistol.gd by tests/weapon.gd.
class _Log extends RefCounted:
	var fired: int = 0

	func _on_fired() -> void:
		fired += 1


const _AUTO_DATA_PATH := "res://data/weapons/auto.tres"
const _AUTO_SCENE_PATH := "res://auto.tscn"
## The projectile scene auto.tscn points at, loaded rather than rebuilt: the
## trail under data-driven test is the trail the shipped scene really carries.
const _PROJECTILE_SCENE_PATH := "res://projectile.tscn"

## The values the design fixes for the auto. Restated here so a balance edit to
## auto.tres cannot silently turn the harness into a check of numbers it does
## not claim to verify.
const _EXPECTED_MAGAZINE := 36
const _EXPECTED_INTERVAL := 0.2
const _EXPECTED_DAMAGE := 15.0
const _EXPECTED_SPEED := 70.0
const _EXPECTED_RADIUS := 0.06
const _EXPECTED_PRICE := 300
const _EXPECTED_COLOR := Color(0.95, 0.75, 0.15)

## Ceiling for every timed wait; a broken weapon leaves it far behind, a hung
## one cannot turn the check into a runner timeout.
const _WAIT_CAP_SECONDS := 15.0
## How far a measured timer may overshoot the nominal interval.
const _TIMER_TOLERANCE := 0.35
## Float slack on the short side of a timer.
const _TIMER_EPSILON := 0.05

var _failures: PackedStringArray = []
var _checks := 0
var _data: WeaponData
var _projectile_scene: PackedScene


func _check(ok: bool, label: String, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  [PASS] %s %s" % [label, detail])
	else:
		_failures.append("%s %s" % [label, detail])
		print("  [FAIL] %s %s" % [label, detail])


func _finish() -> void:
	print("=== RESULT: %d checks, %d failed ===" % [_checks, _failures.size()])
	for f in _failures:
		print("  FAILURE: %s" % f)


func _bail(reason: String) -> void:
	print("FATAL: %s" % reason)
	_finish()
	quit(1)


func _close(a: float, b: float) -> bool:
	return is_equal_approx(a, b)


func _close_color(a: Color, b: Color) -> bool:
	return is_equal_approx(a.r, b.r) and is_equal_approx(a.g, b.g) \
		and is_equal_approx(a.b, b.b)


# --------------------------------------------------------------------------
# waiting
# --------------------------------------------------------------------------

func _await_until(predicate: Callable, max_seconds := _WAIT_CAP_SECONDS) -> bool:
	var deadline := _now_ms() + int(max_seconds * 1000.0)
	var reached := false
	for i in 1000000:
		await process_frame
		if predicate.call():
			reached = true
			break
		if _now_ms() >= deadline:
			break
	return reached


func _now_ms() -> int:
	return Time.get_ticks_msec()


## Releases the fire action and lets real frames go by, so the arming latch has
## seen the button up before the next press is read as input.
func _settle_fire_released() -> void:
	Input.action_release("fire")
	await process_frame
	await process_frame


# --------------------------------------------------------------------------
# world builders
# --------------------------------------------------------------------------

func _new_world() -> Node3D:
	var world := Node3D.new()
	world.name = "World"
	root.add_child(world)
	return world


## A current camera in the pose a player's head hangs at, standing in for
## player.tscn. auto.tscn leaves fire_rate_source empty on purpose, so this is
## the node the weapon actually aims from in the game.
func _new_eye(world: Node3D) -> Camera3D:
	var eye := Camera3D.new()
	eye.name = "Eye"
	eye.current = true
	eye.position = Vector3(0.0, 1.7, 0.0)
	world.add_child(eye)
	return eye


## The shipped auto geometry grafted onto a probe. Children are MOVED over, so
## the Muzzle marker under test is the one auto.tscn really ships; the probe is
## what answers the gate (see the class), and data plus projectile scene are
## set before the node enters the tree because _ready() fills the magazine from
## them.
func _new_pistol_from_scene(world: Node3D, scene: PackedScene, data: WeaponData) -> _PistolProbe:
	var geometry := scene.instantiate()
	var pistol := _PistolProbe.new()
	pistol.name = "Auto"
	pistol.data = data
	pistol.projectile_scene = _projectile_scene
	for child in geometry.get_children():
		geometry.remove_child(child)
		child.owner = null
		pistol.add_child(child)
	geometry.free()
	world.add_child(pistol)
	for i in 8:
		await process_frame
		if pistol.is_node_ready():
			return pistol
	print("FATAL: the auto never became ready")
	return pistol


func _watch(pistol: _PistolProbe) -> _Log:
	var log := _Log.new()
	pistol.fired.connect(log._on_fired)
	return log


## The projectiles under `parent`. The weapon parents every shot to its aim
## source (here: the camera), so this is how live bullets are found.
func _live_projectiles(parent: Node3D) -> Array[Projectile]:
	var out: Array[Projectile] = []
	for child in parent.get_children():
		if child is Projectile:
			out.append(child as Projectile)
	return out


# --------------------------------------------------------------------------
# entry point
# --------------------------------------------------------------------------

func _initialize() -> void:
	print("=== VibeFPS auto weapon test ===")
	_data = load(_AUTO_DATA_PATH) as WeaponData
	if _data == null:
		_bail("cannot load %s as a WeaponData" % _AUTO_DATA_PATH)
		return
	_projectile_scene = load(_PROJECTILE_SCENE_PATH) as PackedScene
	if _projectile_scene == null:
		_bail("cannot load %s" % _PROJECTILE_SCENE_PATH)
		return

	_test_data_contract()
	_test_scene_contract()
	await _test_scene_shot()
	await _test_fire_interval()

	_finish()
	quit(1 if _failures.size() > 0 else 0)


# --------------------------------------------------------------------------
# checks
# --------------------------------------------------------------------------

## The data the auto is defined by. A balance edit to auto.tres has to turn a
## check red, never a scene or a hardcode.
func _test_data_contract() -> void:
	print("-- data: auto.tres is the auto the design fixes")
	_check(_data.is_valid(), "auto.tres reports itself valid")
	_check(_data.display_name == "Auto", "display_name is \"Auto\"",
		"(got \"%s\")" % _data.display_name)
	_check(_close(_data.seconds_between_shots(), _EXPECTED_INTERVAL),
		"seconds_between_shots() is %.1f s at 300 rpm" % _EXPECTED_INTERVAL,
		"(got %.6f)" % _data.seconds_between_shots())
	_check(_data.magazine_size == _EXPECTED_MAGAZINE,
		"magazine_size is %d" % _EXPECTED_MAGAZINE,
		"(got %d)" % _data.magazine_size)
	_check(_close(_data.damage, _EXPECTED_DAMAGE),
		"damage is %.1f" % _EXPECTED_DAMAGE, "(got %.4f)" % _data.damage)
	_check(_data.price == _EXPECTED_PRICE,
		"price is %d" % _EXPECTED_PRICE, "(got %d)" % _data.price)
	_check(_close(_data.projectile_speed, _EXPECTED_SPEED),
		"projectile_speed is %.1f m/s" % _EXPECTED_SPEED,
		"(got %.4f)" % _data.projectile_speed)
	_check(_close(_data.projectile_radius, _EXPECTED_RADIUS),
		"projectile_radius is %.2f" % _EXPECTED_RADIUS,
		"(got %.4f)" % _data.projectile_radius)
	_check(_close_color(_data.projectile_color, _EXPECTED_COLOR),
		"projectile_color is the auto's yellow", "(got %s)" % _data.projectile_color)


## The scene wiring: auto.tscn is the auto with a barrel, carrying the auto
## data and the projectile scene, and no fire_rate_source (the weapon falls
## back to the player's camera exactly like the pistol).
func _test_scene_contract() -> void:
	print("-- scene: auto.tscn instantiates and is wired to auto.tres")
	var packed: PackedScene = load(_AUTO_SCENE_PATH)
	_check(packed != null, "auto.tscn is loadable", "(%s)" % _AUTO_SCENE_PATH)
	if packed == null:
		return
	var direct := packed.instantiate()
	_check(direct != null, "auto.tscn instantiates")
	if direct == null:
		return
	_check(direct.get("data") == _data,
		"auto.tscn carries data = auto.tres")
	_check(direct.get("projectile_scene") == _projectile_scene,
		"auto.tscn drives res://projectile.tscn")
	_check(direct.get("fire_rate_source") == null,
		"auto.tscn leaves fire_rate_source empty: it aims from the camera")
	var barrel := direct.get_node_or_null("Muzzle") as Node3D
	_check(barrel != null, "auto.tscn carries a Muzzle marker")
	_check(barrel != null and barrel.position.z < -0.1,
		"and it sits in front of the weapon, not inside the grip",
		"(got %s)" % ("no Muzzle" if barrel == null else str(barrel.position)))
	direct.free()


## One real shot through the input path with the scene grafted onto the probe:
## the round leaves the barrel, flies at the auto's speed, and the projectile
## instance carries the data -- speed, damage, and the visual radius/color the
## trail is built from. The trail of the shipped projectile.tscn is checked
## too, because that is the "projectile look from data" contract end to end.
func _test_scene_shot() -> void:
	print("-- shot: one round, aimed by a camera, projectile look from auto.tres")
	var world := _new_world()
	var eye := _new_eye(world)
	var packed: PackedScene = load(_AUTO_SCENE_PATH)
	if packed == null:
		world.free()
		return
	var pistol := await _new_pistol_from_scene(world, packed, _data)
	var log := _watch(pistol)

	var barrel := pistol.get_node_or_null("Muzzle") as Node3D
	_check(barrel != null, "precondition: the grafted scene carries its Muzzle marker")

	await _settle_fire_released()
	Input.action_press("fire")
	var fired := await _await_until(func() -> bool: return log.fired > 0, 5.0)
	Input.action_release("fire")
	_check(fired, "the held fire button produced a shot", "(got %d)" % log.fired)
	_check(log.fired == 1, "exactly one shot came out", "(got %d)" % log.fired)
	_check(pistol.current_mag() == _EXPECTED_MAGAZINE - 1,
		"the shot cost exactly one round", "(got %d)" % pistol.current_mag())

	var bullets := _live_projectiles(eye)
	_check(bullets.size() == 1, "one projectile was spawned under the camera",
		"(got %d)" % bullets.size())
	if bullets.size() == 1 and barrel != null:
		var bullet := bullets[0]
		# Sample late by design: the shot came through the input path, so the
		# projectile has already flown part of its line by the time the harness
		# sees it. What the start point is, is still decidable: a bullet that
		# left the eye would sit at eye height (~1.7 m), one that left the
		# barrel hangs at the barrel's height (~0 m) on the camera's line.
		_check(bullet.global_position.distance_to(eye.global_position) > 0.5,
			"the projectile is not hanging out of the eye",
			"(%.3f m from the eye)" % bullet.global_position.distance_to(eye.global_position))
		_check(absf(bullet.global_position.y - barrel.global_position.y) < 0.2,
			"it left from the barrel height, not the camera height",
			"(bullet y=%.3f, barrel y=%.3f, eye y=%.3f)" % [
				bullet.global_position.y, barrel.global_position.y, eye.global_position.y])
		_check(_close(bullet.speed, _EXPECTED_SPEED),
			"the projectile takes the auto's speed from the data",
			"(got %.1f m/s)" % bullet.speed)
		_check(_close(bullet.damage, _EXPECTED_DAMAGE),
			"the projectile takes the auto's damage from the data",
			"(got %.1f)" % bullet.damage)
		_check(_close(bullet.radius, _EXPECTED_RADIUS),
			"the projectile carries the auto's radius from the data",
			"(got %.4f)" % bullet.radius)
		_check(_close_color(bullet.color, _data.projectile_color),
			"the projectile carries the auto's color from the data",
			"(got %s, want %s)" % [str(bullet.color), str(_data.projectile_color)])

		var trail := bullet.get_node_or_null("Trail") as MeshInstance3D
		_check(trail != null, "the projectile carries a trail node")
		if trail != null:
			var sphere := trail.mesh as SphereMesh
			_check(sphere != null and _close(sphere.radius, bullet.radius),
				"the trail sphere has the data radius, so the visual follows auto.tres",
				"(got %s)" % ("no SphereMesh" if sphere == null else "%.4f" % sphere.radius))
			var mat := trail.material_override as StandardMaterial3D
			_check(mat != null and _close_color(mat.albedo_color, _data.projectile_color),
				"the trail material carries the data color",
				"(got %s)" % ("no material" if mat == null else str(mat.albedo_color)))

		var start: Vector3 = bullet.global_position
		await _await_until(func() -> bool: return bullet.global_position.distance_to(start) > 0.5, 5.0)
		var moved: Vector3 = bullet.global_position - start
		_check(moved.length() > 0.5,
			"the projectile is flying, so launch() was called on a node in the tree",
			"(moved %.3f m)" % moved.length())
		_check(moved.normalized().dot(-eye.global_transform.basis.z) > 0.99,
			"it leaves along the camera's forward axis",
			"(%.3f m along %.3f m forward)" % [
				moved.length(), moved.normalized().dot(-eye.global_transform.basis.z)])
	world.free()


## The rate limit lives in seconds and comes from the data: 300 rpm is one shot
## every 0.2 s, refused in the same instant and allowed once the interval has
## passed. The interval is measured on the scene-created weapon, so the whole
## chain (auto.tres -> pistol.gd -> actual timing) is under test, not just the
## resource's arithmetic.
func _test_fire_interval() -> void:
	print("-- rate limit: one shot per %.1f s, in seconds not frames" % _EXPECTED_INTERVAL)
	var world := _new_world()
	var packed: PackedScene = load(_AUTO_SCENE_PATH)
	if packed == null:
		world.free()
		return
	var pistol := await _new_pistol_from_scene(world, packed, _data)
	var log := _watch(pistol)

	_check(pistol.try_fire(), "the first shot is allowed")
	_check(not pistol.try_fire(), "a second shot in the same instant is refused")
	_check(log.fired == 1, "only one round left the magazine",
		"(got %d)" % log.fired)

	var start := _now_ms()
	var second := false
	for i in 6000:
		await process_frame
		if pistol.try_fire():
			second = true
			break
	var elapsed := float(_now_ms() - start) / 1000.0
	print("    second shot after %.3f s" % elapsed)
	_check(second, "the next shot is allowed once the interval has passed")
	_check(elapsed >= _EXPECTED_INTERVAL - _TIMER_EPSILON,
		"the second shot waited at least the full interval",
		"(waited %.3f s, want >= %.2f s)" % [elapsed, _EXPECTED_INTERVAL - _TIMER_EPSILON])
	_check(elapsed <= _EXPECTED_INTERVAL + _TIMER_TOLERANCE,
		"and did not wait much longer than the interval",
		"(waited %.3f s, want <= %.2f s)" % [elapsed, _EXPECTED_INTERVAL + _TIMER_TOLERANCE])
	_check(log.fired == 2, "exactly two rounds came out",
		"(got %d)" % log.fired)
	world.free()

--- FILE: tests/auto_weapon.gd.uid ---
uid://b8ovbq7puhxu2

