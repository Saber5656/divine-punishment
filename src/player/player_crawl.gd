class_name PlayerCrawlRules
extends RefCounted


const MAX_WORLD_COORDINATE := 10000.0
const EPSILON_SQUARED := 0.000001


static func is_finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)


static func is_safe_world_position(value: Vector3) -> bool:
	return (
		is_finite_vector(value)
		and absf(value.x) <= MAX_WORLD_COORDINATE
		and absf(value.y) <= MAX_WORLD_COORDINATE
		and absf(value.z) <= MAX_WORLD_COORDINATE
	)


static func is_capsule_height_valid(height: float, radius: float, standing_height: float) -> bool:
	return (
		is_finite(height)
		and is_finite(radius)
		and is_finite(standing_height)
		and radius > 0.0
		and standing_height >= radius * 2.0
		and height >= radius * 2.0
		and height <= standing_height
	)


static func bounded_posture_drop(requested_drop: float, maximum_drop: float) -> float:
	if not is_finite(requested_drop) or not is_finite(maximum_drop) or maximum_drop < 0.0:
		return 0.0
	return clampf(requested_drop, 0.0, maximum_drop)
