@tool
class_name RoutineStop
extends Marker3D


## A bounded, authored dwell point for an enemy routine.
##
## RoutineStop deliberately stays a lightweight Marker3D.  PatrolPath owns
## ordering and route traversal; this node owns only the data that level
## designers author at a stop (dwell, facing, and an optional time tag).

const MIN_DWELL_SECONDS := 0.0
const MAX_DWELL_SECONDS := 600.0
const MAX_ROUTE_INDEX := 63
const MAX_SCHEDULE_SECONDS := 86400.0
const MAX_GIZMO_SIZE := 0.75
const UNIT_SCALE_TOLERANCE := 0.001

@export_range(0, MAX_ROUTE_INDEX, 1) var route_index := 0:
	set(value):
		route_index = clampi(value, 0, MAX_ROUTE_INDEX)
		_update_editor_state()
@export_range(MIN_DWELL_SECONDS, MAX_DWELL_SECONDS, 0.1) var dwell_seconds := 1.0:
	set(value):
		dwell_seconds = _bounded_dwell(value)
		_update_editor_state()
@export var time_tag: StringName = &"":
	set(value):
		time_tag = value
		_update_editor_state()
@export_range(0.0, MAX_SCHEDULE_SECONDS, 1.0) var active_from_seconds := 0.0:
	set(value):
		active_from_seconds = _bounded_schedule(value)
		_update_editor_state()
@export_range(0.0, MAX_SCHEDULE_SECONDS, 1.0) var active_until_seconds := 0.0:
	set(value):
		active_until_seconds = _bounded_schedule(value)
		_update_editor_state()
@export_range(0.0, MAX_SCHEDULE_SECONDS, 1.0) var repeat_period_seconds := 0.0:
	set(value):
		repeat_period_seconds = _bounded_schedule(value)
		_update_editor_state()
@export var routine_action: StringName = &"stand":
	set(value):
		routine_action = value
		_update_editor_state()
@export var facing_direction := Vector3.FORWARD:
	set(value):
		facing_direction = value
		_update_editor_state()
@export var enabled := true:
	set(value):
		enabled = value
		_update_editor_state()


func _enter_tree() -> void:
	set_notify_transform(true)
	if not is_in_group(&"routine_stops"):
		add_to_group(&"routine_stops")
	_update_editor_state()


func _exit_tree() -> void:
	set_notify_transform(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_update_editor_state()


func is_geometry_valid() -> bool:
	return (
		is_inside_tree()
		and is_world_transform_within_contract(global_transform)
		and route_index >= 0
		and route_index <= MAX_ROUTE_INDEX
		and is_finite(dwell_seconds)
		and dwell_seconds >= MIN_DWELL_SECONDS
		and dwell_seconds <= MAX_DWELL_SECONDS
		and is_finite(active_from_seconds)
		and active_from_seconds >= 0.0
		and active_from_seconds <= MAX_SCHEDULE_SECONDS
		and is_finite(active_until_seconds)
		and active_until_seconds >= 0.0
		and active_until_seconds <= MAX_SCHEDULE_SECONDS
		and is_finite(repeat_period_seconds)
		and repeat_period_seconds >= 0.0
		and repeat_period_seconds <= MAX_SCHEDULE_SECONDS
		and (
			active_until_seconds <= 0.0
			or active_until_seconds >= active_from_seconds
		)
		and _is_finite_vector(facing_direction)
	)


func dwell_duration() -> float:
	return _bounded_dwell(dwell_seconds)


func target_position() -> Vector3:
	return global_position if _is_finite_vector(global_position) else Vector3.ZERO


func world_facing_direction() -> Vector3:
	if not _is_finite_vector(facing_direction) or facing_direction.length_squared() <= 0.000001:
		return -global_transform.basis.z
	var direction := global_transform.basis * facing_direction
	return direction.normalized() if _is_finite_vector(direction) and direction.length_squared() > 0.000001 else Vector3.FORWARD


func is_active_at(elapsed_seconds: float) -> bool:
	if not enabled or not is_geometry_valid() or not is_finite(elapsed_seconds) or elapsed_seconds < 0.0:
		return false
	if elapsed_seconds < active_from_seconds:
		return false
	if active_until_seconds > 0.0:
		if repeat_period_seconds > 0.0:
			var cycle_time := fmod(elapsed_seconds - active_from_seconds, repeat_period_seconds)
			return cycle_time <= active_until_seconds - active_from_seconds
		return elapsed_seconds <= active_until_seconds
	return true


func gizmo_segments() -> PackedVector3Array:
	if not is_geometry_valid():
		return PackedVector3Array()
	var segments := PackedVector3Array()
	var size := clampf(maxf(dwell_duration() * 0.08, 0.15), 0.15, MAX_GIZMO_SIZE)
	for axis: Vector3 in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
		segments.append(-axis * size)
		segments.append(axis * size)
	var direction := world_facing_direction()
	var local_direction := global_transform.basis.inverse() * direction
	if _is_finite_vector(local_direction) and local_direction.length_squared() > 0.000001:
		local_direction = local_direction.normalized()
		segments.append(Vector3.ZERO)
		segments.append(local_direction * minf(size * 2.0, MAX_GIZMO_SIZE))
	return segments


static func is_world_transform_within_contract(world_transform: Transform3D) -> bool:
	if not _is_safe_world_position(world_transform.origin):
		return false
	var axes: Array[Vector3] = [world_transform.basis.x, world_transform.basis.y, world_transform.basis.z]
	for axis: Vector3 in axes:
		if not _is_finite_vector(axis) or absf(axis.length() - 1.0) > UNIT_SCALE_TOLERANCE:
			return false
	return (
		absf(axes[0].dot(axes[1])) <= UNIT_SCALE_TOLERANCE
		and absf(axes[0].dot(axes[2])) <= UNIT_SCALE_TOLERANCE
		and absf(axes[1].dot(axes[2])) <= UNIT_SCALE_TOLERANCE
		and absf(absf(world_transform.basis.determinant()) - 1.0) <= UNIT_SCALE_TOLERANCE
	)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not is_geometry_valid():
		warnings.append("RoutineStop requires finite transform, bounded dwell/schedule values, and a non-zero facing direction.")
	if active_until_seconds > 0.0 and active_until_seconds < active_from_seconds:
		warnings.append("RoutineStop active_until_seconds must be after active_from_seconds.")
	return warnings


func _update_editor_state() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		update_configuration_warnings()
		update_gizmos()


static func _bounded_dwell(value: float) -> float:
	return clampf(value, MIN_DWELL_SECONDS, MAX_DWELL_SECONDS) if is_finite(value) else MIN_DWELL_SECONDS


static func _bounded_schedule(value: float) -> float:
	return clampf(value, 0.0, MAX_SCHEDULE_SECONDS) if is_finite(value) else 0.0


static func _is_finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)


static func _is_safe_world_position(value: Vector3) -> bool:
	return _is_finite_vector(value) and absf(value.x) <= 10000.0 and absf(value.y) <= 10000.0 and absf(value.z) <= 10000.0
