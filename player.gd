extends CharacterBody3D

## Изменилось здоровье: сколько осталось из скольких. Последний аргумент —
## всегда max_health, а не «сколько было», чтобы полоса здоровья не могла
## забыть, на какое число делить.
signal health_changed(current: float, maximum: float)
## Игрок умер. Испускается строго один раз за смерть и до респавна: подписчик
## должен успеть увидеть нулевое здоровье, а не уже восстановленное.
signal died()

@export var speed: float = 5.0
@export var jump_velocity: float = 5.0
@export var sprint_multiplier: float = 1.8
@export var mouse_sensitivity: float = 0.002
@export var fall_limit: float = -50.0
## Наземное ускорение и торможение в м/с². Горизонтальная скорость не
## присваивается, а накапливается за кадры, поэтому разгон и остановка
## конечны по времени; мгновенное присвоение читалось бы как телепортация,
## а разворот направления — как щелчок. 20 м/с² даёт разгон 5 м/с за 0.25 с.
@export var ground_acceleration: float = 20.0
## Доля наземного ускорения, доступная в воздухе. Та же механика накопления,
## но с пониженным коэффициентом: полный воздушный контроль делал бы прыжок
## избыточно управляемым, нулевой — неуправляемым, 0.4 — компромисс между ними.
@export var air_control: float = 0.4
## Потолок здоровья игрока. 100 HP — спека §7.2: этого хватает на десять тиков
## контактного урона контактного врага (10 урона за тик, спека §7.3), то есть
## игрок выдерживает ровно десять касаний — столько, чтобы смерть была
## последствием ошибки, а не случайности.
@export var max_health: float = 100.0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _jump_queued: bool = false
var _spawn_transform: Transform3D = Transform3D.IDENTITY
## Текущее здоровье — отдельное поле рядом с max_health, а не вместо него:
## «сколько максимум» — потолок, который за бой не меняется, а «сколько
## осталось» меняется и после смерти обязана вернуться к этому потолку.
var _health: float = 0.0

@onready var _camera: Camera3D = $Camera3D
## Пистолет игрока. Может отсутствовать: лобби Фазы 4 и любые сцены без
## оружия создают того же персонажа, и требовать в каждой из них узел с
## характеристиками оружия было бы требованием к сцене, а не к игроку.
@onready var _pistol: Pistol = get_node_or_null("Pistol") as Pistol
## Хитбокс игрока. Может отсутствовать по той же причине, что и пистолет:
## подключение урона — это проводка сцены, и сцена без хитбокса (лобби, отладочные
## макетки) обязана оставаться рабочей, а не падать в _ready().
@onready var _hurtbox: Hurtbox = get_node_or_null("Hurtbox") as Hurtbox


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	set_spawn_transform()
	add_to_group("player") # группа вместо пути в сцене врага: путь был бы привязкой чужого файла к этому
	# Порядок не произвольный: точка возрождения и здоровье должны быть готовы
	# до того, как что-то сможет в игрока попасть, иначе первое же попадание
	# пришлось бы на персонажа с нулевым здоровьем и нулевой точкой респавна.
	_health = max_health
	_connect_hurtbox()
	_connect_focus_recapture()
	if _pistol != null:
		# Контракт смены сцены, а не гигиена: полупустой магазин, переживший
		# поездку в лобби и обратно, стоил бы игроку бесплатных патронов при
		# каждом входе в бой.
		_pistol.reset_for_scene_change()


## Подписка на сигнал хитбокса, а не чтение его полей: связь «попадание → минус
## здоровье» обязана быть найдена самой сценой, иначе урон пришлось бы искать
## вручную в каждом новом месте, где кто-то решит перебирать хитбоксы.
func _connect_hurtbox() -> void:
	if _hurtbox != null and not _hurtbox.damage_taken.is_connected(take_damage):
		_hurtbox.damage_taken.connect(take_damage)


func _exit_tree() -> void:
	_disconnect_focus_recapture()


## Сколько здоровья осталось. Публичный доступ, потому что полоса здоровья и
## сохранения читают это поле извне, а писать его напрямую нельзя — тогда смерть
## не наступит.
func health() -> float:
	return _health


func is_alive() -> bool:
	return _health > 0.0


## Нанести урон. Ноль и отрицательные значения игнорируются: урон — величина
## положительная, а «вычитание минуса из здоровья» было бы лечением, которое
## враг мог бы выдать себе сам.
func take_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	if not is_alive():
		return
	_health = maxf(_health - amount, 0.0)
	health_changed.emit(_health, max_health)
	if _health > 0.0:
		return
	# Смерть. Сигнал уходит раньше респавна, иначе подписчик увидел бы уже
	# восстановленное здоровье и не смог отличить смерть от лечения. Ровно один
	# раз: восстановление ниже поднимает здоровье обратно, а is_alive() выше
	# отсекает повторный вход в эту ветку, пока игрок снова жив.
	died.emit()
	_respawn(true)


## Захват курсора восстанавливается при возврате фокуса окну: Godot отпускает
## курсор, когда окно теряет фокус, и без этого игрок возвращался бы в игру с
## невидимым управлением.
func _connect_focus_recapture() -> void:
	var window := get_tree().root
	if window != null and not window.focus_entered.is_connected(_on_focus_entered):
		window.focus_entered.connect(_on_focus_entered)


## Отписка обязательна с проверкой is_connected: лобби и локация создают игрока
## повторно, а без неё второй вход в сцену падает на "signal already connected".
func _disconnect_focus_recapture() -> void:
	var window := get_tree().root if is_inside_tree() else null
	if window != null and window.focus_entered.is_connected(_on_focus_entered):
		window.focus_entered.disconnect(_on_focus_entered)


func _on_focus_entered() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func set_spawn_transform() -> void:
	_spawn_transform = global_transform


## Единственное место в игре, где читается Input.mouse_mode для гейта ввода.
## Обёрнуто в метод, а не вчитывается прямо в _unhandled_input и
## _physics_process, потому что headless-дисплейсер вообще не умеет захватывать
## курсор: Input.set_mouse_mode() там молча ничего не делает и Input.mouse_mode
## навсегда остаётся VISIBLE. Проверки не могут ни захватить курсор, ни подменить
## синглтон Input, поэтому подменяется только значение, попадающее в гейт.
func _mouse_mode_for_play_input() -> int:
	return Input.mouse_mode


func _unhandled_input(event: InputEvent) -> void:
	# ЛКМ здесь намеренно не обрабатывается: он принадлежит действию fire,
	# которое выстрел реализует на следующей фазе. Захват курсора
	# переключается только действием pause (Esc).
	if event is InputEventMouseMotion:
		if not InputGate.is_play_input_allowed(_mouse_mode_for_play_input()):
			return
		var motion := event as InputEventMouseMotion
		rotate_y(-motion.relative.x * mouse_sensitivity)
		_camera.rotation.x = clampf(
			_camera.rotation.x - motion.relative.y * mouse_sensitivity,
			deg_to_rad(-89.0),
			deg_to_rad(89.0)
		)
	elif event.is_action_pressed("pause"):
		_toggle_mouse_capture()
	elif event.is_action_pressed("jump"):
		# Проверка разрешения идёт до постановки в очередь: при свободном
		# курсоре персонаж не прыгает.
		if InputGate.is_play_input_allowed(_mouse_mode_for_play_input()):
			_jump_queued = true


func _toggle_mouse_capture() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _physics_process(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta

	var play_input_allowed := InputGate.is_play_input_allowed(_mouse_mode_for_play_input())

	# Очередь прыжка съедается всегда, но поднимает персонаж только пока ввод
	# разрешён: прыжок, разрешённый до отпускания курсора, не должен сработать
	# после него.
	if _jump_queued:
		_jump_queued = false
		if play_input_allowed and is_on_floor():
			velocity.y = jump_velocity

	if play_input_allowed:
		var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

		var current_speed := speed
		if Input.is_action_pressed("sprint") and input_dir != Vector2.ZERO:
			current_speed *= sprint_multiplier

		# Скорость накапливается через move_toward, а не присваивается: за
		# один кадр она меняется максимум на ускорение*delta, поэтому разгон
		# и торможение (цель — ноль при отпущном вводе) конечны по времени,
		# а в пределе move_toward доезжает ровно до цели — установившаяся
		# скорость равна заявленной, остаточного скольжения нет. В воздухе
		# та же механика с air_control: управление слабее, но не отключено.
		var acceleration := ground_acceleration
		if not is_on_floor():
			acceleration *= air_control
		velocity.x = move_toward(velocity.x, direction.x * current_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * current_speed, acceleration * delta)
	else:
		# Горизонтальная скорость обнуляется явно, а не остаётся от прошлого
		# кадра: иначе персонаж едет по инерции при свободном курсоре.
		velocity.x = 0.0
		velocity.z = 0.0

	move_and_slide()

	if global_position.y < fall_limit:
		_respawn()


## Возврат на точку появления. Общий для падения за карту и для смерти: обе
## причины требуют одного и того же — сбросить инерцию, прыжковую очередь и
## наклон камеры.
##
## restore_health сбрасывает ещё и здоровье, и вызывается из take_damage: после
## смерти игрок возвращается полным. Падение за карту этим флагом не
## восстанавливает ничего: сбрасывать по нему здоровье означало бы, что игрок
## бесплатно лечится, стоит ему прыгнуть в пропасть. Различать два вызова
## флагом дешевле, чем писать второй, почти идентичный метод.
func _respawn(restore_health: bool = false) -> void:
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	_jump_queued = false
	_camera.rotation.x = 0.0
	if not restore_health:
		return
	_health = max_health
	health_changed.emit(_health, max_health)
	print("[player] погиб — респавн на точке появления, здоровье восстановлено до %.1f" % _health)