class_name AssassinationConfig
extends Resource


## Data-driven limits for the four deterministic assassination contexts.
##
## The values are deliberately kept in a Resource instead of the resolver so
## level/campaign tuning can change the feel of a context without changing
## the pure judgment function.  Alert arrays contain Enums.AlertState values;
## COMBAT is intentionally absent from the default lists.

@export_range(0.1, 5.0, 0.05) var presentation_duration_seconds: float = 0.75
@export_range(0.1, 5.0, 0.05) var back_max_distance_m: float = 1.5
@export_range(0.0, 180.0, 1.0) var back_max_angle_degrees: float = 70.0
@export var back_allowed_alert_states: Array[int] = [0, 1, 2, 4]

@export_range(0.1, 6.0, 0.05) var above_max_distance_m: float = 4.0
@export_range(0.0, 180.0, 1.0) var above_max_angle_degrees: float = 45.0
@export var above_allowed_alert_states: Array[int] = [0, 1, 2, 4]

@export_range(0.1, 5.0, 0.05) var below_max_distance_m: float = 1.5
@export_range(0.0, 180.0, 1.0) var below_max_angle_degrees: float = 45.0
@export var below_allowed_alert_states: Array[int] = [0, 1, 2, 4]

@export_range(0.1, 5.0, 0.05) var corner_max_distance_m: float = 1.5
@export_range(0.0, 180.0, 1.0) var corner_max_angle_degrees: float = 60.0
@export var corner_allowed_alert_states: Array[int] = [0, 1, 2, 4]


func is_alert_allowed(context: StringName, alert_state: Enums.AlertState) -> bool:
	if alert_state == Enums.AlertState.COMBAT:
		return false
	var allowed: Array = _allowed_states_for(context)
	return allowed.has(int(alert_state))


func max_distance_for(context: StringName) -> float:
	match context:
		&"back":
			return _finite_positive(back_max_distance_m, 1.5)
		&"above":
			return _finite_positive(above_max_distance_m, 4.0)
		&"below":
			return _finite_positive(below_max_distance_m, 1.5)
		&"corner":
			return _finite_positive(corner_max_distance_m, 1.5)
	return 0.0


func max_angle_for(context: StringName) -> float:
	match context:
		&"back":
			return _finite_angle(back_max_angle_degrees, 70.0)
		&"above":
			return _finite_angle(above_max_angle_degrees, 45.0)
		&"below":
			return _finite_angle(below_max_angle_degrees, 45.0)
		&"corner":
			return _finite_angle(corner_max_angle_degrees, 60.0)
	return 0.0


func _allowed_states_for(context: StringName) -> Array:
	match context:
		&"back":
			return back_allowed_alert_states
		&"above":
			return above_allowed_alert_states
		&"below":
			return below_allowed_alert_states
		&"corner":
			return corner_allowed_alert_states
	return []


func _finite_positive(value: float, fallback: float) -> float:
	return value if is_finite(value) and value > 0.0 else fallback


func _finite_angle(value: float, fallback: float) -> float:
	return clampf(value, 0.0, 180.0) if is_finite(value) else fallback


func presentation_duration() -> float:
	return presentation_duration_seconds if is_finite(presentation_duration_seconds) else 0.75
