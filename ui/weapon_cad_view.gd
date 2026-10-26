class_name WeaponCadView
extends Control

## Векторный 2D-компонент архитектурного CAD-чертежа оружия.
## Отрисовывает координатную CAD-сетку и векторные проекции оружия (вид сбоку)
## с размерными линиями и техническими засечками.

## Идентификатор оружия ("pistol", "auto", "shotgun").
@export var weapon_id: String = "pistol":
	set(value):
		weapon_id = value
		queue_redraw()

const GRID_STEP: float = 15.0
const GRID_COLOR: Color = Color(1.0, 1.0, 1.0, 0.08)
const LINE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.95)
const DIMENSION_COLOR: Color = Color(0.75, 0.75, 0.75, 0.85)
const ACCENT_COLOR: Color = Color(0.9, 0.9, 0.9, 0.5)


func _draw() -> void:
	_draw_grid()
	match weapon_id:
		"auto":
			_draw_ak47()
		"shotgun":
			_draw_shotgun()
		_:
			_draw_pistol()


## Отрисовка координатной сетки CAD
func _draw_grid() -> void:
	var w: float = size.x
	var h: float = size.y
	var x: float = 0.0
	while x <= w:
		draw_line(Vector2(x, 0.0), Vector2(x, h), GRID_COLOR, 1.0)
		x += GRID_STEP
	var y: float = 0.0
	while y <= h:
		draw_line(Vector2(0.0, y), Vector2(w, y), GRID_COLOR, 1.0)
		y += GRID_STEP


## Векторная проекция пистолета с размерной линией 180 мм
func _draw_pistol() -> void:
	var ox: float = size.x * 0.5 - 5.0
	var oy: float = size.y * 0.5 + 5.0
	var font: Font = ThemeDB.fallback_font

	# Затвор и ствол
	var slide := PackedVector2Array([
		Vector2(ox - 45.0, oy - 22.0),
		Vector2(ox + 45.0, oy - 22.0),
		Vector2(ox + 45.0, oy + 2.0),
		Vector2(ox - 45.0, oy + 2.0),
		Vector2(ox - 45.0, oy - 22.0)
	])
	draw_polyline(slide, LINE_COLOR, 2.0)

	# Насечки на затворе (rear serrations)
	for i in range(4):
		var sx: float = ox - 40.0 + float(i) * 5.0
		draw_line(Vector2(sx, oy - 20.0), Vector2(sx, oy - 5.0), ACCENT_COLOR, 1.0)

	# Ствол и дульный срез
	draw_line(Vector2(ox + 45.0, oy - 16.0), Vector2(ox + 52.0, oy - 16.0), LINE_COLOR, 1.5)
	draw_line(Vector2(ox + 52.0, oy - 16.0), Vector2(ox + 52.0, oy - 4.0), LINE_COLOR, 1.5)
	draw_line(Vector2(ox + 52.0, oy - 4.0), Vector2(ox + 45.0, oy - 4.0), LINE_COLOR, 1.5)

	# Прицельные приспособления (целик и мушка)
	draw_line(Vector2(ox - 42.0, oy - 22.0), Vector2(ox - 42.0, oy - 27.0), LINE_COLOR, 2.0)
	draw_line(Vector2(ox - 37.0, oy - 27.0), Vector2(ox - 37.0, oy - 22.0), LINE_COLOR, 2.0)
	draw_line(Vector2(ox + 40.0, oy - 22.0), Vector2(ox + 40.0, oy - 27.0), LINE_COLOR, 2.0)

	# Рукоять с наклоном
	var grip := PackedVector2Array([
		Vector2(ox - 45.0, oy + 2.0),
		Vector2(ox - 25.0, oy + 55.0),
		Vector2(ox - 5.0, oy + 50.0),
		Vector2(ox - 18.0, oy + 2.0)
	])
	draw_polyline(grip, LINE_COLOR, 2.0)

	# Спусковая скоба и спуск
	var trigger_guard := PackedVector2Array([
		Vector2(ox - 18.0, oy + 2.0),
		Vector2(ox - 18.0, oy + 20.0),
		Vector2(ox + 5.0, oy + 20.0),
		Vector2(ox + 5.0, oy + 2.0)
	])
	draw_polyline(trigger_guard, LINE_COLOR, 1.5)
	draw_line(Vector2(ox - 10.0, oy + 5.0), Vector2(ox - 5.0, oy + 14.0), LINE_COLOR, 2.0)

	# Размерная линия: 180 мм
	_draw_dimension_h(ox - 45.0, ox + 52.0, oy - 38.0, "180 mm", font)


## Векторная проекция автомата АК-47 с размерной линией 870 мм
func _draw_ak47() -> void:
	var ox: float = size.x * 0.5
	var oy: float = size.y * 0.5 - 5.0
	var font: Font = ThemeDB.fallback_font

	# Ствольная коробка
	var receiver := PackedVector2Array([
		Vector2(ox - 30.0, oy - 12.0),
		Vector2(ox + 35.0, oy - 12.0),
		Vector2(ox + 35.0, oy + 12.0),
		Vector2(ox - 30.0, oy + 12.0),
		Vector2(ox - 30.0, oy - 12.0)
	])
	draw_polyline(receiver, LINE_COLOR, 2.0)

	# Деревянный приклад АК-47
	var stock := PackedVector2Array([
		Vector2(ox - 30.0, oy - 10.0),
		Vector2(ox - 92.0, oy + 4.0),
		Vector2(ox - 88.0, oy + 36.0),
		Vector2(ox - 30.0, oy + 12.0)
	])
	draw_polyline(stock, LINE_COLOR, 2.0)
	draw_line(Vector2(ox - 92.0, oy + 4.0), Vector2(ox - 88.0, oy + 36.0), LINE_COLOR, 3.0) # затыльник

	# Газоотводная трубка и цевьё
	var handguard := PackedVector2Array([
		Vector2(ox + 35.0, oy - 12.0),
		Vector2(ox + 75.0, oy - 12.0),
		Vector2(ox + 75.0, oy + 10.0),
		Vector2(ox + 35.0, oy + 10.0)
	])
	draw_polyline(handguard, LINE_COLOR, 1.8)
	draw_line(Vector2(ox + 35.0, oy - 2.0), Vector2(ox + 75.0, oy - 2.0), ACCENT_COLOR, 1.0)

	# Ствол и компенсатор
	draw_line(Vector2(ox + 75.0, oy - 8.0), Vector2(ox + 105.0, oy - 8.0), LINE_COLOR, 2.0)
	draw_line(Vector2(ox + 75.0, oy - 2.0), Vector2(ox + 105.0, oy - 2.0), LINE_COLOR, 2.0)
	draw_line(Vector2(ox + 105.0, oy - 10.0), Vector2(ox + 105.0, oy), LINE_COLOR, 2.0)

	# Высокая мушка АК-47
	var front_sight := PackedVector2Array([
		Vector2(ox + 96.0, oy - 8.0),
		Vector2(ox + 98.0, oy - 22.0),
		Vector2(ox + 102.0, oy - 22.0),
		Vector2(ox + 104.0, oy - 8.0)
	])
	draw_polyline(front_sight, LINE_COLOR, 1.5)

	# Прицельная планка
	draw_line(Vector2(ox + 33.0, oy - 12.0), Vector2(ox + 42.0, oy - 19.0), LINE_COLOR, 2.0)

	# Характерный изогнутый рожок-магазин АК-47
	var magazine := PackedVector2Array([
		Vector2(ox + 12.0, oy + 12.0),
		Vector2(ox + 22.0, oy + 42.0),
		Vector2(ox + 30.0, oy + 54.0),
		Vector2(ox + 18.0, oy + 56.0),
		Vector2(ox + 10.0, oy + 42.0),
		Vector2(ox - 2.0, oy + 12.0)
	])
	draw_polyline(magazine, LINE_COLOR, 2.0)

	# Пистолетная рукоять и спуск
	var grip := PackedVector2Array([
		Vector2(ox - 22.0, oy + 12.0),
		Vector2(ox - 10.0, oy + 45.0),
		Vector2(ox + 2.0, oy + 42.0),
		Vector2(ox - 10.0, oy + 12.0)
	])
	draw_polyline(grip, LINE_COLOR, 1.8)
	draw_line(Vector2(ox - 10.0, oy + 12.0), Vector2(ox + 6.0, oy + 20.0), LINE_COLOR, 1.5)
	draw_line(Vector2(ox + 6.0, oy + 20.0), Vector2(ox + 10.0, oy + 12.0), LINE_COLOR, 1.5)

	# Размерная линия: 870 мм
	_draw_dimension_h(ox - 92.0, ox + 105.0, oy - 32.0, "870 mm", font)


## Векторная проекция двустволки с размерной линией 650 мм
func _draw_shotgun() -> void:
	var ox: float = size.x * 0.5
	var oy: float = size.y * 0.5 - 5.0
	var font: Font = ThemeDB.fallback_font

	# Спаренные горизонтальные стволы (вид сбоку: верхний и нижний контуры)
	draw_line(Vector2(ox - 10.0, oy - 10.0), Vector2(ox + 98.0, oy - 10.0), LINE_COLOR, 2.0)
	draw_line(Vector2(ox - 10.0, oy - 5.0), Vector2(ox + 98.0, oy - 5.0), ACCENT_COLOR, 1.0) # разделительная планка
	draw_line(Vector2(ox - 10.0, oy), Vector2(ox + 98.0, oy), LINE_COLOR, 2.0)
	draw_line(Vector2(ox + 98.0, oy - 10.0), Vector2(ox + 98.0, oy), LINE_COLOR, 2.0) # срез

	# Мушка на стволе
	draw_line(Vector2(ox + 94.0, oy - 10.0), Vector2(ox + 94.0, oy - 14.0), LINE_COLOR, 2.0)

	# Деревянное цевье (forearm)
	var forearm := PackedVector2Array([
		Vector2(ox - 8.0, oy),
		Vector2(ox + 46.0, oy),
		Vector2(ox + 40.0, oy + 10.0),
		Vector2(ox - 8.0, oy + 10.0),
		Vector2(ox - 8.0, oy)
	])
	draw_polyline(forearm, LINE_COLOR, 1.8)

	# Колодка (receiver) и переломный шарнир (break-action hinge)
	var receiver := PackedVector2Array([
		Vector2(ox - 30.0, oy - 12.0),
		Vector2(ox - 10.0, oy - 12.0),
		Vector2(ox - 8.0, oy + 12.0),
		Vector2(ox - 30.0, oy + 12.0),
		Vector2(ox - 30.0, oy - 12.0)
	])
	draw_polyline(receiver, LINE_COLOR, 2.0)
	draw_arc(Vector2(ox - 12.0, oy + 6.0), 3.5, 0.0, TAU, 16, LINE_COLOR, 1.5) # шарнир

	# Рычаг отпирания стволов (top lever)
	draw_line(Vector2(ox - 24.0, oy - 12.0), Vector2(ox - 28.0, oy - 18.0), LINE_COLOR, 2.0)

	# Фигурный деревянный приклад (contoured stock)
	var stock := PackedVector2Array([
		Vector2(ox - 30.0, oy - 12.0),
		Vector2(ox - 88.0, oy + 10.0),
		Vector2(ox - 84.0, oy + 42.0),
		Vector2(ox - 45.0, oy + 26.0),
		Vector2(ox - 30.0, oy + 12.0)
	])
	draw_polyline(stock, LINE_COLOR, 2.0)
	draw_line(Vector2(ox - 88.0, oy + 10.0), Vector2(ox - 84.0, oy + 42.0), LINE_COLOR, 3.0)

	# Спусковая скоба и сдвоенные спусковые крючки
	var guard := PackedVector2Array([
		Vector2(ox - 28.0, oy + 12.0),
		Vector2(ox - 24.0, oy + 24.0),
		Vector2(ox - 8.0, oy + 22.0),
		Vector2(ox - 8.0, oy + 12.0)
	])
	draw_polyline(guard, LINE_COLOR, 1.5)
	draw_line(Vector2(ox - 20.0, oy + 12.0), Vector2(ox - 17.0, oy + 20.0), LINE_COLOR, 1.5)
	draw_line(Vector2(ox - 14.0, oy + 12.0), Vector2(ox - 12.0, oy + 19.0), LINE_COLOR, 1.5)

	# Размерная линия: 650 мм
	_draw_dimension_h(ox - 88.0, ox + 98.0, oy - 30.0, "650 mm", font)


## Вспомогательный метод отрисовки горизонтальной размерной линии с засечками и текстом
func _draw_dimension_h(x1: float, x2: float, y: float, label: String, font: Font) -> void:
	# Выносные линии
	draw_line(Vector2(x1, y + 15.0), Vector2(x1, y - 6.0), DIMENSION_COLOR, 1.0)
	draw_line(Vector2(x2, y + 15.0), Vector2(x2, y - 6.0), DIMENSION_COLOR, 1.0)

	# Основная размерная линия
	draw_line(Vector2(x1, y), Vector2(x2, y), DIMENSION_COLOR, 1.0)

	# Засечки (стрелки) на концах
	draw_line(Vector2(x1, y), Vector2(x1 + 6.0, y - 3.0), DIMENSION_COLOR, 1.2)
	draw_line(Vector2(x1, y), Vector2(x1 + 6.0, y + 3.0), DIMENSION_COLOR, 1.2)
	draw_line(Vector2(x2, y), Vector2(x2 - 6.0, y - 3.0), DIMENSION_COLOR, 1.2)
	draw_line(Vector2(x2, y), Vector2(x2 - 6.0, y + 3.0), DIMENSION_COLOR, 1.2)

	# Подпись размера
	var mid_x: float = (x1 + x2) * 0.5
	var text_pos := Vector2(mid_x - 30.0, y - 4.0)
	draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_CENTER, 60, 12, DIMENSION_COLOR)
