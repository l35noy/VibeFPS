extends SceneTree

## Проверка данных оружия (WeaponData) для VibeFPS.
##
## Загружает res://data/weapons/pistol.tres через load() и валидирует его числовые
## параметры, вычисляемый темп стрельбы и метод is_valid().
## Не инстанцирует сцены: это проверка ресурса данных.
## Запуск: godot --headless --path . --script res://tests/weapon_data.gd
##         .\tools\run_checks.ps1 weapon_data

const _PISTOL_PATH := "res://data/weapons/pistol.tres"

## Допуск сравнения интервала выстрелов (числа с плавающей точкой).
const _EPS := 0.0001

## Дизайн фиксирует пистолет: 150 выстрелов в минуту, 18 патронов в магазине.
## 150 выстрелов в минуту = 1 выстрел каждые 0.4 с; полный магазин = 7.2 с непрерывной стрельбы.
const _EXPECTED_BURST_SECONDS := 7.2

var _failures: PackedStringArray = []
var _checks := 0


func _check(ok: bool, label: String, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  [PASS] %s %s" % [label, detail])
	else:
		_failures.append("%s %s" % [label, detail])
		print("  [FAIL] %s %s" % [label, detail])


func _close(got: float, want: float) -> bool:
	return absf(got - want) <= _EPS


## Создаёт временный WeaponData с переопределённым полем для проверки граничных условий.
func _probe(overrides: Dictionary) -> WeaponData:
	var probe := WeaponData.new()
	for key in overrides:
		probe.set(key, overrides[key])
	return probe


## Возвращает true только если is_valid() действительно отвергает некорректное значение.
func _is_valid_rejects(overrides: Dictionary) -> bool:
	return not _probe(overrides).is_valid()


func _finish() -> void:
	print("=== РЕЗУЛЬТАТ: %d проверок, %d провалено ===" % [_checks, _failures.size()])
	for f in _failures:
		print("  ОШИБКА: %s" % f)


func _bail(reason: String) -> void:
	print("FATAL: %s" % reason)
	_finish()
	quit(1)


func _initialize() -> void:
	print("=== Данные оружия (WeaponData) ===")

	print("-- %s должен загружаться как WeaponData" % _PISTOL_PATH)
	var res: Resource = load(_PISTOL_PATH)
	if res == null:
		_bail("не удалось загрузить %s" % _PISTOL_PATH)
		return
	var script_res := res.get_script() as Script
	_check(res is WeaponData, "pistol.tres является экземпляром WeaponData",
		"(script=%s)" % ("none" if script_res == null else script_res.resource_path))
	var data := res as WeaponData
	if data == null:
		_bail("pistol.tres не является WeaponData, дальнейшие проверки бессмысленны")
		return

	print("-- значения баланса пистолета из дизайна")
	_check(data.display_name == "Pistol", "display_name равен \"Pistol\"",
		"(получено \"%s\")" % data.display_name)
	_check(data.price == 0, "цена начального оружия равна 0",
		"(получено %d)" % data.price)
	_check(data.damage == 30.0, "урон равен 30.0", "(получено %.4f)" % data.damage)
	_check(data.rounds_per_minute == 150.0, "rounds_per_minute равен 150.0",
		"(получено %.4f)" % data.rounds_per_minute)
	_check(data.magazine_size == 18, "magazine_size равен 18",
		"(получено %d)" % data.magazine_size)
	_check(data.reload_time == 1.2, "reload_time равен 1.2 с", "(получено %.4f)" % data.reload_time)
	_check(data.projectile_speed == 80.0, "projectile_speed равен 80.0 м/с",
		"(получено %.4f)" % data.projectile_speed)
	_check(data.projectile_radius == 0.05, "projectile_radius равен 0.05 м",
		"(получено %.4f)" % data.projectile_radius)
	_check(data.projectile_lifetime == 4.0, "projectile_lifetime равен 4.0 с",
		"(получено %.4f)" % data.projectile_lifetime)
	_check(data.projectile_color == Color(1.0, 1.0, 1.0),
		"projectile_color равен белому Color(1.0, 1.0, 1.0)",
		"(получено %s)" % data.projectile_color)

	_check(data.projectile_speed > 0.0 and is_finite(data.projectile_speed),
		"скорость снаряда конечна и не равна нулю (баллистический снаряд, от которого можно увернуться)",
		"(%.1f м/с; пуля проходит 15 м за %.3f с)" % [
			data.projectile_speed, 15.0 / data.projectile_speed])

	print("-- вычисляемый интервал стрельбы")
	_check(_close(data.seconds_between_shots(), 0.4),
		"seconds_between_shots() равен 0.4 с при 150 выстр/мин", "(получено %.6f, допуск %.4f)" % [
			data.seconds_between_shots(), _EPS])
	_check(_close(_probe({"rounds_per_minute": 60.0}).seconds_between_shots(), 1.0),
		"seconds_between_shots() динамически следует за скорострельностью, а не зашит константой",
		"(60 выстр/мин -> %.6f с)" % _probe({"rounds_per_minute": 60.0}).seconds_between_shots())

	print("-- валидация данных через is_valid()")
	_check(data.is_valid(), "pistol.tres сообщает о своей валидности (is_valid == true)")
	_check(_is_valid_rejects({"rounds_per_minute": 0.0}),
		"нулевая скорострельность отвергается")
	_check(_is_valid_rejects({"magazine_size": 0}),
		"нулевой размер магазина отвергается")
	_check(_is_valid_rejects({"reload_time": 0.0}),
		"нулевое время перезарядки отвергается")
	_check(_is_valid_rejects({"damage": 0.0}),
		"нулевой урон отвергается")
	_check(_is_valid_rejects({"projectile_speed": 0.0}),
		"нулевая скорость снаряда отвергается")

	print("-- инвариант длины непрерывной очереди")
	var burst := float(data.magazine_size) * data.seconds_between_shots()
	_check(_close(burst, _EXPECTED_BURST_SECONDS),
		"опустошение полного магазина занимает %.1f с непрерывной стрельбы" % _EXPECTED_BURST_SECONDS,
		"(вычислено %.6f из magazine_size=%d и %.6f с на выстрел)" % [
			burst, data.magazine_size, data.seconds_between_shots()])

	_finish()
	quit(1 if _failures.size() > 0 else 0)
