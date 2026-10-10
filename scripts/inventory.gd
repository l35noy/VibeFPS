extends Control

## Инвентарь игрока: панель с кнопками купленного оружия, выбор мышью.
##
## Живёт узлом `InventoryPanel` в `ui.tscn` (player-attached UI из Task 9),
## поэтому доступен везде, где есть игрок, и переживает смену сцены вместе с
## ним. Открывается/закрывается действием `inventory` (физическая I).
##
## Обработка I НЕ гейтится `InputGate`, в отличие от движения, обзора, огня и
## E. Это осознанно: игровой ввод разрешён только при захваченном курсоре, а
## инвентарь как раз и открывают при захваченном курсоре — это UI-действие,
## ровно как пауза. Само открытие переводит курсор в VISIBLE, и уже это
## существующим гейтом гасит движение/обзор/прыжок/огонь/E: отдельного кода
## «заморозить игру» не требуется.
##
## Кнопки строятся по `GameState.owned_weapons`; подпись — `WeaponData.display_name`
## из `res://data/weapons/<id>.tres`, а если ресурса нет — сам id. Текущий
## экипированный ствол помечен. Клик экипирует и закрывает панель.
##
## Null-safe: нет `/root/GameState` — панель открывается пустой, без ошибок.
## `bind()` отделён от `_ready()` по тому же принципу, что в `ui.gd`: тест
## впрыскивает источник явно.

## Выбрано оружие (id). Сигнал об изменении, чтобы вызывающий код узнал о
## выборе, не читая GameState.
signal weapon_selected(weapon_id: String)

const _WEAPON_DATA_PATH := "res://data/weapons/%s.tres"
## Метка текущего экипированного оружия. Текстом, а не цветом: проверяемо без
## рендерера, и цвет не единственный носитель смысла.
const _EQUIPPED_MARK := " ✓"

var _game_state: Node = null
var _open: bool = false

@onready var _list: VBoxContainer = get_node_or_null("List") as VBoxContainer


func _ready() -> void:
	visible = false
	bind(_find_game_state())


## Инвентарь — не пауза: при уходе со сцены открытая панель обязана вернуть
## курсор, иначе следующая сцена встретит игрока свободной мышью без панели.
func _exit_tree() -> void:
	if _open:
		close()


## Привязать панель к источнику прогресса. null — законное состояние: кнопок
## просто не будет.
func bind(game_state: Node) -> void:
	_game_state = game_state
	if _open:
		_rebuild()


func _find_game_state() -> Node:
	return get_node_or_null("/root/GameState")


func is_open() -> bool:
	return _open


## Открыть: показать панель, отпустить курсор, построить кнопки. Повторное
## открытие ничего не делает.
func open() -> void:
	if _open:
		return
	_open = true
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_rebuild()


## Закрыть: спрятать панель и снова захватить курсор. Повторное закрытие ничего
## не делает.
func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func toggle() -> void:
	if _open:
		close()
	else:
		open()


func _unhandled_input(event: InputEvent) -> void:
	# Не гейтится InputGate (см. заголовок файла): I работает и при захваченном
	# курсоре. Поглощается, чтобы клавиша не дошла до сцены ниже по стеку.
	if event.is_action_pressed("inventory"):
		toggle()
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()


# --------------------------------------------------------------------------
# построение кнопок
# --------------------------------------------------------------------------

func _rebuild() -> void:
	if _list == null:
		return
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var equipped := _equipped_id()
	for id in _owned_weapons():
		var button := Button.new()
		button.text = _weapon_label(id)
		if id == equipped:
			button.text += _EQUIPPED_MARK
		button.pressed.connect(_on_weapon_pressed.bind(id))
		_list.add_child(button)


## Имена купленного оружия. PackedStringArray и Array принимаются оба: живой
## GameState хранит PackedStringArray, а фейк в тесте может положить обычный.
func _owned_weapons() -> PackedStringArray:
	if _game_state == null:
		return PackedStringArray()
	var owned: Variant = _game_state.get("owned_weapons")
	if owned is PackedStringArray:
		return owned
	if owned is Array:
		var out := PackedStringArray()
		for item in owned:
			if item is String:
				out.append(item)
		return out
	return PackedStringArray()


func _equipped_id() -> String:
	if _game_state == null:
		return ""
	var id: Variant = _game_state.get("equipped_weapon_id")
	return str(id) if id != null else ""


## Подпись кнопки: display_name из ресурса оружия, а если ресурса нет — id.
## Отсутствие ресурса не должно оставлять кнопку без подписи.
func _weapon_label(id: String) -> String:
	var data := load(_WEAPON_DATA_PATH % id) as WeaponData
	if data != null and not data.display_name.is_empty():
		return data.display_name
	return id


## Клик по оружию: экипировать через GameState и закрыть панель (курсор снова
## захвачен). Без GameState выбор всё равно сообщается сигналом.
func _on_weapon_pressed(id: String) -> void:
	if _game_state != null and _game_state.has_method("equip_weapon"):
		_game_state.call("equip_weapon", id)
	weapon_selected.emit(id)
	close()
