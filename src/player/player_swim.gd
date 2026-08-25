class_name PlayerSwimRules
extends RefCounted


const MAX_WORLD_COORDINATE := 10000.0
const MIN_BREATH_SECONDS := 0.1
const MAX_BREATH_SECONDS := 300.0
const MIN_EXHAUSTION_NOISE_RADIUS := 0.1
const MAX_EXHAUSTION_NOISE_RADIUS := 100.0
const MIN_SWIM_SPEED := 0.0
const MAX_SWIM_SPEED := 20.0
const MAX_TRANSITION_DISTANCE := 8.0
const MAX_PHYSICS_DELTA := 1.0


static func is_finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)


static func is_safe_world_position(value: Vector3) -> bool:
	return (
		is_finite_vector(value)
		and absf(value.x) <= MAX_WORLD_COORDINATE
		and absf(value.y) <= MAX_WORLD_COORDINATE
		and absf(value.z) <= MAX_WORLD_COORDINATE
	)


static func is_breath_capacity_valid(seconds: float) -> bool:
	return (
		is_finite(seconds)
		and seconds >= MIN_BREATH_SECONDS
		and seconds <= MAX_BREATH_SECONDS
	)


static func consume_breath(remaining: float, delta: float, capacity: float) -> float:
	if (
		not is_breath_capacity_valid(capacity)
		or not is_finite(remaining)
		or not is_finite(delta)
		or delta < 0.0
	):
		return 0.0
	return clampf(remaining - delta, 0.0, capacity)


static func is_exhaustion_noise_radius_valid(radius: float) -> bool:
	return (
		is_finite(radius)
		and radius >= MIN_EXHAUSTION_NOISE_RADIUS
		and radius <= MAX_EXHAUSTION_NOISE_RADIUS
	)


static func is_swim_speed_valid(speed: float) -> bool:
	return is_finite(speed) and speed >= MIN_SWIM_SPEED and speed <= MAX_SWIM_SPEED


static func is_physics_delta_valid(delta: float) -> bool:
	return is_finite(delta) and delta >= 0.0 and delta <= MAX_PHYSICS_DELTA
