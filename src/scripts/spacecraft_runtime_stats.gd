extends Node
class_name StatefulStats

## Runtime state for one craft (current speed, health, ...). Seeded from a
## SpacecraftBaseStats resource and mutated by the controller (player input)
## and the environment (damage, drag). Knows nothing about input itself.

signal speed_changed(speed: float)
signal health_changed(health: int)
signal died

## The base data this craft was built from. Assign the craft's .tres here.
@export var base_stats: SpacecraftBaseStats

var current_speed: float
var current_health: int


func _ready() -> void:
	if base_stats:
		setup(base_stats)


func setup(base: SpacecraftBaseStats) -> void:
	base_stats = base
	current_speed = base.base_speed
	current_health = base.base_health
	speed_changed.emit(current_speed)
	health_changed.emit(current_health)


func apply_throttle(axis: float, turbo: bool, delta: float) -> void:
	var top := base_stats.max_speed * (base_stats.turbo_multiplier if turbo else 1.0)
	current_speed = clampf(
		current_speed + axis * base_stats.acceleration * delta,
		base_stats.min_speed,
		top
	)
	speed_changed.emit(current_speed)


func take_damage(amount: int) -> void:
	current_health -= amount
	health_changed.emit(current_health)
	if current_health <= 0:
		died.emit()
