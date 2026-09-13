extends Node
class_name InputController

## Scene-local flight-input reader. Lives inside the craft/player scene so its
## signals can be connected to the controller in the editor (visible wires).
## It only reads raw input and emits intent; it owns no global state. Whether
## it should act at all is decided by the global GameState context.

signal camera_zoom_input(value: float)
signal pitch_input(value: float)
signal yaw_input(value: float)
signal roll_input(value: float)
signal throttle_input(value: float)
signal turbo_changed(active: bool)
signal primary_fire_changed(active: bool)

@export_group("Mouse")
@export var invert_pitch: bool = true
@export var invert_yaw: bool = false
@export var zoom_step: float = 0.1

var _turbo_active: bool = false
var _primary_fire_active: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if not GameState.is_gameplay():
		return
	
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var yaw := motion.relative.x * (-1.0 if invert_yaw else 1.0)
		var pitch := motion.relative.y * (-1.0 if invert_pitch else 1.0)
		pitch_input.emit(pitch)
		yaw_input.emit(yaw)


func _physics_process(_delta: float) -> void:
	if not GameState.is_gameplay():
		# Release whatever is held, so leaving gameplay mid-hold doesn't leave
		# the craft boosting or the guns firing forever.
		_set_turbo(false)
		_set_primary_fire(false)
		return

	roll_input.emit(Input.get_axis("roll_right", "roll_left"))
	throttle_input.emit(Input.get_axis("throttle_down", "throttle_up"))
	
	if Input.is_action_just_pressed("camera_zoom_in"):
		camera_zoom_input.emit(1 - zoom_step)
	elif Input.is_action_just_pressed("camera_zoom_out"):
		camera_zoom_input.emit(1 + zoom_step)
		
	_set_turbo(Input.is_action_pressed("turbo"))
	_set_primary_fire(Input.is_action_pressed("primary_fire"))


func is_turbo_active() -> bool:
	return _turbo_active


func is_primary_fire_active() -> bool:
	return _primary_fire_active


## Held states are emitted on change only, so consumers can treat them as edges.
func _set_turbo(active: bool) -> void:
	if active == _turbo_active:
		return
	_turbo_active = active
	turbo_changed.emit(_turbo_active)


func _set_primary_fire(active: bool) -> void:
	if active == _primary_fire_active:
		return
	_primary_fire_active = active
	primary_fire_changed.emit(_primary_fire_active)
