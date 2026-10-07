class_name RangeTarget
extends StaticBody3D

## Мишень тира: геометрия, хитбокс и реакция на попадание.
##
## `Hurtbox` по контракту не хранит состояние: он только сообщает о попадании
## сигналом `damage_taken`, а здоровье живёт у того, кто хитбоксом владеет. В
## Фазе 2 этим владельцем будет враг. Здесь владелец — мишень, и её реакция
## обязана быть видна глазом: попадание, которое нельзя увидеть, невозможно и
## отладить.
##
## Три решения:
##
## 1. Реакция — вспышка цвета, а не счётчик очков и не разрушаемая геометрия.
##    Вспышка не убирает мишень со сцены, поэтому десятый выстрел в неё же
##    ведёт себя так же, как первый, и дистанция не влияет на результат.
## 2. Материал дублируется в `_ready()`. `surface_material_override` в сцене —
##    общий SubResource: если бы мишень меняла цвет на нём, все три мишени
##    вспыхивали бы одновременно, и «попадание в дальнюю» перестало бы читаться.
## 3. Цвет возвращается к исходному по таймеру, а не остаётся навсегда, иначе
##    через десять попаданий тир был бы полностью красным.

## Сколько секунд мишень горит после попадания.
@export var hit_flash_time: float = 0.3
## Цвет вспышки. Белый, а не «тёмнее своей же окраски»: у мишеней уже есть
## свой цвет, и вспышка, близкая к нему, на кадре не читается.
@export var flash_color: Color = Color(1, 1, 1)

@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _mesh: MeshInstance3D = $Mesh

var _flash_left: float = 0.0
var _base_color: Color = Color.WHITE
var _material: StandardMaterial3D
## Сколько раз в мишень попали. Живёт здесь, а не в хитбоксе: у хитбокса нет
## состояния по контракту, и счётчик попаданий — тоже не его дело.
var _hits: int = 0


func _ready() -> void:
	var override := _mesh.get_surface_override_material(0) as StandardMaterial3D
	if override != null:
		# duplicate(), а не присваивание: общий SubResource принадлежит всей
		# сцене, и вспышка одной мишени перекрасила бы все три.
		_material = override.duplicate()
		_base_color = _material.albedo_color
		_mesh.set_surface_override_material(0, _material)
	if _hurtbox != null:
		_hurtbox.damage_taken.connect(_on_damage_taken)


func _on_damage_taken(amount: float) -> void:
	_flash_left = hit_flash_time
	# Строка в консоли — это наблюдаемое попадание: вспышку можно пропустить
	# взглядом, а напечатанное число попаданий нельзя.
	print("[range] %s took %.1f damage (hits: %d)" % [name, amount, _hits + 1])
	_hits += 1


func hit_count() -> int:
	return _hits


func _process(delta: float) -> void:
	if _flash_left <= 0.0 or _material == null:
		return
	_flash_left = maxf(0.0, _flash_left - delta)
	var weight := 1.0 if hit_flash_time <= 0.0 else _flash_left / hit_flash_time
	_material.albedo_color = _base_color.lerp(flash_color, weight)