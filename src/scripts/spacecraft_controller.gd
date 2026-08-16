extends Node3D
class_name SpacecraftController

## The mediator between input and stats, and the source of two orientations:
##   * AIM    - where the mouse is pointing. Updates instantly. The camera uses
##              this so it always tracks your cursor, centered.
##   * SHIP   - the craft's actual facing. Chases AIM through an under-damped
##              spring, so it lags and wobbles (the intentional delay/shake),
##              then thrusts along its own nose.
## Input signals are connected to the _on_* handlers in the editor (player.tscn).

## Runtime stats for this craft (seeded from the base .tres). Assign in the
## Inspector; the node lives inside the craft sub-scene.
@export var runtime_stats: StatefulStats
@export var body: CharacterBody3D

# --- Aim (instant target, driven by the mouse) ---
var aim_yaw: float = 0.0
var aim_pitch: float = 0.0

# --- Ship attitude (spring-chases the aim) ---
var _yaw: float = 0.0
var _pitch: float = 0.0
var _yaw_vel: float = 0.0
var _pitch_vel: float = 0.0
var _roll: float = 0.0   ## Integrated manual roll angle (A/D).

# --- Latest raw input ---
var _throttle: float = 0.0
var _roll_input: float = 0.0
var _turbo: bool = false
var _pitch_delta: float = 0.0  ## Mouse pitch accumulated since last frame.
var _yaw_delta: float = 0.0    ## Mouse yaw accumulated since last frame.


func _physics_process(delta: float) -> void:
	if runtime_stats == null or runtime_stats.base_stats == null:
		return
	var base := runtime_stats.base_stats

	_update_aim(base)
	_chase_aim(base, delta)
	_apply_attitude(base, delta)
	_apply_thrust(base, delta)


## Fold this frame's mouse motion into the instant aim orientation.
func _update_aim(base: SpacecraftBaseStats) -> void:
	aim_yaw += _yaw_delta * base.yaw_speed
	var max_pitch := deg_to_rad(base.max_pitch_deg)
	aim_pitch = clampf(aim_pitch + _pitch_delta * base.pitch_speed, -max_pitch, max_pitch)
	_pitch_delta = 0.0
	_yaw_delta = 0.0


## Spring the ship's yaw/pitch toward the aim. Under-damping produces the
## overshoot/wobble; a stiffer spring reduces the lag.
func _chase_aim(base: SpacecraftBaseStats, delta: float) -> void:
	_yaw_vel += (aim_yaw - _yaw) * base.turn_stiffness * delta
	_yaw_vel *= exp(-base.turn_damping * delta)
	_yaw += _yaw_vel * delta

	_pitch_vel += (aim_pitch - _pitch) * base.turn_stiffness * delta
	_pitch_vel *= exp(-base.turn_damping * delta)
	_pitch += _pitch_vel * delta

	_roll += _roll_input * base.roll_speed * delta


## Build the ship basis from yaw/pitch/roll plus an auto-bank that leans into
## the turn, and a small hull shake that grows with how hard we're turning.
## Shake is applied to the SHIP only (not the aim), so the camera stays steady
## while the craft visibly jitters.
func _apply_attitude(base: SpacecraftBaseStats, _delta: float) -> void:
	var bank := clampf(-_yaw_vel * base.bank_amount, -1.0, 1.0)

	var shake := base.shake_amount + base.shake_from_turn * get_turn_speed()
	var t := Time.get_ticks_msec() / 1000.0
	var shake_yaw := cos(t * 17.0) * shake
	var shake_pitch := sin(t * 23.0) * shake
	var shake_roll := sin(t * 13.0) * shake

	var ship_basis := _orientation(_yaw + shake_yaw, _pitch + shake_pitch, _roll + bank + shake_roll)
	global_transform = Transform3D(ship_basis, global_position)


func _apply_thrust(_base: SpacecraftBaseStats, delta: float) -> void:
	runtime_stats.apply_throttle(_throttle, _turbo, delta)

	# The Body (CharacterBody3D) resolves collisions, but only IT moves when we
	# call move_and_slide -- and the visual mesh lives on the Spacecraft, not the
	# body. So: let the body slide, carry the whole ship by however far it moved,
	# then re-seat the body at its rest offset so it doesn't drift away.
	var rest_offset := body.global_position - global_position
	var before := body.global_position
	body.velocity = -global_transform.basis.z * runtime_stats.current_speed
	body.move_and_slide()
	global_position += body.global_position - before
	body.global_position = global_position + rest_offset


## Orientation used by both the ship and the camera so they stay consistent.
## Signs chosen so mouse-right yaws right and mouse-down pitches the nose down.
func _orientation(yaw: float, pitch: float, roll: float = 0.0) -> Basis:
	var b := Basis()
	b = b.rotated(Vector3.UP, -yaw)
	b = b.rotated(b.x, pitch)
	if roll != 0.0:
		b = b.rotated(b.z, roll)
	return b


## The camera reads this to track exactly where you're aiming.
func get_aim_basis() -> Basis:
	return _orientation(aim_yaw, aim_pitch)


## Magnitude of the current turn (for camera shake scaling, etc.).
func get_turn_speed() -> float:
	return Vector2(_yaw_vel, _pitch_vel).length()

func _on_input_controller_pitch_input(value: float) -> void:
	_pitch_delta += value


func _on_input_controller_roll_input(value: float) -> void:
	_roll_input = value


func _on_input_controller_throttle_input(value: float) -> void:
	_throttle = value


func _on_input_controller_turbo_changed(active: bool) -> void:
	_turbo = active


func _on_input_controller_yaw_input(value: float) -> void:
	_yaw_delta += value
