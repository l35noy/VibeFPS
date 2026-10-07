class_name Pistol
extends Node3D

## Пистолет: магазин, темп стрельбы, перезарядка, огонь.
##
## Характеристики приходят из `WeaponData`, поведение живёт здесь. Одно
## оружие — один скрипт, параметризованный ресурсом: второго оружия в Фазе 1
## нет, а иерархия «под будущее» — это код, который никто не запускает.
##
## Шесть решений, каждое из которых проверка закрепляет:
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
	if Input.is_action_pressed("fire"):
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


## Откуда стрелять. Заданный источник, иначе камера игрока — выстрел должен
## уходить туда, куда смотрит глаз. Если камеры нет (пистолет проверен без
## игрока), стреляем от самого оружия.
func _muzzle() -> Node3D:
	if fire_rate_source != null:
		return fire_rate_source
	var viewport := get_viewport()
	if viewport != null:
		var camera := viewport.get_camera_3d()
		if camera != null:
			return camera
	return self


## Снаряд из `projectile_scene` или `null`, если выстрела не будет.
##
## Узел добавляется в дерево ДО `launch()`: `Projectile._ready()` выключает
## свою обработку и включает её только `launch()`, поэтому вызов до входа в
## дерево был бы затёрт этим же `_ready()` — снаряд висел бы в мире
## неподвижным.
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
	# Передняя ось источника, а не ось мира: пистолет поворачивается вместе с
	# игроком, и снаряд должен уходить туда, куда он направлен.
	var direction := -muzzle.global_transform.basis.z
	muzzle.add_child(projectile)
	projectile.call("launch", direction)
	return projectile