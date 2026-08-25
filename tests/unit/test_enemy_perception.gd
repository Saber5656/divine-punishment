extends GutTest


const EnemyScene := preload("res://src/enemies/enemy_base.tscn")
const EnemyPerceptionScript := preload("res://src/enemies/enemy_perception.gd")
const PerceptionFormulasScript := preload("res://src/core/perception_formulas.gd")
const PerceptionStimulusScript := preload("res://src/enemies/perception_stimulus.gd")
const NoiseEventScript := preload("res://src/core/noise_event.gd")


func test_component_matches_10_hz_lod_and_raycast_contract() -> void:
	assert_eq(EnemyPerceptionScript.UPDATE_INTERVAL, 0.1)
	assert_eq(EnemyPerceptionScript.LOD_UPDATE_INTERVAL, 0.5)
	assert_eq(EnemyPerceptionScript.LOD_DISTANCE, 30.0)
	assert_eq(EnemyPerceptionScript.MAX_DETECTION_POINTS, 3)
	assert_eq(EnemyPerceptionScript.MAX_RAYCASTS_PER_UPDATE, 3)
	assert_eq(EnemyPerceptionScript.VISION_OCCLUSION_MASK, (1 << 0) | (1 << 4))


func test_vision_gain_uses_shared_accumulation_formula() -> void:
	var expected := PerceptionFormulasScript.vision_gain(1.0, 5.0, 15.0, true, 2.0)
	assert_almost_eq(EnemyPerceptionScript.vision_gain(1.0, 5.0, 15.0, true, 2.0), expected, 0.0001)
	assert_eq(EnemyPerceptionScript.vision_gain(1.0, 15.0, 15.0, true, 2.0), 0.0)
	assert_eq(EnemyPerceptionScript.vision_gain(NAN, 0.0, 15.0, true, 2.0), 0.0)


func test_perception_stimulus_clamps_confidence_and_keeps_anomaly_optional() -> void:
	var visual := PerceptionStimulusScript.create(
		Enums.StimulusKind.VISUAL,
		1,
		Vector3.ONE,
		2.0,
	)
	assert_eq(visual.kind, Enums.StimulusKind.VISUAL)
	assert_eq(visual.priority, 1)
	assert_eq(visual.position, Vector3.ONE)
	assert_eq(visual.confidence, 1.0)
	assert_null(visual.anomaly)


func test_perception_stimulus_normalizes_non_finite_position_and_confidence() -> void:
	var invalid := PerceptionStimulusScript.create(
		Enums.StimulusKind.VISUAL,
		1,
		Vector3(NAN, 0.0, INF),
		INF,
	)
	assert_eq(invalid.position, Vector3.ZERO)
	assert_eq(invalid.confidence, 0.0)


func test_enemy_scene_contains_perception_eye_and_fsm_sink() -> void:
	var enemy := EnemyScene.instantiate()
	add_child_autofree(enemy)
	assert_not_null(enemy.get_node("Brain") as EnemyBrain)
	var perception := enemy.get_node("Perception") as EnemyPerception
	assert_not_null(perception)
	assert_eq(perception.perception_config.view_distance_m, 15.0)
	assert_not_null(enemy.get_node("Perception/EyePoint") as Node3D)
	assert_true(enemy.is_in_group("enemies"))
	var assassination_shape := enemy.get_node("AssassinateTarget/CollisionShape3D") as CollisionShape3D
	assert_not_null(assassination_shape)
	assert_true(assassination_shape.shape is SphereShape3D)


func test_noise_is_forwarded_to_brain_without_raw_event_bus_subscription() -> void:
	var enemy := EnemyScene.instantiate() as EnemyBase
	add_child_autofree(enemy)
	var source := Node.new()
	add_child_autofree(source)
	enemy.on_noise(NoiseEventScript.create(Vector3(0.0, 1.5, 0.0), 6.0, Enums.NoiseKind.TOOL, source))
	var brain := enemy.get_node("Brain") as EnemyBrain
	var stimuli := brain.drain_stimuli()
	assert_eq(stimuli.size(), 1)
	assert_eq(stimuli[0].kind, Enums.StimulusKind.NOISE)
	assert_eq(stimuli[0].priority, 1)
	assert_gt(stimuli[0].confidence, 0.0)


func test_firework_noise_is_masking_only() -> void:
	var enemy := EnemyScene.instantiate() as EnemyBase
	add_child_autofree(enemy)
	var source := Node.new()
	add_child_autofree(source)
	enemy.on_noise(NoiseEventScript.create(Vector3(0.0, 1.5, 0.0), 6.0, Enums.NoiseKind.FIREWORK, source))
	assert_eq((enemy.get_node("Brain") as EnemyBrain).drain_stimuli().size(), 0)


func test_ancestor_owned_noise_is_not_treated_as_enemy_self_noise() -> void:
	var container := Node3D.new()
	var enemy := EnemyScene.instantiate() as EnemyBase
	container.add_child(enemy)
	add_child_autofree(container)
	await get_tree().process_frame
	enemy.on_noise(NoiseEventScript.create(
		Vector3(0.0, 1.5, 0.0), 6.0, Enums.NoiseKind.TOOL, container,
	))
	assert_eq((enemy.get_node("Brain") as EnemyBrain).drain_stimuli().size(), 1)


func test_malformed_perception_resource_fails_closed() -> void:
	var enemy := EnemyScene.instantiate() as EnemyBase
	add_child_autofree(enemy)
	var perception := enemy.get_node("Perception") as EnemyPerception
	var invalid := PerceptionConfig.new()
	invalid.view_distance_m = 0.0
	perception.set_perception_config(invalid)
	perception.on_noise(NoiseEventScript.create(Vector3.ZERO, 6.0, Enums.NoiseKind.TOOL, Node.new()))
	assert_eq(perception.meter(), 0.0)
	assert_eq((enemy.get_node("Brain") as EnemyBrain).drain_stimuli().size(), 0)
