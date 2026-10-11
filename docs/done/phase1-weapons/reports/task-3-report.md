> **Назначение:** Отчёт по задаче фазы.

# Task 3 — Пистолет: магазин, перезарядка, огонь — отчёт исполнителя

**Файлы во владении:** созданы `scripts/pistol.gd` и `tests/weapon.gd`.
Ничего больше не менялось. `weapon_data.gd`, `projectile.gd`, `hurtbox.gd`, `data/`,
`tools/run_checks.ps1`, `player.gd`, `player.tscn`, `main.tscn` не тронуты.

**Коммит и `git add` не выполнялись.** Ни одного коммита, ничего не в индексе —
проверено `git diff --cached --stat` (пусто) и `git log --oneline -3` (последний
коммит `11541c8`, тот же, что был до начала работы). Всё осталось непроиндексированным.

---

## 1. Итог

| | |
|---|---|
| Проверок в `tests/weapon.gd` | **126** утверждений |
| Красный прогон (до `scripts/pistol.gd`) | `weapon FAIL (exit code 1)`, Parse Error: `Could not resolve super class path "res://scripts/pistol.gd"` |
| Зелёный прогон | `RESULT: 8 passed, 0 failed, 4 skipped`, код 0, без `[WARN]` |
| Прямой запуск | код 0, 126 `[PASS]`, 0 `[FAIL]`, **stderr — 0 байт**, 9.5 с |
| Мутаций выполнено | 3, все дали красное, все восстановлены побайтово |

---

## 2. Финальное содержимое `scripts/pistol.gd`

```gdscript
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
## перезагрузку бесконечно.
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
```

**`reset_for_scene_change()` — не мёртвый код.** Он написан сейчас, до того как
кто-либо его вызовет, потому что вызывать его будет Фаза 4 (лобби) из
`player.gd::_ready()`. Причина контракта: лобби и локация создают игрока
заново, и полупустой магазин, переживший смену сцены, дал бы игроку бесплатные
патроны каждый раз. Сейчас его закрепляют 7 утверждений проверки, включая
отменённый таймер перезарядки и обнуление темпа стрельбы. Создавать его позже
означало бы либо окно, в котором поведение не закреплено, либо правку
`pistol.gd` в Фазе 4 — то есть изменение файла, у которого уже есть владелец.

---

## 3. Устройство проверки

`tests/weapon.gd` — самостоятельный `SceneTree`-скрипт, заканчивается
`quit(0)`/`quit(1)`.

* **Игрока нет.** Пистолет строится в коде, источник выстрела — фиктивный
  `Node3D`, мир — пустой `Node3D`. Игрок не создаётся и не двигается.
* **Шов гейта — тот же, что в `tests/movement.gd`.** Внутренний класс
  `_PistolProbe extends "res://scripts/pistol.gd"` переопределяет
  `_mouse_mode_for_play_input()`. Headless не умеет захватывать курсор, поэтому
  подменяется только значение, попадающее в гейт. Подкласса из
  `tests/movement.gd` не потребовалось: фаза 0 не создавала под-агента, фаза 1
  существует отдельно и не должна зависеть от харнесса фазы 0.
* **Снаряд — PackedScene, собранный в памяти.** `Projectile` с
  `CollisionShape3D`/`SphereShape3D` упакован в `PackedScene.pack()` и передан
  пистолету ровно так, как это сделает `pistol.tscn` в Task 5. Никаких `.tscn`
  не создано.
* **Ожидания ограничены секундами стенного часа, а не кадрами.** Таймеры
  оружия — сам предмет проверки, и они в секундах; ожидание по кадрам проверяло
  бы частоту кадров headless, а не скорострельность.
* **`_ready()` не синхронен.** Движок ставит новый узел в очередь и выполняет
  `_ready()` на одном из следующих проходов главного цикла, а не внутри
  `add_child()`. `_new_pistol()` ждёт `is_node_ready()`. Без этого «у свежего
  пистолета полный магазин» измерялось бы на узле, чей `_ready()` ещё не
  отработал: первые четыре пистолета этой проверки давали `current_mag() == 0`.
* **Позиция наблюдения.** `await process_frame` возвращается на сигнал
  `process_frame`, который движок испускает **до** вызовов `_process`, поэтому
  утверждение сразу после `await` наблюдает состояние на конец предыдущего
  кадра. Это позволяет, например, отдельно утверждать «пустой магазин запрещает
  огонь» от «идёт перезарядка».

---

## 4. Все 126 утверждений и какой дефект каждое ловит

### 4.1 Контракт исходника (4) — то, что не видно поведением

| Утверждение | Ловит |
|---|---|
| `pistol.gd is readable` | Отсутствующий/нечитаемый файл |
| `pistol.gd runs its timers in _process` | Перенос таймеров в `_physics_process`: стрельба стала бы частью физической симуляции |
| `pistol.gd declares no _physics_process` | Тот же дефект с другой стороны (появление метода) |
| `can_fire() asks InputGate for permission` | `can_fire()`, читающий `Input.mouse_mode` напрямую или вообще без гейта: действие `fire` стало бы обходом гейта |

### 4.2 Контракт класса и экспортов (18) — то, на что Task 5 собирает сцену

| Утверждение | Ловит |
|---|---|
| `pistol.gd loads` | Отсутствующий скрипт |
| `declares class_name Pistol` | Переименование класса |
| `extends Node3D` | Смена базового типа |
| `exposes can_fire/try_fire/start_reload/current_mag/is_reloading/reset_for_scene_change` (6) | Переименование любого из шести методов контракта |
| `exposes the fired / reload_started / reload_finished / magazine_changed signal` (4) | Переименование любого из четырёх сигналов |
| `magazine_changed carries (current, capacity)` | Изменение арности сигнала: HUD с двумя лямбдами сломался бы |
| `data is a WeaponData export` | Смена типа экспорта: pistol.tscn не смог бы назначить ресурс |
| `projectile_scene is a PackedScene export` | То же |
| `fire_rate_source is a Node3D export` | То же |
| `fire_rate_source is empty by default` | Назначение источника по умолчанию: Task 5 оставляет поле пустым, чтобы пистолет взял камеру игрока |

### 4.3 Шов гейта (4) — иначе все «гейт запрещает огонь» проходят не по той причине

| Утверждение | Ловит |
|---|---|
| `the untouched pistol.gd asks the engine for the mouse mode` | Подмена шва, при которой настоящий `pistol.gd` вообще не читает `Input.mouse_mode` |
| `precondition: headless really cannot capture the cursor` | Среду, в которой проверка гейта потеряла бы смысл |
| `the gate allows play input while the cursor is captured` | Поломка самого `InputGate` (положительная половина) |
| `the gate denies play input while the cursor is free` | Поломка самого `InputGate` (отрицательная половина) |

### 4.4 Стартовое состояние (5)

| Утверждение | Ловит |
|---|---|
| `a fresh pistol starts with a full magazine (got 10 of 10)` | Пустой магазин на старте: игрок начинает с игры без патронов. Ловит и ошибку «`_ready()` не выставил магазин» — именно её дал первый прогон с неготовым узлом |
| `a fresh pistol is not reloading` | Залипший флаг перезарядки на старте |
| `a fresh pistol with valid data can fire` | `can_fire()`, всегда возвращающий `false`: без этой положительной половины все следующие «выстрел отказ» были бы холостыми |
| `nothing fired just by existing` | Побочный выстрел в `_ready()`/`_process` |
| `magazine_changed stays quiet on start` | Сигнал, испускаемый на каждом появлении узла: HUD перерисовывает счётчик без причины |

### 4.5 Один выстрел (11)

| Утверждение | Ловит |
|---|---|
| `try_fire() reports the shot it made` | `try_fire()`, всегда возвращающий `false` |
| `the magazine lost exactly one round (got 9)` | Магазин, не уменьшающийся, или уменьшающийся не на один |
| `fired arrived exactly once (got 1)` | Двойной выстрел или пропавший сигнал |
| `magazine_changed arrived once for the shot` | Пропущенный или дублированный сигнал |
| `magazine_changed carries the new count and the capacity [(9, 10)]` | Сигнал с чужими значениями (например, всегда `(10, 10)`) |
| `exactly one projectile node was spawned (got 1)` | Выстрел без снаряда или два снаряда на один выстрел |
| `the projectile takes its speed from the weapon data (40.0 m/s)` | Снаряд, летящий на значении по умолчанию вместо данных оружия |
| `the projectile takes its damage from the weapon data (30.0)` | То же для урона |
| `the projectile takes its lifetime from the weapon data (3.0 s)` | То же для времени жизни |
| `the projectile is flying, so launch() was called on a node already in the tree (moved 0.667 m)` | `launch()`, вызванный **до** `add_child()`: `Projectile._ready()` затирает включение обработки, снаряд висит неподвижным |
| `it leaves along the fire source's forward axis (1.000)` | Направление из оси мира вместо оси источника |

### 4.6 Направление следует за источником (4)

Источник повёрнут на −90° по yaw, поэтому «вперёд» — это +X.

| Утверждение | Ловит |
|---|---|
| `the shot was fired` | Полностью неработающий огонь (общая предпосылка) |
| `one projectile was spawned (got 1)` | Отсутствие снаряда |
| `the shot left along the turned fire source, not along -Z (dx=0.667 m)` | Зашитый `-Vector3.FORWARD`: пуля улетает в стену вместо цели |
| `and left no trace along the world Z axis it was not aimed at (dz=0.000 m)` | Направление с неправильной осью, дающее ненулевой Z |

### 4.7 Десять патронов, пустой магазин, своя перезарядка (20)

Кнопка `fire` зажата с первого кадра — десять патронов тратятся через реальный
входной путь, а не вызовом `try_fire()` за спиной у пистолета.

| Утверждение | Ловит |
|---|---|
| `holding fire empties the magazine in 10 rounds (got 10)` | `_process`, не читающий `Input.is_action_pressed("fire")`: оружие не стреляет вовсе |
| `the magazine is empty (got 0)` | Магазин, не тратящийся |
| `can_fire() is false on an empty magazine` | `can_fire()`, не спрашивающий магазин. Считается **до** истечения темпа, поэтому отказ принадлежит магазину, а не кулдауну |
| `the eleventh try_fire() is refused` | Огонь без ограничения по числу патронов |
| `the refused shot left the magazine at 0` | Магазин, ушедший в минус |
| `no eleventh round left the magazine (got 10 signals)` | Одиннадцатый выстрел, проскочивший в сигнал |
| `the empty magazine starts a reload without being asked` | Отсутствие автоматической перезарядки: игрок обязан помнить про R |
| `the pistol reports itself reloading` | `is_reloading()`, не отражающий состояние |
| `exactly one reload was started (got 1)` | Перезагрузка, начинающаяся дважды |
| `a held fire button spends no rounds while the magazine is empty (got 10)` | Выстрел по пустому магазину. **Закрывает пункт 1 раздела Review Focus плана:** пустой магазин и нажатие огня в один кадр |
| `the reload finished on its own` | Перезарядка, которая не кончается |
| `the reload took about 1.2 s (got 1.200 s)` | Таймер перезарядки, взятый не из данных (удвоенный, обрезанный, в кадрах вместо секунд) |
| `the magazine is full again (got 10)` | Магазин, не добирающийся до ёмкости |
| `the pistol is no longer reloading` | Залипший флаг перезарядки |
| `reload_finished arrived exactly once (got 1)` | Пропущенный или дублированный сигнал |
| `magazine_changed announced the refilled magazine [(10, 10)]` | HUD не узнал бы о новом магазине |
| `the pistol can shoot again after the reload` | Пистолет, навсегда застрявший после перезарядки |
| `a press right after the reload fires at once: no stuck cooldown (got 11 shots)` | Перенос темпа стрельбы на момент перезарядки: сцена сцены не смогла бы стрелять сразу послеReload. **Это то самое поведение, ради которого кнопка отпускается до конца перезарядки** — и оно закреплено намеренно |
| `and that press cost exactly one round (got 9)` | Двойное списание при выстреле сразу после перезарядки |

### 4.8 Перезарядка как стена и запрет перезапуска (11)

Магазин частично полон (9 из 10), темп истекает на 0.5 с из 1.2 с — то есть
окно, в котором сломанная проверка перезарядки обязательно выдаст патрон.

| Утверждение | Ловит |
|---|---|
| `precondition: nine rounds are left (got 9)` | Общая предпосылка сценария |
| `a spent magazine accepts a reload` | `start_reload()`, всегда возвращающий `false` |
| `the pistol reports itself reloading` | `is_reloading()`, не отражающий состояние |
| `reload_started arrived once (got 1)` | Пропущенный или дублированный сигнал |
| `precondition: half the reload went by with the button still held` | Сценарий, который не дошёл до своей середины |
| `a held fire button spends no rounds while reloading, even with rounds left (got 1 shots)` | **Мутация A.** Снаряд выходит через ~0.5 с, когда кулдаун истёк, а магазин не пуст |
| `start_reload() refuses to restart a reload in progress` | **Мутация B.** Перезапуск, сбрасывающий таймер: игрок откладывает перезарядку бесконечно |
| `the refused restart did not cancel the reload either` | Перезапуск, попутно сбрасывающий и сам факт перезарядки |
| `the reload still finished` | Перезарядка, которая не кончается |
| `the reload still took about 1.2 s in total (got 1.200 s)` | Удвоенный или сдвинутый таймер |
| `the refused restart did not push the timer back to the full reload time (0.599 s left …)` | **Мутация B, вторая половина.** Возврат таймера к полному `reload_time` оставил бы 1.2 с вместо 0.6 с |
| `still exactly one reload was started (got 1)` | Перезапуск, испускающий второй `reload_started` |
| `not one round came out of the reload, held or not (got 1 shots)` | Итоговое состояние сценария: любой патрон, списанный перезарядкой |
| `the reload refilled the magazine (got 10)` | Магазин, не добирающийся до ёмкости после перезагрузки |

### 4.9 Темп стрельбы (10)

| Утверждение | Ловит |
|---|---|
| `precondition: the shipped data asks for one shot per 0.5 s (got 0.5000 s)` | Расхождение данных оружия с ожиданием проверки |
| `the first shot is allowed` | Огонь, запрещённый без причины |
| `a second shot in the same frame is refused by the interval` | Отсутствие темпа вообще: два выстрела в один кадр |
| `only one round left the magazine (got 1)` | Списание двух патронов |
| `the refused second shot cost no round (got 9)` | Списание патрона за выстрел, который не состоялся |
| `the next shot is allowed once the interval has passed (got 0.501 s and 73 process frames)` | Кулдаун, который не истекает никогда: оружие стреляет один раз и замолкает |
| `the second shot waited at least the full interval (>= 0.45 s)` | Скорострельность выше заданной |
| `and did not wait much longer than the interval (<= 0.85 s)` | Интервал, удвоенный или измеряемый в кадрах: на другой частоте кадров пистолет стрелял бы медленнее |
| `exactly two rounds left the magazine (got 2)` | Выстрел, потерянный или списанный дважды |

Замер: `0.501 с и 73 кадра process`. Кадры в утверждении не участвуют — только
в печати. Это и есть заявление «темп в секундах, а не в кадрах».

### 4.10 Гейт ввода (11)

| Утверждение | Ловит |
|---|---|
| `precondition: the pistol under test runs the harness probe script` | Мёртвый шов: дальнейшие «гейт запрещает» прошли бы не по той причине |
| `can_fire() is false while the cursor is free` | Гейт, выпавший из `can_fire()` |
| `try_fire() refuses while the cursor is free` | Прямой вызов в обход гейта |
| `a held fire action shoots nothing while the cursor is free (got 0)` | **`_process`, читающий `fire` без гейта:** зажатая кнопка стреляет при отпущенном курсоре |
| `the gated pistol kept every round (got 10)` | Списание патронов на запрещённый выстрел |
| `and announced nothing to a HUD either` | Сигналы на выстрел, которого не было |
| `can_fire() is true again once the cursor is captured` | Гейт, залипший в закрытом состоянии |
| `the same held input fires as soon as the gate opens (got 1 shots)` | **Мёртвый гейт:** та же кнопка не даёт выстрела и при разрешённом вводе. Без этой половины отрицательная ничего не доказывает |
| `holding fire still does not shoot past the rate limit (got 1 shots)` | Отсутствие темпа на пути ввода |
| `exactly one round was spent by the ungated press (got 9)` | Несколько выстрелов на одно нажатие |

### 4.11 Полный магазин перезаряжать нечего (6)

| Утверждение | Ловит |
|---|---|
| `a full magazine refuses the reload` | Перезагрузка, которая заканчивается без единого изменения состояния |
| `no reload was announced (got 0)` | `reload_started` без реальной перезарядки |
| `and the pistol is not reloading` | Залипший таймер после отказа |
| `the magazine is untouched (got 10)` | Обнуление магазина при отказе |
| `a round comes out as usual` | Отказ, который заблокировал и обычную стрельбу |
| `and now the reload is accepted` | Правило «полный магазин», которое запрещает перезарядку вообще |

### 4.12 Контракт смены сцены (8)

| Утверждение | Ловит |
|---|---|
| `precondition: the magazine is partly spent (got 9)` | Общая предпосылка |
| `precondition: a reload is in progress` | Общая предпосылка |
| `the magazine is full again after a scene change (got 10)` | **Прямое обещание Фазы 4:** полупустой магазин, переживший поездку в лобби, = бесплатные патроны каждый раз |
| `the reload is cancelled` | Перезарядка, пережившая смену сцены |
| `the pistol can shoot again` | Пистолет, оставшийся заблокированным |
| `the reset is announced, so a HUD is not left showing a stale count` | HUD со старым счётчиком после смены сцены |
| `a cancelled reload never claims to have finished (got 0)` | `reload_finished` без реального завершения: звук/анимация перезарядки без патронов |
| `the first shot of the new scene is not rate limited` | Перенос кулдауна через смену сцены: первый кадр новой сцены «мёртв» |

### 4.13 Вырожденные данные (8)

| Утверждение | Ловит |
|---|---|
| `precondition: the shipped data lets the pistol fire` | Без положительной половины все отказы ниже проходят вхолостую |
| `a zero-capacity magazine starts empty (got 0)` | Магазин, стартующий не из данных |
| `can_fire() is false for a zero magazine size` | `is_valid()`, не спрашиваемый оружием: ресурс с нулевым магазином ломает темп/перезарядку |
| `try_fire() refuses to shoot with a zero magazine size` | Выстрел при `magazine_size = 0` |
| `and there is nothing to reload either` | Бесконечная перезагрузка без патронов |
| `nothing fired (got 0)` | Выстрел при запрещённых данных |
| `and no round was invented (got 0)` | Магазин, ушедший в минус |
| `a zero fire rate is refused rather than dividing by zero` | Деление на ноль в `seconds_between_shots()` → бесконечный кулдаун, оружие стреляет один раз навсегда |

### 4.14 Провалившееся инстанцирование (7)

| Утверждение | Ловит |
|---|---|
| `precondition: this pistol has no projectile scene at all` | Общая предпосылка |
| `precondition: it is otherwise ready to shoot` | Общая предпосылка: без неё отказ ниже может идти по другой причине |
| `a pistol with no projectile scene cannot shoot` | Выстрел без снаряда |
| `the round is still in the magazine: instantiate first, decrement after (got 10 of 10)` | **Мутация C.** Порядок «сначала уменьшить, потом инстанцировать» — провалившееся инстанцирование съедает патрон |
| `a shot that never happened announced nothing (got 0)` | `fired` на несостоявшемся выстреле |
| `and the magazine never changed` | `magazine_changed` на несостоявшемся выстреле |
| (плюс `the pistol can fire` / `try_fire()` — из 4.2/4.4) | — |

**Итого 126 утверждений.** Ни одно не может пройти наоборот: каждая негативная
половина имеет положительную, каждое измерение имеет предварительное условие,
а три ключевых правила (перезарядка, запрет перезапуска, порядок в `try_fire()`)
доказаны красным прогоном, а не только зелёным.

---

## 5. Красный прогон (до написания `scripts/pistol.gd`)

Проверка написана первой, `scripts/pistol.gd` ещё не существовал.

```
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_checks.ps1 weapon
```

```
importing project (class cache missing or stale) ...
weapon_data    PASS
weapon         FAIL  (exit code 1)
    Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org
    SCRIPT ERROR: Parse Error: Could not resolve super class path "res://scripts/pistol.gd".
       at: GDScript::reload (res://tests/weapon.gd:29)
    ERROR: Failed to load script "res://tests/weapon.gd" with error "Parse error".
       at: load (modules/gdscript/gdscript_resource_format.cpp:46)

RESULT: 1 passed, 1 failed, 0 skipped
EXITCODE=1
```

Падение называет отсутствующий файл поимённо, а не «check failed».
Красное состояние получено **до** написания `scripts/pistol.gd`, а не
восстановлено задним числом.

---

## 6. Зелёные прогоны

Полный набор после восстановления всех мутаций:

```
smoke          PASS
movement       PASS
input_actions  PASS
input_gate     PASS
weapon_data    PASS
integrity      PASS
weapon         PASS
projectile     PASS
enemies        [SKIP]  (tests\enemies.gd not present)
waves          [SKIP]  (tests\waves.gd not present)
save           [SKIP]  (tests\save.gd not present)
progression    [SKIP]  (tests\progression.gd not present)

RESULT: 8 passed, 0 failed, 4 skipped
EXITCODE=0
```

`[WARN]` в выводе нет. `$Tests` не редактировался: `weapon` уже был в списке.

---

## 7. Мутации

Базовый SHA-256 `scripts/pistol.gd` (зелёное состояние):
`38B86F1C344B1D834552FE29F1C267386CD013FD21BECCAF57114690A7AAC12C`

### Мутация A — убрано условие `is_reloading()` из `can_fire()`

```gdscript
	if not InputGate.is_play_input_allowed(_mouse_mode_for_play_input()):
		return false
	if is_reloading():          # <- удалено
		return false
	return _current > 0
```

Результат: `weapon FAIL (exit code 1)`, `=== RESULT: 126 checks, 2 failed ===`

```
[FAIL] a held fire button spends no rounds while reloading, even with rounds left (got 2 shots, the rate limit expired 0.5 s into the reload)
[FAIL] not one round came out of the reload, held or not (got 2 shots)
```

Ровно те два утверждения, которые обязаны падать. Восстановление:
SHA-256 `38B86F1C…12C` — совпадает.

### Мутация B — `start_reload()` разрешён при идущей перезарядке

```gdscript
func start_reload() -> bool:
	if is_reloading():          # <- удалено
		return false
	if not _has_valid_data():
		return false
```

Результат: `weapon FAIL (exit code 1)`, `=== RESULT: 126 checks, 3 failed ===`

```
[FAIL] start_reload() refuses to restart a reload in progress
[FAIL] the refused restart did not push the timer back to the full reload time (1.200 s left after the restart attempt at 0.6 s, expected under 1.00 s)
[FAIL] still exactly one reload was started (got 2)
```

Падает и возвращаемое значение, и **таймер**: вместо 0.599 с остатка осталось
1.200 с — ровно полный `reload_time`. Обе половины контракта «возврат запрещён»
проверены. Восстановление: SHA-256 `38B86F1C…12C` — совпадает.

### Мутация C (выбрана мной) — магазин уменьшается до инстанцирования снаряда

```gdscript
	_current -= 1                          # <- поднято выше
	var projectile := _instantiate_projectile()
	if projectile == null:
		return false
	_cooldown = data.seconds_between_shots()
```

Результат: `weapon FAIL (exit code 1)`, `=== RESULT: 126 checks, 1 failed ===`

```
[FAIL] the round is still in the magazine: instantiate first, decrement after (got 9 of 10)
```

Восстановление: SHA-256 `38B86F1C…12C` — совпадает.

Все три мутации трогали разные утверждения: A — «перезарядка не выдаёт
выстрелов», B — «перезапуск перезарядки запрещён» (значение и таймер), C —
«провал инстанцирования не съедает патрон».

---

## 8. Прямой запуск Godot

PowerShell 5.1 не читает вывод Godot через `2>&1`, поэтому `Start-Process` с
`-RedirectStandardOutput`/`-RedirectStandardError`:

```
E:\Godot\Godot_v4.7.2-stable_win64.exe --headless --path . --script res://tests/weapon.gd
```

```
exit=0   wallclock=9.5s
PASS markers: 126
FAIL markers: 0
=== RESULT: 126 checks, 0 failed ===
stderr bytes: 0
```

**Консольных ошибок нет:** stderr пуст (0 байт). Ни одного `SCRIPT ERROR`,
`ERROR`, `WARNING` или `USER WARNING`. Это важно и потому, что часть дефектов
(например, `queue_free()` на узле вне дерева или `set_deferred` внутри flush
запросов) проявляется только в консоли и никогда не роняет проверку.

Замеры, напечатанные проверкой (реальные числа этого прогона):

```
reload took 1.200 s
reload took 1.200 s; 0.599 s of it were left after the refused restart
second shot after 0.501 s and 73 process frames
travelled (0.666667, 0.0, 0.0)
```

Полный вывод с 126 утверждениями приведён в разделе 4.

---

## 9. Решения, которые бриф оставил открытыми

1. **`can_fire()` не спрашивает темп стрельбы.** Бриф перечисляет ровно четыре
   условия (данные валидны, курсор захвачен, не перезаряжается, магазин не
   пуст), и список исчерпывающий. Поэтому кулдаун держит `try_fire()`, а
   `can_fire()` отвечает на вопрос «имеет ли игрок право стрелять». Побочная
   польза, ради которой это и сделано: «пустой магазин запрещает огонь»
   проверяется независимо от кулдауна — иначе отказ нельзя было бы отнести к
   магазину.

2. **Шов гейта назван так же, как в `player.gd`.**
   `_mouse_mode_for_play_input() -> int` — единственное место в игре, где
   читается `Input.mouse_mode` для гейта. Без него проверка не могла бы
   проверить гейт вообще: headless не захватывает курсор, и пистолет
   запрещал бы всё. Бриф прямо велит переиспользовать приём из `movement.gd`.

3. **Пустой магазин начинает перезарядку сам.** Бриф этого прямо не требует, но
   требует раздел Review Focus (пункт 1: «пустой магазин и нажатие `fire` в один
   кадр»), а этот сценарий невозможно воспроизвести без автоматической
   перезарядки. Реализовано как четвёртый шаг `_process()`.

4. **Перезарядка полного магазина отказом.** Очевидное игровое правило, которое
   бриф не проговаривает: перезарядка полного магазина кончилась бы без
   единого изменения состояния, то есть анимировала бы перезарядку и
   проигрывала звук вхолостую. Закреплено 6 утверждениями, включая
   положительную половину (потраченный патрон перезаряжается).

5. **`magazine_changed` не испускается при старте и при начале перезарядки.**
   Сигнал объявлен как сигнал об *изменении*: при старте число патронов не
   менялось, а при начале перезарядки не меняется тем более. HUD читает
   начальное состояние через `current_mag()`. Закреплено двумя утверждениями
   («не шумит на старте», «в гейте не объявляет ничего HUD-у»).

6. **`reset_for_scene_change()` испускает `magazine_changed`.** Единственное
   место из трёх, где состояние меняется «молча», — но тут HUD обязан узнать:
   после смены сцены у него старое число патронов. Проверено явно.

7. **`fired` испускается раньше `magazine_changed`.** Оба — уже после
   уменьшения магазина, поэтому порядок для слушателя безопасен; выбран тот,
   при котором «выстрел произошёл» приходит первым событием кадра. Бриф
   порядок сигналов не задаёт.

8. **Характеристики снаряда берутся из данных оружия, а не из сцены.**
   `speed`, `damage`, `lifetime` проставляются в инстанс перед `launch()`.
   Иначе `pistol.tscn` в Task 5 держал бы второе место, где живёт урон пули, и
   баланс пистолета правкой `.tres` перестал бы влиять на пулю.

9. **Узел добавляется в дерево до `launch()`.** `Projectile._ready()`
   выключает свою обработку, а `launch()` включает; вызов до входа в дерево был
   бы затёрт этим же `_ready()`, и снаряд висел бы неподвижным. Закреплено
   утверждением «снаряд летит».

10. **Темп и перезарядка измеряются в секундах стенного часа, а не в кадрах.**
    Таймеры оружия — сам предмет проверки и они в секундах. Проверка печатает
    число кадров, но не утверждает по нему: 120 выстр./мин должны остаться
    120 выстр./мин на 240 Гц.

11. **Ожидания ограничены секундами, а не числом кадров.** Обосновано выше;
    иначе проверка зависела бы от частоты кадров headless.

### Отступления от буквы брифа, которые стоит назвать

* Бриф писал «через `1.2 * 120 = 144` кадра физики». Это верно только при
  частоте кадров ровно 120 Гц. Таймер живёт в `_process` и в секундах, поэтому
  проверка ждёт **1.2 с стенного часа** и печатает число кадров рядом. Это
  укрепляет то же утверждение, а не ослабляет его.
* `can_fire()` не содержит условия кулдауна — см. решение 1.

---

## 10. Замечания по окружению

1. **`_ready()` не выполняется синхронно после `add_child()`.** Обнаружено на
   первом зелёном прогоне: первые четыре пистолета показывали
   `current_mag() == 0`, следующие — 10. Причина: движок ставит новый узел в
   очередь и выполняет `_ready()` на одном из следующих проходов главного цикла.
   `_new_pistol()` теперь ждёт `is_node_ready()`; это же относится к любой
   будущей проверке оружия. Ничего в `pistol.gd` менять не пришлось.
2. **Временный файл.** Для проверки двух допущений о движке (`PackedScene.pack()`
   вне дерева и `"поле" in узел`) был создан `tests/_scratch_pack.gd`. Он удалён,
   и вместе с ним удалён сгенерированный движком `tests/_scratch_pack.gd.uid` —
   «висячий» `.uid` на несуществующий скрипт был бы посторонним мусором в
   `git status`. Это единственный `.uid`, который удалён, и он принадлежал
   моему же временному файлу; `.uid` чужих файлов не трогались.
3. **`.uid` для новых файлов создал сам движок** во время автоимпорта, который
   делает раннер: `scripts/pistol.gd.uid` и `tests/weapon.gd.uid`. Вручную я их
   не создавал и не удалял. Так же выглядят `.uid` задач 1 и 2.
4. **Параллельно шла задача 4:** в рабочем дереве появились
   `scripts/player_body_material.tres` и правка `player.tscn`. Они не мои, я их
   не трогал, на результат прогонов не повлияли.
5. **Класс `Pistol` зарегистрировался сам** через автоимпорт раннера
   («importing project (class cache missing or stale) …»). Ошибки
   «type not declared in the current scope» не возникало ни разу; обходных путей
   не понадобилось.

---

## 11. Состояние рабочего дерева

```
 M player.tscn              <- задача 4, не моё
 M tools/run_checks.ps1     <- задача 1 Фазы 1, не моё
?? data/                    <- задача 1
?? scripts/hurtbox.gd(.uid) <- задача 2
?? scripts/pistol.gd        <- моё
?? scripts/pistol.gd.uid    <- моё, создано движком
?? scripts/player_body_material.tres <- задача 4, не моё
?? scripts/projectile.gd(.uid)      <- задача 2
?? scripts/weapon_data.gd(.uid)     <- задача 1
?? tests/projectile.gd(.uid)        <- задача 2
?? tests/weapon.gd         <- моё
?? tests/weapon.gd.uid     <- моё, создано движком
?? tests/weapon_data.gd(.uid) <- задача 1
```

`git diff --cached --stat` — пусто: **ничего не добавлено в индекс**.
`git log --oneline -3` — последний коммит `11541c8`, тот же, что был до начала
работы: **`git commit` не выполнялся**.