class_name PerceptionFormulas
extends RefCounted


const OCCLUDED_RADIUS_MULTIPLIER := 0.5
const SOUND_OCCLUSION_MULTIPLIER := OCCLUDED_RADIUS_MULTIPLIER
const PERIPHERAL_VISION_MULTIPLIER := 0.4
const DEFAULT_MAX_METER := 3.0


static func light_contribution(dist: float, gameplay_radius: float, occluded: bool) -> float:
	if (
		occluded
		or not is_finite(dist)
		or not is_finite(gameplay_radius)
		or gameplay_radius <= 0.0
	):
		return 0.0
	var bounded_distance := maxf(dist, 0.0)
	return clampf(1.0 - bounded_distance / gameplay_radius, 0.0, 1.0)


static func light_attenuation(dist: float, gameplay_radius: float, occluded: bool) -> float:
	return light_contribution(dist, gameplay_radius, occluded)


static func combine(light_sum: float, stance_mod: float, move_mod: float, cover_mod: float) -> float:
	if (
		not is_finite(light_sum)
		or not is_finite(stance_mod)
		or not is_finite(move_mod)
		or not is_finite(cover_mod)
	):
		return 0.0
	return clampf(light_sum * stance_mod * move_mod * cover_mod, 0.0, 1.0)


static func combine_visibility(
	light_sum: float,
	stance_mod: float,
	move_mod: float,
	cover_mod: float,
) -> float:
	return combine(light_sum, stance_mod, move_mod, cover_mod)


static func effective_sound_radius(base_radius: float, occlusion_count: int) -> float:
	if not is_finite(base_radius) or base_radius <= 0.0:
		return 0.0
	var bounded_count := maxi(occlusion_count, 0)
	var effective_radius := base_radius * pow(OCCLUDED_RADIUS_MULTIPLIER, float(bounded_count))
	if not is_finite(effective_radius):
		return 0.0
	return clampf(effective_radius, 0.0, base_radius)


static func sound_contribution(dist: float, base_radius: float, occlusion_count: int) -> float:
	if not is_finite(dist):
		return 0.0
	var radius := effective_sound_radius(base_radius, occlusion_count)
	if radius <= 0.0:
		return 0.0
	var bounded_distance := maxf(dist, 0.0)
	return clampf(1.0 - bounded_distance / radius, 0.0, 1.0)


static func sound_attenuation(dist: float, base_radius: float, occlusion_count: int) -> float:
	return sound_contribution(dist, base_radius, occlusion_count)


static func vision_gain(
	v: float,
	dist: float,
	view_distance: float,
	central: bool,
	base_gain: float,
) -> float:
	if (
		not is_finite(v)
		or not is_finite(dist)
		or not is_finite(view_distance)
		or not is_finite(base_gain)
		or view_distance <= 0.0
		or base_gain < 0.0
	):
		return 0.0
	var bounded_visibility := clampf(v, 0.0, 1.0)
	var bounded_distance := maxf(dist, 0.0)
	var distance_factor := clampf(1.0 - bounded_distance / view_distance, 0.0, 1.0)
	var peripheral_factor := 1.0 if central else PERIPHERAL_VISION_MULTIPLIER
	var gain := base_gain * bounded_visibility * distance_factor * distance_factor * peripheral_factor
	return gain if is_finite(gain) else 0.0


static func meter_step(
	current_meter: float,
	delta: float,
	gain: float,
	decay: float,
	visible: bool,
	maximum: float = DEFAULT_MAX_METER,
) -> float:
	if (
		not is_finite(current_meter)
		or not is_finite(delta)
		or not is_finite(gain)
		or not is_finite(decay)
		or not is_finite(maximum)
		or delta < 0.0
		or gain < 0.0
		or decay < 0.0
		or maximum < 0.0
	):
		return 0.0
	var bounded_current := clampf(current_meter, 0.0, maximum)
	var rate := gain if visible else -decay
	var next_meter := bounded_current + rate * delta
	if not is_finite(next_meter):
		return maximum if visible else 0.0
	return clampf(next_meter, 0.0, maximum)


static func accumulate_detection_meter(
	current_meter: float,
	delta: float,
	gain: float,
	decay: float,
	visible: bool,
	maximum: float = DEFAULT_MAX_METER,
) -> float:
	return meter_step(current_meter, delta, gain, decay, visible, maximum)


static func accumulate_meter(
	current_meter: float,
	gain: float,
	delta: float,
	visible: bool,
	decay: float,
	maximum: float = DEFAULT_MAX_METER,
) -> float:
	return meter_step(current_meter, delta, gain, decay, visible, maximum)
