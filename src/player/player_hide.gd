class_name PlayerHideRules
extends RefCounted


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
