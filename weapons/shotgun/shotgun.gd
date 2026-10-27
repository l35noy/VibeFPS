class_name Shotgun
extends Pistol

## Двуствольный дробовик (Double-barrel Shotgun): залп из 10 дробинок веером.
##
## Наследует Pistol для полиморфного экипирования игроком (player.gd::apply_equipped_weapon()).
## При выстреле расходует 1 патрон из 2, выпускает 10 снарядов (Area3D, слой 5 projectile,
## маска 4 enemy_hurtbox + 1 world) со скоростью 70 м/с в детерминированном конусе
## (1 центральный, 3 внутренних, 6 внешних).
## На дистанции 1.5 м в упор все 10 снарядов попадают в цель и наносят ровно 120 суммарного урона.

## Список снарядов последнего выстрела для верификации и тестирования.
var last_spawned_pellets: Array[Node3D] = []


## Возвращает количество дробинок в залпе из WeaponData или 10 по умолчанию.
func get_pellet_count() -> int:
	return data.pellets if data != null else 10


## Алиас выстрела для внешних вызовов и E2E-тестов.
func fire() -> bool:
	return try_fire()


## Произвести выстрел залпом дроби, если выстрел разрешен.
## Возвращает true только при успешном залпе.
func try_fire() -> bool:
	if not can_fire():
		return false
	if _cooldown > 0.0:
		return false

	var pellets := _spawn_pellet_burst()
	if pellets.is_empty():
		return false

	last_spawned_pellets = pellets
	_current -= 1
	_cooldown = data.seconds_between_shots()

	_apply_visual_recoil()
	fired.emit()
	magazine_changed.emit(_current, data.magazine_size)
	return true


## Спавнит 10 дробинок в детерминированном конусе рассеивания.
func _spawn_pellet_burst() -> Array[Node3D]:
	var result: Array[Node3D] = []
	var p_scene := projectile_scene
	if p_scene == null:
		p_scene = load("res://weapons/projectile/projectile.tscn") as PackedScene
	if p_scene == null:
		return result

	var muzzle := _muzzle()
	var spawn := _spawn_point()
	var spawn_pos: Vector3 = spawn.global_position if spawn.is_inside_tree() else (global_position + (spawn.position if spawn != null else Vector3.ZERO))
	var base_dir := _calculate_shot_direction(spawn_pos, muzzle)
	var right := muzzle.global_transform.basis.x.normalized()
	var up := muzzle.global_transform.basis.y.normalized()

	var pellet_count: int = get_pellet_count()
	var max_spread_deg: float = data.spread_angle_degrees if data != null else 4.5
	var max_spread_rad: float = deg_to_rad(max_spread_deg)

	for i in range(pellet_count):
		var theta: float = 0.0
		var phi: float = 0.0

		if i == 0:
			# Центральная дробинка
			theta = 0.0
			phi = 0.0
		elif i <= 3:
			# Внутреннее кольцо: 3 дробинки на 45% радиуса конуса
			theta = max_spread_rad * 0.45
			phi = float(i - 1) * (TAU / 3.0)
		else:
			# Внешнее кольцо: 6 дробинок на 100% радиуса конуса со смещением фазы PI/6
			theta = max_spread_rad
			phi = (PI / 6.0) + float(i - 4) * (TAU / 6.0)

		# Направление дробинки в конусе
		var pellet_dir := (base_dir * cos(theta) + (right * cos(phi) + up * sin(phi)) * sin(theta)).normalized()

		var instance := p_scene.instantiate()
		var projectile := instance as Node3D
		if projectile == null or not projectile.has_method("launch"):
			if instance != null:
				instance.free()
			continue

		if projectile is Projectile:
			var bullet := projectile as Projectile
			bullet.speed = data.projectile_speed
			bullet.damage = data.damage
			bullet.lifetime = data.projectile_lifetime
			bullet.radius = data.projectile_radius
			bullet.color = data.projectile_color

		muzzle.add_child(projectile)
		projectile.set_as_top_level(true)
		projectile.global_position = spawn_pos
		projectile.call("launch", pellet_dir)
		result.append(projectile)

	return result
