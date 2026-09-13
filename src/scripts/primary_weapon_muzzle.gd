extends Node3D
class_name PrimaryWeaponMuzzle

## Where a weapon's shots come out, and the only place weapon stats become a
## thing in the world. The runtime decides WHEN a shot happens and announces it
## with `fired`; this node translates that into a projectile launched from its
## own transform. It holds no firing state, never reads input, and knows nothing
## about what kind of craft carries it.
## Connect Runtime.fired to _on_runtime_fired in the editor (the weapon scene).

## The weapon whose shots leave through this muzzle. Assign the sibling Runtime.
@export var runtime: PrimaryWeaponRuntime


func _on_runtime_fired() -> void:
	if runtime == null or runtime.primary_weapon_base_stats == null:
		return
	var base := runtime.primary_weapon_base_stats
	if base.projectile_scene == null:
		return

	var instance := base.projectile_scene.instantiate()
	var projectile := instance as Projectile
	if projectile == null:
		push_warning("%s: projectile_scene root does not use projectile.gd" % name)
		instance.queue_free()
		return

	# Shots leave down the BARREL, so they follow the hull's sprung facing (and
	# its shake) as it trails the aim -- i.e. they go where the lag pip on the
	# crosshair sits, not where the centre reticle is looking.
	var shooter := _find_craft()

	# Shots belong to the world, not to the barrel: parenting them here would
	# drag every shot along as the craft flies on.
	get_tree().current_scene.add_child(projectile)
	projectile.launch(global_transform, base.speed, base.damage, base.range, shooter)


## The craft this muzzle is mounted on, so its own hull can be ignored. A weapon
## scene can't reference anything outside itself in the editor, so it finds the
## slots it was installed into and asks them.
func _find_craft() -> Node:
	var node := get_parent()
	while node != null and not (node is PrimaryWeaponController):
		node = node.get_parent()
	return (node as PrimaryWeaponController).get_craft() if node != null else null
