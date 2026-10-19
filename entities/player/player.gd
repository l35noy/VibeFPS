extends CharacterBody3D

## Изменилось здоровье: сколько осталось из скольких. Последний аргумент —
## всегда max_health, а не «сколько было», чтобы полоса здоровья не могла
## забыть, на какое число делить.
signal health_changed(current: float, maximum: float)
## Игрок умер. Испускается строго один раз за смерть и до респавна: подписчик
## должен успеть увидеть нулевое здоровье, а не уже восстановленное.
signal died()
## Сменилось текущее оружие игрока. Испускается при готовности игрока (и, в
## будущем — Task 10 — при свопе оружия): HUD пере-привязывает счётчик патронов
## по этому сигналу, а не хватает оружие из сцены сам. `weapon` может быть null,
## если в сцене оружия нет (лобби, макетка): это «оружия нет», а не ошибка.
signal weapon_changed(weapon: Node)

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

## Радиус, в котором игрок видит интерактивные точки (E по близости, а не по
## прицелу). 3.5 м, а не 2.5: витрина в лобби стоит в трёх метрах от точки
## появления игрока, и решение R2 зафиксировало именно это значение.
const _INTERACT_RANGE := 3.5

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _jump_queued: bool = false
var _spawn_transform: Transform3D = Transform3D.IDENTITY
## Текущее здоровье — отдельное поле рядом с max_health, а не вместо него:
## «сколько максимум» — потолок, который за бой не меняется, а «сколько
## осталось» меняется и после смерти обязана вернуться к этому потолку.
var _health: float = 0.0
## GameState, на `equipped_changed` которого подписан игрок (Task 10). Хранится
## полем, чтобы отписаться в `_exit_tree`, когда узла уже нет в дереве и путь
## `/root/GameState` не разрешается. Без автозагрузки остаётся null.
var _game_state: Node = null

@onready var _camera: Camera3D = $Camera3D
## Пистолет игрока. Может отсутствовать: лобби Фазы 4 и любые сцены без
## оружия создают того же персонажа, и требовать в каждой из них узел с
## характеристиками оружия было бы требованием к сцене, а не к игроку.
@onready var _pistol: Pistol = get_node_or_null("Pistol") as Pistol
## Хитбокс игрока. Может отсутствовать по той же причине, что и пистолет:
## подключение урона — это проводка сцены, и сцена без хитбокса (лобби, отладочные
## макетки) обязана оставаться рабочей, а не падать в _ready().
@onready var _hurtbox: Hurtbox = get_node_or_null("Hurtbox") as Hurtbox
@onready var _ui: CanvasLayer = get_node_or_null("UI") as CanvasLayer


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
	_connect_equipped_changed()
	# Ствол в руках приводится к купленному ДО эмита стартового состояния:
	# подписчик weapon_changed должен увидеть уже правильное оружие, а не
	# пистолет по умолчанию из сцены. Без /root/GameState (тесты, макетки)
	# остаётся дефолтный Pistol, и ничего не меняется.
	apply_equipped_weapon()
	if _pistol != null:
		# Контракт смены сцены, а не гигиена: полупустой магазин, переживший
		# поездку в лобби и обратно, стоил бы игроку бесплатных патронов при
		# каждом входе в бой.
		_pistol.reset_for_scene_change()
	# Стартовое состояние HUD идёт сигналами, а не чтением полей: дочерний HUD
	# входит в дерево раньше игрока (дети — до родителя), поэтому к этому моменту
	# он уже подписан, и полоса здоровья и счётчик патронов заполняются без
	# пустого первого кадра и без опроса из HUD. Порядок обязателен: сначала
	# состояние (здоровье, сброшенный магазин), потом сигнал о нём.
	health_changed.emit(_health, max_health)
	weapon_changed.emit(_pistol)


## Текущее оружие игрока или null, если оружия в сцене нет. Публичный доступ:
## HUD привязывается к нему при готовности, а Task 10 будет через него же менять
## оружие. Возвращает Node, а не Pistol: HUD не должен знать класс оружия.
func current_weapon() -> Node:
	return _pistol


## Привести ствол в руках к `GameState.equipped_weapon_id`.
##
## Слот оружия — узел с именем "Pistol" (см. player.tscn): и пистолет, и
## автомат занимают одно и то же место в руке, а не стоят рядом. Замена узла, а
## не подмена оружия внутри: у каждого ствола своя сцена (меши, дуло, ресурс
## данных), и собирать её полями значило бы держать два описания одного оружия.
##
## Трансформ руки сохраняется: позиция и доворот ствола — свойство места в руке
## игрока, а не конкретной сцены оружия, и потерять их при свопе значило бы
## смотреть на ствол из другого места.
##
## Идемпотентность проверяется по `scene_file_path`: если в руке уже сцена,
## которую просит GameState, ничего не меняется (иначе стартовый `_ready` и
## восстановленный сейв пересоздавали бы один и тот же ствол и сбрасывали
## магазин на каждом входе). Нет слота (`_pistol == null`) — сцене оружие не
## нужно, и добавлять его сюда нельзя: «нет оружия» — законное состояние лобби
## и макеток. Без /root/GameState — дефолтный Pistol сцены, как есть.
func apply_equipped_weapon() -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs == null:
		return
	var target_path: String = gs.weapon_scene_path(gs.equipped_weapon_id)
	if target_path.is_empty():
		return
	if _pistol == null:
		return
	if _pistol.scene_file_path == target_path:
		return
	var scene := load(target_path) as PackedScene
	if scene == null:
		return
	var replacement := scene.instantiate() as Pistol
	if replacement == null:
		return
	var slot := _pistol
	var hand_transform := slot.transform
	var slot_index := slot.get_index()
	# Сначала освободить имя у старого слота, потом занять его новым: add_child()
	# при конфликте имён молча переименовал бы новый узел в "Pistol2", и слот
	# перестал бы находиться по имени.
	remove_child(slot)
	replacement.name = "Pistol"
	replacement.transform = hand_transform
	add_child(replacement)
	move_child(replacement, slot_index)
	slot.queue_free()
	_pistol = replacement
	_pistol.reset_for_scene_change()
	weapon_changed.emit(_pistol)


## Смена экипировки в GameState: поменять ствол в руках. Аргумент-идентификатор
## не используется: сцена берётся из того же поля GameState, чтобы источник
## истины был один, а не два, которые могут разойтись.
func _on_equipped_changed(_weapon_id: String) -> void:
	apply_equipped_weapon()


## Подписка на сигнал хитбокса, а не чтение его полей: связь «попадание → минус
## здоровье» обязана быть найдена самой сценой, иначе урон пришлось бы искать
## вручную в каждом новом месте, где кто-то решит перебирать хитбоксы.
func _connect_hurtbox() -> void:
	if _hurtbox != null and not _hurtbox.damage_taken.is_connected(take_damage):
		_hurtbox.damage_taken.connect(take_damage)


func _exit_tree() -> void:
	_disconnect_focus_recapture()
	_disconnect_equipped_changed()


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
	_die("death")


## Единственный переход «смерть»: испустить died ровно один раз и уйти из боя.
##
## Порядок обязателен: сигнал уходит раньше перехода, иначе подписчик увидел бы
## уже сменённую сцену и не смог бы отличить смерть от чего-либо ещё. Здоровье к
## этому моменту уже 0 — его обнуляет вызывающий (take_damage или ветка падения),
## а не сам _die, чтобы контракт «в момент died здоровье 0» был виден в одном
## месте с причиной смерти.
##
## Фаза 3 меняет контракт смерти: смерть больше не «респавн на месте», а возврат
## в лобби. Переход идёт через GameState — единственную дверь смены сцены (спека
## §6.1), поэтому в тестах её можно подменить записывающей заглушкой. Без
## /root/GameState (headless-проверки, сцены без автозагрузки) остаётся прежний
## респавн на месте с восстановлением здоровья: это fallback для тестов, а не
## второй контракт смерти.
##
## reason различает причины («death» — летальный урон, «fall» — падение за
## kill-plane). На смену сцены он пока не влияет; параметр заведён под будущие
## экраны смерти.
func _die(reason: String) -> void:
	died.emit()
	var gs := get_node_or_null("/root/GameState") as GameState
	if gs != null:
		gs.return_to_lobby(reason)
	else:
		_respawn(true)  # fallback: headless-проверки и сцены без автозагрузки


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


## Открыто ли в данный момент модальное окно интерфейса (инвентарь).
func is_modal_active() -> bool:
	if _ui != null and _ui.has_method("is_modal_open"):
		if bool(_ui.call("is_modal_open")):
			return true
	var tree := get_tree()
	if tree != null:
		for node in tree.get_nodes_in_group("modal_ui"):
			if node.has_method("is_open") and bool(node.call("is_open")):
				return true
	return false


func _on_focus_entered() -> void:
	if is_modal_active():
		return
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


## Подписка на смену экипировки в GameState (Task 10). Без автозагрузки
## (тесты, макетки) подписываться не на что — и это не ошибка.
##
## Ссылка на GameState хранится полем, а не переигрывается из пути в
## `_disconnect_*`: к моменту `_exit_tree` узел может быть уже вне дерева, и
## `/root/GameState` оттуда не разрешается.
func _connect_equipped_changed() -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs == null or not gs.has_signal("equipped_changed"):
		return
	_game_state = gs
	if not gs.equipped_changed.is_connected(_on_equipped_changed):
		gs.equipped_changed.connect(_on_equipped_changed)


## Отписка с проверкой is_connected: GameState — автозагрузка и переживает
## игрока, а повторная сцена создаёт игрока заново; без отписки второй вход
## упал бы на "signal already connected".
func _disconnect_equipped_changed() -> void:
	if not is_instance_valid(_game_state):
		return
	if _game_state.equipped_changed.is_connected(_on_equipped_changed):
		_game_state.equipped_changed.disconnect(_on_equipped_changed)
	_game_state = null


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
	elif event.is_action_pressed("interact") and InputGate.is_play_input_allowed(_mouse_mode_for_play_input()):
		# Взаимодействие — игровой ввод, тот же гейт, что у огня и движения:
		# со свободным курсором E ничего не делает. Поглощено, чтобы сцена
		# ниже по стеку не получила ту же клавишу повторно.
		_try_interact()
		get_viewport().set_input_as_handled()


func _toggle_mouse_capture() -> void:
	if is_modal_active():
		return
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


## Ближайшая интерактивная точка в радиусе _INTERACT_RANGE, иначе null.
## Публичный: окрестностям лобби (подсветка точки) он понадобится, а тесту —
## чтобы зафиксировать сам радиус.
func nearest_interactable() -> Node:
	var nearest: Node = null
	var nearest_dist := _INTERACT_RANGE
	for node in get_tree().get_nodes_in_group("interactable"):
		# Точка взаимодействия — Area3D, а значит Node3D; узел без мировой
		# позиции в выборку не попадёт. Проверка на дерево — чтобы узел,
		# ожидающий удаления, не попал в ответ.
		if not (node is Node3D):
			continue
		if not node.is_inside_tree():
			continue
		var dist := global_position.distance_to((node as Node3D).global_position)
		if dist > _INTERACT_RANGE:
			continue
		if nearest == null or dist < nearest_dist:
			nearest = node
			nearest_dist = dist
	return nearest


## Выполнить взаимодействие с ближайшей точкой. false, если точки нет, у неё
## нет протокола interact или сам вызов вернул отказ.
func _try_interact() -> bool:
	var target := nearest_interactable()
	if target == null or not target.has_method("interact"):
		return false
	return bool(target.call("interact", self))


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
		# Падение за kill-plane — это смерть, а не тихий респавн: здоровье
		# обнуляется ДО сигнала, чтобы подписчик died увидел мёртвого игрока
		# (тот же контракт Task 5, что у летального урона). Гейт is_alive()
		# гарантирует ровно один вход: без /root/GameState срабатывает
		# fallback-респавн и игрок вытащен выше kill-plane; с GameState, но
		# подменённым scene_changer, сцена не меняется и игрок остаётся ниже
		# kill-plane — однако со нулевым здоровьем, и ветка больше не заходит.
		if is_alive():
			_health = 0.0
			health_changed.emit(_health, max_health)
			_die("fall")


## Возврат на точку появления. Fallback-механика: вызывается из _die() только
## когда /root/GameState нет (headless-проверки, сцены без автозагрузки), а при
## restore_health ещё и возвращает полное здоровье. В проде и урон, и падение
## уходят в лобби через GameState и сюда не попадают.
##
## Флаг оставлен, чтобы различать два смысла вызова: чистый сброс положения
## (restore_health = false, здоровье не трогается) и «смерть без GameState»
## (restore_health = true, игрок возвращается полным). Сегодня _die() зовёт
## только вторую форму; первая — запас на случай сцены, которой нужно вытащить
## игрока из пустоты без лечения. Дешевле, чем второй, почти идентичный метод.
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
