extends Camera3D
class_name CameraRig

## Third-person camera that tracks the ship's AIM (not its lagging facing), so
## your cursor stays centered and the ship swims toward the middle as it catches

## The craft to follow. Assign the Spacecraft node in the Inspector.
@export var target: SpacecraftController

@export_group("Feel")
## Position follow speed. Higher = snappier; 0 = hard snap. Rotation is instant.
@export var position_smoothing: float = 12.0

## Captured editor placement, expressed in the target's local frame.
var _rig_transform: Transform3D

# --- Derived from placement (read-only), purely informational ---
var distance: float    ## Metres behind the target.
var height: float      ## Metres above the target.
var look_ahead: float  ## Metres ahead the camera is pointed, at target height.

var _pos: Vector3
var _initialized: bool = false


func _ready() -> void:
	if target == null:
		push_warning("CameraRig: no target assigned.")
		return
	# Freeze the current editor placement relative to the target.
	_rig_transform = target.global_transform.affine_inverse() * global_transform
	_derive_attributes()


func _physics_process(delta: float) -> void:
	if target == null:
		return

	# The aim frame: positioned on the ship, oriented by where you're aiming.
	var frame := Transform3D(target.get_aim_basis(), target.global_position)
	var desired := frame * _rig_transform

	if not _initialized:
		_pos = desired.origin
		_initialized = true
	elif position_smoothing > 0.0:
		_pos = _pos.lerp(desired.origin, 1.0 - exp(-position_smoothing * delta))
	else:
		_pos = desired.origin

	# Orientation snaps instantly so the camera always tracks the aim.
	global_transform = Transform3D(desired.basis, _pos)


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
