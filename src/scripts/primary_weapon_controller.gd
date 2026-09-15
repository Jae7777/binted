extends Node3D
class_name PrimaryWeaponController

## The mediator between input and the primary weapons mounted on this craft.
## It owns no weapon state itself: it tracks whether the trigger is held and
## hands that intent to every PrimaryWeaponRuntime mounted beneath it. Each
## runtime decides on its own whether it is loaded and what a shot does.
## Input signals are connected to the _on_* handlers in the editor (player.tscn).

## Weapons currently mounted in these slots, collected from the slot sub-scenes
## on ready rather than wired by hand, so a loadout can be swapped by adding or
## removing weapon scenes under this node.
var _weapons: Array[PrimaryWeaponRuntime] = []
var _trigger_held: bool = false


func _ready() -> void:
	refresh_mounts()


## Re-scan the slots for weapons, e.g. after changing loadout at runtime. The
## current trigger state is handed straight to the new set, so a trigger held
## through the swap keeps firing.
func refresh_mounts() -> void:
	_weapons.clear()
	for node in find_children("*", "PrimaryWeaponRuntime", true, false):
		_weapons.append(node as PrimaryWeaponRuntime)
	_push_trigger()


## The craft these slots are mounted on. Mounted weapons ask for it so their
## shots can ignore the hull that fired them.
func get_craft() -> Node3D:
	return get_parent() as Node3D


## Whether the fire intent is currently held (for HUD/animation to read).
func is_trigger_held() -> bool:
	return _trigger_held


func _push_trigger() -> void:
	for weapon in _weapons:
		weapon.set_trigger_held(_trigger_held)


## Hold or release the trigger on every mounted weapon. Pilot intent arrives
## here either straight from the input signal or relayed by the craft, when the
## mount lives inside a ship sub-scene the player scene cannot wire into.
func set_firing(active: bool) -> void:
	if _trigger_held == active:
		return
	_trigger_held = active
	_push_trigger()


func _on_input_controller_primary_fire_changed(active: bool) -> void:
	set_firing(active)
