extends Camera3D
class_name CameraRig

## Third-person camera that tracks the ship's AIM (not its lagging facing), so
## your cursor stays centered and the ship swims toward the middle as it catches
## up. Two extra jobs on top of that:
##   * SIZE-RELATIVE DISTANCE - the boom length is derived from the ship's
##     measured bounding size, so a bigger craft is framed from further away and
##     fills roughly the same amount of screen.
##   * COLLISION AVOIDANCE - a spring-arm-style raycast from the ship out to the
##     camera pulls the view in when a wall/object is in the way, then eases back
##     out once the path clears.

## The craft to follow. Assign the Spacecraft node in the Inspector.
@export var target: SpacecraftController

@export_group("Feel")
## Position follow speed. Higher = snappier; 0 = hard snap. Rotation is instant.
@export var position_smoothing: float = 12.0

@export_group("Framing")
## Boom length as a multiple of the ship's bounding radius.
##   0  -> keep the exact editor placement (WYSIWYG, no size reaction).
##   >0 -> camera distance = ship_radius * distance_scale, so it adapts to
##         ships of different sizes. Set this to a shared constant across ships
##         to get consistent framing. The value that reproduces your current
##         editor placement is printed on start.
@export var distance_scale: float = 0.0

@export_group("Zoom")
## Scroll wheel dollies the camera in/out by scaling the boom length.
@export var zoom_enabled: bool = true
## Fraction of the current zoom added/removed per wheel notch.
@export var zoom_step: float = 0.1
## Closest the wheel can pull in, as a multiple of the base boom length.
@export var min_zoom: float = 0.4
## Furthest the wheel can push out, as a multiple of the base boom length.
@export var max_zoom: float = 2.5
## How fast the zoom eases to the target level (per second). 0 = instant.
@export var zoom_smoothing: float = 12.0

@export_group("Collision")
## Pull the camera in when something blocks the view. Disable for a rigid boom.
@export var avoid_collisions: bool = true
## Physics layers the camera boom collides against.
@export_flags_3d_physics var collision_mask: int = 1
## Keep the camera at least this far off whatever it hits (avoids clipping).
@export var collision_margin: float = 0.25
## Never let the boom collapse closer than this to the ship.
@export var min_distance: float = 0.5
## How fast the boom eases back out after the obstacle clears (per second).
## Pulling IN is always instant so the camera never clips through geometry.
@export var collision_return_speed: float = 8.0

## Captured editor placement, expressed in the target's local frame.
var _rig_transform: Transform3D
var _rig_dir: Vector3          ## Unit direction of the boom, in target space.
var _placement_distance: float ## Boom length as placed in the editor.
var _effective_scale: float    ## Resolved distance_scale (auto or explicit).
var _ship_radius: float        ## Half the ship's longest bounding axis.

# --- Derived from placement (read-only), purely informational ---
var distance: float    ## Metres behind the target.
var height: float      ## Metres above the target.
var look_ahead: float  ## Metres ahead the camera is pointed, at target height.

var _pos: Vector3
var _arm: float = 0.0  ## Current collision-limited boom length.
var _exclude: Array[RID] = []
var _initialized: bool = false

var _zoom: float = 1.0         ## Eased zoom multiplier applied to the boom.
var _zoom_target: float = 1.0  ## Where the wheel wants the zoom to settle.


func _ready() -> void:
	if target == null:
		push_warning("CameraRig: no target assigned.")
		return
	# Freeze the current editor placement relative to the target.
	_rig_transform = target.global_transform.affine_inverse() * global_transform
	_placement_distance = _rig_transform.origin.length()
	_rig_dir = (
		_rig_transform.origin / _placement_distance
		if _placement_distance > 0.0
		else Vector3.BACK
	)

	_ship_radius = _measure_ship_radius()
	_resolve_scale()
	_derive_attributes()
	_collect_exclusions()


## Scroll wheel adjusts the zoom target (multiplicative, so each notch feels the
## same at any distance). Only while gameplay owns the mouse.
func _unhandled_input(event: InputEvent) -> void:
	if not zoom_enabled or not GameState.is_gameplay():
		return
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_zoom_target = clampf(_zoom_target * (1.0 - zoom_step), min_zoom, max_zoom)
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_target = clampf(_zoom_target * (1.0 + zoom_step), min_zoom, max_zoom)


func _physics_process(delta: float) -> void:
	if target == null:
		return

	# Ease the zoom toward the wheel's target.
	if zoom_smoothing > 0.0:
		_zoom = lerpf(_zoom, _zoom_target, 1.0 - exp(-zoom_smoothing * delta))
	else:
		_zoom = _zoom_target

	# The aim frame: positioned on the ship, oriented by where you're aiming.
	var frame := Transform3D(target.get_aim_basis(), target.global_position)
	# Boom length comes from ship size (or the frozen placement when scale is 0).
	var local_origin := _rig_dir * _boom_length()
	var desired := frame * Transform3D(_rig_transform.basis, local_origin)

	if not _initialized:
		_pos = desired.origin
		_arm = target.global_position.distance_to(_pos)
		_initialized = true
	elif position_smoothing > 0.0:
		_pos = _pos.lerp(desired.origin, 1.0 - exp(-position_smoothing * delta))
	else:
		_pos = desired.origin

	var final_origin := _resolve_collision(target.global_position, _pos, delta)

	# Orientation snaps instantly so the camera always tracks the aim.
	global_transform = Transform3D(desired.basis, final_origin)


## Desired boom length in metres for the current ship, after the zoom multiplier.
func _boom_length() -> float:
	var base := _placement_distance
	if _ship_radius > 0.0 and _effective_scale > 0.0:
		base = _ship_radius * _effective_scale
	return base * _zoom


## Cast from the ship (pivot) toward the smoothed camera position; if blocked,
## clamp the boom to the hit point. Pull-in is instant, push-out is eased.
func _resolve_collision(pivot: Vector3, cam_pos: Vector3, delta: float) -> Vector3:
	var to_cam := cam_pos - pivot
	var dist := to_cam.length()
	if not avoid_collisions or dist < 0.0001:
		_arm = dist
		return cam_pos

	var dir := to_cam / dist
	var wanted := dist

	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		pivot, cam_pos, collision_mask, _exclude
	)
	var hit := space.intersect_ray(query)
	if hit:
		wanted = maxf(min_distance, pivot.distance_to(hit.position) - collision_margin)

	# Instant when moving in (avoid clipping); eased when extending back out.
	if wanted < _arm:
		_arm = wanted
	else:
		_arm = lerpf(_arm, wanted, 1.0 - exp(-collision_return_speed * delta))
	_arm = minf(_arm, dist)

	return pivot + dir * _arm


## Merge the AABBs of every visual under the target and return half its longest
## axis as a bounding "radius" the framing scales from.
func _measure_ship_radius() -> float:
	var to_local := target.global_transform.affine_inverse()
	var have := false
	var mn := Vector3.ZERO
	var mx := Vector3.ZERO

	for node in target.find_children("*", "VisualInstance3D", true, false):
		var vi := node as VisualInstance3D
		var xf := to_local * vi.global_transform
		var box := vi.get_aabb()
		for i in 8:
			var p := xf * box.get_endpoint(i)
			if not have:
				mn = p
				mx = p
				have = true
			else:
				mn = mn.min(p)
				mx = mx.max(p)

	if not have:
		return 0.0
	var size := mx - mn
	return 0.5 * maxf(size.x, maxf(size.y, size.z))


## Turn distance_scale into a concrete multiplier. 0 means "reproduce the editor
## placement"; we still log the equivalent scale so it can be pinned per project.
func _resolve_scale() -> void:
	if distance_scale > 0.0:
		_effective_scale = distance_scale
	elif _ship_radius > 0.0:
		_effective_scale = _placement_distance / _ship_radius
		print(
			"CameraRig: ship radius %.2f m, placement distance %.2f m -> set "
			% [_ship_radius, _placement_distance],
			"distance_scale = %.2f for size-relative framing." % _effective_scale
		)
	else:
		_effective_scale = 0.0


## Physics bodies belonging to the ship, so the boom ignores the craft itself.
func _collect_exclusions() -> void:
	_exclude.clear()
	for node in target.find_children("*", "PhysicsBody3D", true, false):
		_exclude.append((node as PhysicsBody3D).get_rid())


## Turn the captured placement into human-readable distances.
func _derive_attributes() -> void:
	var origin := _rig_transform.origin
	height = origin.y
	distance = maxf(0.0, origin.z)  ## +Z is behind the target in Godot.

	# Where the camera's line of sight crosses the target's height plane, ahead.
	var forward := -_rig_transform.basis.z
	if forward.y < 0.0:
		var travel := -origin.y / forward.y
		look_ahead = maxf(0.0, -(origin.z + forward.z * travel))
	else:
		look_ahead = 0.0
