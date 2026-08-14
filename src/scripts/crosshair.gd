extends Control
class_name Crosshair

## Drives the "lag pip": a small dot showing where the ship's nose is actually
## pointing, relative to where you're aiming (the fixed center crosshair).
##
## The center crosshair represents the AIM (what the camera tracks). The dot is
## placed at the on-screen gap between the ship's forward and the aim's forward,
## anchored at screen center -- so when the ship has caught up to the aim the dot
## sits dead center, and it drifts out (and wobbles with hull shake) while the
## ship is still turning. Using the projected difference keeps it correct for any
## camera tilt/FOV.
##
## When the dot falls inside the reticle's radius (ship on target) the center
## crosshair is highlighted; otherwise it is de-emphasised.

@export var camera: Camera3D
@export var ship: SpacecraftController
## The node to move (e.g. a small TextureRect). Positioned so its center lands
## on the ship's look point.
@export var dot: Control
## The center reticle that gets highlighted when the ship is on target.
@export var center_crosshair: Control

## How far ahead (metres) the look directions are sampled before projecting.
## Larger = the pip reacts to smaller angular differences.
@export var project_distance: float = 500.0

@export_group("Lock highlight")
## Colour when the ship's nose is on target (dot inside the reticle radius).
@export var locked_color: Color = Color(0.35, 1.0, 0.45)
## Colour when off target -- de-emphasised.
@export var unlocked_color: Color = Color(1.0, 1.0, 1.0, 0.4)
## Pixel radius that counts as "on target". 0 = use the reticle's own radius.
@export var lock_radius: float = 0.0


func _process(_delta: float) -> void:
	if camera == null or ship == null or dot == null:
		return

	var origin := ship.global_position
	var aim_point := origin + (-ship.get_aim_basis().z) * project_distance
	var ship_point := origin + (-ship.global_transform.basis.z) * project_distance

	# If either look direction is behind the camera the projection is invalid.
	if camera.is_position_behind(aim_point) or camera.is_position_behind(ship_point):
		dot.visible = false
		_set_locked(false)
		return

	dot.visible = true
	var center := size * 0.5
	var offset := camera.unproject_position(ship_point) - camera.unproject_position(aim_point)
	dot.position = center + offset - dot.size * 0.5

	_set_locked(offset.length() <= _lock_radius())


## The on-target radius in pixels: an explicit override, else the reticle's size.
func _lock_radius() -> float:
	if lock_radius > 0.0:
		return lock_radius
	if center_crosshair != null:
		return center_crosshair.size.x * 0.5
	return 8.0


func _set_locked(locked: bool) -> void:
	if center_crosshair != null:
		center_crosshair.modulate = locked_color if locked else unlocked_color
