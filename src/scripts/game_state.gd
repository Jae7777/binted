extends Node

## Autoload singleton holding the only genuinely-global input concerns: which
## context is currently active and the resulting mouse mode. This is NOT a
## signal bus -- it just owns state. Scene-local input controllers read
## `is_gameplay()` to decide whether to act; UI/menus flip `context`.

enum Context {
	GAMEPLAY,  ## Flight controls active, mouse captured.
	MENU,      ## Flight suppressed, mouse visible.
}

signal context_changed(context: Context)

var context: Context = Context.GAMEPLAY:
	set(value):
		if context == value:
			return
		context = value
		_apply_mouse_mode()
		context_changed.emit(context)


func _ready() -> void:
	_apply_mouse_mode()


func _unhandled_input(event: InputEvent) -> void:
	# Escape toggles between gameplay and menu (frees/captures the mouse).
	if event.is_action_pressed(&"ui_cancel"):
		context = Context.GAMEPLAY if context == Context.MENU else Context.MENU


func is_gameplay() -> bool:
	return context == Context.GAMEPLAY


func _apply_mouse_mode() -> void:
	Input.mouse_mode = (
		Input.MOUSE_MODE_CAPTURED
		if context == Context.GAMEPLAY
		else Input.MOUSE_MODE_VISIBLE
	)
