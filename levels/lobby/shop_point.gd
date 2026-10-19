class_name ShopPoint
extends Area3D

## Витрина лобби: точка покупки оружия. Стоит в комнате, игрок подходит вплотную
## и жмёт E; interact() проводит покупку через GameState и говорит, удалась ли
## она. Слой 6 (interactable), маска — только игрок: точка должна видеть игрока
## своим триггером, но не сталкиваться ни с чем остальным.
##
## interact(player) держит player только ради единого протокола взаимодействия
## (у DoorPoint сигнатура та же) — покупает сама покупка, а не игрок.

## Покупка состоялась (или была отклонена). Сигнал об изменении: HUD и тесты
## узнают о результате, не опрашивая состояние.
signal interacted(ok: bool)

## Какое оружие продаёт эта витрина. Имя файла в data/weapons без расширения.
@export var weapon_id: String = "auto"


func _ready() -> void:
	collision_layer = 1 << 5
	collision_mask = 1 << 1
	monitoring = true
	add_to_group("interactable")


@warning_ignore("unused_parameter")
func interact(player: Node) -> bool:
	var gs := get_node_or_null("/root/GameState") as GameState
	if gs == null:
		return false
	var ok := gs.buy_weapon(weapon_id)
	interacted.emit(ok)
	return ok