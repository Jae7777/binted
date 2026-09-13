extends Node
class_name PrimaryWeaponRuntime

## Runtime state for one mounted weapon (trigger, reload). Seeded from a
## PrimaryWeaponBaseStats resource and driven by the controller, which only ever
## tells it whether the trigger is held -- it knows nothing about input. It does
## not spawn anything either: it announces a shot with `fired`, and the muzzle
## side of the weapon scene turns that into a projectile.

signal fired
signal loaded_changed(loaded: bool)

## The base data this weapon was built from. Assign the weapon's .tres here.
@export var primary_weapon_base_stats: PrimaryWeaponBaseStats

var is_loaded: bool = true

var _trigger_held: bool = false
var _load_time_left: float = 0.0


func _ready() -> void:
	if primary_weapon_base_stats:
		setup(primary_weapon_base_stats)


func setup(base: PrimaryWeaponBaseStats) -> void:
	primary_weapon_base_stats = base
	_load_time_left = 0.0
	is_loaded = true
	loaded_changed.emit(is_loaded)


func _physics_process(delta: float) -> void:
	if primary_weapon_base_stats == null:
		return

	if not is_loaded:
		_load_time_left -= delta
		if _load_time_left <= 0.0:
			is_loaded = true
			loaded_changed.emit(is_loaded)

	if _trigger_held and is_loaded:
		_fire()


## The controller's only lever. Holding the trigger keeps the weapon firing each
## time it finishes loading; releasing it stops at the next shot boundary.
func set_trigger_held(held: bool) -> void:
	_trigger_held = held


func _fire() -> void:
	is_loaded = false
	_load_time_left = primary_weapon_base_stats.loading_speed
	loaded_changed.emit(is_loaded)
	fired.emit()
