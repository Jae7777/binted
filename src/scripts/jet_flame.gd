extends Node3D

@export var runtime_stats: RuntimeStats
@export var flames: GPUParticles3D
@export var light: OmniLight3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	flames.emitting = runtime_stats.current_speed != 0
	light.omni_range = clampf(runtime_stats.current_speed, 0, 8)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	flames.emitting = runtime_stats.current_speed != 0
	light.omni_range = clampf(runtime_stats.current_speed, 0, 8)
