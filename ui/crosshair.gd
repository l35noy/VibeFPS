class_name Crosshair
extends Control

## Прицел: точка в центре экрана со светлым центром и тонкой темной обводкой
## для четкой различимости на любых фонах (светлые CAD-поверхности, геометрия, темные враги).

## Радиус внутренней светлой точки в пикселях.
@export var dot_radius: float = 2.0:
	set(value):
		dot_radius = value
		queue_redraw()

## Толщина темной окантовки в пикселях.
@export var outline_width: float = 1.0:
	set(value):
		outline_width = value
		queue_redraw()

## Цвет внутренней точки.
@export var dot_color: Color = Color(1.0, 1.0, 1.0, 0.95):
	set(value):
		dot_color = value
		queue_redraw()

## Цвет темного канта (согласован с line_color шейдера контуров).
@export var outline_color: Color = Color(0.08, 0.09, 0.1, 0.95):
	set(value):
		outline_color = value
		queue_redraw()


func _ready() -> void:
	# Игнорировать клики мыши, чтобы прицел не перехватывал фокус и события интерфейса
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	# 1. Тонкий темный кант (внешний круг)
	draw_circle(Vector2.ZERO, dot_radius + outline_width, outline_color, true, -1.0, true)
	# 2. Светлая точка по центру (внутренний круг)
	draw_circle(Vector2.ZERO, dot_radius, dot_color, true, -1.0, true)
