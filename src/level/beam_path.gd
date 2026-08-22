@tool
class_name BeamPath
extends Area3D


const CLIMB_MARKER_LAYER := 1 << 11
const PLAYER_BODY_LAYER := 1 << 1
const ENEMY_BODY_LAYER := 1 << 2
const MIN_POINT_COUNT := 2
const MAX_POINT_COUNT := 64
const MIN_PATH_LENGTH := 0.5
const MAX_PATH_LENGTH := 100.0
const MIN_BAKE_INTERVAL := 0.1
const MAX_BAKE_INTERVAL := 1.0
const MAX_LOCAL_POINT_DISTANCE := 100.0
const MAX_GEOMETRY_VALIDATION_POINTS := MAX_POINT_COUNT
const MAX_GEOMETRY_VALIDATION_SAMPLES := 4
const MAX_RUNTIME_POSITION_SAMPLES := 1
const MAX_BAKE_EVALUATIONS := 1
const MAX_CONTROL_POLYGON_LENGTH := 400.0
const MAX_BAKE_WORK_SEGMENTS := 4000
const MAX_NAVIGATION_ANCESTORS := 64
const MAX_NAVIGATION_DESCENDANTS := 128
const UNIT_SCALE_TOLERANCE := 0.001
const MAX_GIZMO_SEGMENTS := 128
const TANGENT_SAMPLE_DISTANCE := 0.1

var _path_curve := Curve3D.new()
var _geometry_cache_valid := false
var _geometry_cache_result := false
var _geometry_cache_length := 0.0
var _geometry_cache_world_transform := Transform3D.IDENTITY
var _last_geometry_validation_samples := 0
var _last_runtime_position_samples := 0
var _runtime_position_sample_total := 0
var _last_bake_evaluations := 0
var _last_control_polygon_length := 0.0
var _navigation_cache_valid := false
var _navigation_cache_result := false

@export var path_curve: Curve3D:
	get:
		return _path_curve
	set(value):
		_disconnect_curve()
		_path_curve = value if value != null else Curve3D.new()
		_invalidate_geometry_cache()
		_connect_curve()
		_update_editor_state()
@export_node_path("Area3D") var start_climb_edge: NodePath
@export_node_path("Area3D") var end_climb_edge: NodePath


func _enter_tree() -> void:
	_invalidate_geometry_cache()
	_invalidate_navigation_cache()
	set_notify_transform(true)
	collision_layer = CLIMB_MARKER_LAYER
	collision_mask = PLAYER_BODY_LAYER
	monitoring = true
	monitorable = true
	if not is_in_group(&"beam_paths"):
		add_to_group(&"beam_paths")
	_connect_curve()
	_connect_tree_signals()
	_update_editor_state()


func _exit_tree() -> void:
	_invalidate_geometry_cache()
	_invalidate_navigation_cache()
	_disconnect_tree_signals()
	_disconnect_curve()
	set_notify_transform(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_invalidate_geometry_cache()
	elif what == NOTIFICATION_PARENTED or what == NOTIFICATION_UNPARENTED:
		_invalidate_navigation_cache()


func path_length() -> float:
	if not is_inside_tree() or not is_geometry_valid():
		return 0.0
	return _geometry_cache_length


func is_geometry_valid() -> bool:
	if not is_inside_tree():
		return false
	var current_world_transform := global_transform
	if (
		_geometry_cache_valid
		and current_world_transform.is_equal_approx(_geometry_cache_world_transform)
	):
		return _geometry_cache_result
	_invalidate_geometry_cache()
	_geometry_cache_valid = true
	_geometry_cache_result = false
	_geometry_cache_length = 0.0
	_geometry_cache_world_transform = current_world_transform
	_last_geometry_validation_samples = 0
	_last_bake_evaluations = 0
	_last_control_polygon_length = 0.0
	if _path_curve == null or not is_world_transform_within_contract(current_world_transform):
		return false
	if _path_curve.point_count < MIN_POINT_COUNT or _path_curve.point_count > MAX_POINT_COUNT:
		return false
	if (
		not is_finite(_path_curve.bake_interval)
		or _path_curve.bake_interval < MIN_BAKE_INTERVAL
		or _path_curve.bake_interval > MAX_BAKE_INTERVAL
	):
		return false
	var has_nonzero_geometry := false
	var first_point := _path_curve.get_point_position(0)
	var previous_point := Vector3.ZERO
	var previous_out := Vector3.ZERO
	for index: int in mini(_path_curve.point_count, MAX_GEOMETRY_VALIDATION_POINTS):
		var point := _path_curve.get_point_position(index)
		var point_in := _path_curve.get_point_in(index)
		var point_out := _path_curve.get_point_out(index)
		if (
			not is_local_control_value_valid(point)
			or not is_local_control_value_valid(point_in)
			or not is_local_control_value_valid(point_out)
		):
			return false
		for world_control_point: Vector3 in [point, point + point_in, point + point_out]:
			if not PlayerClimbRules.is_safe_world_position(current_world_transform * world_control_point):
				return false
		if index > 0:
			var previous_control := previous_point + previous_out
			var current_control := point + point_in
			_last_control_polygon_length += (
				previous_point.distance_to(previous_control)
				+ previous_control.distance_to(current_control)
				+ current_control.distance_to(point)
			)
			if (
				not is_finite(_last_control_polygon_length)
				or _last_control_polygon_length > MAX_CONTROL_POLYGON_LENGTH
				or ceili(_last_control_polygon_length / _path_curve.bake_interval) > MAX_BAKE_WORK_SEGMENTS
			):
				return false
		if (
			point.distance_squared_to(first_point) > PlayerClimbRules.EPSILON_SQUARED
			or point_in.length_squared() > PlayerClimbRules.EPSILON_SQUARED
			or point_out.length_squared() > PlayerClimbRules.EPSILON_SQUARED
		):
			has_nonzero_geometry = true
		previous_point = point
		previous_out = point_out
	if not has_nonzero_geometry:
		return false
	if _last_bake_evaluations >= MAX_BAKE_EVALUATIONS:
		return false
	_last_bake_evaluations += 1
	_geometry_cache_length = _path_curve.get_baked_length()
	var length := _geometry_cache_length
	if not is_finite(length) or length < MIN_PATH_LENGTH or length > MAX_PATH_LENGTH:
		return false
	_geometry_cache_result = _validated_tangent_at_distance(0.0) != Vector3.ZERO
	_geometry_cache_result = (
		_geometry_cache_result
		and _validated_tangent_at_distance(length) != Vector3.ZERO
		and _last_geometry_validation_samples <= MAX_GEOMETRY_VALIDATION_SAMPLES
	)
	return _geometry_cache_result


func can_accept_body(body: CollisionObject3D) -> bool:
	return (
		body != null
		and is_instance_valid(body)
		and body.is_inside_tree()
		and body.get_tree() == get_tree()
		and is_geometry_valid()
		and is_enemy_navigation_safe()
		and collision_layer == CLIMB_MARKER_LAYER
		and collision_mask == PLAYER_BODY_LAYER
		and (body.collision_layer & PLAYER_BODY_LAYER) != 0
		and (body.collision_layer & ENEMY_BODY_LAYER) == 0
		and (body.collision_layer & CLIMB_MARKER_LAYER) == 0
	)


func world_position_at_distance(distance: float) -> Vector3:
	var sample := world_sample_at_distance(distance)
	return sample[&"position"] if bool(sample.get(&"valid", false)) else Vector3.ZERO


func world_sample_at_distance(distance: float) -> Dictionary:
	_last_runtime_position_samples = 0
	if not is_geometry_valid() or _last_runtime_position_samples >= MAX_RUNTIME_POSITION_SAMPLES:
		return {&"valid": false}
	var bounded := PlayerClimbRules.bounded_distance(distance, path_length())
	_last_runtime_position_samples += 1
	_runtime_position_sample_total += 1
	var local_position := _path_curve.sample_baked(bounded, true)
	if not PlayerClimbRules.is_finite_vector(local_position):
		return {&"valid": false}
	var world_position := to_global(local_position)
	if not PlayerClimbRules.is_safe_world_position(world_position):
		return {&"valid": false}
	return {&"valid": true, &"position": world_position}


func nearest_distance(world_position: Vector3) -> float:
	if not is_geometry_valid() or not PlayerClimbRules.is_safe_world_position(world_position):
		return 0.0
	var local_position := to_local(world_position)
	if not PlayerClimbRules.is_finite_vector(local_position):
		return 0.0
	return PlayerClimbRules.bounded_distance(
		_path_curve.get_closest_offset(local_position),
		path_length(),
	)


func tangent_at_distance(distance: float) -> Vector3:
	if _path_curve == null or _path_curve.point_count < MIN_POINT_COUNT:
		return Vector3.ZERO
	var length := path_length()
	if length <= 0.0:
		return Vector3.ZERO
	var bounded := PlayerClimbRules.bounded_distance(distance, length)
	var half_step := minf(TANGENT_SAMPLE_DISTANCE, length * 0.5)
	var from_offset := maxf(0.0, bounded - half_step)
	var to_offset := minf(length, bounded + half_step)
	if is_equal_approx(from_offset, to_offset):
		return Vector3.ZERO
	var from_position := _path_curve.sample_baked(from_offset, true)
	var to_position := _path_curve.sample_baked(to_offset, true)
	var local_direction := PlayerClimbRules.finite_direction(from_position, to_position)
	if local_direction == Vector3.ZERO:
		return Vector3.ZERO
	var world_direction := global_transform.basis * local_direction
	return PlayerClimbRules.finite_direction(Vector3.ZERO, world_direction)


func last_geometry_validation_sample_count() -> int:
	return _last_geometry_validation_samples


func last_runtime_position_sample_count() -> int:
	return _last_runtime_position_samples


func runtime_position_sample_total() -> int:
	return _runtime_position_sample_total


func last_bake_evaluation_count() -> int:
	return _last_bake_evaluations


func last_control_polygon_length() -> float:
	return _last_control_polygon_length


static func is_local_control_value_valid(value: Vector3) -> bool:
	return PlayerClimbRules.is_finite_vector(value) and value.length() <= MAX_LOCAL_POINT_DISTANCE


static func is_world_transform_within_contract(world_transform: Transform3D) -> bool:
	if not PlayerClimbRules.is_safe_world_position(world_transform.origin):
		return false
	var axes: Array[Vector3] = [world_transform.basis.x, world_transform.basis.y, world_transform.basis.z]
	for axis: Vector3 in axes:
		if (
			not PlayerClimbRules.is_finite_vector(axis)
			or absf(axis.length() - 1.0) > UNIT_SCALE_TOLERANCE
		):
			return false
	return (
		absf(axes[0].dot(axes[1])) <= UNIT_SCALE_TOLERANCE
		and absf(axes[0].dot(axes[2])) <= UNIT_SCALE_TOLERANCE
		and absf(axes[1].dot(axes[2])) <= UNIT_SCALE_TOLERANCE
		and absf(absf(world_transform.basis.determinant()) - 1.0) <= UNIT_SCALE_TOLERANCE
	)


func connected_climb_at_start() -> ClimbEdge:
	return _resolved_climb_edge(start_climb_edge, 0.0)


func connected_climb_at_end() -> ClimbEdge:
	return _resolved_climb_edge(end_climb_edge, path_length())


func descent_edge_for_distance(distance: float) -> ClimbEdge:
	var length := path_length()
	if not is_geometry_valid() or length <= 0.0:
		return null
	var bounded := PlayerClimbRules.bounded_distance(distance, length)
	if bounded <= endpoint_interaction_distance():
		return connected_climb_at_start()
	if length - bounded <= endpoint_interaction_distance():
		return connected_climb_at_end()
	return null


func endpoint_interaction_distance() -> float:
	return minf(maxf(_path_curve.bake_interval, MIN_BAKE_INTERVAL), 0.5)


func is_enemy_navigation_safe() -> bool:
	if _navigation_cache_valid:
		return _navigation_cache_result
	_navigation_cache_valid = true
	_navigation_cache_result = false
	if not is_inside_tree():
		return false
	var current := get_parent()
	var ancestor_count := 0
	while current != null:
		ancestor_count += 1
		if ancestor_count > MAX_NAVIGATION_ANCESTORS:
			return false
		if current is NavigationRegion3D or current is NavigationLink3D:
			return false
		current = current.get_parent()
	var pending: Array[Node] = [self]
	var descendant_count := 0
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		for child: Node in node.get_children():
			descendant_count += 1
			if descendant_count > MAX_NAVIGATION_DESCENDANTS:
				return false
			if child is NavigationRegion3D or child is NavigationLink3D:
				return false
			pending.append(child)
	_navigation_cache_result = true
	return true


func gizmo_segments() -> PackedVector3Array:
	var segments := PackedVector3Array()
	if not is_geometry_valid():
		return segments
	var length := path_length()
	var segment_count := mini(
		MAX_GIZMO_SEGMENTS,
		maxi(1, ceili(length / _path_curve.bake_interval)),
	)
	for index: int in segment_count:
		var from_offset := length * float(index) / float(segment_count)
		var to_offset := length * float(index + 1) / float(segment_count)
		segments.append(_path_curve.sample_baked(from_offset, true))
		segments.append(_path_curve.sample_baked(to_offset, true))
	return segments


func _resolved_climb_edge(path: NodePath, endpoint_distance: float) -> ClimbEdge:
	if path.is_empty() or not has_node(path):
		return null
	var candidate := get_node_or_null(path)
	if candidate is ClimbEdge:
		var edge := candidate as ClimbEdge
		if (
			not is_instance_valid(edge)
			or not edge.is_inside_tree()
			or edge.get_tree() != get_tree()
			or not edge.is_geometry_valid()
		):
			return null
		var endpoint_position := world_position_at_distance(endpoint_distance)
		var edge_top := edge.top_world_position()
		var connection_radius := edge.connection_radius()
		if (
			PlayerClimbRules.is_finite_vector(endpoint_position)
			and PlayerClimbRules.is_finite_vector(edge_top)
			and connection_radius > 0.0
			and endpoint_position.distance_squared_to(edge_top) <= connection_radius * connection_radius
		):
			return edge
	return null


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not is_geometry_valid():
		warnings.append(
			"BeamPath requires %d–%d finite points, %.2f–%.2f m total length, %.2f–%.2f m bake interval, and nonzero endpoint tangents."
			% [MIN_POINT_COUNT, MAX_POINT_COUNT, MIN_PATH_LENGTH, MAX_PATH_LENGTH, MIN_BAKE_INTERVAL, MAX_BAKE_INTERVAL]
		)
	if not is_enemy_navigation_safe():
		warnings.append("BeamPath must remain outside NavigationRegion3D and must not contain NavigationLink3D nodes.")
	if not start_climb_edge.is_empty() and connected_climb_at_start() == null:
		warnings.append("Start climb edge must resolve to a valid ClimbEdge node.")
	if not end_climb_edge.is_empty() and connected_climb_at_end() == null:
		warnings.append("End climb edge must resolve to a valid ClimbEdge node.")
	return warnings


func _connect_curve() -> void:
	if _path_curve != null and not _path_curve.changed.is_connected(_on_curve_changed):
		_path_curve.changed.connect(_on_curve_changed)


func _disconnect_curve() -> void:
	if _path_curve != null and _path_curve.changed.is_connected(_on_curve_changed):
		_path_curve.changed.disconnect(_on_curve_changed)


func _on_curve_changed() -> void:
	_invalidate_geometry_cache()
	_update_editor_state()


func _validated_tangent_at_distance(distance: float) -> Vector3:
	var length := _geometry_cache_length
	if length <= 0.0:
		return Vector3.ZERO
	var bounded := PlayerClimbRules.bounded_distance(distance, length)
	var half_step := minf(TANGENT_SAMPLE_DISTANCE, length * 0.5)
	var from_position: Variant = _validation_sample(maxf(0.0, bounded - half_step))
	var to_position: Variant = _validation_sample(minf(length, bounded + half_step))
	if from_position is not Vector3 or to_position is not Vector3:
		return Vector3.ZERO
	var local_direction := PlayerClimbRules.finite_direction(from_position, to_position)
	if local_direction == Vector3.ZERO:
		return Vector3.ZERO
	return PlayerClimbRules.finite_direction(Vector3.ZERO, global_transform.basis * local_direction)


func _validation_sample(offset: float) -> Variant:
	if _last_geometry_validation_samples >= MAX_GEOMETRY_VALIDATION_SAMPLES:
		return null
	_last_geometry_validation_samples += 1
	var sample := _path_curve.sample_baked(offset, true)
	return sample if PlayerClimbRules.is_finite_vector(sample) else null


func _invalidate_geometry_cache() -> void:
	_geometry_cache_valid = false
	_geometry_cache_result = false
	_geometry_cache_length = 0.0


func _invalidate_navigation_cache() -> void:
	_navigation_cache_valid = false
	_navigation_cache_result = false


func _connect_tree_signals() -> void:
	var tree := get_tree()
	if tree == null:
		return
	if not tree.node_added.is_connected(_on_tree_node_changed):
		tree.node_added.connect(_on_tree_node_changed)
	if not tree.node_removed.is_connected(_on_tree_node_changed):
		tree.node_removed.connect(_on_tree_node_changed)


func _disconnect_tree_signals() -> void:
	var tree := get_tree()
	if tree == null:
		return
	if tree.node_added.is_connected(_on_tree_node_changed):
		tree.node_added.disconnect(_on_tree_node_changed)
	if tree.node_removed.is_connected(_on_tree_node_changed):
		tree.node_removed.disconnect(_on_tree_node_changed)


func _on_tree_node_changed(_node: Node) -> void:
	_invalidate_navigation_cache()


func _update_editor_state() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		update_configuration_warnings()
		update_gizmos()
