# Review package — Task SHOOT (SHOOT-1 + SHOOT-2)

OWNER COMMITTED 7a4b13d (includes Phase 2 + SHOOT). Working tree clean. Task files: scripts/pistol.gd, pistol.tscn, tests/weapon.gd, tests/enemies.gd.

## git status --short

## controller-run state: full suite 9 passed / 0 failed / 3 skipped (EXIT=0); weapon 2 passed / 0 failed / 0 skipped (EXIT=0)

---

## scripts/pistol.gd (full)
class_name Pistol
extends Node3D

## Пистолет: магазин, темп стрельбы, перезарядка, огонь.
##
## Характеристики приходят из `WeaponData`, поведение живёт здесь. Одно
## оружие — один скрипт, параметризованный ресурсом: второго оружия в Фазе 1
## нет, а иерархия «под будущее» — это код, который никто не запускает.
##
## Восемь решений, каждое из которых проверка закрепляет:
##
## 1. Порядок внутри `try_fire()`: сначала проверки, потом инстанцирование
##    снаряда, и только потом уменьшение магазина. Обратный порядок съедает
##    патрон на провалившемся инстанцировании — игрок теряет пулю, которую
##    не стрелял. Промахнуться можно легко: сцена не назначена, сцена указывает
##    не на тот узел.
## 2. Перезарядку нельзя перезапустить. Перезапуск сбрасывает таймер, а
##    значит игрок, нажимая перезарядку на пустом магазине, откладывает её
##    бесконечно. Поэтому `start_reload()` отказывает, когда перезарядка уже
##    идёт, и не трогает таймер.
## 3. Темп стрельбы — это секунды (`data.seconds_between_shots()`), а не
##    кадры. 120 выстр./мин это один выстрел за 0.5 с при любой частоте кадров;
##    счётчик кадров на 240 Гц превратил бы пистолет в автомат.
## 4. `_process`, а не физический тик: стрельба — игровое действие с частотой
##    кадров рендера, а не часть физической симуляции. Таймеры при этом всё
##    равно в секундах, поэтому правило темпа от выбора функции не зависит.
## 5. Гейт ввода тот же, что у движения: действие `fire` не должно обходить
##    его, иначе пистолет стреляет при отпущенном курсоре, пока остальной
##    персонаж стоит.
## 6. Пустой магазин начинает перезарядку сам. Игрок не обязан помнить про R,
##    а кнопка огня в тот же кадр не должна ни выстрелить, ни сбросить
##    таймер перезагрузки.
## 7. Точка старта снаряда и точка прицеливания — разные узлы (`_muzzle()` и
##    `_spawn_point()`): направление задаёт прицел, а вылетать пуля должна из
##    ствола, иначе она вылетает из головы игрока.
## 8. Защёлка взведения (`_armed`): первый выстрел возможен только после того,
##    как оружие увидело отпущенную кнопку. ЛКМ может быть зажат ещё до входа
##    в дерево, и уровневый опрос без взведения превращает это в бесплатный
##    выстрел на каждом старте уровня.

## Выстрел произошёл. Один сигнал — одна пуля, в том числе когда попадание
## не принесло урона.
signal fired()
## Перезарядка началась.
signal reload_started()
## Перезарядка закончилась, магазин полон.
signal reload_finished()
## Изменилось число патронов. Сигнал об изменении, а не о существовании:
## начальное состояние читается через `current_mag()`.
signal magazine_changed(current: int, capacity: int)

## Характеристики: темп, ёмкость, время перезарядки, урон и параметры снаряда.
@export var data: WeaponData
## Сцена снаряда для инстанцирования. Без неё оружие не стреляет, но и не
## тратит патроны.
@export var projectile_scene: PackedScene
## Откуда выпускать снаряд. По умолчанию — камера игрока: выстрел должен
## уходить оттуда, куда смотрит глаз, а не оттуда, где висит оружие.
@export var fire_rate_source: Node3D

## Осталось патронов.
var _current: int = 0
## Сколько секунд осталось до конца перезарядки; 0 — перезарядки нет.
var _reload_remaining: float = 0.0
## Сколько секунд осталось до следующего выстрела.
var _cooldown: float = 0.0
## Взведён ли огонь. Пока ложь, кнопку огня можно держать сколько угодно и
## выстрела не будет: первый настоящий выстрел — после первого наблюдаемого
## отпускания. Подробность в _process().
var _armed := false


func _ready() -> void:
	# Полный магазин при появлении оружия. magazine_changed здесь не
	# испускается: HUD читает начальное состояние через current_mag().
	_current = _capacity()


func _process(delta: float) -> void:
	# 1. Темп стрельбы. Секунды, поэтому частота кадров на скорострельность не
	#    влияет, а maxf не даёт таймеру уйти в отрицательные значения.
	_cooldown = maxf(0.0, _cooldown - delta)

	# 2. Перезарядка.
	if _reload_remaining > 0.0:
		_reload_remaining -= delta
		if _reload_remaining <= 0.0:
			_reload_remaining = 0.0
			_complete_reload()

	# 3. Действие огня. try_fire() внутри спрашивает гейт ввода, поэтому
	#    нажатая кнопка при отпущенном курсоре выстрела не даёт.
	#
	#    Защёлка взведения — обязательна перед выстрелом. Мышь захватывается
	#    раньше первого _process (player.gd::_ready()), а перезарядка и темп
	#    стрельбы стартуют с нуля, поэтому остаточный бит ЛКМ на кадре 0 без
	#    взведения даёт бесплатный выстрел, который игрок не нажимал. Взводит
	#    первое же наблюдаемое отпускание; после взведения удержание стреляет
	#    как обычно, темп не меняется.
	var fire_held := Input.is_action_pressed("fire")
	if not _armed:
		if not fire_held:
			_armed = true
	elif fire_held:
		try_fire()

	# 4. Пустой магазин уходит в перезарядку сам. Проверка is_reloading()
	#    здесь обязательна: без неё каждый кадр с зажатой кнопкой огня звал бы
	#    start_reload() заново и перезагрузка не кончалась бы никогда.
	if _current <= 0 and _reload_remaining <= 0.0 and _has_valid_data():
		start_reload()


## Единственное место в игре, где читается Input.mouse_mode для гейта ввода.
## Обёрнуто в метод по той же причине, что и в player.gd: headless-дисплейсер
## не умеет захватывать курсор, поэтому проверка подменяет только значение,
## попадающее в гейт, а не синглтон Input.
func _mouse_mode_for_play_input() -> int:
	return Input.mouse_mode


## Можно ли сейчас произвести выстрел.
##
## Четыре игровых правила: данные пригодны, ввод разрешён, перезарядки нет,
## магазин не пуст. Темп стрельбы здесь не проверяется — это таймер, а не
## право стрелять; его держит `try_fire()`. Пока это так, «магазин пуст» и
## «выстрел запрещён» — два разных вопроса, и проверка спрашивает их по
## отдельности.
func can_fire() -> bool:
	if not _has_valid_data():
		return false
	if not InputGate.is_play_input_allowed(_mouse_mode_for_play_input()):
		return false
	if is_reloading():
		return false
	return _current > 0


## Выстрел, если он разрешен. Возвращает `true`, только если выстрел был.
##
## Порядок обязателен: проверки, инстанцирование снаряда, уменьшение
## магазина, таймер, сигналы. Уменьшать магазин до инстанцирования нельзя —
## провалившееся инстанцирование съело бы патрон, который игрок не потратил.
func try_fire() -> bool:
	if not can_fire():
		return false
	# Темп стрельбы держится здесь, а не в can_fire(): can_fire() отвечает на
	# вопрос «имеет ли игрок право стрелять», и право от темпа не зависит.
	if _cooldown > 0.0:
		return false
	var projectile := _instantiate_projectile()
	if projectile == null:
		# Снаряда не будет — патрон остаётся в магазине.
		return false
	_current -= 1
	_cooldown = data.seconds_between_shots()
	# Сигналы после уменьшения: и fired, и magazine_changed наблюдаются уже с
	# новым состоянием, поэтому слушатель никогда не прочитает устаревшее
	# число патронов.
	fired.emit()
	magazine_changed.emit(_current, data.magazine_size)
	return true


## Начать перезарядку. `false`, если перезаряжаться нечего.
##
## Перезапуск идющей перезарядки запрещён и таймер не трогается: перезапуск
## обнулил бы отсчёт, и игрок держал бы R сколько угодно, откладывая
## перезарядку бесконечно.
func start_reload() -> bool:
	if is_reloading():
		return false
	if not _has_valid_data():
		return false
	if _current >= _capacity():
		# Полный магазин перезаряжать нечего: перезагрузка кончилась бы без
		# единого изменения состояния.
		return false
	_reload_remaining = data.reload_time
	# magazine_changed здесь не испускается: число патронов ещё не изменилось,
	# о начале перезагрузки говорит reload_started.
	reload_started.emit()
	return true


## Сколько патронов осталось.
func current_mag() -> int:
	return _current


## Идёт ли перезарядка.
func is_reloading() -> bool:
	return _reload_remaining > 0.0


## Вернуть оружие в исходное состояние при смене сцены.
##
## Контракт на Фазу 4 (лобби), а не мёртвый код: полный магазин, без
## перезарядки, обнулённый темп. Вызывается из player.gd::_ready(). Без него
## полупустой магазин пережил бы поездку в лобби и обратно, и каждая такая
## поездка стоила бы игроку бесплатных патронов.
func reset_for_scene_change() -> void:
	_reload_remaining = 0.0
	_cooldown = 0.0
	_current = _capacity()
	# Взведение сбрасывается вместе с остальным состоянием: кнопка, залипшая
	# на прошлой сцене, не должна выстрелить в новой раньше, чем игрок её
	# отпустит.
	_armed = false
	magazine_changed.emit(_current, _capacity())


# --------------------------------------------------------------------------
# внутреннее
# --------------------------------------------------------------------------

func _has_valid_data() -> bool:
	return data != null and data.is_valid()


func _capacity() -> int:
	return data.magazine_size if data != null else 0


func _complete_reload() -> void:
	_current = _capacity()
	reload_finished.emit()
	magazine_changed.emit(_current, _capacity())


## Откуда ЦЕЛИТЬСЯ: заданный источник, иначе камера игрока — выстрел должен
## уходить туда, куда смотрит глаз. Если камеры нет (пистолет проверен без
## игрока), целимся от самого оружия.
func _muzzle() -> Node3D:
	if fire_rate_source != null:
		return fire_rate_source
	var viewport := get_viewport()
	if viewport != null:
		var camera := viewport.get_camera_3d()
		if camera != null:
			return camera
	return self


## Откуда СТАРТОВАТЬ снаряду — это другой вопрос, и раньше на оба отвечал
## `_muzzle()`, из-за чего пуля вылетала из головы игрока.
##
## Точка — узел `Muzzle` в pistol.tscn, конец дула: рамка длиной 0.3 м, то
## есть чуть за дульной кромкой. Направление при этом остаётся прежним, от
## `_muzzle()`: пистолет довёрнут относительно камеры (player.tscn), и
## смещать точку старта вместе с ним нельзя — пуля пошла бы мимо прицела.
##
## Узла `Muzzle` нет — значит сцена собрана без ствола (харнесс, макетка без
## оружия), и точка остаётся прежней цепочкой. Предупреждение выходит только
## когда цепочка приводит в камеру (fire_rate_source == null): там подмена
## заметна игроку, а в проверках, где источник задан, маркер не нужен и
## сообщение было бы шумом на каждый выстрел.
func _spawn_point() -> Node3D:
	var barrel := get_node_or_null("Muzzle") as Node3D
	if barrel != null:
		return barrel
	if fire_rate_source == null:
		push_warning("[pistol] %s: в сцене нет узла Muzzle — снаряд стартует из прицела" % name)
	return _muzzle()


## Снаряд из `projectile_scene` или `null`, если выстрела не будет.
##
## Порядок обязателен, и каждая строка в нём load-bearing: узел добавляется в
## дерево ДО `launch()` (`Projectile._ready()` выключает свою обработку и
## включает её только `launch()`, поэтому вызов до входа в дерево был бы затёрт
## этим же `_ready()` — снаряд висел бы в мире неподвижным), отвязка от
## родителя идёт ДО записи позиции, а позиция — ДО `launch()`.
func _instantiate_projectile() -> Node3D:
	if projectile_scene == null:
		return null
	var instance := projectile_scene.instantiate()
	var projectile := instance as Node3D
	if projectile == null or not projectile.has_method("launch"):
		# Сцена не снаряда. Ранний выход: узел не в дереве, и queue_free() для
		# него недоступен.
		if instance != null:
			instance.free()
		return null
	# Характеристики приходят из данных оружия, а не из значений сцены: одно
	# место, откуда берётся урон и скорость пули.
	if projectile is Projectile:
		var bullet := projectile as Projectile
		bullet.speed = data.projectile_speed
		bullet.damage = data.damage
		bullet.lifetime = data.projectile_lifetime
	var muzzle := _muzzle()
	# Точка старта и направление — два разных узла (см. _spawn_point()).
	var spawn := _spawn_point()
	# Передняя ось источника, а не ось мира: пистолет поворачивается вместе с
	# игроком, и снаряд должен уходить туда, куда он направлен. Читается один
	# раз — после этого направление у снаряда своё.
	var direction := -muzzle.global_transform.basis.z
	muzzle.add_child(projectile)
	# Отвязка от трансформа родителя — вторая часть фикса SHOOT-1 (первая, выше,
	# это точка старта). У Node3D мировой трансформ = global(родителя) * local,
	# поэтому запись global_position у привязанной ноды лишь пересчитывает
	# local.origin: между тиками мировая позиция снаряда едет вместе с
	# родителем, а Projectile, пишущий global_position += _direction * speed *
	# delta, каждый тик закрепляет себе накопленную погрешность. Поворот камеры
	# на 0.05 rad — это полметра увода на десяти метрах, и повторяется он
	# каждый кадр. top_level делает трансформ снаряда его собственным: после
	# выстрела камера двигает только картинку. Родителем он остаётся прежним —
	# это жизненный цикл (queue_free, списки снарядов), а не позиция.
	projectile.set_as_top_level(true)
	# Мировая позиция ставится ПОСЛЕ отвязки: у top_level-ноды это уже абсолютная
	# точка, а до отвязки та же запись пересчитала бы локальную позицию прежнего
	# родителя.
	projectile.global_position = spawn.global_position
	projectile.call("launch", direction)
	return projectile

---

## pistol.tscn (full)
[gd_scene load_steps=8 format=3]

[ext_resource type="Script" path="res://scripts/pistol.gd" id="1_pistol_script"]
[ext_resource type="Resource" path="res://data/weapons/pistol.tres" id="2_data"]
[ext_resource type="PackedScene" path="res://projectile.tscn" id="3_projectile"]

[sub_resource type="BoxMesh" id="BoxMesh_frame"]
size = Vector3(0.05, 0.09, 0.3)

[sub_resource type="BoxMesh" id="BoxMesh_grip"]
size = Vector3(0.045, 0.13, 0.07)

[sub_resource type="BoxMesh" id="BoxMesh_sight"]
size = Vector3(0.014, 0.022, 0.03)

[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_frame"]
albedo_color = Color(0.24, 0.24, 0.27, 1)
metallic_specular = 0.0
emission_enabled = true
emission = Color(0.24, 0.24, 0.27, 1)
emission_energy_multiplier = 0.5

[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_grip"]
albedo_color = Color(0.34, 0.22, 0.16, 1)
metallic_specular = 0.0
emission_enabled = true
emission = Color(0.34, 0.22, 0.16, 1)
emission_energy_multiplier = 0.5

[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_sight"]
albedo_color = Color(1, 0.706, 0.09, 1)
metallic_specular = 0.0
emission_enabled = true
emission = Color(1, 0.706, 0.09, 1)
emission_energy_multiplier = 1.5

[node name="Pistol" type="Node3D"]
script = ExtResource("1_pistol_script")
data = ExtResource("2_data")
projectile_scene = ExtResource("3_projectile")

[node name="Frame" type="MeshInstance3D" parent="."]
mesh = SubResource("BoxMesh_frame")
surface_material_override/0 = SubResource("StandardMaterial3D_frame")

[node name="Grip" type="MeshInstance3D" parent="."]
position = Vector3(0, -0.1, 0.1)
rotation = Vector3(-0.12, 0, 0)
mesh = SubResource("BoxMesh_grip")
surface_material_override/0 = SubResource("StandardMaterial3D_grip")

[node name="FrontSight" type="MeshInstance3D" parent="."]
position = Vector3(0, 0.062, -0.15)
mesh = SubResource("BoxMesh_sight")
surface_material_override/0 = SubResource("StandardMaterial3D_sight")

[node name="Muzzle" type="Marker3D" parent="."]
position = Vector3(0, 0, -0.18)

---

## tests/weapon.gd (full)
extends SceneTree

## Weapon harness for VibeFPS: the pistol's magazine, its rate limit, its
## reload and the input gate around all three.
##
## The pistol is built here, in code, with a plain Node3D standing in for the
## fire source and no player anywhere in the scene: what is under test is
## magazine bookkeeping, the fire interval and the gate, and none of that needs
## a character or a level. Building it the way Task 5's pistol.tscn will is the
## point -- the pistol is handed a PackedScene for the projectile and is asked
## to instantiate it, so "decrement the magazine only after the projectile
## exists" is exercised for real rather than assumed.
##
## Headless cannot capture the cursor at all: Input.set_mouse_mode() is a silent
## no-op there, so Input.mouse_mode stays VISIBLE for the whole run and a gate
## reading it would deny everything. Exactly as in tests/movement.gd, the pistol
## is handed a subclass that answers the gate with an explicit mode; every other
## line under test is the real pistol.gd, and the harness asserts that the seam
## is live and that the untouched pistol.gd reads the engine's own mouse mode.
##
## Waits are bounded in seconds of wall clock, not in frames. The weapon's
## timers ARE the thing under test and they are in seconds; a check that counted
## frames would be asserting the headless frame rate instead of the rate limit.
##
## Run: godot --headless --path . --script res://tests/weapon.gd
##      .\tools\run_checks.ps1 weapon

## Stand-in for pistol.gd, used only by this harness.
class _PistolProbe extends "res://scripts/pistol.gd":
	## Mouse mode the gate is evaluated against instead of Input.mouse_mode.
	var gate_mouse_mode: int = Input.MOUSE_MODE_CAPTURED

	func _mouse_mode_for_play_input() -> int:
		return gate_mouse_mode


## Records everything the pistol announces, with wall-clock stamps on the two
## reload signals so the check can measure the reload in seconds.
class _Log extends RefCounted:
	var fired: int = 0
	var reload_started: int = 0
	var reload_finished: int = 0
	var magazine: Array[Vector2i] = []
	var reload_started_at_ms: int = -1
	var reload_finished_at_ms: int = -1

	func _on_fired() -> void:
		fired += 1

	func _on_reload_started() -> void:
		reload_started += 1
		reload_started_at_ms = Time.get_ticks_msec()

	func _on_reload_finished() -> void:
		reload_finished += 1
		reload_finished_at_ms = Time.get_ticks_msec()

	func _on_magazine_changed(current: int, capacity: int) -> void:
		magazine.append(Vector2i(current, capacity))

	func last_magazine() -> Vector2i:
		return magazine[magazine.size() - 1]

	func reload_duration() -> float:
		if reload_started_at_ms < 0 or reload_finished_at_ms < 0:
			return -1.0
		return float(reload_finished_at_ms - reload_started_at_ms) / 1000.0


const _PISTOL_SCRIPT_PATH := "res://scripts/pistol.gd"
const _PISTOL_DATA_PATH := "res://data/weapons/pistol.tres"
## The shipped pistol, loaded rather than rebuilt. The barrel marker is scene
## wiring, and a marker the harness invents for itself would be a marker the
## game never loads.
const _PISTOL_SCENE_PATH := "res://pistol.tscn"

## The values the design fixes for the pistol. They are restated here so a
## balance edit to pistol.tres cannot silently turn the harness into a check of
## different numbers than the one it claims to verify.
const _EXPECTED_MAGAZINE := 10
const _EXPECTED_RELOAD_TIME := 1.2
const _EXPECTED_INTERVAL := 0.5
const _EXPECTED_PROJECTILE_SPEED := 40.0
const _EXPECTED_DAMAGE := 30.0
const _EXPECTED_LIFETIME := 3.0

## Ceiling for every timed wait. Generous, because it only has to keep a broken
## pistol from turning the check into a 120 s runner timeout; a healthy pistol
## leaves it far behind.
const _WAIT_CAP_SECONDS := 15.0
## How far a measured timer may overshoot its nominal value. The timers are real
## seconds drained by per-frame deltas, so the answer overshoots by at most one
## frame -- and still nowhere near enough to hide a doubled interval, a reset
## timer or a reload that never ends.
const _TIMER_TOLERANCE := 0.35
## Float slack on the short side of a timer, so accumulated delta rounding can
## never fake a timer that ended early.
const _TIMER_EPSILON := 0.05
## How many physics ticks the flight is watched for after the aim source is
## turned and moved. At the shipped 120 Hz and 40 m/s that is half a second and
## 20 m of flight -- long enough for a bend of the parent to be unmistakable,
## short enough to stay inside the 3 s projectile lifetime.
const _TRAJECTORY_TICKS := 60
## How far off its own line the projectile may drift, in metres. The bug this
## catches moves a shot sideways by METRES (a parent yaw of 45 deg rotates the
## whole subtree around the pivot), while float32 noise over 20 m is about
## 2e-6 m. Centimetres separate the two with four orders of magnitude to spare.
const _TRAJECTORY_DRIFT_TOLERANCE := 0.05
## How many seconds of real frames the startup check watches a weapon that
## entered the tree with the button held. Twice the 0.5 s rate limit, so a
## pistol that fires on level alone would have spent four rounds.
const _NO_SHOT_WATCH_SECONDS := 1

var _failures: PackedStringArray = []
var _checks := 0
var _data: WeaponData
## One PackedScene for every pistol in this harness, standing in for the
## projectile.tscn that Task 5 will build on disk.
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


## Ends the run on a precondition the rest of the check cannot be evaluated
## against, so the runner gets a named failure and a non-zero exit code instead
## of a crash halfway through.
func _bail(reason: String) -> void:
	print("FATAL: %s" % reason)
	_finish()
	quit(1)


# --------------------------------------------------------------------------
# waiting
# --------------------------------------------------------------------------

## Runs one process frame at a time until `predicate` holds, giving up after
## `max_seconds` of wall clock. Returns whether the predicate was reached, so
## the caller can assert on a timeout instead of silently waiting forever.
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


## Releases the fire action and lets at least one real process frame go by,
## so a pistol whose arming latch needs an observed release has actually seen
## one before the next press is read as input. Scenarios that fire through the
## real input path start here; a pistol that entered the tree with the button
## already down is exactly what the startup check is about.
func _settle_fire_released() -> void:
	Input.action_release("fire")
	await process_frame
	await process_frame


## The aim source of the trajectory scenario hangs under a parent that the
## scenario moves afterwards. Every other scenario's aim source hangs straight
## off the world and nothing ever touches its ancestors -- which is precisely
## why a shot could stay glued to it and go unnoticed.
func _new_aim_under_pivot(world: Node3D) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "Pivot"
	world.add_child(pivot)
	var aim := Node3D.new()
	aim.name = "AimSource"
	pivot.add_child(aim)
	return pivot


## A player's camera, in the pose player.tscn gives it: high up, and the
## current one in the viewport. pistol.tscn leaves fire_rate_source empty on
## purpose, so this is the node the pistol actually aims from in the game.
func _new_eye(world: Node3D) -> Camera3D:
	var eye := Camera3D.new()
	eye.name = "Eye"
	eye.current = true
	eye.position = Vector3(0.0, 1.7, 0.0)
	world.add_child(eye)
	return eye


## The shipped pistol's geometry grafted onto a probe. The probe is what
## answers the input gate with an explicit mouse mode (headless cannot capture
## the cursor); the children are the scene's own, MOVED rather than copied, so
## the barrel marker under test is the one pistol.tscn really ships. The
## exports are set before the node enters the tree, because _ready() fills the
## magazine from them and a magazine filled from a null data is empty forever.
func _new_pistol_from_scene(world: Node3D, scene: PackedScene,
		data: WeaponData, projectiles := true) -> _PistolProbe:
	var geometry := scene.instantiate()
	var pistol := _PistolProbe.new()
	pistol.name = "Pistol"
	pistol.data = data
	if projectiles:
		pistol.projectile_scene = _projectile_scene
	for child in geometry.get_children():
		geometry.remove_child(child)
		# owner belongs to the scene tree it was packed from; carrying it over
		# would make Godot complain that the probe now owns nodes it never packed.
		child.owner = null
		pistol.add_child(child)
	geometry.free()
	world.add_child(pistol)
	for i in 8:
		await process_frame
		if pistol.is_node_ready():
			return pistol
	print("FATAL: the pistol never became ready")
	return pistol


# --------------------------------------------------------------------------
# world builders
# --------------------------------------------------------------------------

## One scenario's world. Freeing it at the end of the scenario takes the pistol,
## the dummy fire source and every projectile the pistol spawned with it.
func _new_world() -> Node3D:
	var world := Node3D.new()
	world.name = "World"
	root.add_child(world)
	return world


## The stand-in for the player's camera. `yaw` turns it, so a shot that follows
## the fire source's forward axis is distinguishable from one that fires along a
## hardcoded world axis.
func _new_muzzle(world: Node3D, yaw := 0.0) -> Node3D:
	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	muzzle.rotation.y = yaw
	world.add_child(muzzle)
	return muzzle


## A node added to the tree is not ready the moment add_child() returns: the
## engine queues it and runs _ready() on a later main-loop pass. The harness
## waits for that before measuring anything about a fresh pistol, otherwise
## "a fresh pistol has a full magazine" would be a claim about a node whose
## _ready() had not run yet.
func _new_pistol(world: Node3D, data: WeaponData, muzzle: Node3D,
		with_projectiles := true) -> _PistolProbe:
	var pistol := _PistolProbe.new()
	pistol.name = "Pistol"
	pistol.data = data
	pistol.fire_rate_source = muzzle
	if with_projectiles:
		pistol.projectile_scene = _projectile_scene
	world.add_child(pistol)
	for i in 8:
		await process_frame
		if pistol.is_node_ready():
			return pistol
	print("FATAL: the pistol never became ready")
	return pistol


func _watch(pistol: _PistolProbe) -> _Log:
	var log := _Log.new()
	pistol.fired.connect(log._on_fired)
	pistol.reload_started.connect(log._on_reload_started)
	pistol.reload_finished.connect(log._on_reload_finished)
	pistol.magazine_changed.connect(log._on_magazine_changed)
	return log


func _live_projectiles(muzzle: Node3D) -> Array[Projectile]:
	var out: Array[Projectile] = []
	for child in muzzle.get_children():
		if child is Projectile:
			out.append(child as Projectile)
	return out


## The projectile scene, packed in memory. Task 5 builds projectile.tscn; until
## then this stands in for it, with the CollisionShape3D that Task 2 found to be
## mandatory -- an Area3D with no shape finds nothing.
func _build_projectile_scene() -> PackedScene:
	var bullet := Projectile.new()
	bullet.name = "Projectile"
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var sphere := SphereShape3D.new()
	sphere.radius = 0.08
	shape.shape = sphere
	bullet.add_child(shape)
	# pack() stores only children the packed root owns, exactly as the editor
	# does when it saves a scene.
	shape.owner = bullet
	var packed := PackedScene.new()
	var err := packed.pack(bullet)
	bullet.free()
	if err != OK:
		return null
	return packed


func _signal_arg_count(node: Object, signal_name: String) -> int:
	for entry in node.get_signal_list():
		if String(entry.get("name", "")) == signal_name:
			return (entry["args"] as Array).size()
	return -1


## The hint string an @export carries ("PackedScene", "Node3D", ...), which is
## how the harness sees the declared type of an export.
func _property_hint(node: Object, property_name: String) -> String:
	for entry in node.get_property_list():
		if String(entry.get("name", "")) == property_name:
			return String(entry.get("hint_string", ""))
	return "<missing>"


# --------------------------------------------------------------------------
# entry point
# --------------------------------------------------------------------------

func _initialize() -> void:
	print("=== VibeFPS weapon test ===")
	_data = load(_PISTOL_DATA_PATH) as WeaponData
	if _data == null:
		_bail("cannot load %s as a WeaponData" % _PISTOL_DATA_PATH)
		return
	_projectile_scene = _build_projectile_scene()
	if _projectile_scene == null:
		_bail("cannot pack the in-memory projectile scene")
		return

	_test_source_contract()
	_test_contracts()
	_test_gate_harness()
	await _test_starting_magazine()
	await _test_single_shot()
	await _test_shot_follows_fire_source()
	await _test_shot_keeps_its_line_when_the_aim_source_moves()
	await _test_shot_starts_at_the_barrel()
	await _test_no_shot_while_the_button_is_down_on_entry()
	await _test_empty_magazine_and_automatic_reload()
	await _test_reload_blocks_firing_and_cannot_be_restarted()
	await _test_fire_rate()
	await _test_input_gate()
	await _test_full_magazine_has_nothing_to_reload()
	await _test_scene_change_reset()
	await _test_invalid_data_blocks_firing()
	await _test_missing_projectile_scene_keeps_the_round()

	_finish()
	quit(1 if _failures.size() > 0 else 0)


# --------------------------------------------------------------------------
# checks
# --------------------------------------------------------------------------

## Two rules the brief fixes that no behavioural check can see, because a
## violation shows up as a subtly wrong frame budget rather than a named
## failure: the timers must run in _process (firing is an action at render
## cadence, not a physics simulation) and can_fire() must ask InputGate rather
## than reading Input.mouse_mode itself.
func _test_source_contract() -> void:
	print("-- source contract: the frame the timers run in, and who asks the gate")
	var source := FileAccess.get_file_as_string(_PISTOL_SCRIPT_PATH)
	_check(source != "", "pistol.gd is readable", "(%d bytes)" % source.length())
	_check(source.contains("func _process(delta"),
		"pistol.gd runs its timers in _process, not in a physics tick")
	_check(not source.contains("func _physics_process"),
		"pistol.gd declares no _physics_process: the fire interval is in seconds")
	_check(source.count("InputGate.is_play_input_allowed(") >= 1,
		"can_fire() asks InputGate for permission",
		"(call sites=%d)" % source.count("InputGate.is_play_input_allowed("))


## Task 5 builds pistol.tscn against these names, and a renamed export or a
## renamed signal is a silent break for it.
func _test_contracts() -> void:
	print("-- contracts: the class, exports, methods and signals Task 5 binds to")
	var script := load(_PISTOL_SCRIPT_PATH) as Script
	_check(script != null, "pistol.gd loads")
	if script == null:
		return
	_check(script.get_global_name() == "Pistol",
		"pistol.gd declares class_name Pistol", "(got \"%s\")" % script.get_global_name())
	_check(script.get_instance_base_type() == "Node3D", "Pistol extends Node3D",
		"(got %s)" % script.get_instance_base_type())

	var pistol: Node = script.new()
	for method in ["can_fire", "try_fire", "start_reload", "current_mag",
			"is_reloading", "reset_for_scene_change"]:
		_check(pistol.has_method(method), "Pistol exposes %s()" % method)
	for signal_name in ["fired", "reload_started", "reload_finished", "magazine_changed"]:
		_check(pistol.has_signal(signal_name), "Pistol exposes the %s signal" % signal_name)
	_check(_signal_arg_count(pistol, "magazine_changed") == 2,
		"magazine_changed carries (current, capacity)",
		"(got %d args)" % _signal_arg_count(pistol, "magazine_changed"))
	_check(_property_hint(pistol, "data") == "WeaponData",
		"data is a WeaponData export", "(got \"%s\")" % _property_hint(pistol, "data"))
	_check(_property_hint(pistol, "projectile_scene") == "PackedScene",
		"projectile_scene is a PackedScene export",
		"(got \"%s\")" % _property_hint(pistol, "projectile_scene"))
	_check(_property_hint(pistol, "fire_rate_source") == "Node3D",
		"fire_rate_source is a Node3D export",
		"(got \"%s\")" % _property_hint(pistol, "fire_rate_source"))
	# Unassigned, because pistol.tscn leaves it empty on purpose and the pistol
	# has to fall back to the player's own camera.
	_check(pistol.get("fire_rate_source") == null,
		"fire_rate_source is empty by default, so the pistol falls back to the camera")
	pistol.free()


## The gate is only trustworthy if the harness really is driving it. If the seam
## were dead, every "the gate blocks firing" assertion below would pass for the
## wrong reason -- the pistol would deny itself whatever the mouse mode was.
func _test_gate_harness() -> void:
	print("-- gate harness: the seam is live and pistol.gd reads Input.mouse_mode")
	var script := load(_PISTOL_SCRIPT_PATH) as Script
	var stock: Node = script.new()
	_check(int(stock.call("_mouse_mode_for_play_input")) == Input.mouse_mode,
		"the untouched pistol.gd asks the engine for the mouse mode",
		"(mouse_mode=%d)" % Input.mouse_mode)
	stock.free()
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
		"precondition: headless really cannot capture the cursor",
		"(mouse_mode=%d)" % Input.mouse_mode)
	_check(InputGate.is_play_input_allowed(Input.MOUSE_MODE_CAPTURED),
		"the gate allows play input while the cursor is captured")
	_check(not InputGate.is_play_input_allowed(Input.MOUSE_MODE_VISIBLE),
		"the gate denies play input while the cursor is free")


func _test_starting_magazine() -> void:
	print("-- start: a fresh pistol has a full magazine and nothing else going on")
	var world := _new_world()
	var pistol := await _new_pistol(world, _data, _new_muzzle(world))
	var log := _watch(pistol)

	_check(pistol.current_mag() == _EXPECTED_MAGAZINE,
		"a fresh pistol starts with a full magazine",
		"(got %d of %d)" % [pistol.current_mag(), _EXPECTED_MAGAZINE])
	_check(not pistol.is_reloading(), "a fresh pistol is not reloading")
	_check(pistol.can_fire(), "a fresh pistol with valid data can fire")
	_check(log.fired == 0, "nothing fired just by existing")
	# magazine_changed reports changes. The initial count is read with
	# current_mag(), and a signal that fires on every node that ever appeared
	# would be a HUD that redraws the ammo count for no reason.
	_check(log.magazine.is_empty(),
		"magazine_changed stays quiet on start: it announces changes, not existence",
		"(got %s)" % str(log.magazine))
	world.free()


## One shot has to do all of this at once: consume exactly one round, announce
## itself once, report the new count with the capacity, and put a projectile
## into the world configured from the weapon data and launched along the fire
## source's forward axis.
func _test_single_shot() -> void:
	print("-- one shot: one round, one signal, one flying projectile")
	var world := _new_world()
	var muzzle := _new_muzzle(world)
	var pistol := await _new_pistol(world, _data, muzzle)
	var log := _watch(pistol)

	_check(pistol.try_fire(), "try_fire() reports the shot it made")
	_check(pistol.current_mag() == _EXPECTED_MAGAZINE - 1,
		"the magazine lost exactly one round", "(got %d)" % pistol.current_mag())
	_check(log.fired == 1, "fired arrived exactly once", "(got %d)" % log.fired)
	_check(log.magazine.size() == 1,
		"magazine_changed arrived once for the shot", "(got %d)" % log.magazine.size())
	_check(log.magazine.size() == 1 and log.last_magazine() == Vector2i(9, 10),
		"magazine_changed carries the new count and the capacity",
		"(got %s)" % str(log.magazine))

	var bullets := _live_projectiles(muzzle)
	_check(bullets.size() == 1, "exactly one projectile node was spawned",
		"(got %d)" % bullets.size())
	if bullets.size() == 1:
		var bullet := bullets[0]
		_check(is_equal_approx(bullet.speed, _EXPECTED_PROJECTILE_SPEED),
			"the projectile takes its speed from the weapon data",
			"(got %.1f m/s)" % bullet.speed)
		_check(is_equal_approx(bullet.damage, _EXPECTED_DAMAGE),
			"the projectile takes its damage from the weapon data",
			"(got %.1f)" % bullet.damage)
		_check(is_equal_approx(bullet.lifetime, _EXPECTED_LIFETIME),
			"the projectile takes its lifetime from the weapon data",
			"(got %.1f s)" % bullet.lifetime)
		var start: Vector3 = bullet.global_position
		await _await_until(func() -> bool: return bullet.global_position.distance_to(start) > 0.5, 5.0)
		var moved: Vector3 = bullet.global_position - start
		# A projectile that was added to the tree but never launched would sit
		# still: Projectile._ready() switches its own processing off and only
		# launch() switches it back on.
		_check(moved.length() > 0.5,
			"the projectile is flying, so launch() was called on a node already in the tree",
			"(moved %.3f m)" % moved.length())
		_check(moved.normalized().dot(-muzzle.global_transform.basis.z) > 0.99,
			"it leaves along the fire source's forward axis",
			"(%.3f m along %.3f m forward)" % [
				moved.length(), moved.normalized().dot(-muzzle.global_transform.basis.z)])
	world.free()


## The same shot with a fire source turned 90 degrees. If the direction came
## from a hardcoded world axis, this shot would fly off into the wall and the
## assertions above would still pass.
func _test_shot_follows_fire_source() -> void:
	print("-- direction: the shot follows the fire source, not a world axis")
	var world := _new_world()
	# -90 degrees of yaw turns the forward axis from -Z into +X.
	var muzzle := _new_muzzle(world, -PI / 2.0)
	var pistol := await _new_pistol(world, _data, muzzle)
	_check(pistol.try_fire(), "the shot was fired")

	var bullets := _live_projectiles(muzzle)
	_check(bullets.size() == 1, "one projectile was spawned", "(got %d)" % bullets.size())
	if bullets.size() == 1:
		var bullet := bullets[0]
		var start: Vector3 = bullet.global_position
		await _await_until(func() -> bool: return bullet.global_position.distance_to(start) > 0.5, 5.0)
		var moved: Vector3 = bullet.global_position - start
		print("    travelled %s" % moved)
		_check(moved.x > 0.5,
			"the shot left along the turned fire source, not along -Z",
			"(dx=%.3f m)" % moved.x)
		_check(absf(moved.z) < 0.05,
			"and left no trace along the world Z axis it was not aimed at",
			"(dz=%.3f m)" % moved.z)
	world.free()


## A shot must keep going where it was sent, whatever the aim source does
## afterwards. The player's camera is attached to a character who turns and
## walks every frame, and a projectile that stays a child of that camera has
## its world transform rewritten by the parent's every tick -- so a 45 degree
## yaw after the shot drags the bullet sideways by metres while it is in
## flight, and the bullet the player sees is not the bullet that hits.
##
## The aim source here hangs under a pivot that the scenario turns and moves
## after the shot, which is the player's own situation with one layer of
## indirection. The projectile is still parented to the aim source (the
## lifecycle parent is what free() and the projectile lists read), so this is
## about the transform, never about the parenting.
func _test_shot_keeps_its_line_when_the_aim_source_moves() -> void:
	print("-- trajectory: the shot keeps its line when the aim source's parent moves")
	var world := _new_world()
	var pivot := _new_aim_under_pivot(world)
	var aim := pivot.get_node("AimSource") as Node3D
	var pistol := await _new_pistol(world, _data, aim)
	await _settle_fire_released()
	Input.action_press("fire")
	var spawned := await _await_until(func() -> bool: return _live_projectiles(aim).size() > 0, 5.0)
	Input.action_release("fire")
	_check(spawned, "the shot was fired through the real input path",
		"(got %d projectiles)" % _live_projectiles(aim).size())
	if not spawned:
		world.free()
		return

	var bullet := _live_projectiles(aim)[0]
	_check(bullet.get_parent() == aim,
		"the projectile is still parented to the aim source: lifecycle did not change")
	var start: Vector3 = bullet.global_position
	# The line the shot is supposed to keep. Read once, before the world moves
	# under it -- that is what "goes where it was aimed" means.
	var line := -aim.global_transform.basis.z

	pivot.rotation.y = deg_to_rad(45.0)
	pivot.position = Vector3(2.0, 0.0, 0.0)

	var worst := 0.0
	for i in _TRAJECTORY_TICKS:
		await physics_frame
		if not is_instance_valid(bullet):
			break
		var offset: Vector3 = bullet.global_position - start
		# Distance from the line, not from the origin: the shot is SUPPOSED to
		# travel along `line`, so only the sideways component is drift.
		worst = maxf(worst, (offset - line * offset.dot(line)).length())
	print("    worst sideways drift %.4f m over %d physics ticks" % [worst, _TRAJECTORY_TICKS])
	_check(worst <= _TRAJECTORY_DRIFT_TOLERANCE,
		"the shot flew straight: moving the aim source's parent did not bend it",
		"(worst sideways drift %.4f m, tolerance %.3f m)" % [worst, _TRAJECTORY_DRIFT_TOLERANCE])
	_check(is_instance_valid(bullet), "and the projectile was still alive at the end of the flight")
	world.free()


## Where a shot STARTS and where it is AIMED are two different questions. The
## design pins the second one to the camera (a pistol held to the side is
## offset from the eye on purpose, player.tscn), but the first one is the
## barrel: a bullet that leaves the camera is visibly fired out of the
## player's head, and the two points are a hand's width apart.
##
## The pistol here is the shipped pistol.tscn, instantiated rather than
## rebuilt in code, so this is also the wiring check: a scene without a Muzzle
## marker falls back to the camera, and the fallback is asserted below rather
## than left to the log.
func _test_shot_starts_at_the_barrel() -> void:
	print("-- start point: the shot leaves the barrel, aimed by the camera")
	var packed: PackedScene = load(_PISTOL_SCENE_PATH)
	_check(packed != null, "pistol.tscn is loadable", "(%s)" % _PISTOL_SCENE_PATH)
	if packed == null:
		return
	var world := _new_world()
	var eye := _new_eye(world)
	# fire_rate_source left empty on purpose, exactly as pistol.tscn leaves it:
	# the pistol must find the camera the way it does in the game.
	var pistol := await _new_pistol_from_scene(world, packed, _data)

	var barrel := pistol.get_node_or_null("Muzzle") as Node3D
	_check(barrel != null,
		"pistol.tscn carries a Muzzle marker: the barrel is a place, not a guess")
	_check(barrel != null and barrel.global_position.z < -0.1,
		"and it sits in front of the pistol, not inside the grip",
		"(got %s)" % ("no Muzzle" if barrel == null else str(barrel.global_position)))

	var log := _watch(pistol)
	_check(pistol.try_fire(), "the shot was fired")
	_check(log.fired == 1, "and it announced exactly one shot", "(got %d)" % log.fired)
	var bullets := _live_projectiles(eye)
	_check(bullets.size() == 1, "one projectile was spawned under the camera",
		"(got %d)" % bullets.size())
	if bullets.size() == 1 and barrel != null:
		var bullet := bullets[0]
		_check(bullet.global_position.distance_to(barrel.global_position) < 0.001,
			"the shot starts at the barrel, not at the camera",
			"(bullet at %s, barrel at %s, eye at %s)" % [
				str(bullet.global_position), str(barrel.global_position), str(eye.global_position)])
		_check(bullet.global_position.distance_to(eye.global_position) > 0.1,
			"and visibly not out of the eye the player is looking through",
			"(%.3f m from the eye)" % bullet.global_position.distance_to(eye.global_position))
		var start: Vector3 = bullet.global_position
		await _await_until(func() -> bool: return bullet.global_position.distance_to(start) > 0.5, 5.0)
		var moved: Vector3 = bullet.global_position - start
		_check(moved.normalized().dot(-eye.global_transform.basis.z) > 0.99,
			"but it is still aimed by the camera, not by the barrel",
			"(%.3f m along %.3f m of the camera's forward axis)" % [
				moved.length(), moved.normalized().dot(-eye.global_transform.basis.z)])
	world.free()

	# The fallback chain is part of the contract, not an accident: a harness or
	# a scene built without a barrel marker still has to shoot from somewhere.
	# It is asserted here so a future "no barrel in this scene" cannot turn into
	# a bullet fired out of the player's skull with a clean test log.
	var bare_world := _new_world()
	var bare_eye := _new_eye(bare_world)
	var bare := await _new_pistol(bare_world, _data, null)
	_check(bare.get_node_or_null("Muzzle") == null,
		"precondition: a pistol built without a barrel marker really has none")
	_check(bare.try_fire(), "a pistol without a barrel marker still fires")
	var bare_bullets := _live_projectiles(bare_eye)
	_check(bare_bullets.size() == 1, "its projectile is parented to the camera",
		"(got %d)" % bare_bullets.size())
	if bare_bullets.size() == 1:
		_check(bare_bullets[0].global_position.distance_to(bare_eye.global_position) < 0.001,
			"and falls back to firing from the camera rather than refusing to shoot",
			"(bullet at %s, eye at %s)" % [
				str(bare_bullets[0].global_position), str(bare_eye.global_position)])
	bare_world.free()


## The pistol polls `Input.is_action_pressed("fire")` every frame, so the
## button's state at the moment it enters the tree IS a command. A real player
## gets there with the left button already down -- the window took focus with
## the mouse captured and the button never came up -- and the pistol's cooldown
## and magazine both start at zero, so the first frame of every level is a free
## shot the player never asked for.
##
## The latch is "no shot until a release has been observed", so the shot
## happens on the next REAL press, and holding the button afterwards keeps
## firing at the rate limit exactly as before.
func _test_no_shot_while_the_button_is_down_on_entry() -> void:
	print("-- startup: a fire button already down when the pistol enters the tree is not a shot")
	# Pressed BEFORE the pistol exists: this is a button that was down when the
	# level loaded, not a press the player is making now.
	Input.action_press("fire")
	var world := _new_world()
	# Built here rather than through _new_pistol() so the log is subscribed
	# BEFORE the node enters the tree. _new_pistol() awaits frames, and a shot
	# spent during that wait would fire a signal nobody was listening to yet --
	# which would turn this check green for exactly the wrong reason.
	var pistol := _PistolProbe.new()
	pistol.name = "Pistol"
	pistol.data = _data
	pistol.fire_rate_source = _new_muzzle(world)
	pistol.projectile_scene = _projectile_scene
	var log := _watch(pistol)
	world.add_child(pistol)
	for i in 8:
		await process_frame
		if pistol.is_node_ready():
			break
	_check(pistol.gate_mouse_mode == Input.MOUSE_MODE_CAPTURED,
		"precondition: the input gate is open, so only the button can hold the shot back")

	# A full second of real frames with the button down -- longer than the 0.5 s
	# rate limit, so a pistol that fires on level alone would spend three rounds.
	for i in _NO_SHOT_WATCH_SECONDS * 60:
		await process_frame
	_check(log.fired == 0,
		"a weapon that entered the tree with fire held does not shoot",
		"(got %d shots, magazine %d of %d)" % [log.fired, pistol.current_mag(), _EXPECTED_MAGAZINE])
	_check(pistol.current_mag() == _EXPECTED_MAGAZINE,
		"and it kept every round", "(got %d)" % pistol.current_mag())

	# The player's answer to "nothing happened": let go and press again.
	Input.action_release("fire")
	await process_frame
	await process_frame
	Input.action_press("fire")
	var answered := await _await_until(func() -> bool: return log.fired > 0, 2.0)
	Input.action_release("fire")
	await process_frame
	_check(answered, "and it does shoot on the next real press",
		"(got %d shots)" % log.fired)
	_check(log.fired == 1, "exactly one shot, not a burst that undoes the latch",
		"(got %d shots)" % log.fired)
	_check(pistol.current_mag() == _EXPECTED_MAGAZINE - 1,
		"costing exactly one round", "(got %d)" % pistol.current_mag())
	world.free()


## Ten rounds at the design's rate, then the eleventh attempt: refused, with the
## magazine untouched. The pistol then reloads itself -- the player does not have
## to ask -- and the held fire button produces nothing for the whole reload,
## which is the case the plan's review section calls out: an empty magazine and
## a fire press in the same frame must neither shoot nor restart the reload.
func _test_empty_magazine_and_automatic_reload() -> void:
	print("-- ten rounds, the empty magazine, and the reload the pistol starts itself")
	var world := _new_world()
	var muzzle := _new_muzzle(world)
	var pistol := await _new_pistol(world, _data, muzzle)
	var log := _watch(pistol)

	# The fire action is held from the first frame, so the ten rounds are spent
	# on the real input path rather than by calling try_fire() behind the
	# pistol's back. The release before it is the harness's half of the
	# arming latch (see _settle_fire_released): the pistol has to see the
	# button up before it will read a press as one.
	await _settle_fire_released()
	Input.action_press("fire")
	var emptied := await _await_until(func() -> bool: return log.fired >= _EXPECTED_MAGAZINE, 20.0)
	_check(emptied, "holding fire empties the magazine in %d rounds" % _EXPECTED_MAGAZINE,
		"(got %d)" % log.fired)

	# Same frame as the last round: the cooldown is running and the magazine is
	# empty. can_fire() does not consult the cooldown, so a refusal here is the
	# magazine's doing.
	_check(pistol.current_mag() == 0, "the magazine is empty",
		"(got %d)" % pistol.current_mag())
	_check(not pistol.can_fire(), "can_fire() is false on an empty magazine")
	_check(not pistol.try_fire(), "the eleventh try_fire() is refused")
	_check(pistol.current_mag() == 0, "the refused shot left the magazine at 0",
		"(got %d)" % pistol.current_mag())
	_check(log.fired == _EXPECTED_MAGAZINE,
		"no eleventh round left the magazine", "(got %d signals)" % log.fired)

	var started := await _await_until(func() -> bool: return log.reload_started > 0, 5.0)
	_check(started, "the empty magazine starts a reload without being asked")
	_check(pistol.is_reloading(), "the pistol reports itself reloading")
	_check(log.reload_started == 1, "exactly one reload was started",
		"(got %d)" % log.reload_started)

	# The fire button is still held. Nothing may come out until the magazine is
	# full again.
	var leaked := await _await_until(func() -> bool: return log.fired > _EXPECTED_MAGAZINE, 0.4)
	_check(not leaked, "a held fire button spends no rounds while the magazine is empty",
		"(got %d)" % log.fired)

	# Released before the reload can end, on purpose: a button still held at the
	# moment the magazine is full fires again in that very frame, which is
	# correct weapon behaviour and is pinned on purpose further down. Leaving it
	# held here would measure the refill and the next shot in one observation.
	Input.action_release("fire")
	var finished := await _await_until(func() -> bool: return log.reload_finished > 0)
	_check(finished, "the reload finished on its own")
	if finished:
		var elapsed := log.reload_duration()
		print("    reload took %.3f s" % elapsed)
		_check(elapsed >= _EXPECTED_RELOAD_TIME - _TIMER_EPSILON
				and elapsed <= _EXPECTED_RELOAD_TIME + _TIMER_TOLERANCE,
			"the reload took about %.1f s" % _EXPECTED_RELOAD_TIME,
			"(got %.3f s, tol +%.2f s)" % [elapsed, _TIMER_TOLERANCE])
		_check(pistol.current_mag() == _EXPECTED_MAGAZINE,
			"the magazine is full again", "(got %d)" % pistol.current_mag())
		_check(not pistol.is_reloading(), "the pistol is no longer reloading")
		_check(log.reload_finished == 1, "reload_finished arrived exactly once",
			"(got %d)" % log.reload_finished)
		_check(log.last_magazine() == Vector2i(10, 10),
			"magazine_changed announced the refilled magazine",
			"(got %s)" % str(log.magazine))
		_check(pistol.can_fire(), "the pistol can shoot again after the reload")

		# And it really can: a press now goes through at once, so the reload left
		# behind neither a stuck reloading flag nor a leftover cooldown.
		Input.action_press("fire")
		var resumed := await _await_until(func() -> bool: return log.fired > _EXPECTED_MAGAZINE, 2.0)
		Input.action_release("fire")
		_check(resumed, "a press right after the reload fires at once: no stuck cooldown",
			"(got %d shots)" % log.fired)
		_check(pistol.current_mag() == _EXPECTED_MAGAZINE - 1,
			"and that press cost exactly one round", "(got %d)" % pistol.current_mag())
	world.free()


## The reload has to be a wall, not a suggestion: a magazine that still has rounds
## in it must not hand them out while the pistol is reloading, and the reload
## must not be restartable. The second half matters because a restart resets the
## timer, and a player who can reset it can postpone the reload forever.
func _test_reload_blocks_firing_and_cannot_be_restarted() -> void:
	print("-- reloading: no rounds from a partly full magazine, and no restart")
	var world := _new_world()
	var muzzle := _new_muzzle(world)
	var pistol := await _new_pistol(world, _data, muzzle)
	var log := _watch(pistol)

	pistol.try_fire()
	_check(pistol.current_mag() == _EXPECTED_MAGAZINE - 1,
		"precondition: nine rounds are left", "(got %d)" % pistol.current_mag())
	_check(pistol.start_reload(), "a spent magazine accepts a reload")
	_check(pistol.is_reloading(), "the pistol reports itself reloading")
	_check(log.reload_started == 1, "reload_started arrived once", "(got %d)" % log.reload_started)

	# Nine rounds are in there and the rate limit expires half a second into a
	# 1.2 s reload, so without the is_reloading() rule in can_fire() this window
	# hands the player a round at about 0.5 s -- before the restart attempt
	# below, so the two defects cannot mask each other. The release first is the
	# harness's half of the arming latch: this pistol was created with the
	# button already up and has to be seen holding it that way.
	await _settle_fire_released()
	Input.action_press("fire")
	var halfway := await _await_until(func() -> bool:
		return _now_ms() - log.reload_started_at_ms >= 600, _EXPECTED_RELOAD_TIME + 1.0)
	_check(halfway, "precondition: half the reload went by with the button still held")
	_check(log.fired == 1,
		"a held fire button spends no rounds while reloading, even with rounds left",
		"(got %d shots, the rate limit expired 0.5 s into the reload)" % log.fired)

	# Now halfway in, ask for a second reload.
	var restart_at := _now_ms()
	_check(not pistol.start_reload(),
		"start_reload() refuses to restart a reload in progress")
	_check(pistol.is_reloading(), "the refused restart did not cancel the reload either")
	# Released here for the same reason as in the scenario above: a button held
	# at the instant the magazine is full fires again immediately, and that shot
	# would be counted as a round lost to the reload.
	Input.action_release("fire")

	var finished := await _await_until(func() -> bool: return log.reload_finished > 0)
	_check(finished, "the reload still finished")
	if finished:
		var total := log.reload_duration()
		var left_at_restart := float(log.reload_finished_at_ms - restart_at) / 1000.0
		print("    reload took %.3f s; %.3f s of it were left after the refused restart" % [
			total, left_at_restart])
		_check(total >= _EXPECTED_RELOAD_TIME - _TIMER_EPSILON
				and total <= _EXPECTED_RELOAD_TIME + _TIMER_TOLERANCE,
			"the reload still took about %.1f s in total" % _EXPECTED_RELOAD_TIME,
			"(got %.3f s)" % total)
		# The load-bearing half: the refused restart must not have pushed the
		# timer back to the full reload time. 0.6 s had already gone, so a reset
		# would leave roughly 1.2 s instead of roughly 0.6 s.
		_check(left_at_restart < _EXPECTED_RELOAD_TIME - 0.2,
			"the refused restart did not push the timer back to the full reload time",
			"(%.3f s left after the restart attempt at 0.6 s, expected under %.2f s)" % [
				left_at_restart, _EXPECTED_RELOAD_TIME - 0.2])
		_check(log.reload_started == 1, "still exactly one reload was started",
			"(got %d)" % log.reload_started)
		_check(log.fired == 1,
			"not one round came out of the reload, held or not",
			"(got %d shots)" % log.fired)
		_check(pistol.current_mag() == _EXPECTED_MAGAZINE,
			"the reload refilled the magazine", "(got %d)" % pistol.current_mag())
	world.free()


## The rate limit is in seconds and comes from the weapon data, so it is
## measured in seconds. A limit counted in frames would move with the frame
## rate, and 120 rpm has to stay 120 rpm on a 240 Hz display.
func _test_fire_rate() -> void:
	print("-- rate limit: the interval is the data's 0.5 s, counted in seconds")
	var world := _new_world()
	var pistol := await _new_pistol(world, _data, _new_muzzle(world))
	var log := _watch(pistol)

	_check(is_equal_approx(_data.seconds_between_shots(), _EXPECTED_INTERVAL),
		"precondition: the shipped data asks for one shot per 0.5 s",
		"(got %.4f s)" % _data.seconds_between_shots())
	var start := _now_ms()
	_check(pistol.try_fire(), "the first shot is allowed")
	_check(not pistol.try_fire(),
		"a second shot in the same frame is refused by the interval")
	_check(log.fired == 1, "only one round left the magazine", "(got %d)" % log.fired)
	_check(pistol.current_mag() == _EXPECTED_MAGAZINE - 1,
		"the refused second shot cost no round", "(got %d)" % pistol.current_mag())

	var frames := 0
	var second := false
	for i in 6000:
		await process_frame
		frames += 1
		if pistol.try_fire():
			second = true
			break
	var elapsed := float(_now_ms() - start) / 1000.0
	print("    second shot after %.3f s and %d process frames" % [elapsed, frames])
	_check(second, "the next shot is allowed once the interval has passed")
	_check(elapsed >= _EXPECTED_INTERVAL - _TIMER_EPSILON,
		"the second shot waited at least the full interval",
		"(waited %.3f s, want >= %.2f s)" % [elapsed, _EXPECTED_INTERVAL - _TIMER_EPSILON])
	_check(elapsed <= _EXPECTED_INTERVAL + _TIMER_TOLERANCE,
		"and did not wait much longer than the interval",
		"(waited %.3f s, want <= %.2f s)" % [
			elapsed, _EXPECTED_INTERVAL + _TIMER_TOLERANCE])
	_check(log.fired == 2, "exactly two rounds left the magazine",
		"(got %d)" % log.fired)
	world.free()


## The fire action must not be a way around the input gate: with the cursor
## free the same held input has to do nothing at all, and opening the gate has
## to be the only thing that changes.
func _test_input_gate() -> void:
	print("-- input gate: the fire action does not get around the cursor being free")
	var world := _new_world()
	var pistol := await _new_pistol(world, _data, _new_muzzle(world))
	var log := _watch(pistol)
	_check(pistol.get_script() == _PistolProbe,
		"precondition: the pistol under test runs the harness probe script")

	pistol.gate_mouse_mode = Input.MOUSE_MODE_VISIBLE
	_check(not pistol.can_fire(), "can_fire() is false while the cursor is free")
	_check(not pistol.try_fire(), "try_fire() refuses while the cursor is free")
	# Released first, and seen released: with the gate shut the pistol must be
	# refusing for the gate's reason alone, not because the arming latch never
	# fired. That is the whole point of pinning the two rules apart.
	await _settle_fire_released()
	Input.action_press("fire")
	var gated_shot := await _await_until(func() -> bool: return log.fired > 0, 1.5)
	_check(not gated_shot, "a held fire action shoots nothing while the cursor is free",
		"(got %d)" % log.fired)
	_check(pistol.current_mag() == _EXPECTED_MAGAZINE,
		"the gated pistol kept every round", "(got %d)" % pistol.current_mag())
	_check(log.magazine.is_empty(),
		"and announced nothing to a HUD either", "(got %s)" % str(log.magazine))
	Input.action_release("fire")

	pistol.gate_mouse_mode = Input.MOUSE_MODE_CAPTURED
	_check(pistol.can_fire(), "can_fire() is true again once the cursor is captured")
	Input.action_press("fire")
	var opened := await _await_until(func() -> bool: return log.fired > 0, 2.0)
	_check(opened, "the same held input fires as soon as the gate opens",
		"(got %d shots)" % log.fired)
	# The gate opened halfway through a second interval; holding the button must
	# not turn that into a shot.
	var burst := await _await_until(func() -> bool: return log.fired > 1, 0.2)
	_check(not burst, "holding fire still does not shoot past the rate limit",
		"(got %d shots)" % log.fired)
	Input.action_release("fire")
	_check(pistol.current_mag() == _EXPECTED_MAGAZINE - 1,
		"exactly one round was spent by the ungated press", "(got %d)" % pistol.current_mag())
	world.free()


## Reloading a full magazine would announce a reload that ends with the magazine
## unchanged, and it would be a player's way to start a reload while holding the
## button down for no reason.
func _test_full_magazine_has_nothing_to_reload() -> void:
	print("-- full magazine: nothing to reload, and that is not a failure of the pistol")
	var world := _new_world()
	var pistol := await _new_pistol(world, _data, _new_muzzle(world))
	var log := _watch(pistol)
	_check(not pistol.start_reload(), "a full magazine refuses the reload")
	_check(log.reload_started == 0, "no reload was announced",
		"(got %d)" % log.reload_started)
	_check(not pistol.is_reloading(), "and the pistol is not reloading")
	_check(pistol.current_mag() == _EXPECTED_MAGAZINE, "the magazine is untouched",
		"(got %d)" % pistol.current_mag())
	_check(pistol.try_fire(), "a round comes out as usual")
	_check(pistol.start_reload(), "and now the reload is accepted")
	world.free()


## The Phase 4 contract, asserted before anything calls it. A half-full magazine
## that survives a trip to the lobby hands the player free rounds every time.
func _test_scene_change_reset() -> void:
	print("-- scene change: the weapon is reset, so a lobby trip costs no rounds")
	var world := _new_world()
	var pistol := await _new_pistol(world, _data, _new_muzzle(world))
	var log := _watch(pistol)

	pistol.try_fire()
	pistol.start_reload()
	_check(pistol.current_mag() == _EXPECTED_MAGAZINE - 1,
		"precondition: the magazine is partly spent", "(got %d)" % pistol.current_mag())
	_check(pistol.is_reloading(), "precondition: a reload is in progress")

	pistol.reset_for_scene_change()
	_check(pistol.current_mag() == _EXPECTED_MAGAZINE,
		"the magazine is full again after a scene change",
		"(got %d)" % pistol.current_mag())
	_check(not pistol.is_reloading(), "the reload is cancelled")
	_check(pistol.can_fire(), "the pistol can shoot again")
	_check(log.last_magazine() == Vector2i(10, 10),
		"the reset is announced, so a HUD is not left showing a stale count",
		"(got %s)" % str(log.magazine))
	_check(log.reload_finished == 0,
		"a cancelled reload never claims to have finished", "(got %d)" % log.reload_finished)
	# The rate limit is cleared too: a scene change is not a continuation of the
	# previous one's shot.
	_check(pistol.try_fire(), "the first shot of the new scene is not rate limited")
	world.free()


## A resource edited into a degenerate state must be refused, not obeyed.
func _test_invalid_data_blocks_firing() -> void:
	print("-- degenerate data: a zero magazine size blocks firing instead of dividing by zero")
	var world := _new_world()
	var muzzle := _new_muzzle(world)

	var stock := await _new_pistol(world, _data, muzzle)
	_check(stock.can_fire(),
		"precondition: the shipped data lets the pistol fire, so the refusals below mean something")

	var zero_mag := WeaponData.new()
	zero_mag.magazine_size = 0
	var pistol := await _new_pistol(world, zero_mag, muzzle)
	var log := _watch(pistol)
	_check(pistol.current_mag() == 0,
		"a zero-capacity magazine starts empty", "(got %d)" % pistol.current_mag())
	_check(not pistol.can_fire(), "can_fire() is false for a zero magazine size")
	_check(not pistol.try_fire(), "try_fire() refuses to shoot with a zero magazine size")
	_check(not pistol.start_reload(), "and there is nothing to reload either")
	_check(log.fired == 0, "nothing fired", "(got %d)" % log.fired)
	_check(pistol.current_mag() == 0, "and no round was invented", "(got %d)" % pistol.current_mag())

	var zero_rate := WeaponData.new()
	zero_rate.rounds_per_minute = 0.0
	var rate_pistol := await _new_pistol(world, zero_rate, muzzle)
	_check(not rate_pistol.can_fire(),
		"a zero fire rate is refused rather than dividing by zero")
	world.free()


## The order inside try_fire() is load-bearing: check, then instantiate, then
## decrement. A pistol that decremented first would eat a round for a shot that
## never happened -- and pistol.tscn without a projectile scene, or one pointing
## at a scene whose root cannot be launched, is exactly that situation.
func _test_missing_projectile_scene_keeps_the_round() -> void:
	print("-- failed instantiation: the round survives the shot that never happened")
	var world := _new_world()
	var pistol := await _new_pistol(world, _data, _new_muzzle(world), false)
	var log := _watch(pistol)
	_check(pistol.projectile_scene == null,
		"precondition: this pistol has no projectile scene at all")
	_check(pistol.can_fire(), "precondition: it is otherwise ready to shoot")
	_check(not pistol.try_fire(), "a pistol with no projectile scene cannot shoot")
	_check(pistol.current_mag() == _EXPECTED_MAGAZINE,
		"the round is still in the magazine: instantiate first, decrement after",
		"(got %d of %d)" % [pistol.current_mag(), _EXPECTED_MAGAZINE])
	_check(log.fired == 0, "a shot that never happened announced nothing",
		"(got %d)" % log.fired)
	_check(log.magazine.is_empty(), "and the magazine never changed",
		"(got %s)" % str(log.magazine))
	world.free()

---

## tests/enemies.gd — Muzzle wiring assert context
1433: 	print("-- ствол пистолета в тире: снаряд стартует из Muzzle, а не из камеры")
1434: 	# pistol.gd читает точку старта снаряда из узла Muzzle. Нет узла — и
1439: 	var muzzle_marker := pistol.get_node_or_null("Muzzle") as Node3D if pistol != null else null
1440: 	_check(muzzle_marker != null,
1441: 		"у Pistol в тире есть узел Muzzle — точка старта снаряда",
1443: 			else "у Pistol нет узла Muzzle"))

---

## Task SHOOT report (full)
# Task SHOOT — отчёт

Задача: SHOOT-1 (снаряд вылетает из камеры + траектория гнётся при повороте камеры)
и SHOOT-2 (выстрел на старте без ввода).

Статус: **DONE**. Полный набор проверок: **9 passed / 0 failed / 3 skipped**.

---

## 1. Реализация

### 1.1 SHOOT-1 — две точки вместо одной, плюс отвязка трансформа

**`pistol.tscn`** — добавлен `Muzzle` типа `Marker3D`, ребёнок корня Pistol, позиция
`(0, 0, -0.18)`. Рамка пистолета — `BoxMesh(0.05, 0.09, 0.3)` по центру корня, то есть
по Z она занимает `-0.15 … +0.15`; `-0.18` — чуть за дульной кромкой. Обоснование
продублировано в `pistol.gd` возле `_spawn_point()`, потому что в `.tscn` комментарии
не пишутся.

**`scripts/pistol.gd`, разделение `_muzzle()` / `_spawn_point()`:**

- `_muzzle()` — осталась как была и отвечает только за ПРИЦЕЛИВАНИЕ: `fire_rate_source` →
  камера вьюпорта → `self`. Направление по-прежнему `-muzzle.global_transform.basis.z`,
  читается один раз в момент выстрела. Смещение ~5.7° (доворот пистолета в `player.tscn:40`)
  НЕ вводилось — это осознанное игровое решение, а не баг.
- `_spawn_point()` — новая, отвечает за ТОЧКУ СТАРТА: `get_node_or_null("Muzzle")` →
  фолбэк `_muzzle()` (тот же самый, он же упирается в `self`, поэтому отдельной ветки `self`
  не нужно — это был бы мёртвый код). `push_warning` по конвенции проекта
  (`enemy_contact.gd:126`) выходит **только** при `fire_rate_source == null`: в этом случае
  цепочка действительно приводит в камеру, и подмена видна игроку; в харнессах, где источник
  задан, маркер не нужен и сообщение было бы шумом на каждый выстрел.

**`_instantiate_projectile()` — порядок строго такой:**

```
var muzzle := _muzzle()                                   # родитель + направление
var spawn := _spawn_point()                               # точка старта
var direction := -muzzle.global_transform.basis.z         # читается один раз
muzzle.add_child(projectile)                              # родитель НЕ меняется
projectile.set_as_top_level(true)                         # отвязка трансформа — это и есть фикс
projectile.global_position = spawn.global_position         # абсолютная позиция ПОСЛЕ отвязки
projectile.call("launch", direction)
```

`add_child` оставлен как был: снаряд остаётся ребёнком прицела, поэтому `queue_free()`,
списки снарядов и хелпер `_live_projectiles(muzzle)` в тестах продолжают работать.
`set_as_top_level(true)` меняет только трансформ, не родителя.

Механизм (русский «почему»-комментарий в коде): у `Node3D` мировой трансформ =
`global(родителя) * local`, поэтому запись `global_position` у привязанной ноды лишь
пересчитывает `local.origin`; между тиками мировая позиция снаряда едет вместе с
родителем, а `Projectile._physics_process()` (`projectile.gd:88`,
`global_position += _direction * (speed * delta)`) каждый тик закрепляет себе накопленную
погрешность. `top_level` делает трансформ снаряда его собственным.

`projectile.gd` не трогал — он корректен.

### 1.2 SHOOT-2 — защёлка взведения

- `var _armed := false` рядом с остальным состоянием.
- `_process()`, пункт 3: `if not _armed: if not fire_held: _armed = true`, иначе (взведён и
  кнопка зажата) `try_fire()`. Уровневое поведение «удержание = стрельба» после взведения
  не меняется — темп по-прежнему `_cooldown`, а не edge.
- `reset_for_scene_change()` сбрасывает `_armed = false`: переход сцена→сцена не наследует
  залипшую кнопку.
- Почему: `player.gd::_ready()` захватывает мышь раньше первого `_process` пистолета,
  перезарядка и темп стартуют с нуля, поэтому остаточный бит ЛКМ на кадре 0 без взведения —
  это бесплатный выстрел, который игрок не нажимал.

Edge-only фикс (`is_action_just_pressed`) сознательно **не** применялся: он сломал бы
закреплённое поведение удержания (`tests/weapon.gd`, сцена «input gate» и «ten rounds»).

### 1.3 Прочее

- Шапка `pistol.gd`: список решений расширен с шести до восьми (пункты 7 и 8).
- Комментарий `_muzzle()` переименован из «Откуда стрелять» в «Откуда ЦЕЛИТЬСЯ» — после
  разделения ролей старое имя вводило бы в заблуждение.

---

## 2. TDD: RED → GREEN

### 2.1 Baseline (до работы)

```
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 weapon
  weapon_data    PASS
  weapon         PASS
  RESULT: 2 passed, 0 failed, 0 skipped

powershell ... run_checks.ps1 projectile   -> RESULT: 1 passed, 0 failed, 0 skipped
powershell ... run_checks.ps1 enemies      -> RESULT: 1 passed, 0 failed, 0 skipped
```

### 2.2 RED (`tests/weapon.gd` + `tests/enemies.gd`, до фикса)

```
weapon    FAIL  (exit code 1)
  -- trajectory: the shot keeps its line when the aim source's parent moves
    [FAIL] the shot flew straight: moving the aim source's parent did not bend it
           (worst sideways drift 2.0000 m, tolerance 0.050 m)
  -- start point: the shot leaves the barrel, aimed by the camera
    [FAIL] pistol.tscn carries a Muzzle marker: the barrel is a place, not a guess
    [FAIL] and it sits in front of the pistol, not inside the grip (got no Muzzle)
  -- startup: a fire button already down when the pistol enters the tree is not a shot
    [FAIL] a weapon that entered the tree with fire held does not shoot
           (got 1 shots, magazine 9 of 10)
    [FAIL] and it kept every round (got 9)
  === RESULT: 145 checks, 5 failed ===

enemies   FAIL  (exit code 1)
  -- ствол пистолета в тире: снаряд стартует из Muzzle, а не из камеры
    [FAIL] у Pistol в тире есть узел Muzzle — точка старта снаряда (got у Pistol нет узла Muzzle)
  === RESULT: 160 checks, 1 failed ===
```

### 2.3 GREEN (после фикса)

```
powershell ... run_checks.ps1 weapon      -> RESULT: 2 passed, 0 failed, 0 skipped
powershell ... run_checks.ps1 projectile  -> RESULT: 1 passed, 0 failed, 0 skipped
powershell ... run_checks.ps1 enemies     -> RESULT: 1 passed, 0 failed, 0 skipped
powershell ... run_checks.ps1             -> RESULT: 9 passed, 0 failed, 3 skipped
```

Пин `can_fire() == false / fire_rate_source == null` (бывшие строки 337-343, теперь
`_test_contracts`), проверка направления «-Z источника» (`_test_shot_follows_fire_source`,
`_test_single_shot`), `_live_projectiles()` и held-button сценарии — все зелёные, ничего не
ослаблено.

Единственное `push_warning` в выводе `weapon` — намеренное: это фолбэк-ветка нового теста
(пистолет без маркера `Muzzle` при `fire_rate_source == null`), которая своим existence
доказывает, что сообщение на этой конфигурации действительно появляется.

---

## 3. Мутационные доказательства

Хеши считались через `Get-FileHash -Algorithm SHA256`. До/после каждой мутации файл
восстанавливался и сверялся побайтово.

| # | Что сломано | Фильтр | Падающий именованный ассерт | SHA-256 до == после | Восстановлено |
|---|---|---|---|---|---|
| (a) | `projectile.set_as_top_level(true)` → `(false)` | `weapon` | `the shot flew straight: moving the aim source's parent did not bend it (worst sideways drift 1.7643 m, tolerance 0.050 m)` | `DFBD46C6…15D` | да, зелено |
| (b) | `_spawn_point()` принудительно `return _muzzle()` | `weapon` | `the shot starts at the barrel, not at the camera (bullet at (0.0, 1.7, 0.0), barrel at (0.0, 0.0, -0.18), eye at (0.0, 1.7, 0.0))` + `and visibly not out of the eye the player is looking through (0.000 m from the eye)` | `DFBD46C6…15D` | да, зелено |
| (c) | защёлка снята (`if fire_held: try_fire()`) | `weapon` | `a weapon that entered the tree with fire held does not shoot (got 1 shots, magazine 9 of 10)` + `and it kept every round (got 9)` | `DFBD46C6…15D` | да, зелено |
| (d) | узел `Muzzle` удалён из `pistol.tscn` | `enemies` | `у Pistol в тире есть узел Muzzle — точка старта снаряда (got у Pistol нет узла Muzzle)` | `C2847699…3EC` | да, зелено |

Полные хеши:

```
scripts/pistol.gd   DFBD46C6212F16BADD797CFC2979FA72DAB55E9D08B262D721384E2A1D64115D   (a, b, c — до == после)
pistol.tscn         C284769990E9D1CAC905A408951417A787EFCACBB0657C862C824D2A45F3D3EC   (d — до == после)
```

Замечание по (d): мутация задевает и `weapon` — там краснеют
`pistol.tscn carries a Muzzle marker: the barrel is a place, not a guess` и
`and it sits in front of the pistol, not inside the grip`. Это ожидаемо и правильно: обе
проверки читают одну и ту же сцену. Фолбэк-ветка (`a pistol without a barrel marker still
fires`) осталась зелёной, то есть пересечения с поведенческим фиксом нет.

Замечание по изоляции мутаций: (a) убивает только траекторию, (b) — только старт из ствола,
(c) — только сценарий со стартом, (d) — только проводку сцены. Каждая регрессия ловит свой
дефект и не ловит чужие.

---

## 4. Изменённые файлы

| Файл | Изменение |
|---|---|
| `scripts/pistol.gd` | +76 / −9: `_spawn_point()`, `set_as_top_level` + запись позиции, защёлка `_armed`, сброс в `reset_for_scene_change()`, шапка и комментарии |
| `pistol.tscn` | +4 / −1: узел `Muzzle` (`Marker3D`, `(0, 0, -0.18)`) |
| `tests/weapon.gd` | +291 / −2: три новых теста, четыре хелпера/константы, адаптация трёх существующих сценариев |
| `tests/enemies.gd` | +11: один ассерт проводки `pistol.get_node_or_null("Muzzle")` в `_test_range_scene_wiring` |

Не трогались: `player.gd`, `player.tscn`, `scripts/projectile.gd`,
`scripts/enemy_contact.gd`, `scripts/range_scene.gd`, `scripts/hurtbox.gd`,
`project.godot`, `tools/run_checks.ps1`. Git-мутаций не выполнялось (коммит сделал владелец,
`7a4b13d`).

---

## 5. Новые проверки

### `_test_shot_keeps_its_line_when_the_aim_source_moves` (SHOOT-1, траектория)

Мир `World → Pivot(Node3D) → AimSource(Node3D)`, прицел = `AimSource`, пистолет —
`fire_rate_source = aim`. Выстрел идёт через настоящий ввод (`action_press`), чтобы
проверялся тот же путь, что и в игре. Стартовая позиция и направление снимаются до
движения мира; затем `pivot.rotation.y = 45°`, `pivot.position = (2, 0, 0)`; далее 60
физических тиков с примером позиции каждый тик.

Метрика — расстояние от **прямой**, а не от начала: снаряд и должен лететь вдоль
направления, поэтому дрейфом считается только боковая составляющая
`(offset - line * offset.dot(line)).length()`. Допуск 0.05 м: баг даёт 1.76-2.00 м, а шум
float32 на 20 м — порядка 2e-6 м, четыре порядка запаса.

Дополнительно пиннится `bullet.get_parent() == aim` — «родитель не изменился, менялась
только привязка трансформа».

### `_test_shot_starts_at_the_barrel` (SHOOT-1, старт + проводка)

Пистолет собирается из **настоящей `pistol.tscn`**: сцена инстанцируется, её дети
переносятся в `_PistolProbe` (probe нужен, чтобы подсунуть гейту явный mouse mode —
headless не может захватить курсор). Так маркер под проверкой — тот, который игра
реально грузит, а не тот, который харнесс придумал для себя.

Проверяется: маркер есть; он впереди пистолета (`z < -0.1`); пуля стартует в маркере, а не
в камере, и находится дальше 0.1 м от глаза; направление по-прежнему от камеры
(`dot > 0.99`) — то есть разделение «старт» / «прицел» не превратилось в «стреляем из
ствола по оси ствола». `fire_rate_source` оставлен пустым — ровно как в `player.tscn`.

Фолбэк-ветка проверяется явно: пистолет без маркера при `fire_rate_source == null` всё
равно стреляет и стартует из камеры. Без этой проверки «нет маркера» могло бы когда-нибудь
превратиться в тихий отказ стрелять.

### `_test_no_shot_while_the_button_is_down_on_entry` (SHOOT-2)

`Input.action_press("fire")` **до** создания пистолета (кнопка зажата на входе в дерево).
Пистолет строится прямо в тесте, а не через `_new_pistol()`, и лог подписывается **до**
`add_child`: `_new_pistol()` ждёт кадры, и выстрел, потраченный в это ожидание, не оставил
бы следа в логе — проверка стала бы зелёной ровно по неверной причине (это случилось в
первом прогоне RED, когда ассерт про «не стреляет» был зелёным при магазине 9 — поправлено).

Дальше: 1 с реальных кадров с зажатой кнопкой → `log.fired == 0` и полный магазин; затем
release → кадр → press → `log.fired == 1` и минус один патрон. Проверка гейта открыта
(`gate_mouse_mode == MOUSE_MODE_CAPTURED` как предусловие), иначе headless-гейт закрыл бы
тест и он был бы зелёным не по той причине.

### Пин проводки в `tests/enemies.gd`

Один ассерт в секции «Проводка сцены», сразу после блока игрока:
`pistol.get_node_or_null("Muzzle") != null`. Тир грузится через `load()`/`instantiate()`
как в игре, поэтому отсутствие маркера видно здесь, а не игроку в бою.

---

## 6. Адаптации существующих харнессов

Одна по сути, применённая в трёх местах: **`await _settle_fire_released()` перед первым
`action_press("fire")`**. Хелпер делает `Input.action_release("fire")` и ждёт два
`process_frame`, чтобы пистолет гарантированно **увидел** отпускание (`process_frame`
приходит в начале кадра, до вызовов `_process`, поэтому одного ожидания мало).

Затронуты:

- `_test_empty_magazine_and_automatic_reload` — первое в наборе нажатие, до него отпускания
  не было ни разу; без адаптации защёлка не дала бы выстрелить вовсе;
- `_test_reload_blocks_firing_and_cannot_be_restarted` — свежий пистолет в сцене;
- `_test_input_gate` — свежий пистолет; без отпускания, наблюдаемого pistol'ом, проверка
  «гейт держит выстрел» могла бы проходить из-за невзведённого оружия, а не из-за гейта.

Это **не ослабление** проверок: ассерты не тронуты, у каждого добавлен явный
`release + кадр` перед нажатием. Ослабило бы их как раз обратное — оставить нажатие без
предшествующего отпускания, тогда тест проверял бы не ввод.

---

## 7. Self-review

- **YAGNI.** Отдельной ветки `return self` в `_spawn_point()` нет: `_muzzle()` уже упирается
  в `self`, третья строка фолбэка была бы недостижимым кодом. Публичного геттера `_armed`
  нет — логика проверяется поведением. `fire_held` — локальная переменная вместо двух
  вызовов `Input.is_action_pressed()`, читается дважды, так что это не YAGNI, а
  читаемость.
- **Мёртвого кода нет.** Единственный «лишний» артефакт — намеренный `push_warning`,
  у которого есть наблюдаемая ветка (фолбэк-тест в `weapon`).
- **Честность комментариев.** Русские «почему»-комментарии в `pistol.gd` объясняют
  механизм (произведение трансформов родителя, почему позиция ставится после отвязки,
  почему родитель менять нельзя), а не пересказывают код. Комментарий к `_muzzle()`
  переименован вместе с ролью — иначе он врал бы.
- **Ничего лишнего не добавлено в смежные файлы.** Единственная правка в `tests/enemies.gd` —
  один ассерт, как и требовал бриф.
- **Соответствие брифу.** Порядок в `_instantiate_projectile()`, родитель снаряда,
  предупреждение только при `fire_rate_source == null`, позиция маркера `(0, 0, -0.18)`,
  сброс `_armed` в `reset_for_scene_change()` — всё по брифу. Отступления: для теста
  траектории выстрел идёт через настоящий ввод (как и предлагал бриф), а для проверок
  старта — через `try_fire()`, потому что там нужна синхронность: после `action_press`
  к моменту чтения позиции прошёл бы кадр, и ассерт «стартует в стволе» мерил бы не старт.

## 8. Concerns

1. **Первый RED был частично обманчив** — ассерт «не стреляет» проходил, потому что лог
   подписывался после выстрела. Исправлено (пистолет строится вручную, лог подключается
   до `add_child`) и перепроверено: без защёлки краснеет именно он.
2. **`push_warning` на боевой конфигурации без ствола** — это осознанный компромисс: сообщение
   полезно игроку, но в headless-проверках, создающих пистолет без маркера и без
   `fire_rate_source`, оно будет в stderr на каждый выстрел. Сейчас таких харнессов ровно
   один (наша фолбэк-ветка), и это его и доказывает. Если появятся другие — предупреждение
   надо будет сузить.
3. **`_armed` живёт до первого наблюдаемого отпускания.** Пока игрок ни разу не отпустил
   кнопку (удерживает ЛКМ с момента входа в игру), пистолет не стреляет. Это ровно то
   поведение, которое чинит SHOOT-2, но стоит держать в голове: если когда-нибудь появится
   сцена, где ввод огня задаётся программно (`Input.action_press` из кода) без
   предшествующего `action_release`, она перестанет стрелять.
4. **Траектория теперь не «прилипает» к камере — и это меняет попадания по движущимся
   целям в тире.** Это правильное поведение (попадание определяется геометрией, а не
   наводкой камеры назад), но численные результаты тира сдвинутся. Проверки зелёные, тем не
   менее владельцу стоит знать.
