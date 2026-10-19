extends SceneTree

## Тестовый сценарий данных и поведения врагов для VibeFPS.
##
## Построен по структуре tests/weapon_data.gd: разделы, [PASS]/[FAIL]
## на каждое утверждение, счётчик проверок, завершение с кодом quit(1) при сбое.
## Загружает res://data/enemies/contact.tres через load() и проверяет параметры,
## которые скрипт врага использует в Фазе 2: числовые значения, тип врага и
## корректность ресурса (is_valid). Узлы сцены в первом разделе не инстанцируются —
## это проверка данных, а проверка данных, собирающая мир для чтения одного числа,
## тестировала бы мир, а не ресурс.
##
## Каждое утверждение проверяет как корректные значения, так и отсечение
## некорректных данных через is_valid(). Без негативных тестов метод с захардкоженным
## возвратом true прошёл бы проверку, видя только эталонный ресурс.
##
## Раздел 2: «Здоровье игрока». Загружает реальную сцену
## res://entities/player/player.tscn, ожидает is_node_ready() и проверяет получение
## урона через собственный узел Hurtbox и реакцию сигналов damage_taken -> take_damage.
##
## Раздел 3: «Контактный враг». Проверяет получение урона врагом из
## res://entities/enemies/contact/enemy_contact.tscn снарядом из
## res://weapons/projectile/projectile.tscn в тестовом мире.
##
## Раздел 4: «Навигация». Проверяет перемещение врага по NavigationRegion3D к цели,
## скорость движения и остановку на заданной дистанции.
##
## Раздел 5: «Проводка сцены». Проверяет тир res://levels/range/range.tscn,
## инициализацию навигационной сетки, наличие целей, врага и игрока.
##
## Запуск:
##   godot --headless --path . --script res://tests/enemies.gd
##   powershell -File .\tools\run_checks.ps1 enemies


const _CONTACT_PATH := "res://data/enemies/contact.tres"
const _PLAYER_PATH := "res://entities/player/player.tscn"
const _ENEMY_PATH := "res://entities/enemies/contact/enemy_contact.tscn"
const _PROJECTILE_PATH := "res://weapons/projectile/projectile.tscn"
const _RANGE_PATH := "res://levels/range/range.tscn"
## Скрипт корня тира. Имя файла проверяется строкой, а не поиском узла по
## поведению: bake — это правило проводки сцены, и если он уедет из range.tscn
## куда-то ещё, проверка должна назвать пропавший файл, а не просто «мир не
## запечёкся».
const _RANGE_SCRIPT_PATH := "res://levels/range/range_scene.gd"
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
## Окно наблюдения НЕ задано числом тиков, а выводится из геометрии мира и
## скорости баланса (см. _route_ticks ниже): при 6 м/с враг проходил маршрут
## быстрее, чем 3 с, и «3 с» работало за счёт скорости, а не за счёт смысла.
## Длина ломаной через единственный проход — это нижняя оценка пути: сглаживание
## Recast срезает углы, зато первые кадры агент тратит на построение пути.
const _NAV_PASS_X := _NAV_WALL_MAX_X + 0.75
## Запас окна на реальность пути: 1.25 — четверть маршрута сверх расчётного
## времени. Подгонять его по факту «дошёл за N тиков» нельзя: число тиков зависит
## от навмеша, а окно обязано пережить его перезапекание.
const _NAV_ROUTE_SAFETY := 1.25
## Скорость БАЛАНСА, под которую считаются окно и пороги маршрута. Константа, а
## не data.move_speed: если окно считать по полю данных, «враг прошёл маршрут»
## становится тавтологией — любая скорость дала бы зелёный результат, потому что
## окно подстроилось бы под неё. Пин означает, что смена скорости в contact.tres
## видна здесь, а не подгоняет проверку молча.
const _NAV_DESIGN_SPEED := 2.0
## Допуск «дошёл» на границе окна. Враг стоит у цели уже половину окна (запас
## выше), а замер снимается на границе тика: половина тика при 2 м/с — это
## 0.008 м, и округление сетки даёт сантиметры. Строгая стоп-дистанция без
## допуска проверяется отдельно, в «остановке у цели».
const _NAV_ARRIVAL_MARGIN := 0.1
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
## target_desired_distance из сцены врага (enemy_contact.tscn). Живёт в харнессе
## как подстановка на случай, когда узла агента нет: проверка поведения обязана
## работать и без него, иначе сцена без агента «проверялась» бы зелёным набором
## «проверять нечего». Значение НЕ равно дефолту движка (1.0) и не равно
## path_desired_distance (1.0), и это разные числа с разными смыслами:
## path_desired_distance — «следующая точка пути засчитана пройденной», а
## target_desired_distance — «до цели достаточно близко, можно останавливаться».
## Второе и есть радиус, на котором враг встаёт у игрока, и контактный урон
## ловится пересечением хитбоксов радиусом 0.4 + 0.4 = 0.8 м, то есть при
## стоп-дистанции 1.0 м враг стоял бы в метре и не бил бы никогда. Отсюда 0.5.
const _NAV_TARGET_DISTANCE := 0.5
## Дрейф у цели: за полсекунды простоя дистанция не должна измениться больше чем
## на 2 см. Враг стоит, а не переминается на месте.
const _NAV_DRIFT_EPS := 0.02

# --------------------------------------------------------------------------
# Phase 3 Task 5: смерть → лобби, очки за убийство врага
# --------------------------------------------------------------------------

## Пробный GameState: тот же класс, что у автозагрузки (Task 3), но с
## записывающим `return_to_lobby` и подменённым `scene_changer`. Смерть игрока
## идёт через него — настоящий change_scene_to_file снёс бы это же дерево.
##
## `return_to_lobby` переопределён, потому что reason не доходит до
## `scene_changer` (GameState зовёт его только с путём сцены): «смерть просит
## лобби» и «смерть просит лобби ПО ПРИЧИНЕ смерти» — разные утверждения, и
## второе видно только изнутри самого вызова.
class _RecordingGameState extends GameState:
	var lobby_reasons: PackedStringArray = []

	func return_to_lobby(reason: String) -> void:
		lobby_reasons.append(reason)
		super.return_to_lobby(reason)


## Пробный GameState, пока он стоит в /root. null означает «в root его нет» —
## ровно то состояние, которого требуют fallback-секция смерти и все проверки
## врага, не ждущие очков.
var _probe_game_state: GameState = null
## Пути, запрошенные у подменённого scene_changer, в порядке вызова.
var _lobby_changes: PackedStringArray = []


## Записывающая заглушка смены сцены: фиксирует запрос и ничего не меняет.
func _fake_scene_changer(path: String) -> void:
	_lobby_changes.append(path)


## Ставит пробный GameState в /root. Имя "GameState" — часть контракта: и
## player.gd, и enemy_contact.gd находят его по пути /root/GameState, а не по
## ссылке, поэтому переименование узла сломало бы обе проверки.
func _install_probe_game_state() -> GameState:
	var gs := _RecordingGameState.new()
	gs.name = "GameState"
	gs.scene_changer = _fake_scene_changer
	root.add_child(gs)
	_probe_game_state = gs
	return gs


## Убирает пробный GameState из /root. Обязательно ДО секций, которым нужен
## fallback: живой /root/GameState меняет контракт смерти.
func _remove_probe_game_state() -> void:
	if _probe_game_state != null and is_instance_valid(_probe_game_state):
		_probe_game_state.queue_free()
	_probe_game_state = null
	await physics_frame


## PackedStringArray vs Array по содержимому: Godot не считает два разных
## контейнера равными, поэтому `packed == ["death"]` было бы false даже при
## совпадении содержимого.
func _packed_strings_eq(packed: PackedStringArray, expected: Array) -> bool:
	if packed.size() != expected.size():
		return false
	for i in packed.size():
		if packed[i] != expected[i]:
			return false
	return true


# --------------------------------------------------------------------------
# Task 5: проводка тира
# --------------------------------------------------------------------------

## Пауза после bake перед первым замером. Карта навигации обновляется в начале
## физического шага, а bake тира заканчивается в _ready() корня сцены; без
## этих тиков первый запрос пути ушёл бы в ещё пустую карту.
const _RANGE_SETTLE_TICKS := 10
## Сколько движущихся кадров нужно, чтобы утверждение «враг шёл» не было пустым
## набором «проверять нечего». Полсекунды движения — тот же минимум, что у
## мирового мира.
const _RANGE_MIN_MOVING_FRAMES := 60
## Окно наблюдения врага в ЗАГРУЖЕННОМ тире считается так же, как у мирового
## мира Task 4 (см. _route_ticks): та же скорость баланса и тот же запас, только
## длиной маршрута здесь служит замеренная дистанция до игрока. Сравнивать два
## мира честно можно только по правилу, а не по совпадению чисел.
##
## Окно прохода врага до игрока и окно ожидания касания после его прихода —
## разные вещи, и склеивать их в одно число нельзя: первое считается из
## маршрута, второе — из каденции. Каденция контакта в тире — дефолт врага
## (contact_interval = 1.0 с, проверено выше), поэтому 2.5 с — это один интервал
## с запасом: меньше окно обрезало бы наблюдение, а не отказ врага.
const _RANGE_CONTACT_INTERVAL := 1.0
const _RANGE_CONTACT_TICKS := 300
## Габарит хитбокса по короткой оси — глобальное решение 1: иначе в него
## физически невозможно попасть снарядом, летящим по центру.
const _HURTBOX_MIN_WIDTH := 0.5
## Минимальная дистанция от врага до игрока в сцене (бриф: враг «в дальнем
## углу, не ближе 4 м»). Меньше — враг стоит на игроке с первой секунды.
const _RANGE_MIN_START_DISTANCE := 4.0

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


## Создаёт временный экземпляр EnemyData с одним переопределённым полем для
## проверки отсечения недопустимых значений методом is_valid().
func _probe(overrides: Dictionary) -> EnemyData:
	var probe := EnemyData.new()
	for key in overrides:
		probe.set(key, overrides[key])
	return probe


## Возвращает true только если is_valid() корректно отклоняет недопустимое
## значение, подтверждая надёжность валидации ресурса.
func _is_valid_rejects(overrides: Dictionary) -> bool:
	return not _probe(overrides).is_valid()


func _finish() -> void:
	print("=== RESULT: %d checks, %d failed ===" % [_checks, _failures.size()])
	for f in _failures:
		print("  FAILURE: %s" % f)


## Прерывает выполнение при нарушении критического предусловия.
## Без этого последующие проверки упали бы с разыменованием null-ссылки,
## приведя к аварийному завершению вместо информативного отчёта.
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

	# Fallback-контракт смерти: без /root/GameState смерть обязана вернуть игрока
	# на точку появления с полным здоровьем (см. Phase 3 Task 5). Проверка имеет
	# смысл только пока GameState в root нет.
	_check(root.get_node_or_null("GameState") == null,
		"precondition: в /root нет GameState — смерть ниже идёт по fallback-ветке (респавн на месте)")

	_died_count = 0
	_health_at_death = -1.0
	_alive_at_death = true
	_health_events.clear()

	var packed: PackedScene = load(_PLAYER_PATH)
	if packed == null:
		_bail("не удалось загрузить %s" % _PLAYER_PATH)
		return
	var player := packed.instantiate()
	if not await _spawn_and_wait(player):
		_bail("%s так и не стал node-ready" % _PLAYER_PATH)
		return
	_check(player.is_node_ready(), "предусловие: player.tscn успешно создан и готов (is_node_ready)")

	print("-- дефолтный Hurtbox сохраняет контракт Фазы 1")
	var plain := Hurtbox.new()
	if not await _spawn_and_wait(plain):
		_bail("экземпляр Hurtbox.new() так и не стал node-ready")
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

	print("-- касаний до смерти игрока (спека 7.2): число выведено из данных")
	var contact := load(_CONTACT_PATH) as EnemyData
	if contact == null:
		_bail("не удалось загрузить %s как EnemyData для проверки выживаемости игрока" % _CONTACT_PATH)
		return
	# Сколько касаний убивает игрока — НЕ зашитое число: оно выводится из тех же
	# двух величин, по которым урон и здоровье берутся в игре (потолок из
	# player.tscn и урон за тик из contact.tres), то есть ceil(max_health /
	# contact_damage). Проверка при этом не арифметика над бумагой, а поведение:
	# выведенное число касаний действительно убивает игрока РОВНО на последнем, и
	# ни на одно касание раньше. Подмена константы в take_damage() или в
	# данных врага ломает её в любую сторону.
	var player_max_health := float(player.get("max_health"))
	var hits_to_death := int(ceil(player_max_health / contact.contact_damage))
	player.died.connect(_on_player_died.bind(player))
	player.health_changed.connect(_on_player_health_changed)
	var survived := 0
	for i in hits_to_death:
		player.call("take_damage", contact.contact_damage)
		if _died_count == 0:
			survived += 1
	_check(_died_count == 1 and survived == hits_to_death - 1,
		"игрок гибнет ровно на %d-м касании контактного врага (ceil(max_health / contact_damage))" % hits_to_death,
		"(выдержал %d касаний из %d; max_health %.4f, contact_damage %.4f)" % [
			survived, hits_to_death, player_max_health, contact.contact_damage])

	# Дальше идёт проверка проводки, и она начинается со СВОЕГО цикла урона:
	# респавн вернул игроку полное здоровье (смерть выше это уже сделала), но
	# счётчики сигналов живут в харнессе и пережили тот цикл — их надо сбросить,
	# иначе «died ровно один» ниже посчитал бы смерть и отсюда.
	print("-- счётчики сигналов сброшены: дальше свой цикл урона, с нуля")
	_died_count = 0
	_health_at_death = -1.0
	_alive_at_death = true
	_health_events.clear()

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

	print("-- десятое попадание: смерть и немедленный респавн (fallback без GameState)")
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


## Смерть при живом GameState: возврат в лобби причиной "death", а не респавн на
## месте. Отсутствие респавна наблюдается по состоянию игрока: если бы
## `_respawn(true)` отработал, здоровье вернулось бы к max_health, а игрок снова
## стал бы живым — оба признака обязаны остаться прежними.
func _test_death_returns_to_lobby() -> void:
	print("-- смерть → лобби при живом GameState (Phase 3 Task 5)")

	_check(root.get_node_or_null("GameState") == null,
		"предусловие: до установки GameState в /root его нет — смерть ниже пойдёт по новому контракту")

	var world := _new_world()
	_add_floor(world)
	var packed: PackedScene = load(_PLAYER_PATH)
	if packed == null:
		_bail("не удалось загрузить %s для теста контракта смерти" % _PLAYER_PATH)
		return
	var player := packed.instantiate()
	if not await _spawn_in(world, player, Vector3(0.0, 0.0, 0.0)):
		_bail("%s так и не стал node-ready для теста контракта смерти" % _PLAYER_PATH)
		return

	_lobby_changes.clear()
	var gs := _install_probe_game_state()
	var spy := gs as _RecordingGameState
	await physics_frame
	_check(root.get_node_or_null("GameState") == gs,
		"предусловие: пробный GameState резолвится как /root/GameState")

	_died_count = 0
	_health_at_death = -1.0
	_alive_at_death = true
	player.died.connect(_on_player_died.bind(player))
	var max_health := float(player.get("max_health"))
	player.call("take_damage", max_health)

	_check(_died_count == 1, "смерть испускает died ровно один раз", "(got %d)" % _died_count)
	_check(_near(_health_at_death, 0.0), "в момент сигнала died здоровье игрока равно 0.0",
		"(got %.4f)" % _health_at_death)
	_check(not _alive_at_death, "в момент сигнала died игрок уже мёртв")
	_check(spy != null and _packed_strings_eq(spy.lobby_reasons, ["death"]),
		"смерть возвращает в лобби с причиной \"death\"",
		"(получено %s)" % ("нет пробного GameState" if spy == null else str(spy.lobby_reasons)))
	_check(_packed_strings_eq(_lobby_changes, ["res://levels/lobby/lobby.tscn"]),
		"смерть просит у scene_changer ровно res://levels/lobby/lobby.tscn",
		"(получено %s)" % str(_lobby_changes))
	_check(_near(_health(player), 0.0),
		"смерть НЕ респавнит на месте: здоровье остаётся 0.0, а не max_health",
		"(got %.4f, max_health %.4f)" % [_health(player), max_health])
	_check(not _alive(player), "смерть НЕ респавнит на месте: игрок остаётся мёртвым")

	player.queue_free()
	await physics_frame
	await _remove_probe_game_state()
	_check(root.get_node_or_null("GameState") == null,
		"после секции пробный GameState убран из /root — fallback снова доступен")
	world.queue_free()
	await physics_frame


## Убийство врага начисляет ровно POINTS_PER_KILL очков через GameState и
## ровно один раз.
func _test_kill_awards_points() -> void:
	print("-- очки за убийство врага (Phase 3 Task 5)")

	_check(root.get_node_or_null("GameState") == null,
		"предусловие: до установки GameState в /root его нет")

	var world := _new_world()
	_add_floor(world)
	var enemy_packed: PackedScene = load(_ENEMY_PATH)
	if enemy_packed == null:
		_bail("не удалось загрузить %s для теста очков за убийство" % _ENEMY_PATH)
		return
	var player_packed: PackedScene = load(_PLAYER_PATH)
	if player_packed == null:
		_bail("не удалось загрузить %s для теста очков за убийство" % _PLAYER_PATH)
		return
	# Игрок в мире — не украшение: враг ищет цель по группе "player", и без неё
	# секция проверяла бы одиночный узел, а не убийство в бою.
	var player := player_packed.instantiate()
	if not await _spawn_in(world, player, Vector3(0.0, 0.0, 0.0)):
		_bail("%s так и не стал node-ready для теста очков за убийство" % _PLAYER_PATH)
		return
	var enemy := enemy_packed.instantiate()
	if not await _spawn_in(world, enemy, Vector3(6.0, 0.0, 0.0)):
		_bail("%s так и не стал node-ready для теста очков за убийство" % _ENEMY_PATH)
		return

	_lobby_changes.clear()
	var gs := _install_probe_game_state()
	await physics_frame
	_check(root.get_node_or_null("GameState") == gs,
		"предусловие: пробный GameState резолвится как /root/GameState")
	_check(gs.points == 0, "предусловие: счёт начинается с нуля", "(got %d)" % gs.points)

	var data := enemy.get("data") as EnemyData
	if data == null:
		_bail("враг в тесте очков за убийство не содержит EnemyData")
		return
	_enemy_died_count = 0
	_enemy_health_at_death = -1.0
	_enemy_alive_at_death = true
	enemy.died.connect(_on_enemy_died.bind(enemy))

	enemy.call("take_damage", float(data.max_health))

	_check(_enemy_died_count == 1, "враг умирает ровно один раз, died ровно один",
		"(got %d)" % _enemy_died_count)
	_check(gs.points == gs.POINTS_PER_KILL,
		"убийство врага начисляет ровно POINTS_PER_KILL очков",
		"(points %d, POINTS_PER_KILL %d)" % [gs.points, gs.POINTS_PER_KILL])
	_check(gs.points == 10, "очков ровно 10", "(got %d)" % gs.points)
	# Повторный урон по мёртвому врагу не начисляет очки второй раз: смерть
	# наблюдается ровно один раз (см. _die() в enemy_contact.gd).
	enemy.call("take_damage", float(data.max_health))
	_check(gs.points == 10, "урон по мёртвому врагу не начисляет очки повторно",
		"(got %d)" % gs.points)

	await _remove_probe_game_state()
	world.queue_free()
	await physics_frame


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
		_bail("не удалось загрузить %s" % _ENEMY_PATH)
		return
	var world := _new_world()
	_add_floor(world)
	var enemy := packed.instantiate()
	if not await _spawn_in(world, enemy, Vector3(6.0, 0.0, 0.0)):
		_bail("%s так и не стал node-ready" % _ENEMY_PATH)
		return
	_check(enemy.is_node_ready(), "предусловие: enemy_contact.tscn успешно создан и готов (is_node_ready)")

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
		_check(_near(data.max_health, 60.0), "max_health данных врага равен 60.0",
			"(got %.4f)" % data.max_health)
		_check(_near(data.contact_damage, 30.0), "contact_damage данных врага равен 30.0",
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
		_bail("двойник врага для %s так и не стал node-ready" % _ENEMY_PATH)
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
	# Потолок берётся из данных, а не зашивается: выше он уже запинен на
	# величину из contact.tres, а здесь утверждается, что сцена берёт ИМЕННО его
	# (сцена без data читала бы поле дефолтом и выглядела бы целой).
	_check(data != null and _near(_enemy_health(enemy), data.max_health),
		"враг начинает с data.max_health здоровья",
		"(got %.4f, data.max_health %.4f)" % [
			_enemy_health(enemy), 0.0 if data == null else data.max_health])
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
	# Урон снаряда читается ДО его исчезновения: после free() обращаться к узлу
	# нельзя, а ожидаемое здоровье выводится из него и из потолка врага, а не из
	# двух зашитых чисел (смена баланса урона в pistol.tres обязана ломать это
	# утверждение, а не молча переписывать вместе с ним).
	var bullet_damage := bullet.damage
	var enemy_hurtbox := enemy.get_node_or_null("Hurtbox") as Hurtbox
	var hits: Array[Node] = []
	bullet.hit_something.connect(hits.append)
	bullet.launch(Vector3.RIGHT)
	await _frames_until_free(bullet, 200)
	_check(hits.size() == 1 and hits[0] == enemy_hurtbox,
		"снаряд попал в хитбокс врага и только в него",
		"(hit %s)" % ("nothing" if hits.is_empty() else str((hits[0] as Node).name)))
	_check(_near(_enemy_health(enemy), data.max_health - bullet_damage),
		"после одного попадания у врага data.max_health - урон снаряда (%.4f - %.4f)" % [
			data.max_health, bullet_damage],
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
		_bail("%s так и не стал node-ready для теста двух снарядов" % _ENEMY_PATH)
		return
	enemy.died.connect(_on_enemy_died.bind(enemy))
	var enemy_hurtbox := enemy.get_node_or_null("Hurtbox") as Hurtbox
	_check(enemy_hurtbox != null, "предусловие: у врага есть хитбокс, куда целятся оба снаряда")

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
		_bail("враг без данных так и не стал node-ready")
		return
	var broken_data := packed.instantiate()
	# EnemyData.new() здесь НЕ годится: у ресурса все поля уже имеют рабочие
	# значения по умолчанию (50 HP, 10 урона, 6 м/с), и такой «сломанный» враг
	# прошёл бы is_valid(). Непригодность создаётся явной правкой поля.
	var unusable := EnemyData.new()
	unusable.max_health = 0.0
	broken_data.set("data", unusable)
	if not await _spawn_in(world, broken_data, Vector3(0.0, 0.0, 12.0)):
		_bail("враг с некорректными данными так и не стал node-ready")
		return

	_check(not broken_data.get("data").is_valid(),
		"предусловие: подставленные данные действительно непригодны (is_valid() == false)")
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
		_bail("%s так и не стал node-ready для теста контакта" % _PLAYER_PATH)
		return
	await _physics_frames(20)
	_check(player.is_on_floor(), "предусловие: игрок стоит на полу, а не висит в воздухе")
	_check(player.is_in_group("player"),
		"игрок вошёл в группу \"player\": враг находит цель по группе, а не по пути в сцене")
	var player_hurtbox := player.get_node_or_null("Hurtbox") as Hurtbox
	_check(player_hurtbox != null, "у игрока есть хитбокс, в который влетает хитбокс врага")
	if player_hurtbox == null:
		_bail("в player.tscn нет узла Hurtbox: тест контакта не может выполняться")
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
		_bail("%s так и не стал node-ready для теста контакта" % _ENEMY_PATH)
		return
	enemy.died.connect(_on_enemy_died.bind(enemy))

	var shipped_damage := float((load(_CONTACT_PATH) as EnemyData).contact_damage)
	var contact_damage := float(enemy.get("data").contact_damage)
	_check(_near(contact_damage, probe.contact_damage) and not _near(contact_damage, shipped_damage),
		"предусловие: сценарий контакта идёт по НЕСТАНДАРТНОМУ урону за тик, а не по %.1f из contact.tres" % shipped_damage,
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

## R5: Оптимизация навигации и кэширование игрока на 120 Гц.
## Проверяет:
## 1. _player() кэширует ссылку на игрока в _cached_player и не опрашивает
##    реестр SceneTree при валидном кэше.
## 2. При выходе игрока из группы "player" или удалении узла кэш инвалидируется.
## 3. Обновление _agent.target_position оптимизировано:
##    - первое обновление происходит немедленно на первом тике (_last_target_position == Vector3.INF);
##    - при неподвижном игроке обновления не спамятся на каждом тике 120 Гц;
##    - плановое обновление происходит по истечении интервала 0.1 с;
##    - смещение игрока на расстояние >= 0.25 м вызывает немедленное обновление.
func _test_enemy_optimization() -> void:
	print("-- Оптимизация навигации и кэширование игрока на 120 Гц (R5)")

	var packed: PackedScene = load(_ENEMY_PATH)
	if packed == null:
		_bail("не удалось загрузить %s для теста оптимизации" % _ENEMY_PATH)
		return

	var world := _new_world()
	_add_floor(world)

	# --- Часть 1: Кэширование ссылки на игрока в _player() ---
	var target1 := Node3D.new()
	target1.name = "PlayerTarget1"
	if not await _spawn_in(world, target1, Vector3(0.0, 0.0, 5.0)):
		_bail("цель target1 не стала node-ready")
		return
	target1.add_to_group("player")

	var enemy := packed.instantiate()
	enemy.name = "OptEnemy1"
	if not await _spawn_in(world, enemy, Vector3(0.0, 0.0, 0.0)):
		_bail("враг OptEnemy1 не стал node-ready")
		return

	await physics_frame

	var resolved_player: Node3D = enemy.call("_player")
	_check(resolved_player == target1,
		"_player() возвращает узел игрока из группы \"player\"",
		"(got %s)" % ("null" if resolved_player == null else resolved_player.name))

	var cached_field: Variant = enemy.get("_cached_player")
	_check(cached_field == target1,
		"_cached_player кэширует ссылку на найденного игрока")

	# Проверка O(1) кэширования: подменяем кэш на mock_target, находящийся в группе "player".
	# Если _player() обращается к кэшу, он обязан вернуть mock_target,
	# не вызывая get_tree().get_first_node_in_group("player").
	var target_mock := Node3D.new()
	target_mock.name = "PlayerTargetMock"
	if not await _spawn_in(world, target_mock, Vector3(2.0, 0.0, 5.0)):
		_bail("цель target_mock не стала node-ready")
		return
	target_mock.add_to_group("player")

	enemy.set("_cached_player", target_mock)
	var from_cache: Node3D = enemy.call("_player")
	_check(from_cache == target_mock,
		"_player() при валидном кэше возвращает узел из кэша без повторного опроса дерева узлов")

	# Проверка инвалидации при исключении из группы:
	target_mock.remove_from_group("player")
	var after_unshare: Node3D = enemy.call("_player")
	_check(after_unshare == target1,
		"при исключении узла из группы кэш инвалидируется и _player() находит актуального игрока")
	_check(enemy.get("_cached_player") == target1,
		"_cached_player обновлён на актуального игрока target1")

	# Проверка инвалидации при удалении игрока из дерева:
	target1.queue_free()
	await physics_frame
	var after_free: Node3D = enemy.call("_player")
	_check(after_free == null,
		"при удалении игрока _player() возвращает null без сбоев")
	_check(enemy.get("_cached_player") == null,
		"_cached_player сброшен в null при отсутствии игроков")

	enemy.queue_free()
	target_mock.queue_free()
	await physics_frame

	# --- Часть 2: Троттлинг NavigationAgent3D.target_position на 120 Гц ---
	var nav_player := Node3D.new()
	nav_player.name = "NavPlayer"
	if not await _spawn_in(world, nav_player, Vector3(0.0, 0.0, 5.0)):
		_bail("цель NavPlayer не стала node-ready")
		return
	nav_player.add_to_group("player")

	var nav_enemy := packed.instantiate()
	nav_enemy.name = "OptNavEnemy"
	if not await _spawn_in(world, nav_enemy, Vector3(0.0, 0.0, 0.0)):
		_bail("враг OptNavEnemy не стал node-ready")
		return

	# На первом тике физики происходит первичное обновление target_position
	await physics_frame
	var initial_updates: int = int(nav_enemy.get("_nav_updates_count"))
	_check(initial_updates == 1,
		"на первом тике target_position обновляется немедленно (_last_target_position == Vector3.INF)",
		"(got %d)" % initial_updates)
	var last_pos: Vector3 = nav_enemy.get("_last_target_position")
	_check(last_pos.distance_to(nav_player.global_position) < 0.001,
		"целевая позиция на первом тике точно совпадает с позицией игрока")

	# Игрок остаётся неподвижным. Пропускаем 10 тиков (около 83 мс при 120 Гц, что меньше интервала 100 мс = 0.1 с)
	for i in 10:
		await physics_frame
	var updates_after_10: int = int(nav_enemy.get("_nav_updates_count"))
	_check(updates_after_10 == 1,
		"при неподвижном игроке target_position не спамит обновлениями на каждом тике (10 тиков = 0 повторных обновлений)",
		"(got %d)" % updates_after_10)

	# Ждём ещё 5 тиков (суммарно 15 тиков = 125 мс > 100 мс = 0.1 с) — интервал таймера истёк
	for i in 5:
		await physics_frame
	var updates_after_timer: int = int(nav_enemy.get("_nav_updates_count"))
	_check(updates_after_timer == 2,
		"по истечении таймера 0.1 с происходит ровно одно плановое обновление пути",
		"(got %d)" % updates_after_timer)

	# Небольшое смещение (< 0.25 м, например 0.1 м, 0.1^2 = 0.01 < 0.0625)
	nav_player.global_position += Vector3(0.1, 0.0, 0.0)
	await physics_frame
	var updates_after_small_move: int = int(nav_enemy.get("_nav_updates_count"))
	_check(updates_after_small_move == 2,
		"смещение игрока меньше порога 0.25 м (0.1 м) не вызывает внеочередного пересчёта пути",
		"(got %d)" % updates_after_small_move)

	# Существенное смещение (>= 0.25 м, например 0.4 м, суммарно 0.5 м)
	nav_player.global_position += Vector3(0.4, 0.0, 0.0)
	await physics_frame
	var updates_after_big_move: int = int(nav_enemy.get("_nav_updates_count"))
	_check(updates_after_big_move == 3,
		"смещение игрока на 0.4 м (>= 0.25 м) немедленно обновляет target_position без ожидания таймера",
		"(got %d)" % updates_after_big_move)
	var final_pos: Vector3 = nav_enemy.get("_last_target_position")
	_check(final_pos.distance_to(nav_player.global_position) < 0.001,
		"целевая точка пути синхронизирована с новым положением игрока")

	nav_player.remove_from_group("player")
	nav_enemy.queue_free()
	nav_player.queue_free()
	world.queue_free()
	await physics_frame


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
		_bail("навигационная цель так и не стала node-ready")
		return
	target.add_to_group("player")
	await _physics_frames(2)
	var players := get_nodes_in_group("player")
	_check(players.size() == 1 and players[0] == target,
		"предусловие: в группе \"player\" ровно этот узел — цель врага определена однозначно",
		"(в группе %d узлов)" % players.size())

	var enemy := packed.instantiate()
	if not await _spawn_in(world, enemy, _NAV_ENEMY_START):
		_bail("%s так и не стал node-ready для теста навигации" % _ENEMY_PATH)
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
	# Пин на 0.5, а не на дефолт движка 1.0. Раннее решение Task 4 (оставить
	# 1.0) пересмотрено: стоп-дистанция 1.0 м больше радиуса контакта двух
	# хитбоксов (0.4 + 0.4 = 0.8 м), то есть враг доходил до игрока и замирал в
	# метре, не нанося ни одного тика урона. Пересмотр касается ТОЛЬКО этого
	# числа: path_desired_distance выше остаётся 1.0 — заморозка врага задаётся
	# не им, а смещением навмеша 2 * cell_height (см. правило в navmesh тира).
	_check(scene_agent != null
			and absf(float(scene_agent.get("target_desired_distance")) - 0.5) < _HEALTH_EPS,
		"target_desired_distance агента равен 0.5 м: стоп-дистанция меньше радиуса контакта хитбоксов",
		"(got %.4f, expected 0.5000)" % (
			float(scene_agent.get("target_desired_distance")) if scene_agent != null else -1.0))

	var data := enemy.get("data") as EnemyData
	if data == null:
		print("  (движение оценивать нельзя без данных: проверки ниже пропущены)")
		target.remove_from_group("player")
		world.queue_free()
		return
	_check(enemy.has_method("next_path_direction"),
		"у enemy_contact.gd есть next_path_direction() — направление пути наружу")

	var move_speed := float(data.move_speed)
	# Пин скорости баланса: окно и пороги маршрута считаются под неё (см.
	# _NAV_DESIGN_SPEED), поэтому «прошёл маршрут» должно быть утверждением о
	# балансе, а не тавтологией «враг успел за то время, которое выведено из его
	# же скорости».
	_check(_near(move_speed, _NAV_DESIGN_SPEED),
		"move_speed данных равен скорости баланса %.1f м/с: под неё выведены окно и пороги маршрута" % _NAV_DESIGN_SPEED,
		"(got %.4f)" % move_speed)
	# Порог остановки читается с агента, но подставляется и без него: сцена без
	# агента обязана проверяться теми же утверждениями о поведении, а не
	# зелёным набором «проверять нечего».
	var stop_limit := _NAV_TARGET_DISTANCE + 0.1
	if scene_agent != null:
		stop_limit = float(scene_agent.get("target_desired_distance")) + 0.1
	# Окно выведено из маршрута и скорости баланса, а не выбрано: единственный
	# проход в этом мире — торец стены плюс отступ радиуса агента, навмеш ведёт
	# в него, и враг обязан уложиться в это окно целиком.
	var corner := Vector3(_NAV_PASS_X, 0.0, 0.0)
	var route_m := _route_length(_NAV_ENEMY_START, corner, _NAV_TARGET)
	var observe_ticks := _route_ticks(_NAV_ENEMY_START, corner, _NAV_TARGET)
	print("    проход у торца стены x = %.2f м, маршрут %.2f м, окно %d тиков (%.2f с) при %.1f м/с" % [
		_NAV_PASS_X, route_m, observe_ticks,
		float(observe_ticks) / float(_TICKS_PER_SECOND), _NAV_DESIGN_SPEED])
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
	var arrived_at := -1
	for i in observe_ticks:
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
		if arrived_at < 0 and end_distance <= stop_limit:
			arrived_at = i
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
		if arrived_at >= 0 and far_side_reached and i >= arrived_at + 10:
			break

	print("    старт %.3f м -> финиш %.3f м, худшая ошибка скорости %.4f (максимум %.4f), движущихся кадров %d из %d" % [
		start_distance, end_distance, worst_speed_error, max_speed, moving_frames, observe_ticks])
	print("    худший кадр #%d: скорость %.4f, pos=%s, on_floor=%s, следующая точка пути %s" % [
		worst_frame, worst_speed, str(worst_pos), str(worst_on_floor), str(worst_next)])

	_check(moving_frames >= _NAV_MIN_MOVING_FRAMES,
		"враг реально шёл: не менее %d кадров с горизонтальной скоростью выше %.1f м/с" % [
			_NAV_MIN_MOVING_FRAMES, _NAV_MOVING_EPS],
		"(got %d из %d; без этого проверка скорости ниже ничего бы не утверждала)" % [
			moving_frames, observe_ticks])
	# «Вдвое за 3 с» было утверждением о СКОРОСТИ, а не о маршруте: при 6 м/с
	# враг успевал, при 2 м/с — нет, и красный свет загорался бы на исправном
	# враге. Теперь утверждение о маршруте: за окно, выведенное из длины пути и
	# скорости баланса, враг обязан дойти до стоп-дистанции агента. Порог
	# стоп-дистанции берётся из СЦЕНЫ, а допуск — половина тика при 2 м/с плюс
	# округление сетки; строгая проверка без допуска стоит в «остановке у цели».
	_check(end_distance <= stop_limit + _NAV_ARRIVAL_MARGIN,
		"за окно в %.2f с (%.2f м маршрута при %.1f м/с) враг прошёл весь маршрут: дистанция до цели не больше стоп-дистанции агента" % [
			float(observe_ticks) / float(_TICKS_PER_SECOND), route_m, _NAV_DESIGN_SPEED],
		"(%.3f -> %.3f м из %.3f; стоп-дистанция %.3f м, допуск %.2f м; дошёл на тике %d из %d)" % [
			start_distance, end_distance, start_distance, stop_limit,
			_NAV_ARRIVAL_MARGIN, arrived_at, observe_ticks])
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


## Окно наблюдения для маршрута в тиках физики: сколько времени враг обязан
## уложить, чтобы дойти до цели, и сколько это тиков при 120 тиках в секунду.
##
## Число выводится, а не выбирается: длина ломаной `from -> corner -> to` делится
## на скорость баланса и умножается на запас. При 6 м/с это давало меньше трёх
## секунд, и «3 с» работало за счёт скорости; при 2 м/с тот же маршрут занимает
## больше семи, и окно обязано отражать физику нового баланса. Прямая
## дистанция в тире вместо ломаной — сознательное упрощение: там угол обхода
## задан сценами тира, а не этим харнессом.
func _route_length(from: Vector3, corner: Vector3, to: Vector3) -> float:
	return from.distance_to(corner) + corner.distance_to(to)


func _route_ticks(from: Vector3, corner: Vector3, to: Vector3) -> int:
	return int(ceil(_route_length(from, corner, to) / _NAV_DESIGN_SPEED
		* _NAV_ROUTE_SAFETY * float(_TICKS_PER_SECOND)))


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


# --------------------------------------------------------------------------
# Task 5: проводка тира
# --------------------------------------------------------------------------

## Пятый раздел: тир целиком, ровно так, как его грузит игра.
##
## Предмет проверки здесь — файл `res://levels/range/range.tscn`, а не отдельный узел: три
## мишени, враг, игрок, `NavigationRegion3D` и скрипт корня, который его
## запекает. Сцена грузится через `load()` и инстанцируется как в игре, и
## ничего из этого не собирается кодом: харнесс, собравший тот же мир из
## узлов, остался бы зелёным на тире без навмеша вообще. Это и есть открытый
## пункт HANDOFF §8 («у range.tscn нет проверки»), который закрывает раздел.
##
## Наблюдение за врагом — часть раздела, а не украшение. Полигоны в навмеше и
## зелёные слои ничего не говорят о том, дойдёт ли враг до игрока: bake без
## геометрии под регионом даёт сетку без полигонов, агент без пути стоит на
## месте, и все статические утверждения выше были бы зелёными на мёртвом тире.
func _test_range_scene_wiring() -> void:
	print("-- Проводка сцены (Task 5)")

	var packed: PackedScene = load(_RANGE_PATH)
	if packed == null:
		_bail("не удалось загрузить %s" % _RANGE_PATH)
		return
	var range_root := packed.instantiate()
	if not await _spawn_and_wait(range_root):
		_bail("%s так и не стал node-ready" % _RANGE_PATH)
		return
	_check(range_root.is_node_ready(), "предусловие: range.tscn успешно создан и готов (is_node_ready)")

	print("-- скрипт корня тира и bake навмеша")
	var root_script := range_root.get_script() as Script
	_check(root_script != null and str(root_script.resource_path) == _RANGE_SCRIPT_PATH,
		"корень range.tscn несёт скрипт scripts/range_scene.gd: bake живёт в сцене, а не в тесте",
		"(got \"%s\")" % ("none" if root_script == null else str(root_script.resource_path)))
	var region := range_root.get_node_or_null("NavigationRegion3D") as NavigationRegion3D
	_check(region != null, "в range.tscn есть узел NavigationRegion3D",
		"(got %s)" % ("none" if region == null else str(region.name)))
	# Пол под регионом, а не рядом с ним: режим парсинга по умолчанию
	# (SOURCE_GEOMETRY_ROOT_NODE_CHILDREN) читает геометрию только из потомков
	# региона. Пол-сосед даёт bake без единого полигона, и тир выглядит целым,
	# пока идти некуда.
	_check(region != null and region.get_node_or_null("Floor") != null,
		"пол тира лежит ПОД NavigationRegion3D — bake читает только потомков региона",
		"(got %s)" % ("нет Floor под регионом" if region != null else "нет региона"))
	var nav_mesh: NavigationMesh = null if region == null else region.navigation_mesh as NavigationMesh
	var polygons := 0 if nav_mesh == null else nav_mesh.get_polygon_count()
	_check(polygons > 0,
		"bake навмеша тира удался: navigation_mesh.get_polygon_count() > 0",
		"(got %d полигонов)" % polygons)

	print("-- три мишени тира: тело на слое 3, хитбокс на слое 4")
	var targets: Array[Node] = []
	_collect_by_script(range_root, "RangeTarget", targets)
	_check(targets.size() == 3, "в range.tscn ровно три мишени RangeTarget",
		"(got %d: %s)" % [targets.size(), str(_node_names(targets))])
	for target in targets:
		var body := target as CollisionObject3D
		_check(int(body.collision_layer) == _LAYER_ENEMY_BODY,
			"тело мишени слой 3 (%s)" % str(target.name),
			"(got %d, expected %d)" % [int(body.collision_layer), _LAYER_ENEMY_BODY])
		var hurtbox := target.get_node_or_null("Hurtbox") as Hurtbox
		_check(hurtbox != null and int(hurtbox.collision_layer) == _LAYER_ENEMY_HURTBOX,
			"хитбокс мишени слой 4 (%s)" % str(target.name),
			"(got %s)" % ("нет узла Hurtbox" if hurtbox == null
				else "%d, expected %d" % [int(hurtbox.collision_layer), _LAYER_ENEMY_HURTBOX]))

	print("-- враг в тире: сцена, данные и слои")
	var enemies: Array[Node] = []
	_collect_by_script(range_root, "ContactEnemy", enemies)
	_check(enemies.size() == 1, "в range.tscn ровно один враг ContactEnemy",
		"(got %d: %s)" % [enemies.size(), str(_node_names(enemies))])
	var enemy: Node3D = enemies[0] as Node3D if enemies.size() > 0 else null
	var enemy_data := enemy.get("data") as EnemyData if enemy != null else null
	_check(enemy_data != null and str(enemy_data.resource_path) == _CONTACT_PATH,
		"враг тира использует дефолтный res://data/enemies/contact.tres",
		"(got \"%s\")" % ("none" if enemy_data == null else str(enemy_data.resource_path)))
	var enemy_body := enemy as CharacterBody3D
	_check(enemy_body != null, "корень врага в тире — CharacterBody3D",
		"(got %s)" % ("none" if enemy_body == null else type_string(typeof(enemy))))
	_check(enemy_body != null and int(enemy_body.collision_layer) == _LAYER_ENEMY_BODY,
		"тело врага в тире лежит на слое 3 (enemy_body)",
		"(got %s)" % ("no enemy" if enemy_body == null
			else "%d, expected %d" % [int(enemy_body.collision_layer), _LAYER_ENEMY_BODY]))
	_check(enemy_body != null
			and int(enemy_body.collision_mask) == (_LAYER_WORLD | _LAYER_ENEMY_BODY),
		"маска тела врага в тире — слои 1 и 3: мир и свои",
		"(got %s)" % ("no enemy" if enemy_body == null else "%d, expected %d" % [
			int(enemy_body.collision_mask), (_LAYER_WORLD | _LAYER_ENEMY_BODY)]))
	var enemy_hurtbox := enemy.get_node_or_null("Hurtbox") as Hurtbox if enemy != null else null
	# Агент читается из СЦЕНЫ, а не подставляется: без него тир с врагом без
	# навигации «проверялся» бы зелёным набором «проверять нечего».
	var agent := enemy.get_node_or_null("NavigationAgent3D") as NavigationAgent3D if enemy != null else null
	_check(agent != null, "у врага в тире есть дочерний узел NavigationAgent3D",
		"(got %s)" % ("none" if agent == null else str(agent.name)))
	_check(enemy_hurtbox != null and bool(enemy_hurtbox.monitoring),
		"хитбокс врага в тире обнаруживает: monitoring == true (контакт ловит враг, спека 6.3)")
	_check(enemy_hurtbox != null and int(enemy_hurtbox.collision_layer) == _LAYER_ENEMY_HURTBOX,
		"хитбокс врага в тире лежит на слое 4 (enemy_hurtbox)",
		"(got %s)" % ("нет узла Hurtbox" if enemy_hurtbox == null
			else "%d, expected %d" % [int(enemy_hurtbox.collision_layer), _LAYER_ENEMY_HURTBOX]))

	print("-- игрок в тире: хитбокс на слое 7")
	var player := range_root.get_node_or_null("Player") as Node3D
	_check(player != null, "в range.tscn есть узел Player",
		"(got %s)" % ("нет узла Player" if player == null
			else "%s, экземпляр %s" % [str(player.name), player.get_class()]))
	var players_in_group := get_nodes_in_group("player")
	_check(players_in_group.size() == 1 and players_in_group[0] == player,
		"предусловие: в группе \"player\" ровно игрок тира — цель врага определена однозначно",
		"(в группе %d узлов)" % players_in_group.size())
	var player_hurtbox := player.get_node_or_null("Hurtbox") as Hurtbox if player != null else null
	_check(player_hurtbox != null and int(player_hurtbox.collision_layer) == _LAYER_PLAYER_HURTBOX,
		"хитбокс игрока в тире лежит на слое 7 (player_hurtbox)",
		"(got %s)" % ("нет узла Hurtbox" if player_hurtbox == null
			else "%d, expected %d" % [int(player_hurtbox.collision_layer), _LAYER_PLAYER_HURTBOX]))

	print("-- ствол пистолета в тире: снаряд стартует из Muzzle, а не из камеры")
	# pistol.gd читает точку старта снаряда из узла Muzzle. Нет узла — и
	# _spawn_point() молча откатывается на прицел: пули снова вылетают из глаза,
	# тир при этом цел и все статические проверки выше зелёные. Поэтому
	# отсутствие маркера должно быть видно здесь, а не игроку в бою.
	var pistol := player.get_node_or_null("Pistol") as Node3D if player != null else null
	var muzzle_marker := pistol.get_node_or_null("Muzzle") as Node3D if pistol != null else null
	_check(muzzle_marker != null,
		"у Pistol в тире есть узел Muzzle — точка старта снаряда",
		"(got %s)" % ("нет узла Pistol у игрока" if pistol == null
			else "у Pistol нет узла Muzzle"))

	print("-- враг стоит в дальнем углу, а не на игроке")
	var start_distance := -1.0
	if enemy_body != null and player != null:
		start_distance = enemy_body.global_position.distance_to(player.global_position)
	_check(start_distance >= _RANGE_MIN_START_DISTANCE,
		"враг в тире не ближе %.1f м к игроку (бриф: дальний угол)" % _RANGE_MIN_START_DISTANCE,
		"(got %.3f м)" % start_distance)

	print("-- правило ширины хитбоксов (глобальное решение 1)")
	var hurtboxes: Array[Node] = []
	_collect_by_script(range_root, "Hurtbox", hurtboxes)
	_check(hurtboxes.size() > 0, "в range.tscn есть хитбоксы — ширину которых проверяем",
		"(got %d: %s)" % [hurtboxes.size(), str(_node_names(hurtboxes))])
	for node in hurtboxes:
		var hurt := node as Hurtbox
		var shape_node := hurt.get_node_or_null("CollisionShape3D") as CollisionShape3D if hurt != null else null
		var shape := shape_node.shape if shape_node != null else null
		_check(_hurtbox_width(shape) >= _HURTBOX_MIN_WIDTH,
			"хитбокс не уже %.1f м (%s)" % [_HURTBOX_MIN_WIDTH, str(node.name)],
			"(got %s)" % ("нет CollisionShape3D" if shape == null
				else "%s = %.3f м" % [shape.get_class(), _hurtbox_width(shape)]))

	print("-- запас навмеша против заморозки агента")
	# Правило из Task 4, вынесенное в проверку: запечённая поверхность навмеша
	# лежит на 2 * cell_height выше геометрии, а первая точка пути — это позиция
	# агента, привязанная к сетке, то есть ровно на этом смещении выше пяток.
	# Пока смещение не меньше path_desired_distance, агент не считает точку
	# достигнутой и индекс пути не сдвигается никогда: навмеш есть, путь есть,
	# враг стоит. Порог живёт в сцене врага, смещение — в навмеше тира, и
	# разъехаться они могут молча, поэтому условие проверяется здесь, где оба
	# числа видны.
	var cell_height := 0.0 if nav_mesh == null else float(nav_mesh.get("cell_height"))
	var path_desired := 0.0 if agent == null else float(agent.get("path_desired_distance"))
	_check(cell_height > 0.0 and path_desired > 0.0 and 2.0 * cell_height < path_desired,
		"смещение навмеша (2 * cell_height) меньше path_desired_distance агента — враг не замрёт",
		"(got 2 * %.3f = %.3f м при пороге %.3f м)" % [cell_height, 2.0 * cell_height, path_desired])

	print("-- враг доходит до игрока на расстояние касания")
	# Контактный урон ловится ПЕРЕСЕЧЕНИЕМ двух хитбоксов (спека §6.3: тела
	# проходят друг сквозь друга, касание ловится зонами), то есть когда центры
	# капсул ближе, чем сумма их радиусов. Агент при этом останавливается на
	# target_desired_distance от цели. Если стоп-дистанция больше радиуса
	# контакта, враг доходит до игрока, останавливается в полуметре и молча
	# стоит: навмеш есть, путь пройден, здоровье игрока полно, и ни один
	# статический список утверждений этого не покажет. Проверка арифметическая
	# и потому не зависит от того, как быстро враг успел дойти.
	var enemy_reach := _hurtbox_reach(_hurtbox_shape(enemy_hurtbox))
	var player_reach := _hurtbox_reach(_hurtbox_shape(player_hurtbox))
	var stop_at := 0.0 if agent == null else float(agent.get("target_desired_distance"))
	var contact_reach := enemy_reach + player_reach
	_check(enemy_reach > 0.0 and player_reach > 0.0 and stop_at < contact_reach,
		"стоп-дистанция врага меньше радиуса контакта двух хитбоксов — контактный урон возможен",
		"(got %.3f м при радиусе контакта %.3f м = %.3f + %.3f)" % [
			stop_at, contact_reach, enemy_reach, player_reach])

	print("-- враг из тира идёт к игроку по запечённому навмешу")
	if enemy_body == null or player == null or players_in_group.size() != 1:
		print("  (движение оценивать нельзя без врага и игрока тира: проверки ниже пропущены)")
	else:
		# Карта навигации обновляется в начале физического шага, а bake тира
		# заканчивается в _ready() корня сцены. Без паузы после готовности
		# первый запрос пути ушёл бы в ещё пустую карту.
		await _physics_frames(_RANGE_SETTLE_TICKS)
		# Дистанция старта в дальнем углу (>15 м) уже подтверждена статической проверкой выше.
		# Для теста навигации и контакта перемещаем врага на рабочую дистанцию 3.5 м по линии к игроку:
		# это доказывает навигацию, движение и контакт без 13 секунд ожидания прохода через пустой тир.
		var dir := (enemy_body.global_position - player.global_position).normalized()
		enemy_body.global_position = player.global_position + dir * 3.5
		enemy_body.velocity = Vector3.ZERO
		await _physics_frames(5)
		var settle_distance := enemy_body.global_position.distance_to(player.global_position)
		# Окно прохода — по тому же правилу, что у мирового мира (Task 4), но
		# длиной маршрута здесь служит замеренная дистанция до игрока: угол
		# обхода задан мишенями тира, а не этим харнессом, и выводить его из
		# геометрии сцены — значит дублировать сцену в проверке.
		var range_ticks := int(ceil(settle_distance / _NAV_DESIGN_SPEED * _NAV_ROUTE_SAFETY
			* float(_TICKS_PER_SECOND)))
		print("    дистанция %.3f м, окно прохода %d тиков (%.2f с) при %.1f м/с" % [
			settle_distance, range_ticks, float(range_ticks) / float(_TICKS_PER_SECOND),
			_NAV_DESIGN_SPEED])
		var end_distance := settle_distance
		var moving_frames := 0
		var airborne_frames := 0
		var arrived_at := -1
		# Первый тик контакта ищется ВНУТРИ окна прохода, а не отдельным окном
		# после него: «дошёл и ударил» — одно наблюдение, и разрыв между двумя
		# окнами оставлял бы щель, в которой враг мог бы дойти, ударить и
		# разойтись, а проверка об этом не узнала бы.
		var player_max := float(player.get("max_health"))
		var health_before := _health(player)
		var first_contact_tick := -1
		var contact_ticks := 0
		for i in range_ticks:
			await physics_frame
			var speed := Vector2(enemy_body.velocity.x, enemy_body.velocity.z).length()
			if speed > _NAV_MOVING_EPS:
				moving_frames += 1
			if not enemy_body.is_on_floor():
				airborne_frames += 1
			end_distance = enemy_body.global_position.distance_to(player.global_position)
			if arrived_at < 0 and end_distance <= stop_at + _NAV_ARRIVAL_MARGIN:
				arrived_at = i
			var current := _health(player)
			if not _near(current, health_before):
				contact_ticks += 1
				health_before = current
				if first_contact_tick < 0:
					first_contact_tick = i
			if arrived_at >= 0 and first_contact_tick >= 0 and contact_ticks >= 2:
				break
		print("    дистанция %.3f -> %.3f м за %d тиков, движущихся кадров %d, вне пола %d, дошёл на тике %d" % [
			settle_distance, end_distance, range_ticks, moving_frames, airborne_frames, arrived_at])
		_check(moving_frames >= _RANGE_MIN_MOVING_FRAMES,
			"враг из тира реально шёл: не менее %d кадров со скоростью выше %.1f м/с" % [
				_RANGE_MIN_MOVING_FRAMES, _NAV_MOVING_EPS],
			"(got %d из %d)" % [moving_frames, range_ticks])
		_check(airborne_frames == 0, "враг из тира всю дорогу шёл по полу, а не падал в пустоту",
			"(кадров вне пола %d)" % airborne_frames)
		# Как и в мировом мире — утверждение о маршруте, а не о скорости: за
		# выведенное окно враг обязан дойти до стоп-дистанции агента.
		_check(end_distance <= stop_at + _NAV_ARRIVAL_MARGIN,
			"за окно в %.2f с (%.2f м маршрута при %.1f м/с) враг тира дошёл до игрока" % [
				float(range_ticks) / float(_TICKS_PER_SECOND), settle_distance, _NAV_DESIGN_SPEED],
			"(%.3f -> %.3f м; стоп-дистанция %.3f м, допуск %.2f м; дошёл на тике %d из %d)" % [
				settle_distance, end_distance, stop_at, _NAV_ARRIVAL_MARGIN, arrived_at, range_ticks])
		_check(first_contact_tick >= 0,
			"враг из тира ДОХОДИТ до игрока и нанёс контактный урон — здоровье игрока упало",
			"(за %d тиков (%.2f с) ни одного тика; дошёл на тике %d, первый тик контакта на тике %d, тиков %d, HP игрока %.1f из %.1f)" % [
				range_ticks, float(range_ticks) / float(_TICKS_PER_SECOND), arrived_at,
				first_contact_tick, contact_ticks, _health(player), player_max])
		_check(enemy.has_method("is_alive") and bool(enemy.call("is_alive")),
			"враг тира дожил до конца маршрута — целью был узел группы, а не хитбокс")

		print("-- враг, дошедший до игрока, продолжает бить касанием")
		# Наблюдение, а не вычисление: арифметика радиуса контакта выше говорит,
		# что касание возможно, а здесь видно, что тики продолжаются после
		# прихода. Игрок в харнессе неподвижен (headless не отдаёт ввод), враг
		# стоит у него — и тиков не будет никогда, если стоп-дистанция велика.
		health_before = _health(player)
		var still_ticking := -1
		for i in _RANGE_CONTACT_TICKS:
			await physics_frame
			if not _near(_health(player), health_before):
				still_ticking = i
				break
		print("    следующий тик контакта на кадре %d из %d, HP игрока %.1f из %.1f" % [
			still_ticking, _RANGE_CONTACT_TICKS, _health(player), player_max])
		_check(still_ticking >= 0,
			"после прихода тики контакта продолжаются: окно в %.1f с перекрывает каденцию %.1f с" % [
				float(_RANGE_CONTACT_TICKS) / float(_TICKS_PER_SECOND), _RANGE_CONTACT_INTERVAL],
			"(за %d тиков ни одного тика; HP игрока %.1f из %.1f)" % [
				_RANGE_CONTACT_TICKS, _health(player), player_max])

	range_root.queue_free()
	await physics_frame


## Глобальное имя класса скрипта узла или "" — чтобы отличить узел с чужим
## скриптом от узла вообще без скрипта. Оба случая разные: первый означает,
## что класс есть, но не тот, второй — что скрипт не назначен вовсе.
func _script_global_name(node: Node) -> String:
	var script := node.get_script() as Script
	return "" if script == null else str(script.get_global_name())


## Рекурсивный сбор всех узлов под `node` (включая сам `node`), чей скрипт
## объявляет class_name `global_name`. Именно класс, а не имя узла: мишени тира
## переименовать можно, а вот переименовать их так, чтобы сцена перестала быть
## тиром, нельзя.
func _collect_by_script(node: Node, global_name: String, out: Array[Node]) -> void:
	if _script_global_name(node) == global_name:
		out.append(node)
	for child in node.get_children():
		_collect_by_script(child, global_name, out)


func _node_names(nodes: Array[Node]) -> String:
	var names: Array[String] = []
	for node in nodes:
		names.append(str(node.name))
	return ", ".join(names)


## Габарит хитбокса по короткой оси: у капсулы и цилиндра это диаметр, у
## коробки — минимальная ось. -1.0 у формы, которую правило не умеет мерить:
## пара, с которой нечего сравнить, и проверка падает на ней честно, а не
## молча пропускает неизвестную форма.
func _hurtbox_width(shape: Shape3D) -> float:
	return _hurtbox_reach(shape) * 2.0


## Форма хитбокса, а не сам узел: путь к CollisionShape3D одинаков у мишеней,
## врага и игрока, и искать его в каждом месте отдельно — значит забыть в одном.
func _hurtbox_shape(hurtbox: Node) -> Shape3D:
	if hurtbox == null:
		return null
	var shape_node := hurtbox.get_node_or_null("CollisionShape3D") as CollisionShape3D
	return null if shape_node == null else shape_node.shape


## Горизонтальный вылет зоны из её центра: у капсулы, цилиндра и сферы это
## радиус, у коробки — половина минимальной оси. Именно вылет, а не ширина:
## зоны пересекаются, когда расстояние между их центрами меньше СУММЫ вылетов.
## -1.0 у неизвестной формы — пара, с которой нечего сравнить.
func _hurtbox_reach(shape: Shape3D) -> float:
	if shape is CapsuleShape3D:
		return (shape as CapsuleShape3D).radius
	if shape is CylinderShape3D:
		return (shape as CylinderShape3D).radius
	if shape is SphereShape3D:
		return (shape as SphereShape3D).radius
	if shape is BoxShape3D:
		var size := (shape as BoxShape3D).size
		return 0.5 * minf(size.x, minf(size.y, size.z))
	return -1.0


## Движок регистрирует GameState/SaveSystem как автозагрузки проекта
## (project.godot, Task 6) и создаёт узлы с этими именами в /root даже в режиме
## --script. Весь тест полагается на ОТСУТСТВИЕ /root/GameState
## (fallback-контракт смерти) либо на пробный узел, устанавливаемый тестом;
## автозагрузка затеняла бы пробу (Godot переименовывает узел с занятым именем)
## и передавала player.gd настоящий change_scene_to_file, меняя сцену на lobby.tscn.
## Удаляем их перед запуском: немедленный free(), а не queue_free, чтобы имя
## освободилось до добавления пробного узла.
func _drop_autoloads() -> void:
	for autoload_name in ["GameState", "SaveSystem"]:
		var node := root.get_node_or_null(autoload_name)
		if node != null:
			root.remove_child(node)
			node.free()


func _initialize() -> void:
	print("=== enemies ===")
	_drop_autoloads()

	print("-- %s должен успешно загружаться как EnemyData" % _CONTACT_PATH)
	var res: Resource = load(_CONTACT_PATH)
	if res == null:
		_bail("не удалось загрузить %s" % _CONTACT_PATH)
		return
	var script_res := res.get_script() as Script
	_check(res is EnemyData, "contact.tres является EnemyData",
		"(script=%s)" % ("none" if script_res == null else script_res.resource_path))
	var data := res as EnemyData
	if data == null:
		_bail("contact.tres не является EnemyData, последующие проверки полей бессмысленны")
		return

	print("-- проектные параметры контактного врага")
	# Спецификация 7.3 с учётом баланса: у контактного врага 60 здоровья и 30
	# контактного урона. Каждое утверждение проверяет отдельное поле в contact.tres.
	_check(data.max_health == 60.0, "max_health равен 60.0", "(got %.4f)" % data.max_health)
	_check(data.contact_damage == 30.0, "contact_damage равен 30.0", "(got %.4f)" % data.contact_damage)
	_check(data.move_speed == 2.0, "move_speed равен 2.0", "(got %.4f)" % data.move_speed)
	_check(data.spawn_interval == 1.5, "spawn_interval равен 1.5", "(got %.4f)" % data.spawn_interval)
	# Тип врага определяет поведение и сцену в Фазе 2: дефолтный тип не должен
	# проходить как контактный враг.
	_check(data.kind == EnemyData.EnemyKind.CONTACT, "kind равен EnemyData.EnemyKind.CONTACT",
		"(got %d)" % int(data.kind))

	print("-- метод is_valid() отклоняет некорректные значения")
	_check(data.is_valid(), "contact.tres сообщает о своей корректности")
	# По одному утверждению на каждое условие в is_valid():
	_check(_is_valid_rejects({"max_health": 0.0}),
		"нулевое максимальное здоровье отклоняется")
	_check(_is_valid_rejects({"contact_damage": 0.0}),
		"нулевой контактный урон отклоняется")
	_check(_is_valid_rejects({"move_speed": 0.0}),
		"нулевая скорость перемещения отклоняется")
	_check(_is_valid_rejects({"spawn_interval": 0.0}),
		"нулевой интервал появления отклоняется")

	await _test_player_health()
	await _test_death_returns_to_lobby()
	await _test_contact_enemy()
	await _test_kill_awards_points()
	await _test_enemy_optimization()
	await _test_enemy_navigation()
	await _test_range_scene_wiring()

	if _bailed:
		# _bail() уже напечатал сводку и запросил quit(1). Второй quit() здесь
		# перезаписал бы код возврата нулём, и FATAL прочитали бы как PASS.
		quit(1)
		return
	_finish()
	quit(1 if _failures.size() > 0 else 0)
