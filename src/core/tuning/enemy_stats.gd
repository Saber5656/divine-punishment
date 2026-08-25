class_name EnemyStats
extends Resource


## Combat values authored per enemy archetype, separate from perception.

const MAX_HEALTH := 20
const MAX_DAMAGE := 20
const MAX_DISTANCE_METERS := 20.0
const MAX_REINFORCEMENTS := 32

@export_range(1, MAX_HEALTH, 1) var max_health: int = 3
@export_range(1, MAX_DAMAGE, 1) var attack_power: int = 1
@export_range(0.05, 10.0, 0.05) var attack_cooldown_seconds: float = 1.0
@export_range(0.1, MAX_DISTANCE_METERS, 0.1) var attack_range_m: float = 2.0
@export_range(0.1, MAX_DISTANCE_METERS, 0.1) var reinforcement_radius_m: float = 12.0
@export_range(0, MAX_REINFORCEMENTS, 1) var max_reinforcements: int = 8


func normalized() -> EnemyStats:
	var result := duplicate(true) as EnemyStats
	result.max_health = clampi(result.max_health, 1, MAX_HEALTH)
	result.attack_power = clampi(result.attack_power, 1, MAX_DAMAGE)
	result.attack_cooldown_seconds = (
		clampf(result.attack_cooldown_seconds, 0.05, 10.0)
		if is_finite(result.attack_cooldown_seconds)
		else 1.0
	)
	result.attack_range_m = (
		clampf(result.attack_range_m, 0.1, MAX_DISTANCE_METERS)
		if is_finite(result.attack_range_m)
		else 2.0
	)
	result.reinforcement_radius_m = (
		clampf(result.reinforcement_radius_m, 0.1, MAX_DISTANCE_METERS)
		if is_finite(result.reinforcement_radius_m)
		else 12.0
	)
	result.max_reinforcements = clampi(result.max_reinforcements, 0, MAX_REINFORCEMENTS)
	return result
