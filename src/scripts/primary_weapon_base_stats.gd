extends Resource
class_name PrimaryWeaponBaseStats

## Immutable, per-weapon configuration data. This is DATA, not a node: create one
## .tres file per weapon and tweak the values in the inspector.
##
## As with SpacecraftBaseStats, DISTANCES ARE AUTHORED IN ENGINE UNITS: metres,
## and metres per second. What you type is what the projectile flies at and how
## far it gets, with no conversion in between.

@export var projectile_scene: PackedScene
@export var loading_speed: float = 0.4  ## Seconds to reload between shots.
@export var damage: float = 3.0
@export var travel_range: float = 270.0       ## Metres travelled before the shot expires.
@export var speed: float = 100.0        ## Muzzle speed, metres/sec.
