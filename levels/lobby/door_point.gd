class_name DoorPoint
extends Area3D

## Дверь лобби: точка входа в локацию. Те же конвенции, что у ShopPoint: слой 6
## (interactable), триггер видит только игрока. interact() зовёт
## GameState.enter_location(location_id), который сам решает, открыта ли
## локация, и уходит в смену сцены через подменяемый scene_changer.

## Какую локацию открывает эта дверь (id из GameState._LOCATION_SCENES).
@export var location_id: String = "range"


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
	if location_id == "arena_01" and not ("arena_01" in gs.unlocked_locations):
		gs.unlock_location("arena_01")
	return gs.enter_location(location_id)
