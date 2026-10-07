class_name WeaponData
extends Resource

## Характеристики оружия как данные.
##
## Одно оружие — один ресурс, одна структура полей. Поведение (магазин,
## перезарядка, огонь) живёт в скрипте оружия, а не здесь: ресурс ничего не
## знает про узлы сцены, поэтому его можно проверить headless, не строя мир.

@export var display_name: String = "Weapon"
@export var damage: float = 30.0
## Выстрелов в минуту. Интервал между выстрелами = 60 / rounds_per_minute.
@export var rounds_per_minute: float = 120.0
@export var magazine_size: int = 10
@export var reload_time: float = 1.2
## Скорость снаряда в м/с. Конечная скорость обязательна: игрок и враг могут
## уклоняться. На 40 м/с снаряд пистолета пролетает 15 м за 0.375 с, и это
## окно, за которое цель успевает отойти. Это игровое правило из PROJECT.md
## §9.8, а не техническая деталь: мгновенный (хитскан) выстрел это окно
## убирает, и уклонение становится невозможным.
@export var projectile_speed: float = 40.0
@export var projectile_radius: float = 0.08
@export var projectile_lifetime: float = 3.0
## Цвет снаряда и шлейфа. Геометрический стиль: контрастная геометрия.
@export var projectile_color: Color = Color(0.15, 0.15, 0.15)


## Интервал между выстрелами в секундах. Производное от rounds_per_minute,
## поэтому не хранится вторым числом, которое может разъехаться с первым.
func seconds_between_shots() -> float:
	return 60.0 / rounds_per_minute


## Пригодны ли данные к стрельбе. Оружие спрашивает это до выстрела, а не
## падает на делении на ноль: rounds_per_minute == 0 сделала бы
## seconds_between_shots() бесконечной, magazine_size == 0 — вечной
## перезарядкой без патронов.
func is_valid() -> bool:
	return rounds_per_minute > 0.0 and magazine_size > 0 \
		and reload_time > 0.0 and damage > 0.0 and projectile_speed > 0.0
