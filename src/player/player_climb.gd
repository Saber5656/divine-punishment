class_name PlayerClimbRules
extends RefCounted


const EPSILON_SQUARED := 0.000001
const MAX_WORLD_COORDINATE := 10000.0


static func is_finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)


static func is_safe_world_position(value: Vector3) -> bool:
	return (
		is_finite_vector(value)
		and absf(value.x) <= MAX_WORLD_COORDINATE
		and absf(value.y) <= MAX_WORLD_COORDINATE
		and absf(value.z) <= MAX_WORLD_COORDINATE
	)


static func sanitize_axis(value: float) -> float:
	if not is_finite(value):
		return 0.0
	return clampf(value, -1.0, 1.0)


static func bounded_distance(value: float, maximum: float) -> float:
	if not is_finite(value) or not is_finite(maximum) or maximum <= 0.0:
		return 0.0
	return clampf(value, 0.0, maximum)


static func advance_distance(
	current: float,
	axis: float,
	speed: float,
	delta: float,
	maximum: float,
) -> float:
	if (
		not is_finite(current)
		or not is_finite(speed)
		or speed < 0.0
		or not is_finite(delta)
		or delta < 0.0
		or not is_finite(maximum)
		or maximum <= 0.0
	):
		return bounded_distance(current, maximum)
	return clampf(
		current + sanitize_axis(axis) * speed * delta,
		0.0,
		maximum,
	)


static func finite_direction(from: Vector3, to: Vector3) -> Vector3:
	if not is_finite_vector(from) or not is_finite_vector(to):
		return Vector3.ZERO
	var direction := to - from
	if direction.length_squared() <= EPSILON_SQUARED:
		return Vector3.ZERO
	return direction.normalized()
