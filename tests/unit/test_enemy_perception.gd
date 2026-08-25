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
	assert_eq(perception.perception_config.resource_path, "res://data/tuning/perception_ashigaru.tres")
	assert_not_null(enemy.get_node("Perception/EyePoint") as Node3D)
	assert_true(enemy.is_in_group("enemies"))
	var assassination_shape := enemy.get_node("AssassinateTarget/CollisionShape3D") as CollisionShape3D
	assert_not_null(assassination_shape)
	assert_true(assassination_shape.shape is SphereShape3D)


func test_default_perception_uses_tuning_and_refreshes() -> void:
	var perception := EnemyPerceptionScript.new() as EnemyPerception
	add_child_autofree(perception)
	var tuning := get_node("/root/Tuning") as TuningService
	var original := tuning._perceptions[&"ashigaru"] as PerceptionConfig
	assert_eq(perception.perception_config, original)
	assert_true(tuning.is_connected(&"reloaded", Callable(perception, &"_refresh_tuning")))

	var replacement := PerceptionConfig.new()
	replacement.view_distance_m = 42.0
	tuning._perceptions[&"ashigaru"] = replacement
	tuning.reloaded.emit()
	assert_eq(perception.perception_config, replacement)
	tuning._perceptions[&"ashigaru"] = original
	tuning.reloaded.emit()


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
	invalid.fov_degrees = NAN
	perception.on_anomaly(Anomaly.create(
		Enums.AnomalyKind.CORPSE,
		Vector3(0.0, 1.5, -3.0),
		null,
		3,
	))
	assert_eq((enemy.get_node("Brain") as EnemyBrain).drain_stimuli().size(), 0)


func test_anomaly_perception_requires_fov_line_of_sight_and_occlusion_clearance() -> void:
	var enemy := EnemyScene.instantiate() as EnemyBase
	add_child_autofree(enemy)
	var perception := enemy.get_node("Perception") as EnemyPerception
	var visible_node := Node3D.new()
	visible_node.position = Vector3(0.0, 1.5, -3.0)
	add_child_autofree(visible_node)
	var visible_anomaly := Anomaly.create(
		Enums.AnomalyKind.CORPSE,
		visible_node.global_position,
		visible_node,
		3,
	)
	perception.on_anomaly(visible_anomaly)
	assert_eq((enemy.get_node("Brain") as EnemyBrain).pending_stimulus_count(), 1)
	(enemy.get_node("Brain") as EnemyBrain).drain_stimuli()

	var side_node := Node3D.new()
	side_node.position = Vector3(3.0, 1.5, 0.0)
	add_child_autofree(side_node)
	perception.on_anomaly(Anomaly.create(
		Enums.AnomalyKind.CORPSE,
		side_node.global_position,
		side_node,
		3,
	))
	assert_eq((enemy.get_node("Brain") as EnemyBrain).pending_stimulus_count(), 0)

	var blocker := _add_occluder(Vector3(0.0, 1.5, -1.5))
	await get_tree().physics_frame
	perception.on_anomaly(Anomaly.create(
		Enums.AnomalyKind.CORPSE,
		visible_node.global_position,
		visible_node,
		3,
	))
	assert_eq((enemy.get_node("Brain") as EnemyBrain).pending_stimulus_count(), 0)
	blocker.queue_free()


func test_anomaly_event_subscription_is_single_and_removed_on_teardown() -> void:
	var enemy := EnemyScene.instantiate() as EnemyBase
	add_child_autofree(enemy)
	var perception := enemy.get_node("Perception") as EnemyPerception
	var callback := Callable(perception, &"_on_anomaly_registered")
	assert_true(EventBus.anomaly_registered.is_connected(callback))

	var node := Node3D.new()
	node.position = Vector3(0.0, 1.5, -3.0)
	add_child_autofree(node)
	EventBus.anomaly_registered.emit(Anomaly.create(
		Enums.AnomalyKind.CORPSE,
		node.global_position,
		node,
		3,
	))
	assert_eq((enemy.get_node("Brain") as EnemyBrain).pending_stimulus_count(), 1)

	enemy.queue_free()
	await get_tree().process_frame
	assert_false(EventBus.anomaly_registered.is_connected(callback))


func _add_occluder(at: Vector3) -> StaticBody3D:
	var blocker := StaticBody3D.new()
	blocker.collision_layer = 1
	blocker.collision_mask = 0
	blocker.position = at
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.6, 2.0, 0.6)
	collision.shape = shape
	blocker.add_child(collision)
	add_child_autofree(blocker)
	return blocker
