@tool
class_name CrawlEntrance
extends Area3D


const CrawlRules := preload("res://src/player/player_crawl.gd")
const CRAWL_MARKER_LAYER := 1 << 11
const PLAYER_BODY_LAYER := 1 << 1
const ENEMY_BODY_LAYER := 1 << 2
const MIN_PASSAGE_LENGTH := 0.5
const MAX_PASSAGE_LENGTH := 4.0
const MIN_ENTRY_RADIUS := 0.1
const MAX_ENTRY_RADIUS := 1.5
const UNIT_SCALE_TOLERANCE := 0.001
const OUTSIDE_COLLISION_SHAPE_NODE_NAME := &"_OutsideInteractionShape"
const INSIDE_COLLISION_SHAPE_NODE_NAME := &"_InsideInteractionShape"

var _outside_collision_shape: CollisionShape3D
var _inside_collision_shape: CollisionShape3D
var _outside_interaction_sphere: SphereShape3D
var _inside_interaction_sphere: SphereShape3D

@export var inside_offset := Vector3(0.0, 0.0, -1.0):
	set(value):
		inside_offset = value
		_sync_interaction_shapes()
		_update_editor_state()
@export_range(MIN_ENTRY_RADIUS, MAX_ENTRY_RADIUS, 0.05) var entry_radius := 0.75:
	set(value):
		entry_radius = value
		_sync_interaction_shapes()
		_update_editor_state()


func _enter_tree() -> void:
	collision_layer = CRAWL_MARKER_LAYER
	collision_mask = PLAYER_BODY_LAYER
	monitoring = true
	monitorable = true
	_ensure_interaction_shapes()
	if not is_in_group(&"crawl_entrances"):
		add_to_group(&"crawl_entrances")
	_update_editor_state()


func _ensure_interaction_shapes() -> void:
	_outside_collision_shape = _resolved_or_new_shape(
		_outside_collision_shape,
		OUTSIDE_COLLISION_SHAPE_NODE_NAME,
	)
	_inside_collision_shape = _resolved_or_new_shape(
		_inside_collision_shape,
		INSIDE_COLLISION_SHAPE_NODE_NAME,
	)
	_outside_interaction_sphere = _outside_collision_shape.shape as SphereShape3D
	_inside_interaction_sphere = _inside_collision_shape.shape as SphereShape3D
	_sync_interaction_shapes()


func _resolved_or_new_shape(
	current: Variant,
	node_name: StringName,
) -> CollisionShape3D:
	var resolved_shape: CollisionShape3D
	if is_instance_valid(current) and current is CollisionShape3D:
		resolved_shape = current as CollisionShape3D
	else:
		resolved_shape = get_node_or_null(NodePath(String(node_name))) as CollisionShape3D
	if resolved_shape == null:
		resolved_shape = CollisionShape3D.new()
		resolved_shape.name = node_name
		add_child(resolved_shape, false, Node.INTERNAL_MODE_BACK)
	if resolved_shape.shape is not SphereShape3D:
		resolved_shape.shape = SphereShape3D.new()
	return resolved_shape


func _sync_interaction_shapes() -> void:
	if not is_instance_valid(_outside_collision_shape) or not is_instance_valid(_inside_collision_shape):
		return
	var safe_radius := entry_radius if is_finite(entry_radius) else MIN_ENTRY_RADIUS
	safe_radius = clampf(safe_radius, MIN_ENTRY_RADIUS, MAX_ENTRY_RADIUS)
	for interaction_shape: CollisionShape3D in [_outside_collision_shape, _inside_collision_shape]:
		var sphere := interaction_shape.shape as SphereShape3D
		if sphere != null:
			sphere.radius = safe_radius
	_outside_collision_shape.position = Vector3.ZERO
	_inside_collision_shape.position = inside_offset if CrawlRules.is_finite_vector(inside_offset) else Vector3.ZERO


func outside_world_position() -> Vector3:
	return global_position


func inside_world_position() -> Vector3:
	return to_global(inside_offset)


func passage_length() -> float:
	if not CrawlRules.is_finite_vector(inside_offset):
		return 0.0
	return inside_offset.length()


func is_geometry_valid() -> bool:
	if not is_inside_tree() or not is_world_transform_within_contract(global_transform):
		return false
	if not CrawlRules.is_finite_vector(inside_offset):
		return false
	if not is_finite(entry_radius) or entry_radius < MIN_ENTRY_RADIUS or entry_radius > MAX_ENTRY_RADIUS:
		return false
	var length := passage_length()
	if not is_finite(length) or length < MIN_PASSAGE_LENGTH or length > MAX_PASSAGE_LENGTH:
		return false
	if not _are_interaction_shapes_valid():
		return false
	return (
		CrawlRules.is_safe_world_position(outside_world_position())
		and CrawlRules.is_safe_world_position(inside_world_position())
	)


func _are_interaction_shapes_valid() -> bool:
	return (
		_is_interaction_shape_valid(
			_outside_collision_shape,
			_outside_interaction_sphere,
			Vector3.ZERO,
		)
		and _is_interaction_shape_valid(
			_inside_collision_shape,
			_inside_interaction_sphere,
			inside_offset,
		)
	)


func _is_interaction_shape_valid(
	interaction_shape: Variant,
	expected_sphere: Variant,
	expected_position: Vector3,
) -> bool:
	if (
		not is_instance_valid(interaction_shape)
		or not is_instance_valid(expected_sphere)
		or interaction_shape is not CollisionShape3D
		or expected_sphere is not SphereShape3D
	):
		return false
	var collision_shape := interaction_shape as CollisionShape3D
	var sphere := expected_sphere as SphereShape3D
	if (
		collision_shape.get_parent() != self
		or not collision_shape.is_inside_tree()
		or collision_shape.get_tree() != get_tree()
		or collision_shape.disabled
		or collision_shape.shape != sphere
	):
		return false
	return (
		collision_shape.transform.is_equal_approx(
			Transform3D(Basis.IDENTITY, expected_position),
		)
		and is_finite(sphere.radius)
		and is_equal_approx(sphere.radius, entry_radius)
	)


static func is_world_transform_within_contract(world_transform: Transform3D) -> bool:
	if not CrawlRules.is_safe_world_position(world_transform.origin):
		return false
	var axes: Array[Vector3] = [world_transform.basis.x, world_transform.basis.y, world_transform.basis.z]
	for axis: Vector3 in axes:
		if not CrawlRules.is_finite_vector(axis) or absf(axis.length() - 1.0) > UNIT_SCALE_TOLERANCE:
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
		and collision_layer == CRAWL_MARKER_LAYER
		and collision_mask == PLAYER_BODY_LAYER
		and (body.collision_layer & PLAYER_BODY_LAYER) != 0
		and (body.collision_layer & ENEMY_BODY_LAYER) == 0
		and (body.collision_layer & CRAWL_MARKER_LAYER) == 0
	)


func is_near_outside(world_position: Vector3) -> bool:
	return _is_near_endpoint(world_position, outside_world_position())


func is_near_inside(world_position: Vector3) -> bool:
	return _is_near_endpoint(world_position, inside_world_position())


func _is_near_endpoint(world_position: Vector3, endpoint: Vector3) -> bool:
	if not is_geometry_valid() or not CrawlRules.is_finite_vector(world_position):
		return false
	return endpoint.distance_squared_to(world_position) <= entry_radius * entry_radius


func gizmo_segments() -> PackedVector3Array:
	var segments := PackedVector3Array()
	if not is_geometry_valid():
		return segments
	segments.append(Vector3.ZERO)
	segments.append(inside_offset)
	var marker_size := minf(maxf(passage_length() * 0.12, 0.1), 0.35)
	for point: Vector3 in [Vector3.ZERO, inside_offset]:
		segments.append(point - Vector3.RIGHT * marker_size)
		segments.append(point + Vector3.RIGHT * marker_size)
		segments.append(point - Vector3.UP * marker_size)
		segments.append(point + Vector3.UP * marker_size)
	return segments


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not is_geometry_valid():
		warnings.append(
			"CrawlEntrance requires a finite %.2f–%.2f m outside-to-inside offset, a %.2f–%.2f m interaction radius, and a unit-scale world transform."
			% [MIN_PASSAGE_LENGTH, MAX_PASSAGE_LENGTH, MIN_ENTRY_RADIUS, MAX_ENTRY_RADIUS]
		)
	return warnings


func _update_editor_state() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		update_configuration_warnings()
		update_gizmos()
