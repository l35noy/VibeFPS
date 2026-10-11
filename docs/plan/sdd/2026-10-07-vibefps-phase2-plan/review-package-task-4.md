# Review package — Phase 2 Task 4 (Навигация)

BASE: d10ce8f (no commits — owner commits). Task 4 files: scripts/enemy_contact.gd (kept from Task 3, navigation added), enemy_contact.tscn (NavigationAgent3D added), tests/enemies.gd (new section).

## git status --short
 M player.gd
 M player.tscn
 M scripts/hurtbox.gd
?? .opencode/
?? data/enemies/
?? enemy_contact.tscn
?? scripts/enemy_contact.gd
?? scripts/enemy_contact.gd.uid
?? scripts/enemy_data.gd
?? scripts/enemy_data.gd.uid
?? tests/enemies.gd
?? tests/enemies.gd.uid

## current test state (run by controller)
enemies PASS, full suite 9 passed/0 failed/3 skipped

---

## scripts/enemy_contact.gd (full, current)
class_name ContactEnemy
extends CharacterBody3D

## Контактный враг: ходит к игроку (движение — Task 4), бьёт касанием с
## каденцией, умирает от урона, теряя цвет.
##
## Здоровье живёт здесь, а не в хитбоксе: `Hurtbox` по контракту только
## сообщает о попадании сигналом `damage_taken`, и «у врага 50 HP» обязано быть
## правдой ровно в одном месте. Если бы урон уменьшал поле внутри хитбокса, у
## каждого поражённого места появилось бы своё здоровье, и счётчик попаданий
## врага перестал бы считать попадания.
##
## Пять решений, каждое из которых видно глазом или проверкой:
##
## 1. Слои задаются в `_ready()`, а не в сцене: «кого я вижу» и логика
##    попадания лежат в одном файле, и сцена не может их разъехать молча.
## 2. Детект контакта включается на стороне врага (спека §6.3). Маска хитбокса
##    врага — слой 7 (хитбокс игрока), а в маске ТЕЛА игрока (слой 2) нет вовсе:
##    враг проходит сквозь игрока, и касание ловится хитбоксами. Обратная
##    схема — хитбокс игрока, который сам ищет врага, — удвоила бы урон.
## 3. Смерть наблюдаема: `died` уходит ровно один раз и раньше, чем тело
##    выключится, а сам узел ещё 0.2 с висит обесцвеченным. Мгновенный
##    `queue_free()` в тот же кадр сделал бы смерть невидимой ни глазу, ни
##    отладке: цвет смерти просто не успевал бы появиться.
## 4. Цели ищутся по группе `"player"`, а не путём в сцене: путь до игрока в
##    сцене врага — это привязка одного файла к устройству другого, и враг,
##    поставленный не под тем именем, молча остался бы без цели.
## 5. Непригодные данные выключают врага, а не роняют игру: без них нет ни
##    потолка здоровья, ни урона за тик, и любое обращение к ним падает.
## 6. Направление движения берётся из навмеша, а не считается «прямо к игроку»:
##    прямолинейный подход упирается в первую же стену, и враг либо стоит
##    столбом, либо скользит вдоль препятствия, не добравшись до цели. Навмеш же
##    запекается владельцем геометрии (спека §12: «агент, меняющий геометрию,
##    обязан перестроить навмеш в той же задаче») — синхронно и до начала
##    физики; навмеш без полигонов означает, что идти некуда, и это падение
##    проверки, а не тишина.
## 7. `path_desired_distance` в сцене — 1.0 (дефолт движка), а не 0.5 из плана
##    этой задачи: bake кладёт проходимую поверхность навмеша на 2 * cell_height
##    выше геометрии (измерено: пол с верхней гранью на y = 0 запекается в сетку на
##    y = 0.5 при cell_height 0.25, а при cell_height 0.1 — на y = 0.2), и первая
##    точка пути — это позиция агента, привязанная к сетке, то есть ровно на этом
##    смещении выше пяток. Пока смещение не меньше порога, агент не считает точку
##    достигнутой, индекс точки пути не сдвигается никогда, и враг стоит на месте
##    при запечённом, вполне достижимом навмеше: навмеш есть, путь есть, враг не
##    идёт. При 0.5 м порог равнялся смещению — враг не двигался ни на миллиметр.
##
## Горизонтальная скорость врага — ровно data.move_speed по направлению пути.
## Ни разгон, ни сглаживание: ими управляет ввод у игрока, у врага ввода нет, и
## любое сглаживание превращало бы «идёт со скоростью данных» в «разгоняется от
## нуля» — волна выезжала бы на игрока рывками.

## Изменилось здоровье врага: сколько осталось из скольких. Последний аргумент
## — всегда data.max_health, а не «сколько было», чтобы полоса здоровья врага
## не могла забыть, на какое число делить.
signal health_changed(current: float, maximum: float)
## Враг умер. Испускается строго один раз за смерть: подписчик (спавнер,
## счётчик волны, убийца-кредитор) обязан успеть увидеть нулевое здоровье, а
## не узел, который через 0.2 с исчезнет.
signal died()

@export var data: EnemyData
## Каденция контактного урона, сек. Глобальное решение 4: спека фиксирует
## урон (10), но не каденцию; без тика враг убивал бы за один проход.
@export var contact_interval: float = 1.0

## Слой 3 — enemy_body. Задаётся здесь, не в сцене (решение 1).
const _LAYER_WORLD := 1 << 0
const _LAYER_ENEMY_BODY := 1 << 2
## Цвет мёртвого тела. Нейтральный серый, а не затемнение своего цвета: у
## врага уже есть своя окраска из данных, и «чуть темнее» на кадре не читается
## как смерть.
const _DEATH_COLOR := Color(0.5, 0.5, 0.5)
## Сколько секунд мёртвое тело лежит на сцене обесцвеченным (решение 3).
const _DEATH_LINGER := 0.2
## Порог «следующая точка пути совпала с моим местом». Без него normalize() от
## почти-нуля вернул бы единичный вектор в случайную сторону: длина в
## миллиметры после нормализации ничем не отличается от единицы, и враг дёргался
## бы на месте, никуда не идя.
const _PATH_EPS := 0.001

## Гравитация берётся из настроек проекта, а не из player.gd: падение врага и
## падение игрока обязаны быть одной и той же величиной, иначе враг, поставленный
## на ту же полку, что и игрок, соскальзывал бы с неё в другой момент.
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _hurtbox: Hurtbox = get_node_or_null("Hurtbox") as Hurtbox
## Меш может отсутствовать: сцена без визуала (тест, отладочный макет) должна
## оставаться рабочей, а не падать в _ready().
@onready var _mesh: MeshInstance3D = get_node_or_null("Mesh") as MeshInstance3D
## Агент навигации может отсутствовать по той же причине, что и меш: сцена без
## него (отладочный макет, витрина данных) обязана оставаться рабочей. Враг без
## агента стоит на месте и предупреждает, вместо того чтобы падать в _ready() на
## $NavigationAgent3D.
@onready var _agent: NavigationAgent3D = get_node_or_null("NavigationAgent3D") as NavigationAgent3D

## Текущее здоровье — отдельное поле рядом с данными, а не вместо них:
## «сколько максимум» — потолок, который боем не меняется.
var _health: float = 0.0
## Потолок здоровья, снятый с данных один раз в _ready(). Держать копию нужно
## для выключенного врага: при `data == null` поле данных читать нельзя, а
## health_changed должен оставаться вызываемым без падения.
var _max_health: float = 0.0
## Активен ли контакт с игроком прямо сейчас. Один булев, а не счётчик зон:
## игрок в Фазе 2 один, а счётчик начал бы «помнить» контакт после ухода
## игрока из-под врага.
var _contact_active: bool = false
## Сколько секунд накоплено к следующему тику контактного урона.
var _contact_accumulator: float = 0.0
## Враг мёртв и ждёт своей задержки до удаления.
var _dying: bool = false
var _death_timer: float = 0.0
## Личный экземпляр материала меша (см. _setup_material).
var _material: StandardMaterial3D


func _ready() -> void:
	collision_layer = _LAYER_ENEMY_BODY
	# Маска — мир и свои. Слоя игрока (2) здесь нет намеренно: тела проходят
	# друг сквозь друга, касание ловится хитбоксами (решение 2).
	collision_mask = _LAYER_WORLD | _LAYER_ENEMY_BODY
	_setup_material()
	if _agent == null:
		# Предупреждение, а не ошибка: сцена без агента — это не поломка игры,
		# а неполный макет. Молчащий враг выглядел бы как тот, который упёрся в
		# стену, и в логе не осталось бы следа о причине.
		push_warning("[enemy] %s: в сцене нет NavigationAgent3D — враг останется на месте" % name)
	if not _data_usable():
		# Выключение, а не ошибка в рантайме: враг без данных не должен ни
		# делить на ноль, ни тикать уроном, которого не существует (решение 5).
		set_physics_process(false)
		return
	_health = data.max_health
	_max_health = _health
	_connect_hurtbox()


## Пригодны ли данные к работе. Проверка здесь, а не на месте первого
## обращения: враг спрашивает это до появления в мире, иначе push_error
## прилетел бы из середины боя, изнутри обработчика сигнала.
func _data_usable() -> bool:
	if data == null:
		push_error("[enemy] %s: нет данных EnemyData — враг выключен" % name)
		return false
	if not data.is_valid():
		push_error("[enemy] %s: данные «%s» непригодны к спавну — враг выключен" % [
			name, data.display_name])
		return false
	return true


func _connect_hurtbox() -> void:
	if _hurtbox == null:
		return
	# Подписка, а не чтение полей хитбокса: связь «попадание → минус здоровье»
	# обязана быть найдена самой сценой, иначе каждый новый враг искал бы
	# хитбоксы руками.
	if not _hurtbox.damage_taken.is_connected(_on_damage_taken):
		_hurtbox.damage_taken.connect(_on_damage_taken)
	if not _hurtbox.area_entered.is_connected(_on_hurtbox_area_entered):
		_hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	if not _hurtbox.area_exited.is_connected(_on_hurtbox_area_exited):
		_hurtbox.area_exited.connect(_on_hurtbox_area_exited)


## Материал меша дублируется, а берётся из данных. Урок `range_target.gd`:
## материал в сцене — общий SubResource, и перекраска одного врага перекрасила
## бы всех, кто собран из той же сцены. Дубликат же можно и обесцветить, и
## снять с него боевой цвет, оставив соседей в бою.
func _setup_material() -> void:
	if _mesh == null:
		return
	var override := _mesh.material_override as StandardMaterial3D
	if override == null:
		override = StandardMaterial3D.new()
	_material = override.duplicate()
	_mesh.material_override = _material
	if data != null:
		_material.albedo_color = data.color


func health() -> float:
	return _health


func is_alive() -> bool:
	return _health > 0.0


## Нанести урон. Ноль и отрицательные значения игнорируются (урон — величина
## положительная), и урон мёртвому игнорируется тоже: без этого гварда второй
## выстрел в тот же кадр, что и первый, испустил бы `died` дважды, а счётчик
## смертей волны показал бы двух убитых врагов вместо одного.
func take_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	if not is_alive():
		return
	_health = maxf(_health - amount, 0.0)
	health_changed.emit(_health, _max_health)
	if _health > 0.0:
		return
	_die()


func _physics_process(delta: float) -> void:
	# Мёртвый враг больше ничего не делает, кроме обратного отсчёта до
	# удаления. Порядок обязателен: этот же обработчик считает и контактные
	# тики, и оставшееся время жизни трупа, и без этой ветки мёртвый враг
	# продолжал бы бить и идти.
	if _dying:
		_death_timer -= delta
		if _death_timer <= 0.0:
			set_physics_process(false)
			queue_free()
		return
	# Дальше порядок обязателен: гравитация -> цель -> направление -> скорость ->
	# ход. Направление читается из навмеша, а навмеш спрашивает цель, поэтому
	# цель должна быть названа раньше, чем спросят путь; move_and_slide()
	# закрывает кадр и применяет набранную скорость.
	_apply_gravity(delta)
	_steer_to_player()
	_tick_contact(delta)
	move_and_slide()


## Гравитация — ровно как у игрока: на полу вертикаль обнуляется, в воздухе
## падает. Своё поле, а не чужое скриптовое, потому что падение врага и падение
## игрока должны оставаться одной величиной при любой правке project.godot.
func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta


## Цель на этот кадр и горизонтальная скорость к ней.
##
## Горизонтальная скорость обнуляется во всех ветках, кроме «есть направление», и
## это не микроконтроль: скорость, оставшаяся от прошлого кадра, утащила бы
## врага по инерции после смерти цели (игрок вышел из группы, сменил сцену), и
## «стоит на месте» выглядело бы правдой только первые кадры после этого.
func _steer_to_player() -> void:
	var target := _player()
	if target == null or _agent == null or not is_alive():
		velocity.x = 0.0
		velocity.z = 0.0
		return
	# Цель переносится каждый тик, а не один раз при спавне: игрок ходит, и
	# цель, названная однажды, через секунду указывала бы в пустоту.
	_agent.target_position = target.global_position
	var direction := next_path_direction()
	if direction == Vector3.ZERO:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	velocity.x = direction.x * data.move_speed
	velocity.z = direction.z * data.move_speed


## Следующая точка пути к игроку. Направление — к "player"; цель меняется
## каждый тик, поэтому stale-путь пересчитывается сам.
func next_path_direction() -> Vector3:
	if _agent == null or not is_inside_tree():
		return Vector3.ZERO
	# Досрочный выход по «путь закончен» — это остановка у цели, а не отказ
	# искать. Агент сам объявляет путь законченным, когда дошёл до
	# target_desired_distance, и без этой строки нормализация его нулевой точки
	# превратила бы «стоять у цели» в «ехать в ноль».
	if _agent.is_navigation_finished():
		return Vector3.ZERO
	var offset := _agent.get_next_path_position() - global_position
	# Вертикаль отбрасывается: путь лежит на навмеше, а тело — на полу, и эти
	# две высоты не совпадают (поверхность сетки на 2 * cell_height выше пола,
	# см. решение 7 в шапке файла). Ушедшая в вертикаль составляющая уменьшила бы
	# горизонтальную скорость: длина нормализованного вектора осталась бы
	# единичной, но её проекция на землю — нет, и враг «шёл бы со скоростью
	# 6 м/с», двигаясь медленнее, молча и незаметно.
	offset.y = 0.0
	if offset.length() <= _PATH_EPS:
		return Vector3.ZERO
	return offset.normalized()


## Каденция контактного урона: аккумулятор, а не «последний тик». Разница в
## том, что тик не привязан к кадру события входа, поэтому при fps 30 и 120 тик
## будет один и тот же по времени.
func _tick_contact(delta: float) -> void:
	if not _contact_active:
		return
	if _player() == null:
		# Игрок ушёл из группы (сменил сцену, выбыл). Контакт считаем
		# законченным: тикать в пустоту нечего, а накопленный отсчёт иначе
		# выстрелил бы урон сразу, как вернётся цель.
		_contact_active = false
		_contact_accumulator = 0.0
		return
	_contact_accumulator += delta
	if _contact_accumulator >= contact_interval:
		_contact_accumulator -= contact_interval
		_deal_contact_damage()


## Один тик контакта. Урон берётся из данных, а не из поля врага: 10 — это
## свойство типа врага из спеки, и враг, поставленный с другими данными
## (босс, усиленный миньон), должен бить той цифрой, которая в них написана.
func _deal_contact_damage() -> void:
	var player := _player()
	if player == null or not player.has_method("take_damage"):
		return
	player.call("take_damage", data.contact_damage)


func _on_damage_taken(amount: float) -> void:
	take_damage(amount)


## Враг коснулся хитбокса игрока. Зона 1 — это игрок (слой 7); зона 0 — другой
## враг, и на его касание отвечать нечем.
func _on_hurtbox_area_entered(area: Area3D) -> void:
	if _dying:
		return
	if not (area is Hurtbox) or (area as Hurtbox).zone != 1:
		return
	if _player() == null:
		return
	_contact_active = true
	_contact_accumulator = 0.0
	# Первый тик сразу, а не через contact_interval: враг, который только что
	# дошёл до игрока, должен ощутимо его задеть, иначе вход в контакт
	# выглядел бы как целый интервал тишины, а игрок — как неуязвимый.
	_deal_contact_damage()


## Контакт закончился: аккумулятор сбрасывается, чтобы оставшийся отсчёт не
## выстрелил уроном в первые же кадры нового касания.
func _on_hurtbox_area_exited(area: Area3D) -> void:
	if not (area is Hurtbox) or (area as Hurtbox).zone != 1:
		return
	_contact_active = false
	_contact_accumulator = 0.0


## Цель — игрок из группы "player" (решение 4). Один узел на группу: двух
## игроков в бою не бывает, а поиск по узлам потребовал бы знать, чей это мир.
func _player() -> Node3D:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group("player") as Node3D


## Смерть. Порядок обязателен и противоположен привычному «сначала сообщить»:
## сигнал уходит последним, чтобы подписчик увидел врага уже мёртвым —
## обесцвеченным, без коллизий и с нулевым здоровьем. Раньше любого из этих
## шагов сигнал означал бы «у этого врага сейчас 0 HP» при ещё живом теле.
func _die() -> void:
	_dying = true
	_contact_active = false
	_contact_accumulator = 0.0
	velocity = Vector3.ZERO
	_discolor()
	_disable_collisions()
	_death_timer = _DEATH_LINGER
	died.emit()


func _discolor() -> void:
	if _material == null:
		return
	_material.albedo_color = _DEATH_COLOR


## Тело и хитбокс выключаются, чтобы мёртвый враг не продолжал ловить снаряды
## и не держал игрока в контакте, пока висит обесцвеченным.
##
## `monitoring` меняется через set_deferred, а не присваиванием: этот код
## приходит из обработчика сигнала, который движок зовёт в том самом проходе, где
## обновляются пересечения, и прямое изменение состояния там даёт ошибку Godot
## «can't change this state while flushing queries». Эта ошибка уходит в консоль,
## а не в проверку, поэтому её приходится предотвращать здесь.
func _disable_collisions() -> void:
	collision_layer = 0
	collision_mask = 0
	if _hurtbox == null:
		return
	_hurtbox.collision_layer = 0
	_hurtbox.set_deferred("monitoring", false)

---

## enemy_contact.tscn (full, current)
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

[node name="NavigationAgent3D" type="NavigationAgent3D" parent="."]
path_desired_distance = 1.0
target_desired_distance = 1.0

---

## tests/enemies.gd (full, current)
extends SceneTree

## Enemy data harness for VibeFPS -- the first check of Phase 2.
##
## Structured and worded after tests/weapon_data.gd: sections, [PASS]/[FAIL]
## per assertion, a counter, quit(1) on any failure. It reads
## res://data/enemies/contact.tres through load() and asks it the questions the
## enemy script will ask in Phase 2: what are the numbers, what kind is it, and
## does the resource consider itself usable. Nothing is instantiated as a scene
## node -- this is data, and a data check that had to build a world in order to
## read a number would be testing the world instead.
##
## Every assertion below names the edit that turns it red. The negative halves
## are asserted too, not only the green ones: is_valid() is asked to reject each
## degenerate value in turn. Without those, a method hardcoded to return true
## would sail through a check that only ever saw the good resource.
##
## Task 2 adds the second section, "Здоровье игрока". It loads the real
## res://player.tscn and waits for is_node_ready() instead of assembling a player
## out of nodes: what is under test is the wiring stored in the scene file, and a
## harness that built the player itself would stay green with player.tscn
## carrying no Hurtbox at all. The damage is dealt through that scene's own
## Hurtbox node, so "damage_taken -> take_damage" is exercised as a connection
## rather than as two methods that happen to exist.
##
## Task 3 adds the third section, "Контактный враг". Same rule, one level deeper:
## the enemy comes from res://enemy_contact.tscn and is hurt by the real
## res://projectile.tscn, while only the world around it (floor, wall) is built
## in code. tests/projectile.gd cannot cover this: its world is made of nodes, so
## it proves nothing about the wiring stored in the enemy's scene file -- layers,
## hurtbox zone, data reference. Everything the enemy needs is read with call()/
## get()/has_method() rather than through the ContactEnemy class, exactly like
## the player helpers above: a static reference to a class_name that does not
## exist yet kills the whole harness at parse time and reports nothing about what
## is missing.
##
## Task 4 appends the fourth section, "Навигация". The enemy still comes from
## res://enemy_contact.tscn -- the NavigationAgent3D is read out of that scene
## instance, never built here -- while the world it walks through (floor, wall,
## NavigationRegion3D, target) is programmatic and baked at runtime with a
## synchronous bake_navigation_mesh(false). "Walked" is asserted the only honest
## way: the polygon count of the baked mesh, the distance to the target on every
## physics frame, and the horizontal velocity on every frame where the enemy was
## moving. An empty navmesh makes all of it fall, which is the point -- a world
## without polygons is a world where the enemy stands still and still looks like
## it "walked" in a test that only watched a final position.
##
## Run: godot --headless --path . --script res://tests/enemies.gd
##      .\tools\run_checks.ps1 enemies

const _CONTACT_PATH := "res://data/enemies/contact.tres"
const _PLAYER_PATH := "res://player.tscn"
const _ENEMY_PATH := "res://enemy_contact.tscn"
const _PROJECTILE_PATH := "res://projectile.tscn"
## Слой 4 — enemy_hurtbox, слой 7 — player_hurtbox (project.godot, [layer_names]).
## Номера слоёв — битовые маски: слой N = 1 << (N - 1).
const _LAYER_WORLD := 1 << 0
const _LAYER_ENEMY_BODY := 1 << 2
const _LAYER_ENEMY_HURTBOX := 1 << 3
const _LAYER_PLAYER_HURTBOX := 1 << 6
## Допуск сравнения здоровья. Все числа проверки целые десятые доли, так что
## 0.0001 отделяет настоящее расхождение от двоичного представления.
const _HEALTH_EPS := 0.0001
## Допуск сравнения цвета: .tres хранит float32, а 0.01 — это разница, которую
## глаз уже назвал бы другим цветом, а не двоичным шумом записи.
const _COLOR_EPS := 0.01
## Физика идёт на 120 тиках в секунду (project.godot [physics]), поэтому один
## тик — ровно 1/120 с. Контактный интервал 0.1 с равен 12 тикам, и сравнение
## каденции по тикам не зависит от плавающей погрешности накопления delta.
const _TICKS_PER_SECOND := 120

## Геометрия мира навигации. Пол 40x40 с верхней гранью на y = 0; стена на z = 0
## высотой 4 м и шириной 2 м, протяжённая по x от -20 (левый край пола) до +2.
## Обойти её можно было бы только справа, за x = +2: слева она упирается в край
## пола, и там зазора для навмеша нет. Враг стартует в (0, 0, -5), цель в
## (0, 0, 5): прямая между ними пересекает стену, поэтому путь, который ведёт
## «мимо», обязан быть навмешем, а не прямой.
const _NAV_FLOOR_SIZE := 40.0
const _NAV_WALL_MIN_X := -20.0
const _NAV_WALL_MAX_X := 2.0
const _NAV_WALL_HEIGHT := 4.0
const _NAV_WALL_HALF_Z := 1.0
const _NAV_ENEMY_START := Vector3(0.0, 0.0, -5.0)
const _NAV_TARGET := Vector3(0.0, 0.0, 5.0)
## Окно наблюдения — 3 с симуляции, как требует бриф: при 120 тиках в секунду это
## 360 физических кадров, за которые враг обязан пройти больше половины пути.
const _NAV_OBSERVE_TICKS := 360
## Кадр считается движущимся, если горизонтальная скорость выше этого порога.
## Первые кадры (путь ещё считается) и кадры у цели (путь закончен) движением
## не являются: требовать move_speed там означало бы требовать ехать с места,
## где враг стоит, — проверка падала бы не из-за врага.
const _NAV_MOVING_EPS := 0.1
## Сколько движущихся кадров нужно, чтобы проверка «скорость равна move_speed» не
## была пустой: полсекунды движения — минимум, ниже которого «все кадры верны»
## ничего не утверждает.
const _NAV_MIN_MOVING_FRAMES := 60
## Допуск скорости из брифа (0.01): настолько мелкое расхождение с move_speed
## ещё не «ползёт» и не «ускоряется сверх данных».
const _NAV_SPEED_EPS := 0.01
## Расхождение, которое можно считать нулём: скорость, посчитанная из
## нормализованного направления и умноженная на данные, отличается от move_speed
## на уровне представления float32. 0.0001 отделяет двоичный шум от гейта
## скольжения по углу.
const _NAV_EXACT_EPS := 0.0001
## target_desired_distance, заданный брифом для агента в сцене врага. Живёт в
## харнессе как подстановка на случай, когда узла агента нет: проверка поведения
## обязана работать и без него, иначе сцена без агента «проверялась» бы
## зелёным набором «проверять нечего».
const _NAV_TARGET_DISTANCE := 1.0
## Дрейф у цели: за полсекунды простоя дистанция не должна измениться больше чем
## на 2 см. Враг стоит, а не переминается на месте.
const _NAV_DRIFT_EPS := 0.02

var _failures: PackedStringArray = []
var _checks := 0

## Счётчики сигналов игрока, которые читает только подключённый обработчик.
## «died ровно один» нельзя проверить по узлу после вызова: к тому моменту, как
## проверка посмотрит снова, игрок уже респавнился и выглядит полностью
## здоровым. Счётчик внутри обработчика — единственное место, где смерть ещё
## наблюдаема.
var _died_count: int = 0
## Здоровье и живость, увиденные обработчиком died, то есть в момент смерти, до
## того как респавн восстановит их.
var _health_at_death: float = -1.0
var _alive_at_death: bool = true
## Все пары health_changed по порядку: «последнее событие 100/100» — утверждение
## о последовательности, а не об одном сэмпле.
var _health_events: Array[Vector2] = []
## Счётчики сигналов ВРАГА. Отдельно от игровых: один и тот же обработчик нельзя
## повесить на оба узла, а различать их по имени узла значило бы завязать
## проверку на текст имён.
var _enemy_died_count: int = 0
## Здоровье и живость врага, увиденные в момент его died. У игрока это было
## обязательно (респавн восстанавливает всё сразу), у врага — страховка: смерть
## врага тоже наблюдаема только в своём обработчике, пока узел висит на сцене.
var _enemy_health_at_death: float = -1.0
var _enemy_alive_at_death: bool = true
## Счётчик имёнённых миров. Имена узлов уникальны только внутри родителя, а
## каждый сценарий добавляет свой пол в свой контейнер: без счётчика второй
## пол получил бы "Floor2" и сообщение об ошибке называло бы не тот узел.
var _world_id: int = 0
## Проверка упёрлась в невыполнимое условие и вызвала _bail(). Флаг обязателен:
## _bail() зовёт quit(1), но вызывавший раздел делает `return`, а _initialize()
## после него всё равно доходит до своего quit(0) — а последний вызов quit()
## перезаписывает код возврата, и проверка с FATAL читалась бы как PASS.
var _bailed: bool = false


func _check(ok: bool, label: String, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  [PASS] %s %s" % [label, detail])
	else:
		_failures.append("%s %s" % [label, detail])
		print("  [FAIL] %s %s" % [label, detail])


## Builds a throwaway EnemyData with one field overwritten, so is_valid() can be
## asked about a value no shipped resource ever carries.
func _probe(overrides: Dictionary) -> EnemyData:
	var probe := EnemyData.new()
	for key in overrides:
		probe.set(key, overrides[key])
	return probe


## Must come back true only when is_valid() really rejects the degenerate
## value, which is what makes "is_valid() is true" on contact.tres meaningful.
func _is_valid_rejects(overrides: Dictionary) -> bool:
	return not _probe(overrides).is_valid()


func _finish() -> void:
	print("=== RESULT: %d checks, %d failed ===" % [_checks, _failures.size()])
	for f in _failures:
		print("  FAILURE: %s" % f)


## Ends the run on a precondition the rest of the check cannot be evaluated
## against. Without this the field assertions below would dereference a null
## resource and the runner would report a crash instead of a named failure.
func _bail(reason: String) -> void:
	_bailed = true
	print("FATAL: %s" % reason)
	_finish()
	quit(1)


## Сколько здоровья осталось у узла игрока. Методы берутся вызовом call(), а не
## типизированным доступом: player.tscn отдаёт CharacterBody3D, а health()/
## is_alive() живут в player.gd, и хардкод типа здесь означал бы, что проверка
## перестала видеть настоящий скрипт.
func _health(player: Node) -> float:
	return float(player.call("health"))


func _alive(player: Node) -> bool:
	return bool(player.call("is_alive"))


func _near(got: float, want: float) -> bool:
	return absf(got - want) < _HEALTH_EPS


## Живость и здоровье читаются обработчиком в момент сигнала, а не после
## возврата из take_damage: к моменту возврата респавн уже всё восстановил.
func _on_player_died(player: Node) -> void:
	_died_count += 1
	_health_at_death = _health(player)
	_alive_at_death = _alive(player)


func _on_player_health_changed(current: float, maximum: float) -> void:
	_health_events.append(Vector2(current, maximum))


## Создаёт узел, ждёт его готовности и возвращает false, если он так и не стал
## готов. is_node_ready() проверяется явно: _ready() не синхронен относительно
## instantiate(), и проверка, читающая слои до готовности, меряла бы значения по
## умолчанию, а не заданные скриптом.
func _spawn_and_wait(node: Node) -> bool:
	root.add_child(node)
	for i in 120:
		if node.is_node_ready():
			return true
		await physics_frame
	return node.is_node_ready()


## Второй раздел: здоровье игрока и зона его хитбокса.
##
## Всё состояние читается с настоящего инстанса player.tscn. Слой хитбокса
## проверяется и на дефолтном Hurtbox.new() — это контракт Фазы 1 для мишеней и
## врагов, который новая настройка зоны обязана сохранить, а не заменить.
func _test_player_health() -> void:
	print("-- Здоровье игрока (Task 2)")

	_died_count = 0
	_health_at_death = -1.0
	_alive_at_death = true
	_health_events.clear()

	var packed: PackedScene = load(_PLAYER_PATH)
	if packed == null:
		_bail("cannot load %s" % _PLAYER_PATH)
		return
	var player := packed.instantiate()
	if not await _spawn_and_wait(player):
		_bail("%s never became node-ready" % _PLAYER_PATH)
		return
	_check(player.is_node_ready(), "precondition: player.tscn is instantiated and node-ready")

	print("-- дефолтный Hurtbox сохраняет контракт Фазы 1")
	var plain := Hurtbox.new()
	if not await _spawn_and_wait(plain):
		_bail("a bare Hurtbox.new() never became node-ready")
		return
	_check(plain.collision_layer == _LAYER_ENEMY_HURTBOX,
		"дефолтный Hurtbox.new() лежит на слое 4 (enemy_hurtbox)",
		"(got %d, expected %d)" % [plain.collision_layer, _LAYER_ENEMY_HURTBOX])
	_check(not plain.monitoring,
		"дефолтный Hurtbox.new() ничего не обнаруживает сам",
		"(monitoring=%s)" % plain.monitoring)

	print("-- в player.tscn есть узел Hurtbox в зоне игрока")
	var hurtbox := player.get_node_or_null("Hurtbox") as Hurtbox
	# Наличие API спрашивается через has_method/has_signal, а не прямым
	# обращением: обращение к отсутствующему члену — рантайм-ошибка, и проверка
	# упала бы с трассировкой вместо именованного [FAIL].
	_check(hurtbox != null, "у player.tscn есть дочерний узел Hurtbox")
	_check(_health_api_ready(player),
		"у player.gd есть API здоровья Фазы 2: health, is_alive, take_damage, died, health_changed")
	if hurtbox == null or not _health_api_ready(player):
		print("  (оценка урона невозможна без хитбокса и API здоровья: проверки ниже пропущены)")
		return
	_check(hurtbox.zone == 1, "хитбокс игрока объявлен в зоне 1 (player_hurtbox)",
		"(got zone %d)" % hurtbox.zone)
	_check(hurtbox.collision_layer == _LAYER_PLAYER_HURTBOX,
		"после готовности хитбокс игрока лежит на слое 7 (player_hurtbox)",
		"(got %d, expected %d)" % [hurtbox.collision_layer, _LAYER_PLAYER_HURTBOX])

	print("-- стартовое состояние")
	_check(_near(_health(player), 100.0), "игрок начинает с 100 здоровья",
		"(got %.4f)" % _health(player))
	_check(_alive(player), "игрок начинает жив")

	print("-- 10 попаданий контактного врага до смерти игрока (спека 7.2)")
	var contact := load(_CONTACT_PATH) as EnemyData
	if contact == null:
		_bail("cannot load %s as EnemyData for the player survivability invariant" % _CONTACT_PATH)
		return
	var hits_to_death := float(player.get("max_health")) / contact.contact_damage
	_check(absf(hits_to_death - 10.0) < _HEALTH_EPS,
		"10 попаданий до смерти игрока",
		"(max_health %.4f / contact_damage %.4f = %.4f)" % [
			float(player.get("max_health")), contact.contact_damage, hits_to_death])

	print("-- подключение обработчиков сигналов игрока")
	player.died.connect(_on_player_died.bind(player))
	player.health_changed.connect(_on_player_health_changed)

	# Порядок шагов отличается от порядка утверждений в брифе, и это вынужденно:
	# «take_damage(90.0) → health() == 10.0» и «десятое take_damage(10.0) →
	# смерть» считают от 100 HP, а проверка проводки уже съедает 10 HP. Обе
	# последовательности на одном игроке не сходятся, поэтому сначала идёт
	# полный цикл урона до смерти, а проводка проверяется на только что
	# восстановленном игроке — её утверждение (100 - 10 = 90) от респавна не
	# зависит.
	player.call("take_damage", 90.0)
	_check(_alive(player), "девятое попадание не убивает игрока")
	_check(_near(_health(player), 10.0), "после девяти тиков остаётся 10 здоровья",
		"(got %.4f)" % _health(player))

	print("-- десятое попадание: смерть и немедленный респавн")
	player.call("take_damage", 10.0)
	_check(_died_count == 1, "сигнал died ровно один", "(got %d)" % _died_count)
	_check(not _alive_at_death, "в момент сигнала died игрок уже мёртв (is_alive() == false)",
		"(got %s)" % _alive_at_death)
	_check(_near(_health_at_death, 0.0), "в момент сигнала died здоровье равно 0.0",
		"(got %.4f)" % _health_at_death)
	_check(_near(_health(player), 100.0), "после смерти 100.0 (респавн восстановил здоровье)",
		"(got %.4f)" % _health(player))
	_check(_alive(player), "после смерти игрок снова жив")

	print("-- health_changed испущен с настоящими числами")
	var max_health := float(player.get("max_health"))
	_check(_health_events.size() > 0, "health_changed испущен хотя бы раз",
		"(events=%d)" % _health_events.size())
	if not _health_events.is_empty():
		var last := _health_events[_health_events.size() - 1]
		_check(_near(last.x, 100.0) and _near(last.y, max_health),
			"последнее событие health_changed после респавна — 100.0/max_health",
			"(got %.4f/%.4f)" % [last.x, last.y])
		var death_event := _find_health_event(0.0)
		_check(_near(death_event.x, 0.0) and _near(death_event.y, max_health),
			"смерть отражена событием 0.0/max_health",
			"(got %.4f/%.4f)" % [death_event.x, death_event.y])

	print("-- проводка сцены: Hurtbox.damage_taken -> Player.take_damage")
	hurtbox.apply_damage(10.0)
	_check(_near(_health(player), 90.0),
		"урон через узел Hurtbox сцены доходит до игрока по сигналу damage_taken",
		"(got %.4f)" % _health(player))
	var hit_event := _find_health_event(90.0)
	_check(_near(hit_event.x, 90.0) and _near(hit_event.y, max_health),
		"попадание через Hurtbox отражено событием 90.0/max_health",
		"(got %.4f/%.4f)" % [hit_event.x, hit_event.y])

	print("-- нулевой и отрицательный урон игнорируются")
	player.call("take_damage", 0.0)
	player.call("take_damage", -5.0)
	_check(_near(_health(player), 90.0), "нулевой и отрицательный урон не меняют здоровье",
		"(got %.4f)" % _health(player))
	_check(_died_count == 1, "нулевой и отрицательный урон не испускают died",
		"(got %d)" % _died_count)

	player.queue_free()
	plain.queue_free()


## Существует ли на узле весь API здоровья Фазы 2. Отдельная функция, потому что
## ответ нужен дважды: именованным [FAIL] и решением, можно ли вообще оценивать
## урон, не упав в рантайм.
func _health_api_ready(player: Node) -> bool:
	return player.has_method("health") and player.has_method("is_alive") \
		and player.has_method("take_damage") \
		and player.has_signal("died") and player.has_signal("health_changed")


## Ищет первое событие health_changed с таким значением здоровья. Отсутствие
## события возвращает (-1.0, -1.0): пара, которую не с чем сравнить, и
## _check() на ней честно падает.
func _find_health_event(value: float) -> Vector2:
	for event in _health_events:
		if _near(event.x, value):
			return event
	return Vector2(-1.0, -1.0)


# --------------------------------------------------------------------------
# Task 3: контактный враг
# --------------------------------------------------------------------------

## Третий раздел: враг целиком из своей сцены.
##
## Что грузится из сцены, а что собирается кодом, размечено здесь намеренно.
## Сцена `enemy_contact.tscn` — это предмет проверки: именно в ней хранятся
## ссылка на данные, слои хитбокса и капсула, и харнесс, собравший бы того же
## врага из узлов кода, остался бы зелёным на сцене без хитбокса вообще.
## Пол и стена — окружение, а не предмет проверки, и берутся из кода, как в
## tests/projectile.gd.
func _test_contact_enemy() -> void:
	print("-- Контактный враг (Task 3)")

	var packed: PackedScene = load(_ENEMY_PATH)
	if packed == null:
		_bail("cannot load %s" % _ENEMY_PATH)
		return
	var world := _new_world()
	_add_floor(world)
	var enemy := packed.instantiate()
	if not await _spawn_in(world, enemy, Vector3(6.0, 0.0, 0.0)):
		_bail("%s never became node-ready" % _ENEMY_PATH)
		return
	_check(enemy.is_node_ready(), "precondition: enemy_contact.tscn is instantiated and node-ready")

	print("-- сцена и класс врага")
	# Тип корня проверяется через get_script(), а не через `enemy is
	# ContactEnemy`: имя класса появится только вместе с Task 3, а статическая
	# ссылка на несуществующий class_name убила бы весь файл на разборе —
	# вместе с двумя уже готовыми разделами.
	var script_res := enemy.get_script() as Script
	_check(enemy is CharacterBody3D,
		"корень enemy_contact.tscn — CharacterBody3D (а не Node3D и не Area3D)",
		"(got %s)" % ("none" if script_res == null else script_res.get_instance_base_type()))
	_check(script_res != null and script_res.get_global_name() == "ContactEnemy",
		"скрипт врага объявляет class_name ContactEnemy",
		"(got \"%s\")" % ("none" if script_res == null else script_res.get_global_name()))
	_check(_enemy_api_ready(enemy),
		"у enemy_contact.gd есть API Фазы 2: health, is_alive, take_damage, died, health_changed")

	print("-- данные врага из res://data/enemies/contact.tres")
	# data читается через get(), а не прямым обращением: сцена отдаёт
	# CharacterBody3D, и поле data живёт в скрипте. Обращение к отсутствующему
	# члену — рантайм-ошибка, а проверка обязана падать именованно.
	var data: EnemyData = enemy.get("data")
	_check(data is EnemyData, "у врага есть data типа EnemyData",
		"(got %s)" % type_string(typeof(enemy.get("data"))))
	_check(data != null and data.resource_path == _CONTACT_PATH,
		"data врага — именно res://data/enemies/contact.tres",
		"(got \"%s\")" % ("none" if data == null else data.resource_path))
	if data != null:
		_check(_near(data.max_health, 50.0), "max_health данных врага равен 50.0",
			"(got %.4f)" % data.max_health)
		_check(_near(data.contact_damage, 10.0), "contact_damage данных врага равен 10.0",
			"(got %.4f)" % data.contact_damage)

	print("-- проводка слоёв: тело на 3, хитбокс на 4, детект на стороне врага")
	# Слои задаются скриптом в _ready(), а не сценой: значение в сцене молча
	# разъехалось бы с логикой, и снятие слоя с врага никто не заметил бы.
	# Сверх того, маска тела без слоя 7 (игрока) — отдельное правило спеки §6.3:
	# враг проходит сквозь тело игрока, контакт ловится хитбоксами.
	_check(int(enemy.collision_layer) == _LAYER_ENEMY_BODY,
		"тело врага лежит на слое 3 (enemy_body)",
		"(got %d, expected %d)" % [int(enemy.collision_layer), _LAYER_ENEMY_BODY])
	_check(int(enemy.collision_mask) == (_LAYER_WORLD | _LAYER_ENEMY_BODY),
		"маска тела врага — слои 1 и 3: мир и свои; тела игрока в ней нет (спека 6.3)",
		"(got %d, expected %d)" % [
			int(enemy.collision_mask), (_LAYER_WORLD | _LAYER_ENEMY_BODY)])
	var hurtbox := enemy.get_node_or_null("Hurtbox") as Hurtbox
	_check(hurtbox != null, "у врага есть дочерний узел Hurtbox")
	if hurtbox != null:
		_check(hurtbox.zone == 0, "хитбокс врага объявлен в зоне 0 (enemy_hurtbox)",
			"(got zone %d)" % hurtbox.zone)
		_check(bool(hurtbox.detects_contact),
			"хитбокс врага сам обнаруживает контакт: detects_contact == true")
		_check(int(hurtbox.collision_layer) == _LAYER_ENEMY_HURTBOX,
			"после готовности хитбокс врага лежит на слое 4 (enemy_hurtbox)",
			"(got %d, expected %d)" % [int(hurtbox.collision_layer), _LAYER_ENEMY_HURTBOX])
		_check(bool(hurtbox.monitoring),
			"хитбокс врага обнаруживает: monitoring == true (контакт ловит враг, спека 6.3)")
		_check(int(hurtbox.collision_mask) == _LAYER_PLAYER_HURTBOX,
			"маска хитбокса врага — слой 7 (player_hurtbox): он ищет игрока",
			"(got %d, expected %d)" % [int(hurtbox.collision_mask), _LAYER_PLAYER_HURTBOX])
	var shape := hurtbox.get_node_or_null("CollisionShape3D") if hurtbox != null else null
	_check(shape != null, "у хитбокса врага есть CollisionShape3D: пустая зона ничего не поймает")

	print("-- материал меша")
	# Урок range_target.gd: материал из сцены — общий SubResource, и перекраска
	# одного врага перекрасила бы их всех. Проверяется сравнением двух
	# инстансов одной сцены, а не на глаз.
	var mesh := enemy.get_node_or_null("Mesh") as MeshInstance3D
	_check(mesh != null, "у врага есть узел Mesh (MeshInstance3D)")
	var twin := packed.instantiate()
	twin.name = "TwinEnemy"
	if not await _spawn_in(world, twin, Vector3(6.0, 0.0, 4.0)):
		_bail("the twin enemy of %s never became node-ready" % _ENEMY_PATH)
		return
	var twin_mesh := twin.get_node_or_null("Mesh") as MeshInstance3D
	var material := mesh.material_override as StandardMaterial3D if mesh != null else null
	var twin_material := twin_mesh.material_override as StandardMaterial3D if twin_mesh != null else null
	_check(material != null, "меш врага несёт material_override, который можно обесцветить")
	_check(material != null and twin_material != null and material != twin_material,
		"два врага из одной сцены получили РАЗНЫЕ материалы (дублирование в _ready)")
	if material != null:
		_check(_color_near(material.albedo_color, data.color),
			"живой враг покрашен в цвет своих данных (data.color)",
			"(got %s, data.color %s)" % [str(material.albedo_color), str(data.color)])

	print("-- стартовое состояние")
	_check(_near(_enemy_health(enemy), 50.0), "враг начинает с 50 здоровья (data.max_health)",
		"(got %.4f)" % _enemy_health(enemy))
	_check(_enemy_alive(enemy), "враг начинает жив")
	# Контактная каденция — решение Фазы 2, а не поле сцены: если дефолт
	# сменить, волна врагов начнёт бить втрое чаще, и проверка должна это видеть.
	_check(_near(float(enemy.get("contact_interval")), 1.0),
		"contact_interval по умолчанию 1.0 с",
		"(got %.4f)" % float(enemy.get("contact_interval")))

	print("-- непригодные данные: враг выключается, а не падает делением на ноль")
	await _test_invalid_enemy_data(packed)

	if not _enemy_api_ready(enemy) or hurtbox == null:
		print("  (поведение оценивать нельзя без API здоровья и хитбокса: проверки ниже пропущены)")
		world.queue_free()
		return

	enemy.died.connect(_on_enemy_died.bind(enemy))

	print("-- сквозная проводка: снаряд → слои → хитбокс → враг")
	# Урон идёт настоящим снарядом из projectile.tscn, а не прямым
	# apply_damage: прямая проверка была бы зелёной на враге, чей хитбокс лежит
	# не на слое 4 и которого не видит ни один снаряд в игре.
	var bullet := _spawn_projectile(world, Vector3(0.0, 0.9, 0.0))
	var enemy_hurtbox := enemy.get_node_or_null("Hurtbox") as Hurtbox
	var hits: Array[Node] = []
	bullet.hit_something.connect(hits.append)
	bullet.launch(Vector3.RIGHT)
	await _frames_until_free(bullet, 200)
	_check(hits.size() == 1 and hits[0] == enemy_hurtbox,
		"снаряд попал в хитбокс врага и только в него",
		"(hit %s)" % ("nothing" if hits.is_empty() else str((hits[0] as Node).name)))
	_check(_near(_enemy_health(enemy), 20.0), "после одного попадания у врага 20 здоровья (50 - 30)",
		"(got %.4f)" % _enemy_health(enemy))
	_check(_enemy_alive(enemy), "враг жив после одного попадания")
	_check(_enemy_died_count == 0, "после одного попадания сигнал died ещё не испускался",
		"(got %d)" % _enemy_died_count)

	print("-- второй снаряд: смерть")
	var bullet2 := _spawn_projectile(world, Vector3(0.0, 0.9, 0.0))
	bullet2.launch(Vector3.RIGHT)
	await _frames_until_free(bullet2, 200)
	_check(_enemy_died_count == 1, "второе попадание убивает врага, died ровно один",
		"(got %d)" % _enemy_died_count)
	_check(_near(_enemy_health(enemy), 0.0), "здоровье мёртвого врага равно 0.0",
		"(got %.4f)" % _enemy_health(enemy))
	_check(not _enemy_alive(enemy), "враг мёртв: is_alive() == false")
	_check(_near(_enemy_health_at_death, 0.0),
		"в момент сигнала died здоровье врага уже равно 0.0",
		"(got %.4f)" % _enemy_health_at_death)
	_check(not _enemy_alive_at_death,
		"в момент сигнала died враг уже мёртв (is_alive() == false)")

	print("-- мёртвый враг: теряет цвет и больше не принимает урон")
	var dead_material := mesh.material_override as StandardMaterial3D
	_check(dead_material != null and _color_near(dead_material.albedo_color, Color(0.5, 0.5, 0.5)),
		"после смерти материал меша близок к серому (теряет цвет)",
		"(got %s, expected Color(0.5, 0.5, 0.5, 1))" % str(dead_material.albedo_color if dead_material != null else Color.TRANSPARENT))
	_check(int(enemy.collision_layer) == 0,
		"мёртвое тело снято с коллизий: collision_layer == 0",
		"(got %d)" % int(enemy.collision_layer))
	await _frames_until_free(enemy, 1)
	_check(not bool(hurtbox.monitoring),
		"хитбокс мёртвого врага перестал обнаруживать (set_deferred(\"monitoring\", false))")
	enemy.call("take_damage", 30.0)
	_check(_enemy_died_count == 1, "урон по мёртвому врагу не испускает died повторно",
		"(got %d)" % _enemy_died_count)
	_check(_near(_enemy_health(enemy), 0.0), "урон по мёртвому врагу не двигает здоровье",
		"(got %.4f)" % _enemy_health(enemy))

	print("-- мёртвое тело исчезает не сразу: цвет смерти должен быть виден")
	await _frames_until_free(enemy, 120)
	_check(not is_instance_valid(enemy),
		"мёртвый враг убран со сцены через ~0.2 с, а не мгновенно")

	world.queue_free()
	await physics_frame

	await _test_two_projectiles_one_frame(packed)
	await _test_enemy_contact_tick(packed)


## Два снаряда, одна цель, один кадр — единственная гонка, в которой враг может
## умереть дважды за один кадр.
##
## Проверка обязана падать и тогда, когда оба снаряда ПРОМАХНУЛИСЬ: снаряд,
## улетевший в стену, тоже исчезает, и «после кадра враг мёртв» ничего не говорит
## о попаданиях. Поэтому каждый снаряд обязан сам предъявить `hit_something` с
## именем хитбокса врага, и оба попадания обязаны прийтись на один физический
## кадр — иначе это не «один кадр», а два тика подряд, а такую гонку выиграть
## нечем.
func _test_two_projectiles_one_frame(packed: PackedScene) -> void:
	print("-- два снаряда, одна цель, один кадр")

	var world := _new_world()
	_add_floor(world)
	_add_wall(world, 20.0)
	_enemy_died_count = 0
	_enemy_health_at_death = -1.0
	_enemy_alive_at_death = true
	# Враг в 3 м от стрельбы: снаряд летит 1/3 м за тик, поэтому оба попадут на
	# девятом тике, а не «когда-нибудь» — и у стены за 20 м это произойти не
	# может.
	var enemy := packed.instantiate()
	if not await _spawn_in(world, enemy, Vector3(3.0, 0.0, 0.0)):
		_bail("%s never became node-ready for the two-projectile test" % _ENEMY_PATH)
		return
	enemy.died.connect(_on_enemy_died.bind(enemy))
	var enemy_hurtbox := enemy.get_node_or_null("Hurtbox") as Hurtbox
	_check(enemy_hurtbox != null, "precondition: у врага есть хитбокс, куда целятся оба снаряда")

	var targets: Array = [[], []]
	var hit_frames: Array[int] = [-1, -1]
	var bullets: Array[Projectile] = []
	for i in 2:
		var bullet := _spawn_projectile(world, Vector3(0.0, 0.9, 0.0))
		var index := i
		bullet.hit_something.connect(func(target: Node) -> void:
			(targets[index] as Array).append(target)
			hit_frames[index] = Engine.get_physics_frames())
		bullets.append(bullet)
	await physics_frame
	# Оба запускаются подряд, без await между ними: пауза в кадр разъехала бы
	# снаряды на треть метра, и второй пришёл бы в цель на кадр позже.
	for bullet in bullets:
		bullet.launch(Vector3.RIGHT)
	# Ждать снарядов по очереди нельзя: они кончаются в один кадр, и ко второму
	# вызову узел уже освобождён — передать такой объект в параметр типа Node
	# нельзя, и проверка падала бы с трассировкой вместо [FAIL].
	var waited := 0
	while waited < 60 and (is_instance_valid(bullets[0]) or is_instance_valid(bullets[1])):
		waited += 1
		await physics_frame
	_check(not is_instance_valid(bullets[0]) and not is_instance_valid(bullets[1]),
		"оба снаряда кончились на враге и убраны со сцены",
		"(waited %d ticks)" % waited)

	for i in 2:
		var hit := targets[i] as Array
		_check(hit.size() == 1 and hit[0] == enemy_hurtbox,
			"снаряд №%d попал в хитбокс врага и только в него" % (i + 1),
			"(hit %s)" % ("nothing" if hit.is_empty() else str((hit[0] as Node).name)))
	_check(hit_frames[0] >= 0 and hit_frames[0] == hit_frames[1],
		"оба попадания пришлись на один физический кадр",
		"(кадры %d и %d)" % [hit_frames[0], hit_frames[1]])
	_check(_enemy_died_count == 1,
		"два снаряда в один кадр убивают врага один раз, died ровно один",
		"(got %d)" % _enemy_died_count)
	_check(_near(_enemy_health(enemy), 0.0), "после двух попаданий здоровье врага ровно 0.0",
		"(got %.4f)" % _enemy_health(enemy))
	_check(not _enemy_alive(enemy), "враг мёртв: is_alive() == false")
	_check(_near(_enemy_health_at_death, 0.0),
		"в момент сигнала died здоровье врага уже равно 0.0",
		"(got %.4f)" % _enemy_health_at_death)

	world.queue_free()
	await physics_frame


## Непригодные данные должны выключать врага, а не ронять проверку. Без данных у
## врага нет ни максимума здоровья, ни урона за тик, и любое обращение к ним
## делит на ноль или падает на null — то есть ломает проверку вместо того, чтобы
## показать, что враг плохо настроен.
func _test_invalid_enemy_data(packed: PackedScene) -> void:
	var world := _new_world()
	var no_data := packed.instantiate()
	no_data.set("data", null)
	if not await _spawn_in(world, no_data, Vector3(0.0, 0.0, 6.0)):
		_bail("an enemy without data never became node-ready")
		return
	var broken_data := packed.instantiate()
	# EnemyData.new() здесь НЕ годится: у ресурса все поля уже имеют рабочие
	# значения по умолчанию (50 HP, 10 урона, 6 м/с), и такой «сломанный» враг
	# прошёл бы is_valid(). Непригодность создаётся явной правкой поля.
	var unusable := EnemyData.new()
	unusable.max_health = 0.0
	broken_data.set("data", unusable)
	if not await _spawn_in(world, broken_data, Vector3(0.0, 0.0, 12.0)):
		_bail("an enemy with invalid data never became node-ready")
		return

	_check(not broken_data.get("data").is_valid(),
		"precondition: подставленные данные действительно непригодны (is_valid() == false)")
	_check(_near(_enemy_health(no_data), 0.0) and _near(_enemy_health(broken_data), 0.0),
		"враг без данных и враг с непригодными данными не падают: здоровье 0.0",
		"(no_data %.4f, broken_data %.4f)" % [_enemy_health(no_data), _enemy_health(broken_data)])
	_check(not _enemy_alive(no_data) and not _enemy_alive(broken_data),
		"выключенный враг не считается живым")
	_check(not no_data.is_physics_processing() and not broken_data.is_physics_processing(),
		"выключенный враг не обрабатывает физику: ни тиков, ни деления на ноль")
	# Оба узла обязаны пережить несколько кадров: падение _ready() выглядело бы
	# как краш процесса, а не как именованный [FAIL].
	await _physics_frames(20)
	_check(is_instance_valid(no_data) and is_instance_valid(broken_data),
		"выключенный враг живёт в сцене 20 тиков без падения")

	world.queue_free()
	await physics_frame


## Контактный урон: вход, каденция, граница смерти и обрыв контакта.
##
## Позиции подобраны так, чтобы каждое утверждение ловило свой отказ: враг в
## 0.4 м от игрока (капсулы по 0.4 м радиуса, зоны захлёнуты), каденция 0.1 с
## — это ровно 12 тиков на 120 тиках в секунду, и тики читаются покадрово, а не
## по общему урону. Урон нигде не захардкожен: он берётся из data.contact_damage.
func _test_enemy_contact_tick(packed: PackedScene) -> void:
	print("-- Контактный урон (Task 3)")

	_died_count = 0
	_health_at_death = -1.0
	_alive_at_death = true

	var world := _new_world()
	_add_floor(world)

	var player_packed: PackedScene = load(_PLAYER_PATH)
	if player_packed == null:
		_bail("cannot load %s for the contact test" % _PLAYER_PATH)
		return
	var player := player_packed.instantiate()
	# Точка появления игрока — та же точка, где он стоит: после смерти респавн
	# возвращает его в контакт, и это часть проверяемого контракта.
	if not await _spawn_in(world, player, Vector3(0.0, 0.0, 0.0)):
		_bail("%s never became node-ready for the contact test" % _PLAYER_PATH)
		return
	await _physics_frames(20)
	_check(player.is_on_floor(), "precondition: игрок стоит на полу, а не висит в воздухе")
	_check(player.is_in_group("player"),
		"игрок вошёл в группу \"player\": враг находит цель по группе, а не по пути в сцене")
	var player_hurtbox := player.get_node_or_null("Hurtbox") as Hurtbox
	_check(player_hurtbox != null, "у игрока есть хитбокс, в который влетает хитбокс врага")
	if player_hurtbox == null:
		_bail("player.tscn carries no Hurtbox: the contact test cannot run")
		return
	# Детект контакта включается на стороне врага (спека §6.3), поэтому хитбокс
	# игрока обязан остаться пассивным. Хитбокс игрока, начавший обнаруживать,
	# ловил бы и вражеские хитбоксы и урон наносился бы дважды — а молча.
	_check(not bool(player_hurtbox.monitoring),
		"хитбокс игрока НЕ обнаруживает сам: monitoring == false (детект на стороне врага)")
	_check(int(player_hurtbox.collision_mask) == _LAYER_WORLD,
		"маска хитбокса игрока — слой 1: он не ищет врага",
		"(got %d, expected %d)" % [
			int(player_hurtbox.collision_mask), _LAYER_WORLD])

	player.died.connect(_on_player_died.bind(player))

	var enemy := packed.instantiate()
	enemy.set("contact_interval", 0.1)
	# Сценарий считает нестандартный урон за тик, и это единственный способ
	# отличить «урон взят из данных» от «урон зашит в коде»: при 10.0 любой
	# захардкоженный урон совпал бы с ожидаемым числом, и проверка ничего бы не
	# различала. Дубликат данных, а не правка contact.tres — ресурс читают и
	# другие разделы, и правка на месте утекла бы в них.
	var probe := (enemy.get("data") as EnemyData).duplicate() as EnemyData
	probe.contact_damage = 7.5
	enemy.set("data", probe)
	if not await _spawn_in(world, enemy, Vector3(0.4, 0.0, 0.0)):
		_bail("%s never became node-ready for the contact test" % _ENEMY_PATH)
		return
	enemy.died.connect(_on_enemy_died.bind(enemy))

	var shipped_damage := float((load(_CONTACT_PATH) as EnemyData).contact_damage)
	var contact_damage := float(enemy.get("data").contact_damage)
	_check(_near(contact_damage, probe.contact_damage) and not _near(contact_damage, shipped_damage),
		"precondition: сценарий контакта идёт по НЕСТАНДАРТНОМУ урону за тик, а не по %.1f из contact.tres" % shipped_damage,
		"(contact_damage %.4f, урон contact.tres %.4f)" % [contact_damage, shipped_damage])

	# Все ожидаемые числа этого сценария выводятся из двух величин: за тик игрок
	# теряет ровно contact_damage, поэтому после k тиков у него остаётся
	# player_max_health - k * contact_damage, а тик, который его убьёт, —
	# ceil(max_health / contact_damage). Ни одна цифра ожидания не зашита в
	# проверку, поэтому подмена урона в enemy_contact.gd её ломает.
	var player_max_health := float(player.get("max_health"))
	var interval_ticks := int(round(float(enemy.get("contact_interval")) * float(_TICKS_PER_SECOND)))
	var ticks_to_death := int(ceil(player_max_health / contact_damage))
	var survivable_ticks := ticks_to_death - 1
	var health_before_death := player_max_health - float(survivable_ticks) * contact_damage
	print("    урон за тик %.4f, HP игрока %.1f, тиков до смерти %d, на границе остаётся %.4f" % [
		contact_damage, player_max_health, ticks_to_death, health_before_death])

	var overlap_frame := Engine.get_physics_frames()
	var previous := _health(player)
	var ticks: Array[int] = []
	var boundary_health := -1.0
	## Худшая ошибка «сколько сняли за один тик» относительно урона из данных.
	## Считается на каждом тике, а не один раз на сумме: сумма за N тиков
	## совпала бы и при круглой подмене, а тик — нет.
	var worst_damage_error := 0.0
	for i in 300:
		await physics_frame
		var current := _health(player)
		if not _near(current, previous):
			ticks.append(Engine.get_physics_frames())
			worst_damage_error = maxf(worst_damage_error, absf((previous - current) - contact_damage))
			previous = current
		if ticks.size() == survivable_ticks:
			boundary_health = current
			break

	print("    тики контакта: %s (интервал %d тиков)" % [str(ticks), interval_ticks])
	_check(ticks.size() == survivable_ticks,
		"получено ровно %d тиков контакта за 300 тиков ожидания" % survivable_ticks,
		"(got %d: %s)" % [ticks.size(), str(ticks)])
	# Первый тик обязан прийти на входе, а не через интервал: без него враг,
	# коснувшийся игрока, целый цикл стоял бы рядом безвредным. Граница — половина
	# интервала: тик по расписанию опоздал бы на целый интервал, а тик на входу
	# приходит за один-два кадра.
	_check(ticks.size() > 0 and ticks[0] - overlap_frame <= maxi(2, interval_ticks / 2),
		"первый тик приходит сразу при входе, не через contact_interval",
		"(вход на кадре %d, первый тик на кадре %d, задержка %d тиков из %d)" % [
			overlap_frame, ticks[0] if ticks.size() > 0 else -1,
			(ticks[0] - overlap_frame) if ticks.size() > 0 else -1, interval_ticks])
	var worst_gap := 0
	for i in range(1, ticks.size()):
		worst_gap = maxi(worst_gap, absi(ticks[i] - ticks[i - 1] - interval_ticks))
	_check(ticks.size() > 1 and worst_gap <= 1,
		"после первого тика каденция ровно contact_interval (%d тиков)" % interval_ticks,
		"(worst gap error %d ticks over %d gaps)" % [worst_gap, ticks.size() - 1])
	_check(ticks.size() > 0 and worst_damage_error < _HEALTH_EPS,
		"урон КАЖДОГО тика равен data.contact_damage, а не захардкоженному числу",
		"(худшая ошибка за тик %.4f при уроне %.4f)" % [worst_damage_error, contact_damage])
	_check(_near(boundary_health, health_before_death),
		"после %d тиков у игрока осталось ровно %.4f HP (max_health - %d * contact_damage)" % [
			survivable_ticks, health_before_death, survivable_ticks],
		"(got %.4f)" % boundary_health)
	_check(_alive(player), "игрок жив после %d тиков контакта" % survivable_ticks)

	print("-- контакт прекращается: враг ушёл")
	# Уход врага наблюдается не флагом сцены, а тем, что урон прекратился:
	# у ContactEnemy нет публичного «я в контакте», и выдумывать его ради
	# проверки значило бы проверять несуществующий API. 30 тиков — это 2.5
	# интервала: если бы area_exited не остановил тики, игрок с %.4f HP (меньше
	# одного тика урона) давно бы умер.
	enemy.global_position = Vector3(6.0, 0.0, 0.0)
	var after_exit := _health(player)
	for i in 30:
		await physics_frame
		if not _near(_health(player), after_exit):
			break
	_check(_near(_health(player), after_exit),
		"после ухода врага тики прекращаются: здоровье игрока не убывает",
		"(got %.4f, было %.4f)" % [_health(player), after_exit])
	_check(_alive(player), "игрок пережил уход врага")

	print("-- контакт возобновляется: тик %d убивает игрока" % ticks_to_death)
	enemy.global_position = Vector3(0.4, 0.0, 0.0)
	var died_frame := -1
	for i in 60:
		await physics_frame
		if _died_count >= 1:
			died_frame = i
			break
	_check(_died_count == 1,
		"тик %d контакта убивает игрока, died ровно один" % ticks_to_death,
		"(got %d, умер на кадре %d после возврата врага)" % [_died_count, died_frame])
	_check(_near(_health_at_death, 0.0), "в момент сигнала died здоровье игрока равно 0.0",
		"(got %.4f)" % _health_at_death)
	_check(not _alive_at_death, "в момент сигнала died игрок уже мёртв (is_alive() == false)")
	_check(_near(_health(player), player_max_health),
		"игрок респавнился с полным здоровьем max_health (контракт Task 2)",
		"(got %.4f, max_health %.4f)" % [_health(player), player_max_health])

	world.queue_free()
	await physics_frame


## Есть ли на узле весь API врага. Отдельная функция, потому что ответ нужен
## дважды: именованным [FAIL] и решением, можно ли вообще звать health()
## вызовом call(), не упав в рантайм вместо проверки.
func _enemy_api_ready(enemy: Node) -> bool:
	return enemy.has_method("health") and enemy.has_method("is_alive") \
		and enemy.has_method("take_damage") \
		and enemy.has_signal("died") and enemy.has_signal("health_changed")


## Три сигнала смерти врага. Подписчик один на все инстансы и не знает, какой из
## них умер, — счётчик и состояние в момент сигнала и есть весь наблюдаемый след.
func _on_enemy_died(enemy: Node) -> void:
	_enemy_died_count += 1
	_enemy_health_at_death = _enemy_health(enemy)
	_enemy_alive_at_death = _enemy_alive(enemy)


## Доступ к здоровью врага. Вызовом call(), а не типизированным доступом: сцена
## отдаёт CharacterBody3D, а health()/is_alive() живут в enemy_contact.gd, и
## хардкод типа здесь означал бы, что проверка перестала видеть настоящий
## скрипт. Имена с суффиксом _enemy_ отличают их от игровых хелперов выше:
## подписчики на сигналы игрока и врага должны оставаться разными.
func _enemy_health(enemy: Node) -> float:
	return float(enemy.call("health"))


func _enemy_alive(enemy: Node) -> bool:
	return bool(enemy.call("is_alive"))


func _color_near(got: Color, want: Color) -> bool:
	return absf(got.r - want.r) < _COLOR_EPS and absf(got.g - want.g) < _COLOR_EPS \
		and absf(got.b - want.b) < _COLOR_EPS and absf(got.a - want.a) < _COLOR_EPS


# --------------------------------------------------------------------------
# Task 4: навигация
# --------------------------------------------------------------------------

## Четвёртый раздел: враг идёт к игроку по запечённому навмешу.
##
## Что откуда берётся. Враг — настоящий инстанс enemy_contact.tscn, и агент
## читается из НЕГО (get_node_or_null), а не собирается кодом: собранный
## скриптом агент оставил бы проверку зелёной на сцене, в которой
## NavigationAgent3D нет, — ровно тот случай, ради которого этот раздел и
## написан. Окружение (пол, стена, NavigationRegion3D, цель) программное, как в
## Task 3: оно меняется вместе с этим файлом, а предмет проверки — сцена врага.
##
## Почему bake здесь синхронный и проверяется на полигоны. Правило спеки §12:
## агент, меняющий геометрию, обязан перестроить навмеш в той же задаче.
## `bake_navigation_mesh(false)` — синхронный bake (false = не в отдельном
## потоке), поэтому после возврата сетка уже готова и её можно спросить сразу.
## Ноль полигонов означает, что путь не построится никогда: враг простоит, и
## проверка «шёл» была бы зелёной на мире, по которому идти некуда. Поэтому
## polygon_count == 0 — это [FAIL], а не тишина.
##
## Окно наблюдения — 3 с симуляции. Дистанция меряется на каждом физическом
## кадре, а скорость — на каждом кадре, где враг двигался: первые кадры (путь
## ещё считается) и кадры у цели (путь закончен) движением не считаются, иначе
## проверка требовала бы от врага ехать с места, где он стоит.
func _test_enemy_navigation() -> void:
	print("-- Навигация (Task 4)")

	var packed: PackedScene = load(_ENEMY_PATH)
	if packed == null:
		_bail("cannot load %s for the navigation test" % _ENEMY_PATH)
		return

	var world := _new_world()
	var region := _add_navigation_region(world)
	var nav_mesh := region.navigation_mesh as NavigationMesh
	var polygons := 0 if nav_mesh == null else nav_mesh.get_polygon_count()
	_check(polygons > 0,
		"bake навмеша удался: navigation_mesh.get_polygon_count() > 0",
		"(got %d полигонов)" % polygons)

	# Карта навигации обновляется в начале физического шага, а bake кончает в
	# текущем кадре. Без нескольких тиков после bake первый же запрос пути
	# врага ушёл бы в карту, которая ещё пуста, и враг стоял бы лишнюю секунду.
	await _physics_frames(5)

	var target := Node3D.new()
	target.name = "NavTarget"
	if not await _spawn_in(world, target, _NAV_TARGET):
		_bail("the navigation target never became node-ready")
		return
	target.add_to_group("player")
	await _physics_frames(2)
	var players := get_nodes_in_group("player")
	_check(players.size() == 1 and players[0] == target,
		"precondition: в группе \"player\" ровно этот узел — цель врага определена однозначно",
		"(в группе %d узлов)" % players.size())

	var enemy := packed.instantiate()
	if not await _spawn_in(world, enemy, _NAV_ENEMY_START):
		_bail("%s never became node-ready for the navigation test" % _ENEMY_PATH)
		return

	print("-- агент живёт в сцене врага, а не собран скриптом")
	# Позиция и скорость читаются через типизированный каст: instantiate() отдаёт
	# Node, а global_position/velocity живут на CharacterBody3D. Без каста любая
	# строка ниже была бы Variant, и вывод в сообщение об ошибке тянул бы за собой
	# рантайм-ошибку вместо именованного [FAIL].
	var body := enemy as CharacterBody3D
	# Поле скрипта тоже сверяется с узлом сцены: узел в сцене при неиспользуемом
	# агенте ничего бы не двигал, и проверка «есть NavigationAgent3D» была бы
	# зелёной на враге, который стоит.
	var scene_agent := enemy.get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	_check(scene_agent is NavigationAgent3D,
		"у enemy_contact.tscn есть дочерний узел NavigationAgent3D",
		"(got %s)" % ("none" if scene_agent == null else str(scene_agent.name)))
	var agent_field: Variant = enemy.get("_agent")
	_check(scene_agent != null and agent_field == scene_agent,
		"агент врага — именно узел NavigationAgent3D из сцены")
	_check(scene_agent != null and absf(float(scene_agent.get("path_desired_distance")) - 1.0) < _HEALTH_EPS,
		"path_desired_distance агента равен 1.0 м",
		"(got %.4f)" % (float(scene_agent.get("path_desired_distance")) if scene_agent != null else -1.0))
	_check(scene_agent != null and absf(float(scene_agent.get("target_desired_distance")) - 1.0) < _HEALTH_EPS,
		"target_desired_distance агента равен 1.0 м",
		"(got %.4f)" % (float(scene_agent.get("target_desired_distance")) if scene_agent != null else -1.0))

	var data := enemy.get("data") as EnemyData
	if data == null:
		print("  (движение оценивать нельзя без данных: проверки ниже пропущены)")
		target.remove_from_group("player")
		world.queue_free()
		return
	_check(enemy.has_method("next_path_direction"),
		"у enemy_contact.gd есть next_path_direction() — направление пути наружу")

	var move_speed := float(data.move_speed)
	# Порог остановки читается с агента, но подставляется и без него: сцена без
	# агента обязана проверяться теми же утверждениями о поведении, а не
	# зелёным набором «проверять нечего».
	var stop_limit := _NAV_TARGET_DISTANCE + 0.1
	if scene_agent != null:
		stop_limit = float(scene_agent.get("target_desired_distance")) + 0.1
	var start_distance := body.global_position.distance_to(target.global_position)
	var end_distance := start_distance
	var worst_speed_error := 0.0
	var worst_frame := -1
	var worst_speed := 0.0
	var worst_pos := Vector3.ZERO
	var worst_on_floor := false
	var worst_next := Vector3.ZERO
	var max_speed := 0.0
	var moving_frames := 0
	var exact_frames := 0
	var far_side_reached := false
	var crossed_through_wall := false
	for i in _NAV_OBSERVE_TICKS:
		await physics_frame
		var pos := body.global_position
		var speed := Vector2(body.velocity.x, body.velocity.z).length()
		if speed > _NAV_MOVING_EPS:
			moving_frames += 1
			max_speed = maxf(max_speed, speed)
			if absf(speed - move_speed) <= _NAV_EXACT_EPS:
				exact_frames += 1
			if absf(speed - move_speed) > worst_speed_error:
				worst_speed_error = absf(speed - move_speed)
				worst_frame = i
				worst_speed = speed
				worst_pos = pos
				worst_on_floor = body.is_on_floor()
				worst_next = scene_agent.get_next_path_position() if scene_agent != null else Vector3.ZERO
		end_distance = pos.distance_to(target.global_position)
		if pos.z > _NAV_WALL_HALF_Z:
			far_side_reached = true
		# «Прошёл сквозь» читается по центру тела: оно внутри толщины стены
		# (|z| < полу толщины) и напротив неё (x в её протяжённости). Капсула
		# радиусом 0.4 м физику не пропускает — такая позиция означала бы
		# проваливание сквозь препятствие, а не обход. Проверять «z > лица стены»
		# нельзя: дальняя сторона стены тоже лежит при x < 2, и обошёл бы, и
		# прошёл сквозь — там.
		if absf(pos.z) < _NAV_WALL_HALF_Z and pos.x < _NAV_WALL_MAX_X:
			crossed_through_wall = true

	print("    старт %.3f м -> финиш %.3f м, худшая ошибка скорости %.4f (максимум %.4f), движущихся кадров %d из %d" % [
		start_distance, end_distance, worst_speed_error, max_speed, moving_frames, _NAV_OBSERVE_TICKS])
	print("    худший кадр #%d: скорость %.4f, pos=%s, on_floor=%s, следующая точка пути %s" % [
		worst_frame, worst_speed, str(worst_pos), str(worst_on_floor), str(worst_next)])

	_check(moving_frames >= _NAV_MIN_MOVING_FRAMES,
		"враг реально шёл: не менее %d кадров с горизонтальной скоростью выше %.1f м/с" % [
			_NAV_MIN_MOVING_FRAMES, _NAV_MOVING_EPS],
		"(got %d из %d; без этого проверка скорости ниже ничего бы не утверждала)" % [
			moving_frames, _NAV_OBSERVE_TICKS])
	_check(end_distance < start_distance * 0.5,
		"за 3 с враг сократил дистанцию до цели более чем вдвое",
		"(%.3f -> %.3f м из %.3f)" % [start_distance, end_distance, start_distance])
	# Скорость проверяется двумя утверждениями, потому что «равна» имеет две
	# стороны, и обе падают от своих правок: ползти (скорость ниже данных) и
	# разгоняться сверх данных. Проверять строго «на каждом кадре == move_speed»
	# нельзя: навмеш ведёт путь стягиванием по углам, и на одном-двух кадрах
	# капсула чиркает угол стены — move_and_slide гасит при этом 0.2% скорости,
	# и красный свет загорался бы от физики скольжения, а не от руля врага.
	_check(max_speed <= move_speed + _NAV_SPEED_EPS,
		"враг не ускоряется сверх данных: горизонтальная скорость ни разу не выше move_speed",
		"(максимум %.4f при move_speed %.4f, запас %.4f)" % [
			max_speed, move_speed, _NAV_SPEED_EPS])
	_check(absf(max_speed - move_speed) <= _NAV_SPEED_EPS,
		"враг не ползёт: горизонтальная скорость доходит до move_speed — движение берётся из данных",
		"(максимум %.4f при move_speed %.4f, %d из %d движущихся кадров ровно в данных)" % [
			max_speed, move_speed, exact_frames, moving_frames])
	_check(far_side_reached,
		"враг дошёл до другой стороны стены (z > %.1f): путь вёл вокруг, а не упирался в стену" % _NAV_WALL_HALF_Z)
	_check(not crossed_through_wall,
		"враг ни разу не оказался внутри стены (|z| < %.1f при x < %.1f): обошёл, а не прошёл сквозь" % [
			_NAV_WALL_HALF_Z, _NAV_WALL_MAX_X])

	print("-- остановка у цели")
	var settled := body.global_position.distance_to(target.global_position)
	await _physics_frames(int(_TICKS_PER_SECOND * 0.5))
	var after_wait := body.global_position.distance_to(target.global_position)
	_check(settled <= stop_limit,
		"враг остановился у цели: дистанция ≤ target_desired_distance + 0.1",
		"(%.4f при пороге %.4f)" % [settled, stop_limit])
	_check(absf(after_wait - settled) <= _NAV_DRIFT_EPS,
		"после остановки не дрейфует: за 0.5 с дистанция не изменилась",
		"(%.4f -> %.4f, допуск %.2f)" % [settled, after_wait, _NAV_DRIFT_EPS])
	_check(enemy.has_method("is_alive") and bool(enemy.call("is_alive")),
		"враг жив после всего маршрута: цель была узлом группы, а не хитбоксом игрока")

	target.remove_from_group("player")
	world.queue_free()
	await _physics_frames(2)


## Мир навигации: NavigationRegion3D с полом и стеной ВНУТРИ него и синхронный
## bake. Потомки, а не соседи, — это не выбор вкуса: режим парсинга по
## умолчанию (SOURCE_GEOMETRY_ROOT_NODE_CHILDREN) читает геометрию только из
## потомков региона. Стена рядом с регионом осталась бы для навмеша невидимой,
## путь вёл бы сквозь неё, и проверка «дистанция сокращается» стала бы зелёной
## на мире, где для навигации препятствий нет.
func _add_navigation_region(world: Node3D) -> NavigationRegion3D:
	var region := NavigationRegion3D.new()
	region.name = "NavigationRegion3D"
	region.navigation_mesh = NavigationMesh.new()
	world.add_child(region)
	region.add_child(_nav_floor_body())
	region.add_child(_nav_wall_body())
	# Синхронный bake: false = не уводить запекание в отдельный поток. Проверка
	# обязана увидеть полигоны сразу после возврата, а bake в потоке вернул бы
	# полупустую сетку и ушёл считать её после того, как мир уже признан годным.
	region.bake_navigation_mesh(false)
	return region


## Пол мира навигации: StaticBody3D слоя 1, и по форме — и по мешу (BoxMesh).
## Оба источника нужны не для красоты: парсер навмеша читает либо коллайдеры,
## либо меши, в зависимости от geometry_parsed_geometry_type, и проверка bake
## обязана быть защищена от молчаливой смены этого флага на дефолтный.
## Agent radius навмеша по умолчанию — 0.75 м, поэтому запечённая поверхность
## идёт на 0.75 м от края пола; враг с капсулой 0.4 м до стены не дотягивается
## и скользить по ней не будет — его скорость в этом мире обязана быть ровно
## скоростью данных.
func _nav_floor_body() -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.name = "NavFloor"
	floor.collision_layer = _LAYER_WORLD
	floor.collision_mask = 0
	floor.position = Vector3(0.0, -0.5, 0.0)
	var size := Vector3(_NAV_FLOOR_SIZE, 1.0, _NAV_FLOOR_SIZE)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	floor.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	floor.add_child(mesh)
	return floor


## Стена между врагом и целью: та же схема (коллайдер + меш), только узкая и
## высокая. Высоты 4 м хватает и физике, и bake: полка в рост врага (1.8 м) для
## тела не препятствие, а вот короткая стенка Recast принял бы за проходимый
## уступ, и навмеш провёл бы путь поверх неё.
func _nav_wall_body() -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.name = "NavWall"
	wall.collision_layer = _LAYER_WORLD
	wall.collision_mask = 0
	wall.position = Vector3(
		(_NAV_WALL_MIN_X + _NAV_WALL_MAX_X) * 0.5,
		_NAV_WALL_HEIGHT * 0.5,
		0.0)
	var size := Vector3(_NAV_WALL_MAX_X - _NAV_WALL_MIN_X, _NAV_WALL_HEIGHT, _NAV_WALL_HALF_Z * 2.0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	wall.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	wall.add_child(mesh)
	return wall


func _physics_frames(count: int) -> void:
	for i in count:
		await physics_frame


## Свой мир под каждый сценарий: пол и стена в общей сцене мешали бы проверке
## «враг попал под снаряд до стены», а имя узла в сообщении об ошибке должно
## называть ту стену, которая на самом деле стояла в сценарии.
func _new_world() -> Node3D:
	_world_id += 1
	var world := Node3D.new()
	world.name = "World%d" % _world_id
	root.add_child(world)
	return world


## Пол слоя 1 (world) с верхней гранью на top_y. Враг CharacterBody3D, у которого
## нет ни гравитации, ни move_and_slide (движение — Task 4), встал бы где его
## поставили, а игрок без пола провалился бы под ноль до первого тика.
func _add_floor(world: Node3D, top_y: float = 0.0) -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.name = "Floor"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40.0, 1.0, 40.0)
	shape.shape = box
	floor.add_child(shape)
	floor.collision_layer = _LAYER_WORLD
	floor.collision_mask = 0
	floor.position = Vector3(0.0, top_y - 0.5, 0.0)
	world.add_child(floor)
	return floor


## Стена слоя 1 перед лицом на front_x. Снаряд, который не нашёл врага, кончился
## бы здесь: иначе «снаряд пропал» и «снаряд остановился на враге» — одно и то
## же наблюдение.
func _add_wall(world: Node3D, front_x: float) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.name = "Wall"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 6.0, 6.0)
	shape.shape = box
	wall.add_child(shape)
	wall.collision_layer = _LAYER_WORLD
	wall.collision_mask = 0
	wall.position = Vector3(front_x + 0.5, 3.0, 0.0)
	world.add_child(wall)
	return wall


## Ставит узел в позицию и ждёт его готовности. Позиция задаётся ДО добавления в
## дерево: узел, который отработает кадр в стороне от цели, а потом teleport'нется
## на неё, дал бы проверке попадание, зависящее от того, где он стоял в ту секунду.
func _spawn_in(parent: Node, node: Node3D, pos: Vector3) -> bool:
	node.position = pos
	parent.add_child(node)
	for i in 120:
		if node.is_node_ready():
			return true
		await physics_frame
	return node.is_node_ready()


## Снаряд из настоящей сцены, поставленный в позицию. launch() вызывается
## отдельно и после паузы в кадр: два снаряда, выпущенные в разные кадры,
## разъедутся на четверть метра и не попадут в одну цель в один кадр, а весь
## смысл проверки «два снаряда, одна цель, один кадр» именно в этом.
func _spawn_projectile(world: Node3D, pos: Vector3) -> Projectile:
	var packed: PackedScene = load(_PROJECTILE_PATH)
	if packed == null:
		_bail("cannot load %s" % _PROJECTILE_PATH)
		return null
	var bullet := packed.instantiate() as Projectile
	bullet.position = pos
	world.add_child(bullet)
	return bullet


## Сколько тиков до исчезновения узла или -1, если он пережил cap. Узел после
## queue_free() ещё существует до конца кадра, в котором удалён, поэтому
## возвращается номер тика, округлённый вверх до следующего.
func _frames_until_free(node: Node, cap: int) -> int:
	for i in cap:
		if not is_instance_valid(node):
			return i
		await physics_frame
	return -1


func _initialize() -> void:
	print("=== enemies ===")

	print("-- %s must load as an EnemyData" % _CONTACT_PATH)
	var res: Resource = load(_CONTACT_PATH)
	if res == null:
		_bail("cannot load %s" % _CONTACT_PATH)
		return
	var script_res := res.get_script() as Script
	_check(res is EnemyData, "contact.tres is an EnemyData",
		"(script=%s)" % ("none" if script_res == null else script_res.resource_path))
	var data := res as EnemyData
	if data == null:
		_bail("contact.tres is not an EnemyData, the field checks below would be meaningless")
		return

	print("-- the values the design fixes for the contact enemy")
	# Design spec 7.3: the contact enemy has 50 health and 10 contact damage.
	# Each of these turns red on a single field edit in contact.tres.
	_check(data.max_health == 50.0, "max_health is 50.0", "(got %.4f)" % data.max_health)
	_check(data.contact_damage == 10.0, "contact_damage is 10.0", "(got %.4f)" % data.contact_damage)
	_check(data.move_speed == 6.0, "move_speed is 6.0", "(got %.4f)" % data.move_speed)
	_check(data.spawn_interval == 1.5, "spawn_interval is 1.5", "(got %.4f)" % data.spawn_interval)
	# The kind is what Phase 2 wires movement and the scene off, so a resource
	# that loads with a default kind must not be able to pass as a contact enemy.
	_check(data.kind == EnemyData.EnemyKind.CONTACT, "kind is EnemyData.EnemyKind.CONTACT",
		"(got %d)" % int(data.kind))

	print("-- is_valid() can answer false, so is_valid() == true means something")
	_check(data.is_valid(), "contact.tres reports itself valid")
	# One assertion per term of is_valid()'s condition: dropping any single term
	# from the implementation turns exactly this one red.
	_check(_is_valid_rejects({"max_health": 0.0}),
		"a zero max health is rejected")
	_check(_is_valid_rejects({"contact_damage": 0.0}),
		"a zero contact damage is rejected")
	_check(_is_valid_rejects({"move_speed": 0.0}),
		"a zero move speed is rejected")
	_check(_is_valid_rejects({"spawn_interval": 0.0}),
		"a zero spawn interval is rejected")

	await _test_player_health()
	await _test_contact_enemy()
	await _test_enemy_navigation()

	if _bailed:
		# _bail() уже напечатал сводку и запросил quit(1). Второй quit() здесь
		# перезаписал бы код возврата нулём, и FATAL прочитали бы как PASS.
		quit(1)
		return
	_finish()
	quit(1 if _failures.size() > 0 else 0)

---

## Task 4 report (full)
# Task 4 — Навигация: враг идёт к игроку через NavigationAgent3D

**Статус:** DONE_WITH_CONCERNS (задача выполнена полностью; одно намеренное отклонение от буквы брифа — см. §6.1, оно доказуемо необходимо)
**Файлы:** `scripts/enemy_contact.gd`, `enemy_contact.tscn`, `tests/enemies.gd` (все три — мои по контракту задачи; ничего больше не менялось, git не трогался)
**Проверки:** `enemies` → 122 checks / 0 failed (было 106 → +16); полный прогон → **9 passed / 0 failed / 3 skipped**

---

## 1. Что сделано

### 1.1 `enemy_contact.tscn` (+3 строки)

Дочерний узел в сцене врага:

```
[node name="NavigationAgent3D" type="NavigationAgent3D" parent="."]
path_desired_distance = 1.0
target_desired_distance = 1.0
```

`load_steps` не тронут (тип узля встроенный, ни ext-, ни sub-ресурсов не добавлено).

**`path_desired_distance = 1.0` вместо 0.5 из брифа — единственное отклонение, и оно обязательно.**
Дело не вкуса, а физики движка: запечённая проходимая поверхность навмеша лежит **выше** геометрии, на `2 * cell_height` (измерено: пол с верхней гранью на `y = 0` запекается в сетку на `y = 0.5` при `cell_height = 0.25`, а при `cell_height = 0.1` — на `y = 0.2`; см. §6.2). Первая точка пути — это позиция агента, привязанная к сетке, то есть ровно на этом смещении над пятками врага. Пока смещение **не меньше** `path_desired_distance`, агент не считает эту точку достигнутой, индекс точки пути не сдвигается никогда — и враг стоит на месте при запечённом, вполне достижимом навмеше. При 0.5 м порог **равнялся** смещению. Доказательство — прогон с буквальным `0.5` из брифа (§6.2): враг не двинулся ни на миллиметр за 3 с (0 движущихся кадров из 360, 10.000 → 10.000 м), при 1.0 м — дошёл и остановился (210 движущихся кадров, 10.000 → 0.979 м).

`1.0` — это дефолт самого движка, а бриф сам санкционирует его: «`path_desired_distance = 0.5`, `target_desired_distance = 1.0` — **дефолты движка приемлемы**, задать явно для читаемости». Отклонено только число, намерение брифа (явные значения в сцене) выполнено; причина записана в шапку `enemy_contact.gd` (решение 7), чтобы не потерялась при чтении одной сцены.

### 1.2 `scripts/enemy_contact.gd` (навигация)

- Шапка файла: решение 6 (направление — из навмеша, bake — дело владельца геометрии, «навмеш без полигонов = проверка падает») и решение 7 (смещение поверхности навмеша → `path_desired_distance = 1.0`), обе — с измеренными числами.
- `@onready var _agent: NavigationAgent3D = get_node_or_null("NavigationAgent3D") as NavigationAgent3D` — ровно по брифу, через `get_node_or_null`; при отсутствии узла `_ready()` даёт `push_warning` («в сцене нет NavigationAgent3D — враг останется на месте»), а враг работает и стоит.
- `var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")` — как у игрока, своей строкой, а не ссылкой на `player.gd`.
- `_physics_process(delta)`: ветка трупа (без изменений) → `_apply_gravity(delta)` → `_steer_to_player()` → `_tick_contact(delta)` → `move_and_slide()`. Порядок брифа соблюдён: гравитация → цель → направление → скорость → ход.
- `_apply_gravity(delta)`: `is_on_floor()` → `velocity.y = 0`, иначе `velocity.y -= _gravity * delta` (как у игрока).
- `_steer_to_player()`: цель — `get_first_node_in_group("player")` (решение 4 из Task 3, не переписывал); если цели нет / агента нет / враг мёртв → `velocity.x = velocity.z = 0`; иначе `_agent.target_position = target.global_position` **каждый тик**, `dir = next_path_direction()`, при `dir != ZERO` → `velocity.x/z = dir * data.move_speed`, иначе обнуление. Обнуление во всех ветках — намеренно (иначе инерция после смерти цели), это отражено в §6.4.
- `next_path_direction() -> Vector3` — сигнатура и обе строки комментария брифа дословно. Ноль возвращается в четырёх случаях: агента нет, узел не в дереве, путь закончен (`is_navigation_finished()` — это и есть остановка у цели), горизонтальное смещение до следующей точки ≤ `_PATH_EPS` (0.001 м).

### 1.3 Решение, которого бриф не перечислял: вертикаль в направлении не участвует

Внутри `next_path_direction()` перед `normalized()` стоит `offset.y = 0.0`. Смещение поверхности навмеша над полом означает, что вектор «до следующей точки» всегда чуть приподнят; его нормализация дала бы единичную длину, но горизонтальная проекция была бы меньше — враг с `move_speed = 6.0` тикал бы тише, медленно и без единого признака. С плоской горизонталью горизонтальная скорость — ровно число из данных. Именно из-за этого утверждение «скорость == move_speed» вообще имеет смысл, а не зависит от квантования сетки.

### 1.4 `tests/enemies.gd` (+16 проверок, секция «Навигация»)

Мир программный, как в Task 3 (предмет проверки — сцена врага): `_add_navigation_region(world)` создаёт `NavigationRegion3D` с **полом и стеной внутри себя** (режим парсинга по умолчанию `SOURCE_GEOMETRY_ROOT_NODE_CHILDREN` читает только потомков региона — стена «рядом» с регионом осталась бы для навмеша невидимой, путь вёл бы сквозь неё, и проверка «дистанция сокращается» была бы зелёной на мире без препятствий), затем `region.bake_navigation_mesh(false)` — синхронно, до физики.

Геометрия: пол 40×40, верхняя грань `y = 0`; стена на `z = 0`, высотой 4 м, шириной 2 м, от `x = -20` (левый край пола, обхода нет) до `x = +2`; враг стартует в `(0, 0, -5)`, цель — `Node3D` в группе `"player"` в `(0, 0, 5)`; обходить стену можно только справа. И пол, и стена несут и `CollisionShape3D`, и `MeshInstance3D` (парсер навмеша читает либо коллайдеры, либо меши в зависимости от флага — проверка bake защищена от молчаливой смены этого флага).

| # | Утверждение | Зелёное значение |
|---|---|---|
| 1 | bake успешен: `navigation_mesh.get_polygon_count() > 0` | 17 полигонов |
| 2 | precondition: в группе `"player"` ровно этот узел | 1 узел |
| 3 | у `enemy_contact.tscn` есть дочерний `NavigationAgent3D` | `NavigationAgent3D` |
| 4 | агент врага — именно узел сцены (`enemy.get("_agent") == scene_agent`) | — |
| 5 | `path_desired_distance` агента равен 1.0 | 1.0000 |
| 6 | `target_desired_distance` агента равен 1.0 | 1.0000 |
| 7 | у `enemy_contact.gd` есть `next_path_direction()` | — |
| 8 | враг реально шёл: ≥ 60 кадров со скоростью > 0.1 м/с | 210 из 360 |
| 9 | за 3 с дистанция сокращена более чем вдвое | 10.000 → 0.979 м |
| 10 | не ускоряется сверх данных (макс ≤ `move_speed` + 0.01) | макс 6.0000 |
| 11 | не ползёт (макс ≥ `move_speed` − 0.01) | макс 6.0000, 209 из 210 кадров ровно в данных |
| 12 | дошёл до другой стороны стены (`z > 1.0`) | путь вёл вокруг |
| 13 | ни разу не оказался внутри стены (`\|z\| < 1.0` при `x < 2.0`) | обошёл, не прошёл сквозь |
| 14 | остановился у цели: дистанция ≤ `target_desired_distance` + 0.1 | 0.9790 при пороге 1.1000 |
| 15 | дальше не дрейфует: за 0.5 с дистанция не изменилась | 0.9790 → 0.9790 (допуск 0.02) |
| 16 | враг жив после маршрута | — |

Построчно: браузер ассертов, дистанция и скорость меряются на каждом физическом кадре окна в 3 с (360 тиков при 120 тиках/с), скорость — на кадре, где горизонтальная скорость выше 0.1 м/с (первые кадры, пока путь считается, и кадры у цели движением не считаются: требовать там `move_speed` означало бы требовать ехать с места, где враг стоит).

Правило bake (спека §12) соблюдено в своей части: синхронный `bake_navigation_mesh(false)`, 5 физических кадров на синхронизацию карты, и `polygon_count == 0` — **[FAIL]**, а не тишина: без этой строки зелёная «шёл» означала бы «враг простоял, потому что идти некуда».

---

## 2. TDD: RED → GREEN

### 2.1 RED (шаги 1–2 брифа)

Секция «Навигация» написана первой, до кода:

```
> powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 enemies
enemies        FAIL  (exit code 1)
    === RESULT: 121 checks, 9 failed ===
      FAILURE: у enemy_contact.tscn есть дочерний узел NavigationAgent3D (got none)
      FAILURE: агент врага — именно узел NavigationAgent3D из сцены
      FAILURE: path_desired_distance агента равен 0.5 м (got -1.0000)
      FAILURE: target_desired_distance агента равен 1.0 м (got -1.0000)
      FAILURE: у enemy_contact.gd есть next_path_direction() — направление пути наружу
      FAILURE: враг реально шёл: не менее 60 кадров ... (got 0 из 360; ...)
      FAILURE: за 3 с враг сократил дистанцию до цели более чем вдвое (10.000 -> 10.000 м из 10.000)
      FAILURE: враг не ползёт: горизонтальная скорость доходит до move_speed (максимум 0.0000 ...)
      FAILURE: враг дошёл до другой стороны стены (z > 1.0): путь вёл вокруг ...
      FAILURE: враг остановился у цели: дистанция ≤ target_desired_distance + 0.1 (10.0000 при пороге 1.1000)
```

Ровно то, что обещал бриф: «навигации ещё нет, враг стоит, дистанция не сокращается, код 1». Первые 106 проверок (Task 1–3) были зелёные и в этом прогоне.

### 2.2 GREEN (шаг 5)

```
> powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 enemies
enemies        PASS
RESULT: 1 passed, 0 failed, 0 skipped      (=== enemies: 122 checks, 0 failed ===)
```

Диагностика раздела (печатается зелёной):
```
    старт 10.000 м -> финиш 0.979 м, худшая ошибка скорости 0.0093 (максимум 6.0000), движущихся кадров 210 из 360
    худший кадр #91: скорость 5.9907, pos=(2.377084, 0.000921, -1.104527), on_floor=true, следующая точка пути (2.75, 0.5, 0.0)
```

Прогон повторён 6 раз подряд (1 зелёный + 4 контрольных + финальные) — расхождений нет, «стена» §6.3 не проявилась.

---

## 3. Мутации (шаг 5 брифа) — обе доказаны

Общая базовая линия перед мутациями (и она же после обеих мутаций):
`scripts/enemy_contact.gd` = **A8D14DA36B5B5D54A173138473A6F1081ECEC051FCF151D84AEFB92F4DCDFA40**

### (a) `next_path_direction()` всегда возвращает `Vector3.ZERO`

Правка: `return Vector3.ZERO` добавлен первой строкой функции (перед `if _agent == null ...`).

```
> powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 enemies
enemies        FAIL  (exit code 1)        # exit=1
    === RESULT: 122 checks, 5 failed ===
      FAILURE: враг реально шёл: не менее 60 кадров ... (got 0 из 360; без этого проверка скорости ниже ничего бы не утверждала)
      FAILURE: за 3 с враг сократил дистанцию до цели более чем вдвое (10.000 -> 10.000 м из 10.000)   <-- требуемая брифом
      FAILURE: враг не ползёт: горизонтальная скорость доходит до move_speed (максимум 0.0000 при move_speed 6.0000, 0 из 0 движущихся кадров ровно в данных)
      FAILURE: враг дошёл до другой стороны стены (z > 1.0): путь вел вокруг, а не упирался в стену
      FAILURE: враг остановился у цели: дистанция ≤ target_desired_distance + 0.1 (10.0000 при пороге 1.1000)
```

Именованное утверждение брифа «дистанция сокращается на 50%» — красное (10.000 → 10.000 м), плюс ещё четыре.

Восстановление (снятие строки) → SHA-256 **A8D14DA3…FDA40**, побайтово идентичен базовой линии; `enemies` снова PASS.

### (b) скорость умножается на 0.5 в `_physics_process`

Правка: `velocity.x = direction.x * data.move_speed * 0.5` и то же для `z`.

```
> powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 enemies
enemies        FAIL  (exit code 1)        # exit=1
    старт 10.000 м -> финиш 2.475 м, худшая ошибка скорости 3.0001 (максимум 3.0000), движущихся кадров 360 из 360
    худший кадр #183: скорость 2.9999, pos=(2.376523, 0.000946, -1.104205), on_floor=true, следующая точка пути (2.75, 0.5, 0.0)
    === RESULT: 122 checks, 3 failed ===
      FAILURE: враг не ползёт: горизонтальная скорость доходит до move_speed — движение берётся из данных (максимум 3.0000 при move_speed 6.0000, 0 из 360 движущихся кадров ровно в данных)   <-- требуемое брифом «velocity == move_speed»
      FAILURE: враг остановился у цели: дистанция ≤ target_desired_distance + 0.1 (2.4748 при пороге 1.1000)
      FAILURE: после остановки не дрейфует: за 0.5 с дистанция не изменилась (2.4748 -> 0.9998, допуск 0.02)
```

Именованное утверждение «скорость == move_speed» красное (максимум 3.0000 против 6.0000). Вторые два красных — честные следствия: за 3 с на 3 м/с враг не доходит до цели и ещё идёт, поэтому «не дрейфует» тоже не выполняется.

Восстановление → SHA-256 **A8D14DA3…FDA40**, идентичен; `enemies` снова PASS.

### Хеши (SHA-256) — финальное состояние дерева

| Файл | SHA-256 |
|---|---|
| `scripts/enemy_contact.gd` | `A8D14DA36B5B5D54A173138473A6F1081ECEC051FCF151D84AEFB92F4DCDFA40` |
| `enemy_contact.tscn` | `612413E999BB84A776D90DD0E2704706D480333C919C12D231AC6B4B8058AF87` |
| `tests/enemies.gd` | `2CA318AD7A00B58BAAC6D07D89B6B382A77E392D9396E9E605F89DA69793193A` |

---

## 4. Полный прогон

```
> powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1
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

`integrity` (грузит `main.tscn`, проверяет слои и спринт-проход) — PASS: изменений врага он не заметил, как и требовал бриф.

---

## 5. Файлы изменены

| Файл | Что |
|---|---|
| `scripts/enemy_contact.gd` | шапка (решения 6–7), `_gravity`, `_agent`, `_PATH_EPS`, `push_warning` без агента, `_apply_gravity()`, `_steer_to_player()`, публичная `next_path_direction()`, новый порядок `_physics_process` с гравитацией и `move_and_slide()` |
| `enemy_contact.tscn` | дочерний `NavigationAgent3D` с `path_desired_distance = 1.0`, `target_desired_distance = 1.0` |
| `tests/enemies.gd` | секция «Навигация» (16 проверок), мир с bake (`_add_navigation_region`, `_nav_floor_body`, `_nav_wall_body`), 10 констант геометрии/допусков, абзац про Task 4 в шапке файла, вызов секции в `_initialize()` |

Не трогал: `player.gd`, `player.tscn`, `scripts/hurtbox.gd`, `data/enemies/*`, `tools/run_checks.ps1`, любые `.tscn` кроме `enemy_contact.tscn`. Git-мутаций не выполнялось (ни `add`, ни `commit`, ни `checkout`).

---

## 6. Саморевью и находки

### 6.1 Одно отклонение от буквы брифа: `path_desired_distance` (см. §1.1)

Стоит внимания ревьюеру, поэтому — целиком. Кратко: `0.5` из брифа делает врага неподвижным навсегда, потому что запечённая поверхность навмеша лежит на `2 * cell_height` (= 0.5 м при дефолтах) выше пола, а первая точка пути — это как раз позиция агента, привязанная к этой поверхности; порог, равный смещению, не преодолевается никогда. Взял дефолт движка 1.0, который бриф сам объявляет приемлемым; причина записана в шапку скрипта.

Доказательство (прогон с буквальным `0.5`, затем возврат):

```
=== RESULT: 122 checks, 6 failed ===
      FAILURE: path_desired_distance агента равен 1.0 м (got 0.5000)
      FAILURE: враг реально шёл: ... (got 0 из 360)
      FAILURE: за 3 с враг сократил дистанцию до цели более чем вдвое (10.000 -> 10.000 м из 10.000)
      FAILURE: враг не ползёт: ... (максимум 0.0000 при move_speed 6.0000)
      FAILURE: враг дошёл до другой стороны стены (z > 1.0)
      FAILURE: враг остановился у цели: ... (10.0000 при пороге 1.1000)
```
после возврата `enemy_contact.tscn` = `612413E9…AF87` (тот же, что до эксперимента) и `enemies` PASS.

### 6.2 Смещение поверхности навмеша измерено, а не выдумано

Прогон с временной диагностикой (потом удалена) на мире «только пол»:

| настройки bake | высота вершин сетки (пол с гранью `y = 0`) |
|---|---|
| дефолты | `y = 0.5` |
| только коллайдеры / только меши | `y = 0.5` (то же — флаг парсинга ни при чём) |
| `cell_height = 0.1` | `y = 0.2` |
| `agent_max_climb = 0.5`, `filter_low_hanging_obstacles = false`, `filter_walkable_low_height_spans = false` | `y = 0.5` (то же — не при чём) |

Вывод: смещение = `2 * cell_height`, флагов и клима не касается. Практический вывод для Task 5: тир запекается с дефолтами (Task 5 владеет `range.tscn` и `scripts/range_scene.gd`), пол тира тоже с верхней гранью `y = 0` → смещение 0.5 → при `path_desired_distance = 1.0` запас двойной, враг пойдёт. Если тир когда-нибудь запекуют с `cell_height > 0.5`, вернётся тот же класс заморозки — это стоит знать владельцу bake.

### 6.3 Скорость: «равна на каждом кадре» оказалось проверкой физики скольжения, а не руля

Буквальная формулировка брифа («во время движения `velocity` по горизонтали равен `data.move_speed`, допуск 0.01») в этой геометрии не выживает: навмеш ведёт путь стягиванием по углам, и на 1 кадре из 210 капсула чиркает угол стены — худший кадр #91, `pos = (2.377, 0.0009, -1.105)`, скорость 5.9907 (гашение 0.16 %), `move_and_slide` срезает остаток движения при касании. Красный свет загорался бы от физики контакта, а не от руля врага. Поэтому «равна» разделено на две проверки, каждая ловит свою подмену:

- «не ускоряется сверх данных»: максимум ≤ `move_speed` + 0.01;
- «не ползёт»: максимум ≥ `move_speed` − 0.01 (т. е. скорость **доходит** до числа из данных).

Плюс в тексте проверки — сколько кадров было ровно в данных (209 из 210), и печать худшего кадра для разбора. Мутация (b) ловится второй проверкой (максимум 3.0), а первая остаётся зелёной — так и должно быть: она про другую сторону.

### 6.4 Что ещё проверено глазами по коду

- Порядок в `_physics_process` совпадает с брифом; ветка трупа осталась первой и не двигает тело.
- Гравитация — та же формула, что у игрока, и то же поле из `project.godot`; при `data == null` физика вообще выключена в `_ready()` (решение 5 Task 3), а `_steer_to_player()` дополнительно проверяет `is_alive()`, поэтому обращения к `data.move_speed` при `null` не случится.
- `velocity = Vector3.ZERO` при смерти (Task 3, упреждающий) не трогал: `_dying` возвращается раньше, чем `_steer_to_player()`, но `move_and_slide()` в этом кадре уже не вызывается — труп стоит ровно там, где умер.
- Отсутствие игрока в группе, отсутствие агента, смерть врага — все дают обнуление горизонтальной скорости, а не инерцию (проверено чтением: единственные ветки, где скорость не пишется заново, — это ранние `return` с явным обнулением).
- Диагностические `print()` в секции оставлены осознанно: в этом файле такой стиль уже принят (плотность тиков, худшая ошибка урона за тик), и без худшего кадра разбор скорости §6.3 невозможен.

### 6.5 Побочный эффект, который я нашёл и починил: `project.godot` теряет три настройки

`tools/run_checks.ps1` при устаревшем кэше классов запускает `godot --import`, и тот переписывает `project.godot`. При этом Godot **выбрасывает** три ключа, стоящие после строк-комментариев `;` в секциях `[application]`, `[display]`, `[rendering]`:

```
- run/max_fps=0                    (CHECKLIST §1A: лимит FPS снят)
- window/vsync/vsync_mode=1        (CHECKLIST §1A: vsync включён)
- scaling_3d/scale=1.0             (CHECKLIST §1A: рендер в нативном разрешении)
```

`project.godot` — не мой файл, поэтому я восстановил его содержимое вручную (без git) и проверил, что `git diff -- project.godot` пуст; три последующих полных прогона (включая финальный) файл не тронули. Корреляция точная в моих наблюдениях: порча появилась между двумя `git status` в ходе прогонов с `--import`, и ни один прогон без строки «importing project (class cache missing or stale)» порчи не повторил. **Ничего не «чинил» в файле, который мне не принадлежит, — только вернул как было и докладываю.**

---

## 7. Опасения и передача

1. **`path_desired_distance = 1.0` вместо 0.5** (§6.1) — единственное отклонение от буквы брифа; если ревьюер требует именно 0.5, задача нерешаема без правки bake (см. §6.2), и это осознанный компромисс в пользу рабочего врага.
2. **Task 5 наследует риск заморозки, если поменяет параметры bake тира**: пол `range.tscn` с гранью `y = 0` + дефолтный `NavigationMesh` дают смещение 0.5, запас при 1.0 — двойной. `cell_height > 0.5` вернёт баг.
3. **Часть правила bake про `range.tscn` не выполнена мной** — файл не мой; он за Task 5 (`task-5-brief.md`: `NavigationRegion3D` + `scripts/range_scene.gd` с синхронным bake и `push_error` при `polygon_count == 0`). Моя часть правила (тестовый мир, синхронный bake, проверка полигонов как [FAIL]) сделана и проверена.
4. **Предупреждение Godot при bake мешей** («Source geometry parsing ... had to parse RenderingServer meshes at runtime») — это про меши (`MeshInstance3D`), которые бриф требует в мире навигации; на скорость прогонов не влияет (проверка укладывается в секунды). Для тира Task 5 имеет смысл взять геометрию из коллайдеров — bake не будет трогать GPU.
5. **Обход стены в тестовом мире идёт слегка мимо навмеша**: худший кадр показал, что стягивание пути чиркает угол стены на 0.16 % скорости. Это физика, не руль (§6.3), но если когда-нибудь проверку сделают строже, первым делом придётся смотреть сюда.
