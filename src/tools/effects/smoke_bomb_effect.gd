class_name SmokeBombTool
extends ToolBase


const MAX_SMOKE_RADIUS := 5.0
const MAX_SMOKE_DURATION := 5.0
const SMOKE_GROUP := &"smoke_volumes"

var _radius := 0.0
var _expires_at := 0.0


func _apply_effect(hit: Dictionary) -> void:
	var definition := tool_definition
	if definition == null:
		return
	_radius = clampf(definition.parameter_float(&"radius", MAX_SMOKE_RADIUS), 0.0, MAX_SMOKE_RADIUS)
	var duration := clampf(definition.parameter_float(&"duration", MAX_SMOKE_DURATION), 0.0, MAX_SMOKE_DURATION)
	if _radius <= 0.0 or duration <= 0.0:
		return
	# Smoke is an impact volume, not a projectile child: stop inheriting the moving ToolRig transform.
	top_level = true
	global_position = _impact_position(hit)
	if not global_position.is_finite():
		_radius = 0.0
		return
	_expires_at = _now() + duration
	if not is_in_group(SMOKE_GROUP):
		add_to_group(SMOKE_GROUP)
	set_process(true)


func is_active() -> bool:
	return _radius > 0.0 and _expires_at > _now()


func smoke_radius() -> float:
	return _radius


func remaining_seconds() -> float:
	return maxf(_expires_at - _now(), 0.0) if is_active() else 0.0


func blocks_visibility(observer: Vector3, target: Vector3) -> bool:
	if not is_active() or not observer.is_finite() or not target.is_finite():
		return false
	var segment := target - observer
	var segment_length_squared := segment.length_squared()
	if segment_length_squared <= 0.000001:
		return global_position.distance_squared_to(observer) <= _radius * _radius
	var projection := clampf((global_position - observer).dot(segment) / segment_length_squared, 0.0, 1.0)
	var nearest := observer + segment * projection
	return global_position.distance_squared_to(nearest) <= _radius * _radius


func _process(_delta: float) -> void:
	if not is_active():
		queue_free()


func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
