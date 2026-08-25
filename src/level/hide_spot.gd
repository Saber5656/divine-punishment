@tool
class_name HideSpot
extends Area3D


const HideRules := preload("res://src/player/player_hide.gd")
const HIDE_SPOT_LAYER := 1 << 7
const HIDESPOT_LAYER := HIDE_SPOT_LAYER
const PLAYER_BODY_LAYER := 1 << 1
const ENEMY_BODY_LAYER := 1 << 2
const MIN_ENTRY_RADIUS := 0.1
const MAX_ENTRY_RADIUS := 2.0
const MAX_STORED_BODIES := 1
const MAX_STORAGE_OFFSET := 2.0
const UNIT_SCALE_TOLERANCE := 0.001
const ENTRY_COLLISION_SHAPE_NODE_NAME := &"_EntryInteractionShape"

var _entry_collision_shape: CollisionShape3D
var _expected_entry_shape: SphereShape3D
var _stored_body: Node3D

@export var storage_offset := Vector3.ZERO

@export_range(MIN_ENTRY_RADIUS, MAX_ENTRY_RADIUS, 0.05) var entry_radius := 0.75:
	set(value):
		entry_radius = value
		_sync_entry_collision_shape()
		_update_editor_state()


func _enter_tree() -> void:
	collision_layer = HIDE_SPOT_LAYER
	collision_mask = PLAYER_BODY_LAYER
	monitoring = true
	monitorable = true
	_ensure_entry_collision_shape()
	if not is_in_group(&"hide_spots"):
		add_to_group(&"hide_spots")
	_update_editor_state()


func _ensure_entry_collision_shape() -> void:
	if not is_instance_valid(_entry_collision_shape):
		_entry_collision_shape = get_node_or_null(
			NodePath(String(ENTRY_COLLISION_SHAPE_NODE_NAME)),
		) as CollisionShape3D
	if _entry_collision_shape == null:
		_entry_collision_shape = CollisionShape3D.new()
		_entry_collision_shape.name = ENTRY_COLLISION_SHAPE_NODE_NAME
		add_child(_entry_collision_shape, false, Node.INTERNAL_MODE_BACK)
	if _entry_collision_shape.shape is not SphereShape3D:
		_entry_collision_shape.shape = SphereShape3D.new()
	_expected_entry_shape = _entry_collision_shape.shape as SphereShape3D
	_sync_entry_collision_shape()


func _sync_entry_collision_shape() -> void:
	if not is_instance_valid(_entry_collision_shape):
		return
	var sphere := _entry_collision_shape.shape as SphereShape3D
	if sphere == null:
		return
	var safe_radius := entry_radius if is_finite(entry_radius) else MIN_ENTRY_RADIUS
	sphere.radius = clampf(safe_radius, MIN_ENTRY_RADIUS, MAX_ENTRY_RADIUS)
	_entry_collision_shape.position = Vector3.ZERO


func entry_world_position() -> Vector3:
	return global_position


func storage_world_position() -> Vector3:
	if not storage_offset.is_finite() or not global_position.is_finite():
		return Vector3(NAN, NAN, NAN)
	return global_position + global_transform.basis * storage_offset


func stored_body() -> Node3D:
	return _stored_body if has_stored_body() else null


func has_stored_body() -> bool:
	if (
		_stored_body == null
		or not is_instance_valid(_stored_body)
		or not _stored_body.is_inside_tree()
		or _stored_body.get_tree() != get_tree()
		or _stored_body.get_parent() != self
		or not _stored_body.has_method(&"is_stored")
		or not bool(_stored_body.call(&"is_stored"))
	):
		_stored_body = null
		return false
	return true


func entry_shape_identity() -> int:
	if not is_instance_valid(_expected_entry_shape):
		return 0
	return _expected_entry_shape.get_instance_id()


func is_geometry_valid() -> bool:
	return (
		is_inside_tree()
		and is_world_transform_within_contract(global_transform)
		and is_finite(entry_radius)
		and entry_radius >= MIN_ENTRY_RADIUS
		and entry_radius <= MAX_ENTRY_RADIUS
		and HideRules.is_safe_world_position(entry_world_position())
		and storage_offset.is_finite()
		and storage_offset.length() <= MAX_STORAGE_OFFSET
		and HideRules.is_safe_world_position(storage_world_position())
		and _is_entry_collision_shape_valid()
	)


func _is_entry_collision_shape_valid() -> bool:
	if not is_instance_valid(_entry_collision_shape):
		return false
	var sphere := _entry_collision_shape.shape as SphereShape3D
	return (
		sphere != null
		and _entry_collision_shape.get_parent() == self
		and _entry_collision_shape.is_inside_tree()
		and _entry_collision_shape.get_tree() == get_tree()
		and not _entry_collision_shape.disabled
		and _entry_collision_shape.shape == sphere
		and sphere == _expected_entry_shape
		and _entry_collision_shape.transform.is_equal_approx(Transform3D.IDENTITY)
		and is_finite(sphere.radius)
		and is_equal_approx(sphere.radius, entry_radius)
	)


static func is_world_transform_within_contract(world_transform: Transform3D) -> bool:
	if not HideRules.is_safe_world_position(world_transform.origin):
		return false
	var axes: Array[Vector3] = [world_transform.basis.x, world_transform.basis.y, world_transform.basis.z]
	for axis: Vector3 in axes:
		if not HideRules.is_finite_vector(axis) or absf(axis.length() - 1.0) > UNIT_SCALE_TOLERANCE:
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
		and collision_layer == HIDE_SPOT_LAYER
		and collision_mask == PLAYER_BODY_LAYER
		and (body.collision_layer & PLAYER_BODY_LAYER) != 0
		and (body.collision_layer & ENEMY_BODY_LAYER) == 0
		and (body.collision_layer & HIDE_SPOT_LAYER) == 0
	)


func can_store_body(body: Node3D) -> bool:
	return (
		body != null
		and is_instance_valid(body)
		and body.is_inside_tree()
		and body.get_tree() == get_tree()
		and is_geometry_valid()
		and not has_stored_body()
		and body.global_position.is_finite()
		and body.has_method(&"is_body_carryable")
		and body.has_method(&"is_being_carried")
		and body.has_method(&"begin_storage")
		and bool(body.call(&"is_being_carried"))
		and bool(body.call(&"is_body_carryable")) == false
	)


func store_body(body: Node3D) -> bool:
	if not can_store_body(body):
		return false
	if not bool(body.call(&"begin_storage", self)):
		return false
	if body.get_parent() != self or not bool(body.call(&"is_stored")):
		if body.has_method(&"end_storage"):
			body.call(&"end_storage")
		return false
	_stored_body = body
	return true


func can_retrieve_body(receiver: Node3D = null) -> bool:
	if not has_stored_body() or not is_geometry_valid():
		return false
	if receiver == null:
		return true
	return (
		is_instance_valid(receiver)
		and receiver.is_inside_tree()
		and receiver.get_tree() == get_tree()
		and receiver.global_position.is_finite()
		and is_near_entry(receiver.global_position)
	)


func retrieve_body(receiver: Node3D = null) -> Node3D:
	if not can_retrieve_body(receiver):
		return null
	var body := _stored_body
	if not body.has_method(&"end_storage") or not bool(body.call(&"end_storage", receiver)):
		# Keep the occupancy pointer only when the body really remains stored.
		# This covers a failed reparent/receiver transition without retaining a
		# stale HideSpot reference to an exposed body.
		if (
			not is_instance_valid(body)
			or body.get_parent() != self
			or not body.has_method(&"is_stored")
			or not bool(body.call(&"is_stored"))
		):
			_stored_body = null
		return null
	_stored_body = null
	return body


func is_near_entry(world_position: Vector3) -> bool:
	return (
		is_geometry_valid()
		and HideRules.is_safe_world_position(world_position)
		and entry_world_position().distance_squared_to(world_position)
			<= entry_radius * entry_radius
	)


func can_enter(body: CollisionObject3D, close_range_seen: bool = false) -> bool:
	return can_accept_body(body) and is_near_entry(body.global_position) and not close_range_seen


func gizmo_segments() -> PackedVector3Array:
	var segments := PackedVector3Array()
	if not is_geometry_valid():
		return segments
	var marker_size := minf(maxf(entry_radius * 0.5, 0.1), 0.35)
	for axis: Vector3 in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
		segments.append(-axis * marker_size)
		segments.append(axis * marker_size)
	return segments


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not is_geometry_valid():
		warnings.append(
			"HideSpot requires a finite %.2f–%.2f m entry radius and a unit-scale world transform."
			% [MIN_ENTRY_RADIUS, MAX_ENTRY_RADIUS],
		)
	return warnings


func _update_editor_state() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		update_configuration_warnings()
		update_gizmos()
