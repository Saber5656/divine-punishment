class_name ToolDefinition
extends Resource


## Data-only description of a ninja tool.
##
## Tool effects deliberately live in a PackedScene.  Adding a new tool therefore
## only requires a resource and an effect scene; the inventory and aiming code
## do not need a new branch for every tool type.
const MAX_COUNT := 999
const MIN_PROJECTILE_SPEED := 0.1
const MAX_PROJECTILE_SPEED := 200.0
const MAX_TRAJECTORY_SECONDS := 10.0
const MAX_TRAJECTORY_STEPS := 128

@export var id: StringName = &""
@export var display_name: String = ""
@export_range(0, MAX_COUNT, 1) var default_count: int = 0
@export var is_projectile: bool = false
@export var lethal: bool = false
@export var effect_scene: PackedScene
@export var params: Dictionary = {}

# These values are framework tuning rather than effect-specific behaviour.  A
# tool may override them in its resource while the eventual effect scene owns
# the actual hit/effect implementation (Issue #33 and later).
@export_range(MIN_PROJECTILE_SPEED, MAX_PROJECTILE_SPEED, 0.1) var projectile_speed: float = 18.0
@export_range(0.0, 100.0, 0.1) var trajectory_gravity: float = 9.8
@export_range(0.05, MAX_TRAJECTORY_SECONDS, 0.05) var trajectory_seconds: float = 1.2
@export_range(2, MAX_TRAJECTORY_STEPS, 1) var trajectory_steps: int = 24


func is_valid() -> bool:
	return (
		id != &""
		and not display_name.strip_edges().is_empty()
		and default_count >= 0
		and default_count <= MAX_COUNT
		and (not is_projectile or (is_finite(projectile_speed) and projectile_speed > 0.0))
	)


func count_limit() -> int:
	return MAX_COUNT


func safe_default_count() -> int:
	return clampi(default_count, 0, MAX_COUNT)


func supports_aiming() -> bool:
	return is_projectile and is_finite(projectile_speed) and projectile_speed > 0.0


func trajectory_duration() -> float:
	if not is_finite(trajectory_seconds):
		return 0.0
	return clampf(trajectory_seconds, 0.05, MAX_TRAJECTORY_SECONDS)


func trajectory_sample_count() -> int:
	return clampi(trajectory_steps, 2, MAX_TRAJECTORY_STEPS)


func parameter_float(key: StringName, fallback: float = 0.0) -> float:
	var value: Variant = params.get(key, fallback)
	if value is float or value is int:
		var number := float(value)
		return number if is_finite(number) else fallback
	return fallback
