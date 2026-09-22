extends Node3D
class_name EnemySpawner

## Ship scenes to draw from, picked at random per spawn.
@export var ship_scenes: Array[PackedScene] = []
@export var count: int = 5
@export var group: StringName = &"enemies"

@export_group("Placement")
@export var min_distance: float = 40.0
@export var max_distance: float = 200.0
## 1 spreads through a full sphere, 0 keeps spawns in the spawner's plane.
@export_range(0.0, 1.0) var vertical_spread: float = 0.35
@export var face_spawner: bool = true
## 0 seeds from the clock; any other value repeats the same layout.
@export var random_seed: int = 0

var _rng := RandomNumberGenerator.new()
var _spawned: Array[Node3D] = []


func _ready() -> void:
	if random_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = random_seed
	spawn(count)


func spawn(amount: int) -> void:
	if ship_scenes.is_empty():
		push_warning("%s: no ship_scenes assigned." % name)
		return
	for _i in amount:
		_spawn_one()


func despawn_all() -> void:
	for ship in _spawned:
		if is_instance_valid(ship):
			ship.queue_free()
	_spawned.clear()


func _spawn_one() -> void:
	var scene := ship_scenes[_rng.randi_range(0, ship_scenes.size() - 1)]
	var ship := scene.instantiate() as Node3D
	# Set before it enters the tree: a craft seeds its heading in _ready().
	ship.transform = _random_placement()
	add_child(ship)
	ship.add_to_group(group)
	_spawned.append(ship)


func _random_placement() -> Transform3D:
	var dir := _random_direction()
	var origin := dir * _rng.randf_range(min_distance, max_distance)
	if not face_spawner:
		return Transform3D(Basis(Vector3.UP, _rng.randf_range(0.0, TAU)), origin)
	var up := Vector3.UP if absf(dir.y) < 0.99 else Vector3.FORWARD
	return Transform3D(Basis(), origin).looking_at(Vector3.ZERO, up)


func _random_direction() -> Vector3:
	var y := _rng.randf_range(-1.0, 1.0) * vertical_spread
	var angle := _rng.randf_range(0.0, TAU)
	var r := sqrt(maxf(0.0, 1.0 - y * y))
	return Vector3(r * cos(angle), y, r * sin(angle))
