class_name CombatConfig
extends Resource


## Shared, data-driven combat timing and damage values.
##
## Combat components clamp values at runtime as well as in the editor.  This
## keeps malformed authored resources from creating an unbounded attack loop
## or a non-finite movement step.

const MAX_COMBO_HITS := 3
const MAX_HEALTH := 20
const MAX_DAMAGE := 20
const MIN_DURATION_SECONDS := 0.05
const MAX_DURATION_SECONDS := 10.0
const MAX_DISTANCE_METERS := 20.0
const MAX_REINFORCEMENTS := 32

@export_range(0.05, MAX_DURATION_SECONDS, 0.05) var combo_window_seconds: float = 0.75
@export_range(MIN_DURATION_SECONDS, MAX_DURATION_SECONDS, 0.05) var attack_startup_seconds: float = 0.10
@export_range(0.05, MAX_DURATION_SECONDS, 0.05) var attack_active_seconds: float = 0.20
@export_range(MIN_DURATION_SECONDS, MAX_DURATION_SECONDS, 0.05) var attack_recovery_seconds: float = 0.25
@export_range(0.1, MAX_DISTANCE_METERS, 0.1) var attack_range_m: float = 2.2
@export var combo_damage: Array[int] = [1, 1, 1]

@export_range(0.05, MAX_DURATION_SECONDS, 0.05) var parry_window_seconds: float = 0.25
@export_range(MIN_DURATION_SECONDS, MAX_DURATION_SECONDS, 0.05) var parry_cooldown_seconds: float = 0.35
@export_range(0.05, MAX_DURATION_SECONDS, 0.05) var dodge_invulnerability_seconds: float = 0.35
@export_range(MIN_DURATION_SECONDS, MAX_DURATION_SECONDS, 0.05) var dodge_cooldown_seconds: float = 0.80
@export_range(0.1, MAX_DISTANCE_METERS, 0.1) var dodge_distance_m: float = 2.5

@export_range(1, MAX_HEALTH, 1) var player_max_health: int = 3
@export_range(MIN_DURATION_SECONDS, MAX_DURATION_SECONDS, 0.05) var hit_invulnerability_seconds: float = 0.20

@export_range(1, MAX_HEALTH, 1) var enemy_max_health: int = 3
@export_range(1, MAX_DAMAGE, 1) var enemy_attack_power: int = 1
@export_range(0.05, MAX_DURATION_SECONDS, 0.05) var enemy_attack_cooldown_seconds: float = 1.0
@export_range(0.1, MAX_DISTANCE_METERS, 0.1) var enemy_attack_range_m: float = 2.0
@export_range(0.1, MAX_DISTANCE_METERS, 0.1) var reinforcement_radius_m: float = 12.0
@export_range(0, MAX_REINFORCEMENTS, 1) var max_reinforcements: int = 8


func normalized() -> CombatConfig:
	var result := duplicate(true) as CombatConfig
	result.combo_window_seconds = _bounded_duration(result.combo_window_seconds, 0.75)
	result.attack_startup_seconds = _bounded_duration(result.attack_startup_seconds, 0.10)
	result.attack_active_seconds = _bounded_duration(result.attack_active_seconds, 0.20)
	result.attack_recovery_seconds = _bounded_duration(result.attack_recovery_seconds, 0.25)
	result.attack_range_m = _bounded_distance(result.attack_range_m, 2.2)
	result.parry_window_seconds = _bounded_duration(result.parry_window_seconds, 0.25)
	result.parry_cooldown_seconds = _bounded_duration(result.parry_cooldown_seconds, 0.35)
	result.dodge_invulnerability_seconds = _bounded_duration(result.dodge_invulnerability_seconds, 0.35)
	result.dodge_cooldown_seconds = _bounded_duration(result.dodge_cooldown_seconds, 0.80)
	result.dodge_distance_m = _bounded_distance(result.dodge_distance_m, 2.5)
	result.hit_invulnerability_seconds = _bounded_duration(result.hit_invulnerability_seconds, 0.20)
	result.player_max_health = clampi(result.player_max_health, 1, MAX_HEALTH)
	result.enemy_max_health = clampi(result.enemy_max_health, 1, MAX_HEALTH)
	result.enemy_attack_power = clampi(result.enemy_attack_power, 1, MAX_DAMAGE)
	result.enemy_attack_cooldown_seconds = _bounded_duration(
		result.enemy_attack_cooldown_seconds,
		1.0,
	)
	result.enemy_attack_range_m = _bounded_distance(result.enemy_attack_range_m, 2.0)
	result.reinforcement_radius_m = _bounded_distance(result.reinforcement_radius_m, 12.0)
	result.max_reinforcements = clampi(result.max_reinforcements, 0, MAX_REINFORCEMENTS)
	var bounded_damage: Array[int] = []
	for value in result.combo_damage.slice(0, MAX_COMBO_HITS):
		bounded_damage.append(clampi(int(value), 1, MAX_DAMAGE))
	while bounded_damage.size() < MAX_COMBO_HITS:
		bounded_damage.append(1)
	result.combo_damage = bounded_damage
	return result


func damage_for_combo(index: int) -> int:
	var values := combo_damage
	if values.is_empty():
		return 1
	return clampi(int(values[clampi(index - 1, 0, values.size() - 1)]), 1, MAX_DAMAGE)


static func _bounded_duration(value: float, fallback: float) -> float:
	return clampf(value, MIN_DURATION_SECONDS, MAX_DURATION_SECONDS) if is_finite(value) else fallback


static func _bounded_distance(value: float, fallback: float) -> float:
	return clampf(value, 0.1, MAX_DISTANCE_METERS) if is_finite(value) else fallback
