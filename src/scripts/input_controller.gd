extends Node
class_name InputController

## Scene-local flight-input reader. Lives inside the craft/player scene so its
## signals can be connected to the controller in the editor (visible wires).
## It only reads raw input and emits intent; it owns no global state. Whether
## it should act at all is decided by the global GameState context.

signal pitch_input(value: float)
signal yaw_input(value: float)
signal roll_input(value: float)
signal throttle_input(value: float)
signal turbo_changed(active: bool)

@export_group("Mouse")
@export var mouse_sensitivity: float = 0.008
@export var invert_pitch: bool = true
@export var invert_yaw: bool = false

var _turbo_active: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if not GameState.is_gameplay():
		return

	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		# Conventional aim mapping: horizontal mouse -> yaw, vertical mouse -> pitch.
		var yaw := motion.relative.x * mouse_sensitivity * (-1.0 if invert_yaw else 1.0)
		var pitch := motion.relative.y * mouse_sensitivity * (-1.0 if invert_pitch else 1.0)
		pitch_input.emit(pitch)
		yaw_input.emit(yaw)


func _physics_process(_delta: float) -> void:
	if not GameState.is_gameplay():
		return

	roll_input.emit(Input.get_axis("roll_left", "roll_right"))
	throttle_input.emit(Input.get_axis("throttle_down", "throttle_up"))

	var turbo_now := Input.is_action_pressed("turbo")
	if turbo_now != _turbo_active:
		_turbo_active = turbo_now
		turbo_changed.emit(_turbo_active)


func is_turbo_active() -> bool:
	return _turbo_active
