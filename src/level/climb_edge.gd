@tool
class_name ClimbEdge
extends Area3D


const CLIMB_MARKER_LAYER := 1 << 11
const PLAYER_BODY_LAYER := 1 << 1
const ENEMY_BODY_LAYER := 1 << 2
const MIN_SPAN := 0.5
const MAX_SPAN := 8.0
const MIN_VERTICAL_RISE := 0.25
const MIN_ENTRY_RADIUS := 0.1
const MAX_ENTRY_RADIUS := 2.0
const UNIT_SCALE_TOLERANCE := 0.001
const ENTRY_COLLISION_SHAPE_NODE_NAME := &"_EntryInteractionShape"

var _entry_collision_shape: CollisionShape3D

@export var top_offset := Vector3(0.0, 2.0, 0.0):
	set(value):
		top_offset = value
		_update_editor_state()
@export_range(MIN_ENTRY_RADIUS, MAX_ENTRY_RADIUS, 0.05) var entry_radius := 1.0:
	set(value):
		entry_radius = value
		_sync_entry_collision_shape()
		_update_editor_state()
@export_node_path("Area3D") var connected_beam_path: NodePath
@export_enum("Start", "End") var connected_beam_endpoint := 0


func _enter_tree() -> void:
	collision_layer = CLIMB_MARKER_LAYER
	collision_mask = PLAYER_BODY_LAYER
	monitoring = true
	monitorable = true
	_ensure_entry_collision_shape()
	if not is_in_group(&"climb_edges"):
		add_to_group(&"climb_edges")
	_update_editor_state()


func _ensure_entry_collision_shape() -> void:
	if not is_instance_valid(_entry_collision_shape):
		_entry_collision_shape = get_node_or_null(
			NodePath(String(ENTRY_COLLISION_SHAPE_NODE_NAME))
		) as CollisionShape3D
	if _entry_collision_shape == null:
		_entry_collision_shape = CollisionShape3D.new()
		_entry_collision_shape.name = ENTRY_COLLISION_SHAPE_NODE_NAME
		add_child(_entry_collision_shape, false, Node.INTERNAL_MODE_BACK)
	if _entry_collision_shape.shape is not SphereShape3D:
		_entry_collision_shape.shape = SphereShape3D.new()
	_sync_entry_collision_shape()


func _sync_entry_collision_shape() -> void:
	if not is_instance_valid(_entry_collision_shape):
		return
	var sphere := _entry_collision_shape.shape as SphereShape3D
	if sphere == null:
		return
	var safe_radius := entry_radius if is_finite(entry_radius) else MIN_ENTRY_RADIUS
	sphere.radius = clampf(safe_radius, MIN_ENTRY_RADIUS, MAX_ENTRY_RADIUS)


func bottom_world_position() -> Vector3:
	return global_position


func top_world_position() -> Vector3:
	return to_global(top_offset)


func span_length() -> float:
	var bottom := bottom_world_position()
	var top := top_world_position()
	if not PlayerClimbRules.is_finite_vector(bottom) or not PlayerClimbRules.is_finite_vector(top):
		return 0.0
	return bottom.distance_to(top)


func is_geometry_valid() -> bool:
	if not is_inside_tree():
		return false
	if not is_world_transform_within_contract(global_transform):
		return false
	if not PlayerClimbRules.is_finite_vector(top_offset):
		return false
	if not is_finite(entry_radius) or entry_radius < MIN_ENTRY_RADIUS or entry_radius > MAX_ENTRY_RADIUS:
		return false
	var bottom := bottom_world_position()
	var top := top_world_position()
	if not PlayerClimbRules.is_safe_world_position(bottom) or not PlayerClimbRules.is_safe_world_position(top):
		return false
	var span := bottom.distance_to(top)
	if not is_finite(span) or span < MIN_SPAN or span > MAX_SPAN:
		return false
	return top.y - bottom.y >= MIN_VERTICAL_RISE


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


func can_accept_body(body: CollisionObject3D) -> bool:
	return (
		body != null
		and is_instance_valid(body)
		and body.is_inside_tree()
		and body.get_tree() == get_tree()
		and is_geometry_valid()
		and collision_layer == CLIMB_MARKER_LAYER
		and collision_mask == PLAYER_BODY_LAYER
		and (body.collision_layer & PLAYER_BODY_LAYER) != 0
		and (body.collision_layer & ENEMY_BODY_LAYER) == 0
		and (body.collision_layer & CLIMB_MARKER_LAYER) == 0
	)


func is_near_bottom(world_position: Vector3) -> bool:
	if not is_geometry_valid() or not PlayerClimbRules.is_finite_vector(world_position):
		return false
	return bottom_world_position().distance_squared_to(world_position) <= entry_radius * entry_radius


func world_position_at_distance(distance: float) -> Vector3:
	if not is_geometry_valid():
		return bottom_world_position()
	var span := span_length()
	var bounded := PlayerClimbRules.bounded_distance(distance, span)
	return bottom_world_position().lerp(top_world_position(), bounded / span)


func nearest_distance(world_position: Vector3) -> float:
	if not is_geometry_valid() or not PlayerClimbRules.is_finite_vector(world_position):
		return 0.0
	var bottom := bottom_world_position()
	var segment := top_world_position() - bottom
	var span_squared := segment.length_squared()
	if span_squared <= PlayerClimbRules.EPSILON_SQUARED:
		return 0.0
	var ratio := clampf((world_position - bottom).dot(segment) / span_squared, 0.0, 1.0)
	return ratio * sqrt(span_squared)


func connected_beam() -> BeamPath:
	var connection := connected_beam_connection()
	return connection.get(&"path") as BeamPath if bool(connection.get(&"valid", false)) else null


func connected_beam_connection() -> Dictionary:
	if connected_beam_path.is_empty() or not has_node(connected_beam_path):
		return {&"valid": false}
	var candidate := get_node_or_null(connected_beam_path)
	if candidate is BeamPath:
		var beam := candidate as BeamPath
		if (
			not is_instance_valid(beam)
			or not beam.is_inside_tree()
			or beam.get_tree() != get_tree()
			or not beam.is_geometry_valid()
		):
			return {&"valid": false}
		var endpoint_distance := beam.path_length() if connected_beam_endpoint == 1 else 0.0
		var endpoint_sample := beam.world_sample_at_distance(endpoint_distance)
		if not bool(endpoint_sample.get(&"valid", false)):
			return {&"valid": false}
		var endpoint_position: Vector3 = endpoint_sample[&"position"]
		if (
			PlayerClimbRules.is_safe_world_position(endpoint_position)
			and top_world_position().distance_squared_to(endpoint_position) <= entry_radius * entry_radius
		):
			return {
				&"valid": true,
				&"path": beam,
				&"distance": endpoint_distance,
				&"position": endpoint_position,
			}
	return {&"valid": false}


func connected_beam_distance() -> float:
	var connection := connected_beam_connection()
	if not bool(connection.get(&"valid", false)):
		return 0.0
	return float(connection[&"distance"])


func connection_radius() -> float:
	return entry_radius if is_geometry_valid() else 0.0


func gizmo_segments() -> PackedVector3Array:
	var segments := PackedVector3Array()
	if not is_geometry_valid():
		return segments
	segments.append(Vector3.ZERO)
	segments.append(top_offset)
	var marker_size := minf(maxf(top_offset.length() * 0.08, 0.1), 0.35)
	for point: Vector3 in [Vector3.ZERO, top_offset]:
		segments.append(point - Vector3.RIGHT * marker_size)
		segments.append(point + Vector3.RIGHT * marker_size)
		segments.append(point - Vector3.FORWARD * marker_size)
		segments.append(point + Vector3.FORWARD * marker_size)
	return segments


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not is_geometry_valid():
		warnings.append(
			"ClimbEdge requires finite geometry, a %.2f–%.2f m span, at least %.2f m vertical rise, and a %.2f–%.2f m entry radius."
			% [MIN_SPAN, MAX_SPAN, MIN_VERTICAL_RISE, MIN_ENTRY_RADIUS, MAX_ENTRY_RADIUS]
		)
	var beam := connected_beam()
	if not connected_beam_path.is_empty() and beam == null:
		warnings.append("Connected BeamPath must resolve to a valid BeamPath node.")
	return warnings


func _update_editor_state() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		update_configuration_warnings()
		update_gizmos()
