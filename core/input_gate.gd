class_name InputGate
extends RefCounted

## Разрешён ли игровой ввод.
## Зависит только от переданного режима мыши, чтобы проверяться без
## дисплейного сервера: headless не умеет захватывать курсор.


static func is_play_input_allowed(mouse_mode: int) -> bool:
	return mouse_mode == Input.MOUSE_MODE_CAPTURED