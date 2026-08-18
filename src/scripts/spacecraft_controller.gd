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
@export var runtime_stats: RuntimeStats
@export var body: CharacterBody3D

# --- Aim (instant target orientation, driven by the mouse) ---
## Full body-relative orientation. Yaw/pitch/roll are each integrated in this
## frame's OWN local axes, so there is no world-up reference and no pitch limit
## -- true 6DOF. The camera reads this so the view tracks where you point.
var aim_basis: Basis = Basis()

# --- Ship attitude (3D spring-chases the aim) ---
var _basis: Basis = Basis()           ## Current ship orientation.
var _ang_vel: Vector3 = Vector3.ZERO  ## Angular velocity (world space) for the spring.

# --- Latest raw input ---
var _throttle: float = 0.0
var _roll_input: float = 0.0
var _turbo: bool = false
var _pitch_delta: float = 0.0  ## Mouse pitch accumulated since last frame.
var _yaw_delta: float = 0.0    ## Mouse yaw accumulated since last frame.


func _ready() -> void:
	# Seed both orientations from wherever the craft is placed in the scene.
	aim_basis = global_transform.basis.orthonormalized()
	_basis = aim_basis


func _physics_process(delta: float) -> void:
	if runtime_stats == null or runtime_stats.base_stats == null:
		return
	var base := runtime_stats.base_stats

	_update_aim(base, delta)
	_chase_aim(base, delta)
	_apply_attitude(base, delta)
	_apply_thrust(base, delta)


## Fold this frame's mouse + roll input into the aim orientation. Each rotation
## is applied in the aim's OWN local frame, so steering is always relative to
## where you currently point and how you're banked -- which is exactly what
## makes roll-then-turn feel natural and removes any need for a pitch clamp or
## roll compensation. Flip a sign below if an axis feels inverted.
func _update_aim(base: SpacecraftBaseStats, delta: float) -> void:
	var yaw := -_yaw_delta * base.yaw_speed
	var pitch := _pitch_delta * base.pitch_speed
	var roll := _roll_input * base.roll_speed * delta

	aim_basis = aim_basis * Basis(Vector3.UP, yaw)       # yaw about local up
	aim_basis = aim_basis * Basis(Vector3.RIGHT, pitch)  # pitch about local right
	aim_basis = aim_basis * Basis(Vector3.BACK, roll)    # roll about local forward
	aim_basis = aim_basis.orthonormalized()

	_pitch_delta = 0.0
	_yaw_delta = 0.0


## Spring the ship orientation toward the aim in full 3D. The error between the
## two orientations is expressed as an axis*angle vector; an under-damped spring
## on the angular velocity produces the lag and overshoot/wobble in every axis.
func _chase_aim(base: SpacecraftBaseStats, delta: float) -> void:
	var current := _basis.get_rotation_quaternion()
	var target := aim_basis.get_rotation_quaternion()
	if current.dot(target) < 0.0:
		target = -target  # take the shortest rotational path

	var error := _log_quat(target * current.inverse())
	_ang_vel += error * base.turn_stiffness * delta
	_ang_vel *= exp(-base.turn_damping * delta)

	current = (_exp_quat(_ang_vel * delta) * current).normalized()
	_basis = Basis(current)


## Apply the ship orientation plus a small hull shake that grows with how hard
## we're turning. The shake is a purely local jitter layered on the sprung
## orientation, so the craft visibly wobbles while the aim target stays clean.
func _apply_attitude(base: SpacecraftBaseStats, _delta: float) -> void:
	var shake := base.shake_amount + base.shake_from_turn * get_turn_speed()
	var t := Time.get_ticks_msec() / 1000.0
	var jitter := Vector3(
		sin(t * 23.0) * shake,  # pitch
		cos(t * 17.0) * shake,  # yaw
		sin(t * 13.0) * shake,  # roll
	)
	var ship_basis := _basis * Basis.from_euler(jitter)
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


## Quaternion log: express a rotation as an axis*angle vector (radians), the
## form the angular spring integrates.
func _log_quat(q: Quaternion) -> Vector3:
	q = q.normalized()
	var w := clampf(q.w, -1.0, 1.0)
	var s := sqrt(1.0 - w * w)
	if s < 0.0001:
		return Vector3.ZERO
	var angle := 2.0 * acos(w)
	if angle > PI:
		angle -= TAU
	return Vector3(q.x, q.y, q.z) / s * angle


## Quaternion exp: turn an axis*angle vector back into a rotation.
func _exp_quat(v: Vector3) -> Quaternion:
	var angle := v.length()
	if angle < 0.0001:
		return Quaternion.IDENTITY
	return Quaternion(v / angle, angle)


## The camera reads this to track exactly where you're aiming (full orientation,
## roll included).
func get_aim_basis() -> Basis:
	return aim_basis


## Magnitude of the current turn (for camera shake scaling, etc.).
func get_turn_speed() -> float:
	return _ang_vel.length()

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
