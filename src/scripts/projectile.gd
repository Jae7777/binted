extends Area3D
class_name Projectile

## A shot in flight. It carries only what the muzzle handed it at launch -- it
## never reads weapon stats, and knows nothing about the weapon that fired it
## beyond the hull to ignore.
##
## Travel direction comes from the launch, NOT from the node's own rotation: the
## rotation the scene was authored with is kept as a rest pose and re-applied on
## top of the flight direction. So rotating the projectile scene (root or child,
## whichever is convenient) aims the MODEL along its nose and never changes where
## the shot goes.
##
## Movement sweeps a ray from the previous position to the new one instead of
## teleporting and waiting for an overlap, so a fast shot cannot skip past a
## target between frames. What it can hit is the Area3D's own collision_mask.

## Emitted on impact, before the shot frees itself. `collider` is whatever was
## struck; it has already been dealt damage if it could take any.
signal hit(collider: Node3D, point: Vector3)

var _direction: Vector3 = Vector3.FORWARD  ## World-space, set at launch.
var _rest_basis: Basis = Basis()  ## How the scene author posed the model.
var _speed: float = 0.0
var _damage: float = 0.0
var _range_left: float = 0.0
var _exclude: Array[RID] = []


func _ready() -> void:
	# Capture the authored pose before launch overwrites the transform.
	_rest_basis = transform.basis
	# Nothing moves until a muzzle launches it.
	set_physics_process(false)


## Arm and fire this shot, at `speed` metres per second for `max_range` metres.
## Add it to the tree FIRST -- the muzzle transform is a global one, and gives
## both the launch point and the direction of travel.
## `shooter` is the craft that fired: every collider under it is excluded, so a
## ship never shoots itself as the shot leaves the barrel.
func launch(muzzle_transform: Transform3D, speed: float, damage: float,
		max_range: float, shooter: Node) -> void:
	_direction = (-muzzle_transform.basis.z).normalized()
	global_transform = Transform3D(muzzle_transform.basis * _rest_basis, muzzle_transform.origin)
	_speed = speed
	_damage = damage
	_range_left = max_range
	_exclude = _collider_rids(shooter)
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	# Never overshoot the remaining range: the last step stops exactly at it.
	var step := minf(_speed * delta, _range_left)
	var from := global_position
	var to := from + _direction * step

	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask, _exclude)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result:
		_impact(result.collider, result.position)
		return

	global_position = to
	_range_left -= step
	if _range_left <= 0.0:
		queue_free()  # spent


## Anything that can be shot answers take_damage(); anything else just stops the
## shot. That keeps the projectile ignorant of what it hit.
func _impact(collider: Object, point: Vector3) -> void:
	if collider and collider.has_method("take_damage"):
		collider.take_damage(_damage)
	hit.emit(collider as Node3D, point)
	queue_free()


func _collider_rids(root: Node) -> Array[RID]:
	var rids: Array[RID] = []
	if root == null:
		return rids
	if root is CollisionObject3D:
		rids.append((root as CollisionObject3D).get_rid())
	for node in root.find_children("*", "CollisionObject3D", true, false):
		rids.append((node as CollisionObject3D).get_rid())
	return rids
