extends SceneTree

## Тестовый сценарий прогрессии для VibeFPS (Фаза 3, лобби ветка A): очки, покупка и
## экипировка оружия, разблокированные локации, переходы между сценами и автосохранение
## через SaveSystem.
##
## Автозагрузка SaveSystem изолируется вручную по пути user://progression_test.json
## — аналогичная изоляция используется в tests/save.gd, поэтому боевой user://save.json
## никогда не затрагивается. Смена сцен производится через внедряемый фейковый обработчик:
## в headless-режиме нет окна для переключения сцен, и боевые сцены не должны загружаться
## поверх тестового дерева.
##
## Основной экземпляр (`_gs`) проходит весь путь прогрессии. Второй, чистый экземпляр
## (`_roundtrip`) используется для проверки чтения/записи на диск: award_points(50)
## проверяет фиксацию ровно 50 очков из чистого состояния.
##
## Запуск: godot --headless --path . --script res://tests/progression.gd
##         .\tools\run_checks.ps1 progression

## Изолированный путь сохранения для теста. user://save.json никогда не затрагивается.
const _TMP_PATH := "user://progression_test.json"

var _failures: PackedStringArray = []
var _checks := 0

var _save: SaveSystem
var _gs: GameState
## Чистый экземпляр для проверки автосохранения на диск (см. заголовок файла).
var _roundtrip: GameState
## Пути, переданные фейковому обработчику смены сцен, в порядке вызова. Сцены фактически
## не переключаются — обработчик только записывает запрошенные пути.
var _changed_to: PackedStringArray = []


func _check(ok: bool, label: String, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  [PASS] %s %s" % [label, detail])
	else:
		_failures.append("%s %s" % [label, detail])
		print("  [FAIL] %s %s" % [label, detail])


## Фейковый обработчик смены сцен: записывает запрошенный путь и ничего не делает.
## Реальный change_scene_to_file разрушил бы текущее SceneTree во время теста.
func _fake_changer(path: String) -> void:
	_changed_to.append(path)


## Сравнение PackedStringArray и Array по содержимому. Godot не считает эти
## типы контейнеров эквивалентными при прямом сравнении ==.
func _packed_eq(packed: PackedStringArray, expected: Array) -> bool:
	if packed.size() != expected.size():
		return false
	for i in packed.size():
		if packed[i] != expected[i]:
			return false
	return true


func _cleanup() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_TMP_PATH))


## Движок регистрирует GameState/SaveSystem как автозагрузки проекта (project.godot)
## и создает узлы с этими именами под /root даже в режиме --script.
## Оставленные узлы затеняли бы тестовые узлы с такими же именами.
## Удаляем их перед запуском теста через free(), чтобы тестовые узлы владели именами в /root.
func _drop_autoloads() -> void:
	for autoload_name in ["GameState", "SaveSystem"]:
		var node := root.get_node_or_null(autoload_name)
		if node != null:
			root.remove_child(node)
			node.free()


func _initialize() -> void:
	print("=== VibeFPS: тест прогрессии ===")
	_drop_autoloads()
	# Очистка: остаточное сохранение от предыдущего запуска не должно влиять на тест.
	_cleanup()

	_save = SaveSystem.new()
	# Имя узла позволяет резолвить /root/SaveSystem для автосохранения GameState.
	_save.name = "SaveSystem"
	_save.save_path = _TMP_PATH
	root.add_child(_save)

	_gs = GameState.new()
	# Внедряется до add_child, чтобы GameState._ready() не перезаписал его.
	_gs.scene_changer = _fake_changer
	root.add_child(_gs)
	await physics_frame

	_test_initial_state()
	_test_award_points()
	_test_afford()
	_test_buy_weapon()
	_test_buy_owned_again()
	_test_buy_missing()
	_test_equip()
	_test_enter_location()
	_test_return_to_lobby()
	await _test_autosave_roundtrip()
	await _test_save_debounce_and_batching()

	_save.clear_save()
	_cleanup()

	print("=== ИТОГ: проверок %d, ошибок %d ===" % [_checks, _failures.size()])
	for f in _failures:
		print("  ОШИБКА: %s" % f)
	quit(1 if _failures.size() > 0 else 0)


func _test_initial_state() -> void:
	print("-- старт: новая игра начинается с пистолетом и стрельбищем")
	_check(_gs.points == 0, "начальное количество очков 0", "(получено %d)" % _gs.points)
	_check(_packed_eq(_gs.owned_weapons, ["pistol"]),
		"в наличии только пистолет", "(получено %s)" % _gs.owned_weapons)
	_check(_gs.equipped_weapon_id == "pistol", "экипирован пистолет",
		"(получено \"%s\")" % _gs.equipped_weapon_id)
	_check(_packed_eq(_gs.unlocked_locations, ["range"]),
		"разблокировано только стрельбище", "(получено %s)" % _gs.unlocked_locations)


func _test_award_points() -> void:
	print("-- award_points: добавление очков, игнорирование отрицательных значений")
	_gs.award_points(10)
	_check(_gs.points == 10, "award_points(10) добавляет 10 очков", "(получено %d)" % _gs.points)
	_gs.award_points(-5)
	_check(_gs.points == 10, "award_points(-5) игнорируется и не уменьшает баланс",
		"(получено %d)" % _gs.points)


func _test_afford() -> void:
	print("-- can_afford: автомат стоит 300 очков")
	_check(_gs.weapon_price("auto") == 300,
		"weapon_price(\"auto\") считывает 300 из auto.tres",
		"(получено %d)" % _gs.weapon_price("auto"))
	_check(not _gs.can_afford(300), "при 10 очках нельзя купить автомат за 300")
	_gs.award_points(300)
	_check(_gs.can_afford(300), "после award_points(300) хватает средств на автомат")


func _test_buy_weapon() -> void:
	print("-- buy_weapon: списание стоимости, получение и экипировка оружия")
	var bought := _gs.buy_weapon("auto")
	_check(bought, "buy_weapon(\"auto\") успешен при наличии достаточных средств")
	_check(_gs.points == 10, "цена 300 списана корректно (310 -> 10)",
		"(получено %d)" % _gs.points)
	_check("auto" in _gs.owned_weapons, "\"auto\" теперь в наличии",
		"(получено %s)" % _gs.owned_weapons)
	_check(_gs.equipped_weapon_id == "auto", "и автомат экипирован",
		"(получено \"%s\")" % _gs.equipped_weapon_id)


func _test_buy_owned_again() -> void:
	print("-- buy_weapon для уже купленного оружия: только экипировка без повторного списания")
	var again := _gs.buy_weapon("auto")
	_check(again, "покупка уже имеющегося оружия возвращает true")
	_check(_gs.points == 10, "очки не списываются повторно",
		"(получено %d)" % _gs.points)
	_check(_gs.owned_weapons.size() == 2,
		"оружие не дублируется в инвентаре", "(получено %s)" % _gs.owned_weapons)


## Оружие без файла .tres сообщает цену 0, но это не должно делать его доступным бесплатно:
## отсутствие ресурса означает отказ в покупке.
func _test_buy_missing() -> void:
	print("-- buy_weapon(\"nope\"): несуществующий ресурс не продается")
	_check(_gs.weapon_price("nope") == 0,
		"weapon_price(\"nope\") возвращает 0 при отсутствии",
		"(получено %d)" % _gs.weapon_price("nope"))
	var bought := _gs.buy_weapon("nope")
	_check(not bought, "buy_weapon отклоняет оружие без файла .tres")
	_check(not ("nope" in _gs.owned_weapons), "и не добавляет его в список владения",
		"(получено %s)" % _gs.owned_weapons)


func _test_equip() -> void:
	print("-- equip_weapon: экипировка только имеющегося оружия")
	_check(_gs.equip_weapon("pistol"), "экипировка имеющегося пистолета возвращает true")
	_check(_gs.equipped_weapon_id == "pistol", "пистолет снова экипирован",
		"(получено \"%s\")" % _gs.equipped_weapon_id)
	_check(_gs.equip_weapon("auto"), "экипировка имеющегося автомата возвращает true")
	_check(_gs.equipped_weapon_id == "auto", "автомат экипирован",
		"(получено \"%s\")" % _gs.equipped_weapon_id)
	_check(not _gs.equip_weapon("nope"), "экипировка некупленного оружия отклоняется")
	_check(_gs.equipped_weapon_id == "auto",
		"и текущее экипированное оружие не изменяется",
		"(получено \"%s\")" % _gs.equipped_weapon_id)


func _test_enter_location() -> void:
	print("-- enter_location: только разблокированные локации через внедренный обработчик")
	var entered := _gs.enter_location("range")
	_check(entered, "переход в разблокированное стрельбище успешен")
	_check(_packed_eq(_changed_to, ["res://levels/range/range.tscn"]),
		"обработчик запросил переход на res://levels/range/range.tscn", "(получено %s)" % _changed_to)
	var before := _changed_to.size()
	_check(not _gs.enter_location("secret"), "заблокированная локация отклоняется")
	_check(_changed_to.size() == before,
		"и смена сцены не запрашивалась", "(получено %s)" % _changed_to)


func _test_return_to_lobby() -> void:
	print("-- return_to_lobby: возврат в лобби через обработчик")
	_gs.return_to_lobby("death")
	_check(_packed_eq(_changed_to, ["res://levels/range/range.tscn", "res://levels/lobby/lobby.tscn"]),
		"обработчик запросил переход на res://levels/lobby/lobby.tscn",
		"(получено %s)" % _changed_to)


func _test_autosave_roundtrip() -> void:
	print("-- autosave: изменения сохраняются на диск, а чистое состояние корректно загружается")
	# Покупка и экипировка выше уже должны быть записаны на диск:
	# автосохранение после каждого изменения данных.
	var disk := _save.load_state()
	_check(int(disk.get("points", -1)) == 10,
		"автосохранение после покупки/экипировки сохранило points == 10",
		"(получено %s)" % disk.get("points"))
	_check(disk.get("equipped_weapon_id") == "auto",
		"автосохранение зафиксировало экипированное оружие",
		"(получено %s)" % disk.get("equipped_weapon_id"))

	# Проверка чистого сохранения: award_points(50) в новом состоянии с последующим чтением с диска.
	_save.clear_save()
	_roundtrip = GameState.new()
	root.add_child(_roundtrip)
	await physics_frame
	_roundtrip.award_points(50)
	await physics_frame
	var loaded := _save.load_state()
	_check(int(loaded.get("points", -1)) == 50,
		"award_points(50) сохранено на диск как points == 50",
		"(получено %s)" % loaded.get("points"))
	_check(loaded.get("equipped_weapon_id") == "pistol",
		"и сохраненное экипированное оружие корректно",
		"(получено %s)" % loaded.get("equipped_weapon_id"))


func _test_save_debounce_and_batching() -> void:
	print("-- save debounce & batching: множественные award_points не вызывают синхронного I/O")
	_save.clear_save()
	_save.reset_save_count()
	var test_gs := GameState.new()
	root.add_child(test_gs)
	await physics_frame

	# 1. Проверка отсутствия синхронных блокирующих записей при множественных award_points
	var initial_writes := _save.save_count
	test_gs.award_points(10)
	test_gs.award_points(20)
	test_gs.award_points(30)
	_check(_save.save_count == initial_writes,
		"множественные award_points подряд не вызывают синхронных записей на диск",
		"(записей %d)" % _save.save_count)
	_check(test_gs.is_save_dirty(),
		"состояние GameState помечено как dirty после начисления очков")
	_check(test_gs.points == 60,
		"очки корректно аккумулированы в памяти (60)", "(получено %d)" % test_gs.points)

	# 2. Проверка принудительной фиксации состояния через flush_save()
	var flushed := test_gs.flush_save()
	_check(flushed, "flush_save() возвращает true при успешной фиксации")
	_check(_save.save_count == initial_writes + 1,
		"flush_save() выполнил ровно 1 запись на диск для накопленного пакета очков",
		"(записей %d)" % _save.save_count)
	_check(not test_gs.is_save_dirty(),
		"после flush_save() состояние больше не dirty")
	var disk_data := _save.load_state()
	_check(int(disk_data.get("points", -1)) == 60,
		"на диске зафиксированы все 60 очков", "(получено %s)" % disk_data.get("points"))

	# 3. Повторный вызов flush_save() без изменений не производит лишних записей на диск
	var second_flush := test_gs.flush_save()
	_check(second_flush, "повторный flush_save() возвращает true")
	_check(_save.save_count == initial_writes + 1,
		"повторный flush_save() без dirty-состояния не производит повторной записи на диск",
		"(записей %d)" % _save.save_count)

	# 4. Проверка дебаунс-таймера (симуляция обычного игрового режима с задержкой 1.5 с)
	test_gs.autosave_debounce_delay = 1.5
	test_gs.award_points(40)
	_check(test_gs.is_save_dirty(), "состояние снова dirty после award_points(40)")
	# Ждем 1 кадр физики — при задержке 1.5 с запись на диск не должна происходить через 1 кадр
	await physics_frame
	_check(_save.save_count == initial_writes + 1,
		"при активном дебаунс-таймере запись на диск не происходит на следующем физическом кадре",
		"(записей %d)" % _save.save_count)
	# Принудительный сброс через flush_save() фиксирует очки немедленно
	test_gs.flush_save()
	_check(_save.save_count == initial_writes + 2,
		"flush_save() принудительно сбрасывает данные, не дожидаясь истечения таймера",
		"(записей %d)" % _save.save_count)
	var final_disk := _save.load_state()
	_check(int(final_disk.get("points", -1)) == 100,
		"на диске зафиксированы все 100 очков", "(получено %s)" % final_disk.get("points"))

	root.remove_child(test_gs)
	test_gs.free()

