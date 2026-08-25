@tool
class_name PatrolPath
extends Path3D


## Authored route for an enemy's routine movement.
##
## PatrolPath is intentionally a Path3D so it can be authored beside a
## NavigationRegion3D.  RoutineStop children provide deterministic dwell and
## facing data; a Curve3D remains useful as the route's editor preview and as
## a fallback route when a level has not authored individual stops yet.

const MIN_POINT_COUNT := 2
const MAX_POINT_COUNT := 64
const MAX_STOP_COUNT := 64
const MIN_ROUTE_LENGTH := 0.5
const MAX_ROUTE_LENGTH := 500.0
const MAX_LOCAL_POINT_DISTANCE := 100.0
const MAX_GIZMO_SEGMENTS := 192
const MAX_GIZMO_SAMPLES := 64
const UNIT_SCALE_TOLERANCE := 0.001

@export var looped := true:
	set(value):
		looped = value
		_update_editor_state()
@export_range(0.1, 12.0, 0.1) var route_speed := 1.5:
	set(value):
		route_speed = clampf(value, 0.1, 12.0) if is_finite(value) else 1.5
		_update_editor_state()
@export var enabled := true:
	set(value):
		enabled = value
		_update_editor_state()
@export var route_tag: StringName = &"":
	set(value):
		route_tag = value
		_update_editor_state()


## Compatibility alias used by authored marker APIs and tests.
var path_curve: Curve3D:
	get:
		return curve
	set(value):
		curve = value if value != null else Curve3D.new()
		_update_editor_state()


func _enter_tree() -> void:
	set_notify_transform(true)
	if not is_in_group(&"patrol_paths"):
		add_to_group(&"patrol_paths")
	_update_editor_state()


func _exit_tree() -> void:
	set_notify_transform(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_update_editor_state()


func is_geometry_valid() -> bool:
	if not is_inside_tree() or not enabled:
		return false
	if not is_world_transform_within_contract(global_transform):
		return false
	var route_has_geometry := false
	if curve != null and curve.point_count > 0:
		if curve.point_count < MIN_POINT_COUNT or curve.point_count > MAX_POINT_COUNT:
			return false
		if not _curve_is_valid():
			return false
		route_has_geometry = curve.get_baked_length() >= MIN_ROUTE_LENGTH
	var stops := ordered_stops()
	if stops.size() > MAX_STOP_COUNT:
		return false
	for stop: RoutineStop in stops:
		if stop == null or not is_instance_valid(stop) or not stop.is_geometry_valid():
			return false
	if stops.size() >= 2:
		route_has_geometry = true
	return route_has_geometry


func route_length() -> float:
	if curve != null and curve.point_count >= MIN_POINT_COUNT:
		var curve_length := curve.get_baked_length()
		if is_finite(curve_length) and curve_length >= 0.0:
			return minf(curve_length, MAX_ROUTE_LENGTH)
	var stops := ordered_stops()
	var route_length_total := 0.0
	for index in range(1, stops.size()):
		var segment := stops[index - 1].global_position.distance_to(stops[index].global_position)
		if is_finite(segment):
			route_length_total += segment
	if looped and stops.size() > 1:
		var closing := stops[-1].global_position.distance_to(stops[0].global_position)
		if is_finite(closing):
			route_length_total += closing
	return minf(route_length_total, MAX_ROUTE_LENGTH) if is_finite(route_length_total) else 0.0


func path_length() -> float:
	return route_length()


func is_looped() -> bool:
	return looped


func ordered_stops() -> Array[RoutineStop]:
	var result: Array[RoutineStop] = []
	var child_count := mini(get_child_count(), MAX_STOP_COUNT + 1)
	for child_index in range(child_count):
		var stop := get_child(child_index) as RoutineStop
		if stop != null and is_instance_valid(stop):
			# Stable insertion sort keeps scene order for equal route indices.
			var insert_at := result.size()
			for index in range(result.size()):
				if stop.route_index < result[index].route_index:
					insert_at = index
					break
			result.insert(insert_at, stop)
	return result


func stops() -> Array[RoutineStop]:
	return ordered_stops()


## Return authored stops available at the permanent area-alert level.  The
## result is bounded by the same MAX_STOP_COUNT contract as ordered_stops().
func stops_for_alert_level(area_alert_level: int = 0) -> Array[RoutineStop]:
	var result: Array[RoutineStop] = []
	var bounded_level := clampi(area_alert_level, 0, RoutineStop.MAX_AREA_ALERT_LEVEL)
	for stop: RoutineStop in ordered_stops():
		if stop != null and stop.is_available_at(bounded_level):
			result.append(stop)
	return result


func eligible_stops(area_alert_level: int = 0) -> Array[RoutineStop]:
	return stops_for_alert_level(area_alert_level)


func stop_count() -> int:
	return ordered_stops().size()


func stop_at(index: int) -> RoutineStop:
	var route_stops := ordered_stops()
	return route_stops[index] if index >= 0 and index < route_stops.size() else null


func current_stop() -> RoutineStop:
	return stop_at(0)


func world_position_for_stop(index: int) -> Vector3:
	var stop := stop_at(index)
	return stop.target_position() if stop != null else Vector3.ZERO


func world_facing_for_stop(index: int) -> Vector3:
	var stop := stop_at(index)
	return stop.world_facing_direction() if stop != null else Vector3.ZERO


func next_stop_index(current_index: int, forward := true) -> int:
	var count := stop_count()
	if count == 0:
		return -1
	var current := clampi(current_index, 0, count - 1)
	var next := current + (1 if forward else -1)
	if looped:
		return posmod(next, count)
	return clampi(next, 0, count - 1)


func next_stop_index_for_alert(
	current_index: int,
	area_alert_level: int = 0,
	forward := true,
) -> int:
	var route_stops := ordered_stops()
	if route_stops.is_empty():
		return -1
	var bounded_level := clampi(area_alert_level, 0, RoutineStop.MAX_AREA_ALERT_LEVEL)
	var current := clampi(current_index, 0, route_stops.size() - 1)
	for offset in range(1, route_stops.size() + 1):
		var candidate_index := current + (offset if forward else -offset)
		if looped:
			candidate_index = posmod(candidate_index, route_stops.size())
		elif candidate_index < 0 or candidate_index >= route_stops.size():
			break
		var candidate := route_stops[candidate_index]
		if candidate != null and candidate.is_available_at(bounded_level):
			return candidate_index
	return -1


func world_position_at_distance(distance: float) -> Vector3:
	if curve == null or curve.point_count < MIN_POINT_COUNT or not is_finite(distance):
		return Vector3.ZERO
	var length := curve.get_baked_length()
	if not is_finite(length) or length <= 0.0:
		return Vector3.ZERO
	var local_position := curve.sample_baked(clampf(distance, 0.0, length), true)
	var world_position := to_global(local_position)
	return world_position if _is_safe_world_position(world_position) else Vector3.ZERO


func gizmo_segments() -> PackedVector3Array:
	if not is_inside_tree() or not is_world_transform_within_contract(global_transform):
		return PackedVector3Array()
	var segments := PackedVector3Array()
	if curve != null and curve.point_count > 0:
		if (
			curve.point_count < MIN_POINT_COUNT
			or curve.point_count > MAX_POINT_COUNT
			or not _curve_is_valid()
		):
			return PackedVector3Array()
		var length := curve.get_baked_length()
		if not is_finite(length) or length <= 0.0 or length > MAX_ROUTE_LENGTH:
			return PackedVector3Array()
		var sample_count := mini(MAX_GIZMO_SAMPLES, maxi(2, ceili(length / 2.0)))
		var previous := curve.sample_baked(0.0, true)
		if not _is_safe_gizmo_local_position(previous):
			return PackedVector3Array()
		for index in range(1, sample_count):
			var current := curve.sample_baked(length * float(index) / float(sample_count - 1), true)
			if not _is_safe_gizmo_local_position(current):
				return PackedVector3Array()
			if segments.size() + 2 > MAX_GIZMO_SEGMENTS * 2:
				return PackedVector3Array()
			segments.append(previous)
			segments.append(current)
			previous = current
	var route_stops := ordered_stops()
	if route_stops.size() > MAX_STOP_COUNT:
		return PackedVector3Array()
	var local_stop_positions: Array[Vector3] = []
	for stop: RoutineStop in route_stops:
		if stop == null or not is_instance_valid(stop) or not stop.is_geometry_valid():
			return PackedVector3Array()
		var local_position := to_local(stop.global_position)
		if not _is_safe_gizmo_local_position(local_position):
			return PackedVector3Array()
		local_stop_positions.append(local_position)
	var stop_sampling_complete := true
	for index in range(route_stops.size()):
		var local_position := local_stop_positions[index]
		var required_segments := 4 + (2 if index > 0 else 0)
		if segments.size() + required_segments > MAX_GIZMO_SEGMENTS * 2:
			stop_sampling_complete = false
			break
		var size := 0.35
		var marker_positions: Array[Vector3] = [
			local_position + Vector3.LEFT * size,
			local_position + Vector3.RIGHT * size,
			local_position + Vector3.FORWARD * size,
			local_position + Vector3.BACK * size,
		]
		for marker_position: Vector3 in marker_positions:
			if not _is_safe_gizmo_local_position(marker_position):
				return PackedVector3Array()
		for marker_position: Vector3 in marker_positions:
			segments.append(marker_position)
		if index > 0:
			segments.append(local_stop_positions[index - 1])
			segments.append(local_position)
	if looped and stop_sampling_complete and route_stops.size() > 1 and segments.size() + 2 <= MAX_GIZMO_SEGMENTS * 2:
		segments.append(local_stop_positions[-1])
		segments.append(local_stop_positions[0])
	return segments


func _curve_is_valid() -> bool:
	if curve == null:
		return false
	if not is_finite(curve.bake_interval) or curve.bake_interval < 0.05 or curve.bake_interval > 2.0:
		return false
	var previous := Vector3.ZERO
	var polygon_length := 0.0
	for index in range(mini(curve.point_count, MAX_POINT_COUNT)):
		var point := curve.get_point_position(index)
		var point_in := curve.get_point_in(index)
		var point_out := curve.get_point_out(index)
		for local_value: Vector3 in [point, point + point_in, point + point_out]:
			if not _is_finite_vector(local_value) or local_value.length() > MAX_LOCAL_POINT_DISTANCE:
				return false
			var world_value := to_global(local_value)
			if not _is_safe_world_position(world_value):
				return false
		if index > 0:
			var segment := previous.distance_to(point)
			if not is_finite(segment):
				return false
			polygon_length += segment
			if polygon_length > MAX_ROUTE_LENGTH:
				return false
		previous = point
	return true


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not is_geometry_valid():
		warnings.append("PatrolPath requires a bounded Curve3D or at least two valid RoutineStop children.")
	if not looped and stop_count() > 1:
		warnings.append("Non-looped PatrolPath stops at the final RoutineStop.")
	return warnings


func _update_editor_state() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		update_configuration_warnings()
		update_gizmos()


static func is_world_transform_within_contract(world_transform: Transform3D) -> bool:
	return RoutineStop.is_world_transform_within_contract(world_transform)


static func _is_finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)


static func _is_safe_world_position(value: Vector3) -> bool:
	return _is_finite_vector(value) and absf(value.x) <= 10000.0 and absf(value.y) <= 10000.0 and absf(value.z) <= 10000.0


func _is_safe_gizmo_local_position(local_position: Vector3) -> bool:
	return (
		_is_finite_vector(local_position)
		and local_position.length() <= MAX_LOCAL_POINT_DISTANCE
		and _is_safe_world_position(to_global(local_position))
	)
