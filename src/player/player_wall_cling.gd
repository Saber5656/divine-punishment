class_name PlayerWallCling
extends RefCounted


const NORMAL_EPSILON_SQUARED := 0.000001
const MAX_VERTICAL_NORMAL_COMPONENT := 0.35


static func normalized_wall_normal(candidate: Vector3) -> Vector3:
	if not _is_finite_vector(candidate) or candidate.length_squared() <= NORMAL_EPSILON_SQUARED:
		return Vector3.ZERO

	var normalized := candidate.normalized()
	if absf(normalized.y) > MAX_VERTICAL_NORMAL_COMPONENT:
		return Vector3.ZERO

	var horizontal := Vector3(normalized.x, 0.0, normalized.z)
	if horizontal.length_squared() <= NORMAL_EPSILON_SQUARED:
		return Vector3.ZERO
	return horizontal.normalized()


static func wall_tangent(wall_normal: Vector3) -> Vector3:
	var normalized := normalized_wall_normal(wall_normal)
	if normalized == Vector3.ZERO:
		return Vector3.ZERO
	return Vector3.UP.cross(normalized).normalized()


static func project_movement(input_direction: Vector3, wall_normal: Vector3) -> Vector3:
	if not _is_finite_vector(input_direction):
		return Vector3.ZERO
	var normalized := normalized_wall_normal(wall_normal)
	if normalized == Vector3.ZERO:
		return Vector3.ZERO

	var horizontal_input := Vector3(input_direction.x, 0.0, input_direction.z)
	if horizontal_input.length_squared() <= NORMAL_EPSILON_SQUARED:
		return Vector3.ZERO

	var projected := horizontal_input - normalized * horizontal_input.dot(normalized)
	if projected.length_squared() <= NORMAL_EPSILON_SQUARED:
		return Vector3.ZERO

	var maximum_length := minf(horizontal_input.length(), 1.0)
	if projected.length() > maximum_length:
		projected = projected.normalized() * maximum_length
	return projected


static func sanitize_axis(value: float) -> float:
	if not is_finite(value):
		return 0.0
	return clampf(value, -1.0, 1.0)


static func _is_finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
