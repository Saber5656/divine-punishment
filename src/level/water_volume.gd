@tool
class_name WaterVolume
extends Area3D


const SwimRules := preload("res://src/player/player_swim.gd")
const WATER_LAYER := 1 << 12
const PLAYER_BODY_LAYER := 1 << 1
const ENEMY_BODY_LAYER := 1 << 2
const MIN_HORIZONTAL_SIZE := 0.5
const MIN_VERTICAL_SIZE := 3.0
const MAX_SIZE := 100.0
const MIN_SURFACE_BODY_DEPTH := 0.2
const MIN_DIVE_DISTANCE := 0.5
# Preserve the standing capsule's 0.9 m lower extent plus clearance for shape-query margin.
const MIN_BOTTOM_CLEARANCE := 0.91
const UNIT_SCALE_TOLERANCE := 0.001
const ALIGNMENT_TOLERANCE := 0.001
const VOLUME_SHAPE_NODE_NAME := &"_WaterVolumeShape"

var _collision_shape: CollisionShape3D
var _volume_box: BoxShape3D

@export var size := Vector3(8.0, 4.0, 8.0):
	set(value):
		size = value
		_sync_volume_shape()
		_update_editor_state()
@export_range(MIN_SURFACE_BODY_DEPTH, 2.0, 0.05) var surface_body_depth := 0.75:
	set(value):
		surface_body_depth = value
		_update_editor_state()
@export_range(0.7, MAX_SIZE, 0.05) var underwater_body_depth := 2.25:
	set(value):
		underwater_body_depth = value
		_update_editor_state()


func _enter_tree() -> void:
	collision_layer = WATER_LAYER
	collision_mask = PLAYER_BODY_LAYER
	monitoring = true
	monitorable = true
	_ensure_volume_shape()
	if not is_in_group(&"water_volumes"):
		add_to_group(&"water_volumes")
	_update_editor_state()


func _ensure_volume_shape() -> void:
	if not is_instance_valid(_collision_shape):
		_collision_shape = get_node_or_null(
			NodePath(String(VOLUME_SHAPE_NODE_NAME)),
		) as CollisionShape3D
	if _collision_shape == null:
		_collision_shape = CollisionShape3D.new()
		_collision_shape.name = VOLUME_SHAPE_NODE_NAME
		add_child(_collision_shape, false, Node.INTERNAL_MODE_BACK)
	if _collision_shape.shape is not BoxShape3D:
		_collision_shape.shape = BoxShape3D.new()
	_volume_box = _collision_shape.shape as BoxShape3D
	_sync_volume_shape()


func _sync_volume_shape() -> void:
	if not is_instance_valid(_volume_box):
		return
	_volume_box.size = _safe_shape_size(size)


func is_geometry_valid() -> bool:
	return (
		is_inside_tree()
		and is_world_transform_within_contract(global_transform)
		and _is_size_valid(size)
		and is_finite(surface_body_depth)
		and surface_body_depth >= MIN_SURFACE_BODY_DEPTH
		and surface_body_depth < size.y - MIN_BOTTOM_CLEARANCE
		and is_finite(underwater_body_depth)
		and underwater_body_depth >= surface_body_depth + MIN_DIVE_DISTANCE
		and underwater_body_depth <= size.y - MIN_BOTTOM_CLEARANCE
		and underwater_body_depth - surface_body_depth <= SwimRules.MAX_TRANSITION_DISTANCE
		and _are_operational_world_positions_valid()
		and _is_volume_shape_valid()
	)


func can_accept_body(body: CollisionObject3D) -> bool:
	return (
		body != null
		and is_instance_valid(body)
		and body.is_inside_tree()
		and body.get_tree() == get_tree()
		and is_geometry_valid()
		and collision_layer == WATER_LAYER
		and collision_mask == PLAYER_BODY_LAYER
		and body.collision_layer == PLAYER_BODY_LAYER
	)


func contains_world_position(world_position: Vector3) -> bool:
	if not is_geometry_valid() or not SwimRules.is_safe_world_position(world_position):
		return false
	var local_position := to_local(world_position)
	if not SwimRules.is_finite_vector(local_position):
		return false
	var half_size := size * 0.5
	return (
		absf(local_position.x) <= half_size.x
		and absf(local_position.y) <= half_size.y
		and absf(local_position.z) <= half_size.z
	)


func surface_world_y() -> float:
	if not is_geometry_valid():
		return NAN
	return to_global(Vector3.UP * size.y * 0.5).y


func surface_body_position_for(world_position: Vector3) -> Vector3:
	if not contains_world_position(world_position):
		return Vector3(INF, INF, INF)
	var result := world_position
	result.y = surface_world_y() - surface_body_depth
	return result if contains_world_position(result) else Vector3(INF, INF, INF)


func underwater_body_position_for(world_position: Vector3) -> Vector3:
	if not contains_world_position(world_position):
		return Vector3(INF, INF, INF)
	var result := world_position
	result.y = surface_world_y() - underwater_body_depth
	return result if contains_world_position(result) else Vector3(INF, INF, INF)


func can_enter_from_position(world_position: Vector3) -> bool:
	var destination := surface_body_position_for(world_position)
	return (
		SwimRules.is_safe_world_position(world_position)
		and SwimRules.is_safe_world_position(destination)
		and world_position.distance_squared_to(destination)
			<= SwimRules.MAX_TRANSITION_DISTANCE * SwimRules.MAX_TRANSITION_DISTANCE
	)


func _are_operational_world_positions_valid() -> bool:
	var half_size := size * 0.5
	for x_sign: float in [-1.0, 1.0]:
		for y_sign: float in [-1.0, 1.0]:
			for z_sign: float in [-1.0, 1.0]:
				var corner := global_transform * Vector3(
					half_size.x * x_sign,
					half_size.y * y_sign,
					half_size.z * z_sign,
				)
				if not SwimRules.is_safe_world_position(corner):
					return false
	var surface_center := global_transform * (Vector3.UP * half_size.y)
	var surface_body_position := surface_center - Vector3.UP * surface_body_depth
	var underwater_body_position := surface_center - Vector3.UP * underwater_body_depth
	return (
		SwimRules.is_safe_world_position(surface_body_position)
		and SwimRules.is_safe_world_position(underwater_body_position)
		and surface_body_position.distance_squared_to(underwater_body_position)
			<= SwimRules.MAX_TRANSITION_DISTANCE * SwimRules.MAX_TRANSITION_DISTANCE
	)


func _is_volume_shape_valid() -> bool:
	return (
		is_instance_valid(_collision_shape)
		and is_instance_valid(_volume_box)
		and _collision_shape.get_parent() == self
		and _collision_shape.is_inside_tree()
		and _collision_shape.get_tree() == get_tree()
		and not _collision_shape.disabled
		and _collision_shape.shape == _volume_box
		and _collision_shape.transform.is_equal_approx(Transform3D.IDENTITY)
		and _volume_box.size.is_equal_approx(size)
	)


static func is_world_transform_within_contract(world_transform: Transform3D) -> bool:
	if not SwimRules.is_safe_world_position(world_transform.origin):
		return false
	var axes: Array[Vector3] = [world_transform.basis.x, world_transform.basis.y, world_transform.basis.z]
	for axis: Vector3 in axes:
		if not SwimRules.is_finite_vector(axis) or absf(axis.length() - 1.0) > UNIT_SCALE_TOLERANCE:
			return false
	return (
		absf(axes[0].dot(axes[1])) <= UNIT_SCALE_TOLERANCE
		and absf(axes[0].dot(axes[2])) <= UNIT_SCALE_TOLERANCE
		and absf(axes[1].dot(axes[2])) <= UNIT_SCALE_TOLERANCE
		and absf(absf(world_transform.basis.determinant()) - 1.0) <= UNIT_SCALE_TOLERANCE
		and axes[1].dot(Vector3.UP) >= 1.0 - ALIGNMENT_TOLERANCE
		and absf(axes[0].y) <= ALIGNMENT_TOLERANCE
		and absf(axes[2].y) <= ALIGNMENT_TOLERANCE
	)


static func _is_size_valid(candidate: Vector3) -> bool:
	return (
		SwimRules.is_finite_vector(candidate)
		and candidate.x >= MIN_HORIZONTAL_SIZE
		and candidate.y >= MIN_VERTICAL_SIZE
		and candidate.z >= MIN_HORIZONTAL_SIZE
		and candidate.x <= MAX_SIZE
		and candidate.y <= MAX_SIZE
		and candidate.z <= MAX_SIZE
	)


static func _safe_shape_size(candidate: Vector3) -> Vector3:
	if not SwimRules.is_finite_vector(candidate):
		return Vector3(MIN_HORIZONTAL_SIZE, MIN_VERTICAL_SIZE, MIN_HORIZONTAL_SIZE)
	return Vector3(
		clampf(candidate.x, MIN_HORIZONTAL_SIZE, MAX_SIZE),
		clampf(candidate.y, MIN_VERTICAL_SIZE, MAX_SIZE),
		clampf(candidate.z, MIN_HORIZONTAL_SIZE, MAX_SIZE),
	)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not is_geometry_valid():
		warnings.append(
			"WaterVolume requires finite bounded dimensions, aligned unit scale, and valid surface/underwater body depths.",
		)
	return warnings


func _update_editor_state() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		update_configuration_warnings()
		update_gizmos()
