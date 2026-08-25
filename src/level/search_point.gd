@tool
class_name SearchPoint
extends Marker3D


## Authored point used by an enemy SEARCHING route.
##
## SearchPoint is intentionally a data-only Marker3D.  EnemyBrain owns route
## selection and movement; this node owns only the bounded authoring contract
## that level designers can inspect in the editor.

const MIN_CONFIDENCE := 0.0
const MAX_CONFIDENCE := 1.0
const MAX_SEARCH_ORDER := 63
const MAX_GIZMO_SIZE := 0.9
const UNIT_SCALE_TOLERANCE := 0.001

@export_range(MIN_CONFIDENCE, MAX_CONFIDENCE, 0.01) var confidence := 0.5:
	set(value):
		confidence = clampf(value, MIN_CONFIDENCE, MAX_CONFIDENCE) if is_finite(value) else MIN_CONFIDENCE
		_update_editor_state()
@export_range(0, MAX_SEARCH_ORDER, 1) var search_order := 0:
	set(value):
		search_order = clampi(value, 0, MAX_SEARCH_ORDER)
		_update_editor_state()
@export var area_id: StringName = &"":
	set(value):
		area_id = value
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
	if not is_in_group(&"search_points"):
		add_to_group(&"search_points")
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
		and is_finite(confidence)
		and confidence >= MIN_CONFIDENCE
		and confidence <= MAX_CONFIDENCE
		and search_order >= 0
		and search_order <= MAX_SEARCH_ORDER
		and _is_finite_vector(facing_direction)
	)


func is_searchable() -> bool:
	return enabled and is_geometry_valid()


func target_position() -> Vector3:
	return global_position if _is_finite_vector(global_position) else Vector3.ZERO


func world_facing_direction() -> Vector3:
	if not _is_finite_vector(facing_direction) or facing_direction.length_squared() <= 0.000001:
		return -global_transform.basis.z
	var direction := global_transform.basis * facing_direction
	return direction.normalized() if _is_finite_vector(direction) and direction.length_squared() > 0.000001 else Vector3.FORWARD


func gizmo_segments() -> PackedVector3Array:
	if not is_geometry_valid():
		return PackedVector3Array()
	var segments := PackedVector3Array()
	var size := clampf(0.25 + confidence * 0.65, 0.25, MAX_GIZMO_SIZE)
	for axis: Vector3 in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
		segments.append(-axis * size)
		segments.append(axis * size)
	var local_direction := facing_direction
	if _is_finite_vector(local_direction) and local_direction.length_squared() > 0.000001:
		local_direction = local_direction.normalized()
		segments.append(Vector3.ZERO)
		segments.append(local_direction * minf(size * 1.75, MAX_GIZMO_SIZE))
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
		warnings.append("SearchPoint requires a finite transform, confidence in [0, 1], and a non-zero facing direction.")
	return warnings


func _update_editor_state() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		update_configuration_warnings()
		update_gizmos()


static func _is_finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)


static func _is_safe_world_position(value: Vector3) -> bool:
	return _is_finite_vector(value) and absf(value.x) <= 10000.0 and absf(value.y) <= 10000.0 and absf(value.z) <= 10000.0
