extends GutTest


const NoiseEventScript := preload("res://src/core/noise_event.gd")
const NoiseEmitterScript := preload("res://src/stealth/noise_emitter.gd")
const MovementConfigScript := preload("res://src/core/tuning/movement_config.gd")


func test_noise_event_has_typed_payload() -> void:
	var source := Node.new()
	var event: NoiseEvent = NoiseEventScript.create(Vector3.ONE, 6.0, Enums.NoiseKind.TOOL, source)
	assert_eq(event.position, Vector3.ONE)
	assert_eq(event.radius, 6.0)
	assert_eq(event.kind, Enums.NoiseKind.TOOL)
	assert_eq(event.source, source)
	source.free()


func test_footstep_radius_uses_stance_and_material_multiplier() -> void:
	var config := MovementConfigScript.new()
	assert_eq(NoiseEmitterScript.footstep_radius(Enums.Stance.SNEAK, &"tatami", config), 0.5)
	assert_eq(NoiseEmitterScript.footstep_radius(Enums.Stance.SPRINT, &"gravel", config), 18.0)
	config.free()


func test_occluded_noise_radius_is_halved() -> void:
	assert_eq(NoiseEventSystem.OCCLUDED_RADIUS_MULTIPLIER, 0.5)
	assert_eq(NoiseEventSystem.HEARING_OCCLUSION_MASK, 1 << 5)
