class_name ScoringConfig
extends Resource


@export var shadow_walker_points: int = 40
@export var no_traces_points: int = 25
@export var one_strike_points: int = 20
@export var swift_points: int = 15
@export var nontarget_kill_penalty: int = -3
@export var nontarget_kill_penalty_cap: int = -15
@export var civilian_kill_penalty: int = -10
@export var side_objective_bonus: int = 5
@export var rank_kaiden_threshold: int = 90
@export var rank_okuden_threshold: int = 75
@export var rank_chuden_threshold: int = 55
@export var m9_knockout_success_ratio: float = 0.8
@export var m10_shadow_walker_bonus_shift: int = 15
@export var epilogue_a_condition: int = 12

## Measured developer-route limits; unknown missions retain their authored limit.
@export var measured_par_seconds: Dictionary = {}

func par_seconds(mission_id: StringName, authored_minutes: float) -> float:
	if not is_finite(authored_minutes) or authored_minutes <= 0.0: return 0.0
	var measured: Variant = measured_par_seconds.get(String(mission_id), authored_minutes * 60.0)
	if (measured is float or measured is int) and is_finite(float(measured)) and float(measured) > 0.0:
		return float(measured)
	return authored_minutes * 60.0
