class_name NoiseEmitter
extends Node


@export var floor_material: StringName = &"wood"


func emit_footstep(stance: Enums.Stance, material: StringName = floor_material) -> NoiseEvent:
	var config := Tuning.movement()
	var radius := 0.0
	if config != null:
		radius = footstep_radius(stance, material, config)
	return emit_noise(radius, Enums.NoiseKind.FOOTSTEP)


func emit_landing() -> NoiseEvent:
	var config := Tuning.movement()
	var radius := float(config.noise_radii.get(&"walk", 4.0)) if config != null else 4.0
	return emit_noise(radius, Enums.NoiseKind.LANDING)


func emit_door(_opening: bool) -> NoiseEvent:
	var config := Tuning.movement()
	var radius := float(config.noise_radii.get(&"walk", 4.0)) if config != null else 4.0
	return emit_noise(radius, Enums.NoiseKind.DOOR)


func emit_noise(radius: float, kind: Enums.NoiseKind) -> NoiseEvent:
	var source_node := get_parent() as Node3D
	var source_position := source_node.global_position if source_node != null else Vector3.ZERO
	var event := NoiseEvent.create(source_position, maxf(radius, 0.0), kind, self)
	return NoiseEventSystem.emit(event, get_tree())


static func floor_material_for(collider: Object, fallback: StringName = &"wood") -> StringName:
	if collider == null:
		return fallback
	var metadata: Variant = collider.get_meta(&"floor_material", fallback)
	if metadata is StringName:
		return metadata
	if metadata is String:
		return StringName(metadata)
	var property_value: Variant = collider.get(&"floor_material")
	if property_value is StringName:
		return property_value
	if property_value is String:
		return StringName(property_value)
	return fallback


static func footstep_radius(stance: Enums.Stance, material: StringName, config: MovementConfig) -> float:
	if config == null:
		return 0.0
	var tuning_key: StringName = PlayerProfile.TUNING_KEYS_BY_STANCE.get(stance, &"walk")
	return float(config.noise_radii.get(tuning_key, 0.0)) * float(config.material_noise_multipliers.get(material, 1.0))
