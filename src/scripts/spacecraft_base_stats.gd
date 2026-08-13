extends Resource
class_name SpacecraftBaseStats

## Immutable, per-craft configuration data. This is DATA, not a node: create
## one .tres file per spacecraft (speeder_a_stats.tres, cruiser_stats.tres, ...)
## and tweak the values in the inspector. StatefulStats reads from this to seed
## and clamp its runtime values.

@export_group("Speed")
@export var min_speed: float = 0  ## Standstill
@export var max_speed: float = 40.0    ## Forward cap before turbo.
@export var base_speed: float = 0.0    ## Speed the craft spawns with.
@export var acceleration: float = 20.0 ## Units/sec added per full throttle.
@export var turbo_multiplier: float = 1.6 ## max_speed multiplier while turbo held.

@export_group("Handling")
@export var pitch_speed: float = 1.5   ## Multiplier on mouse pitch input (aim rate).
@export var yaw_speed: float = 1.5     ## Multiplier on mouse yaw input (aim rate).
@export var roll_speed: float = 2.5    ## Radians/sec of manual roll at full input.
@export var max_pitch_deg: float = 85.0 ## Clamp so the nose can't flip over the top.

@export_subgroup("Chase feel")
## Higher = the ship snaps to your aim faster (stiffer). Lower = more lag.
@export var turn_stiffness: float = 20.0
## Higher = settles quickly; lower = looser and wobblier (the "shakiness").
@export var turn_damping: float = 6.0
## How hard the ship banks into a turn (visual lean). 0 disables auto-bank.
@export var bank_amount: float = 0.15

@export_subgroup("Shake")
## Constant idle jitter of the hull, in radians. 0 disables idle shake.
@export var shake_amount: float = 0.003
## Extra jitter added in proportion to how hard the ship is turning.
@export var shake_from_turn: float = 0.02

@export_group("Durability")
@export var base_health: int = 100
