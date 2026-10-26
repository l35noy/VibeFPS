extends Node3D

## Первая боевая локация VibeFPS (Фаза 4).
##
## Содержит запечённый навмеш арены, укрытия, точки спавна и WaveManager,
## управляющий 4 волнами врагов.

@onready var _region: NavigationRegion3D = get_node_or_null("NavigationRegion3D") as NavigationRegion3D
@onready var _wave_manager: WaveManager = get_node_or_null("WaveManager") as WaveManager
@onready var _exit_portal: Area3D = get_node_or_null("ExitPortal") as Area3D


func _ready() -> void:
	if _region != null and _region.navigation_mesh != null:
		_region.bake_navigation_mesh(false)

	if _exit_portal != null:
		_exit_portal.visible = false
		_exit_portal.monitoring = false
		_exit_portal.collision_layer = 0

	if _wave_manager != null:
		_wave_manager.location_cleared.connect(_on_location_cleared)


func _on_location_cleared() -> void:
	if _exit_portal != null:
		_exit_portal.visible = true
		_exit_portal.monitoring = true
		_exit_portal.collision_layer = 1 << 5
