extends GutTest


const EnemyScene := preload("res://src/enemies/enemy_base.tscn")
const EnemyBrainScript := preload("res://src/enemies/enemy_brain.gd")
const PerceptionStimulusScript := preload("res://src/enemies/perception_stimulus.gd")
const AnomalyScript := preload("res://src/core/anomaly.gd")
const LightSourceScript := preload("res://src/stealth/light_source.gd")
const NoiseEventScript := preload("res://src/core/noise_event.gd")


func test_alert_state_transitions_follow_five_state_priority_table() -> void:
	var enemy := _spawn_enemy()
	var brain := enemy.get_node("Brain") as EnemyBrain

	brain.submit_stimulus(_stimulus(1, Vector3(2.0, 0.0, 0.0)))
	brain._physics_process(0.016)
	assert_eq(brain.alert_state(), Enums.AlertState.SUSPICIOUS)

	brain.submit_stimulus(_stimulus(2, Vector3(3.0, 0.0, 0.0)))
	brain._physics_process(0.016)
	assert_eq(brain.alert_state(), Enums.AlertState.SEARCHING)

	brain.submit_stimulus(_stimulus(4, Vector3(4.0, 0.0, 0.0)))
	brain._physics_process(0.016)
	assert_eq(brain.alert_state(), Enums.AlertState.COMBAT)

	brain._physics_process(EnemyBrain.COMBAT_LOST_SIGHT_DURATION)
	assert_eq(brain.alert_state(), Enums.AlertState.SEARCHING)
	brain._physics_process(EnemyBrain.SEARCH_DURATION)
	assert_eq(brain.alert_state(), Enums.AlertState.RETURN)
	assert_eq(brain.detection_multiplier(), 1.5)

	brain.submit_stimulus(_stimulus(1, Vector3(5.0, 0.0, 0.0)))
	brain._physics_process(0.016)
	assert_eq(brain.alert_state(), Enums.AlertState.SUSPICIOUS)


func test_same_frame_uses_highest_priority_then_nearest_stimulus() -> void:
	var enemy := _spawn_enemy()
	var brain := enemy.get_node("Brain") as EnemyBrain
	var far := _stimulus(1, Vector3(20.0, 0.0, 0.0))
	var near := _stimulus(1, Vector3(2.0, 0.0, 0.0))
	var high := _stimulus(3, Vector3(30.0, 0.0, 0.0))
	brain.submit_stimulus(far)
	brain.submit_stimulus(near)
	brain.submit_stimulus(high)
	brain._physics_process(0.016)

	assert_eq(brain.alert_state(), Enums.AlertState.SEARCHING)
	assert_eq(brain.last_known_position(), high.position)


func test_suspicious_investigates_sound_or_anomaly_then_returns() -> void:
	var enemy := _spawn_enemy()
	var brain := enemy.get_node("Brain") as EnemyBrain
	var target := Vector3(4.0, 0.0, -2.0)
	brain.submit_stimulus(_stimulus(1, target))
	brain._physics_process(0.016)
	assert_eq(brain.alert_state(), Enums.AlertState.SUSPICIOUS)
	assert_eq(brain.investigation_target(), target)

	brain._physics_process(EnemyBrain.INVESTIGATION_DURATION)
	assert_eq(brain.alert_state(), Enums.AlertState.SUSPICIOUS)
	brain.mark_investigation_arrived()
	brain._physics_process(EnemyBrain.INVESTIGATION_DURATION)
	assert_eq(brain.alert_state(), Enums.AlertState.RETURN)
	brain.mark_routine_arrived()
	brain._physics_process(EnemyBrain.RETURN_ARRIVAL_DURATION)
	assert_eq(brain.alert_state(), Enums.AlertState.UNAWARE)


func test_investigation_dwell_starts_only_after_navigation_arrival() -> void:
	var enemy := _spawn_enemy()
	var brain := enemy.get_node("Brain") as EnemyBrain
	var target := Vector3(20.0, 0.0, 0.0)
	brain.submit_stimulus(_stimulus(1, target))
	brain._physics_process(0.016)
	brain._physics_process(EnemyBrain.INVESTIGATION_DURATION + 1.0)
	assert_eq(brain.alert_state(), Enums.AlertState.SUSPICIOUS)

	brain.mark_investigation_arrived()
	brain._physics_process(EnemyBrain.INVESTIGATION_DURATION - 0.1)
	assert_eq(brain.alert_state(), Enums.AlertState.SUSPICIOUS)
	brain._physics_process(0.1)
	assert_eq(brain.alert_state(), Enums.AlertState.RETURN)


func test_extinguished_light_is_requested_and_relit_after_bounded_delay() -> void:
	var enemy := _spawn_enemy()
	var brain := enemy.get_node("Brain") as EnemyBrain
	var light := LightSourceScript.new() as LightSource
	light.position = Vector3(2.0, 0.0, 0.0)
	add_child_autofree(light)
	await get_tree().process_frame
	light.set_extinguished(true)
	assert_false(light.is_on())

	var anomaly := AnomalyScript.create(
		Enums.AnomalyKind.LIGHT_OUT,
		light.global_position,
		light,
		1,
	)
	var stimulus := PerceptionStimulusScript.create(
		Enums.StimulusKind.ANOMALY,
		1,
		anomaly.position,
		1.0,
		anomaly,
	)
	brain.submit_stimulus(stimulus)
	brain._physics_process(0.016)
	assert_eq(brain.alert_state(), Enums.AlertState.SUSPICIOUS)
	brain.mark_investigation_arrived()
	brain._physics_process(EnemyBrain.INVESTIGATION_DURATION)
	assert_eq(brain.alert_state(), Enums.AlertState.RETURN)
	assert_true(brain.relight_pending())
	brain._physics_process(EnemyBrain.RELIGHT_DELAY - EnemyBrain.INVESTIGATION_DURATION - 0.016 - 0.1)
	assert_false(light.is_on())
	brain._physics_process(0.1)
	assert_false(light.is_on())
	enemy.global_position = light.global_position
	brain.mark_routine_arrived()
	assert_true(light.is_on())
	assert_false(brain.relight_pending())


func test_return_vigilance_multiplier_expires_and_scales_perception_hook() -> void:
	var enemy := _spawn_enemy()
	var brain := enemy.get_node("Brain") as EnemyBrain
	_add_routine_target(enemy, Vector3(20.0, 0.0, 0.0))
	brain.force_state(Enums.AlertState.RETURN, &"test")
	assert_true(brain.residual_alert_active())
	assert_eq(brain.vigilance_multiplier(), 1.5)
	assert_almost_eq(brain.return_vigilance_remaining(), 120.0, 0.0001)

	brain._physics_process(EnemyBrain.DEFAULT_RETURN_VIGILANCE_DURATION - 0.1)
	assert_true(brain.residual_alert_active())
	assert_eq(brain.detection_multiplier(), 1.5)
	brain._physics_process(0.1)
	assert_false(brain.residual_alert_active())
	assert_eq(brain.detection_multiplier(), 1.0)


func test_return_waits_for_routine_navigation_arrival() -> void:
	var enemy := _spawn_enemy()
	var brain := enemy.get_node("Brain") as EnemyBrain
	_add_routine_target(enemy, Vector3(20.0, 0.0, 0.0))
	brain.force_state(Enums.AlertState.RETURN, &"test")
	brain._physics_process(EnemyBrain.RETURN_ARRIVAL_DURATION + 1.0)
	assert_eq(brain.alert_state(), Enums.AlertState.RETURN)

	brain.mark_routine_arrived()
	brain._physics_process(0.016)
	assert_eq(brain.alert_state(), Enums.AlertState.UNAWARE)


func test_incapacitation_stops_fsm_until_recovery() -> void:
	var enemy := _spawn_enemy()
	var brain := enemy.get_node("Brain") as EnemyBrain
	brain.set_incapacitated(&"sleep")
	brain.submit_stimulus(PerceptionStimulusScript.create(
		Enums.StimulusKind.VISUAL,
		4,
		Vector3.ONE,
		1.0,
	))
	brain._physics_process(10.0)
	assert_true(brain.is_incapacitated())
	assert_eq(brain.alert_state(), Enums.AlertState.UNAWARE)

	brain.set_incapacitated(&"")
	assert_false(brain.is_incapacitated())
	assert_eq(brain.alert_state(), Enums.AlertState.SEARCHING)


func test_timed_knockout_wakes_after_bounded_duration() -> void:
	var enemy := _spawn_enemy()
	var brain := enemy.get_node("Brain") as EnemyBrain
	brain.set_incapacitated(&"knockout", 20.0)
	brain._physics_process(19.9)
	assert_true(brain.is_incapacitated())
	assert_almost_eq(brain.incapacitation_remaining(), 0.1, 0.0001)
	brain._physics_process(0.1)
	assert_false(brain.is_incapacitated())
	assert_eq(brain.alert_state(), Enums.AlertState.SEARCHING)


func test_noise_wakes_knockout_and_is_queued_for_search() -> void:
	var enemy := _spawn_enemy()
	var brain := enemy.get_node("Brain") as EnemyBrain
	var source := Node.new()
	add_child_autofree(source)
	brain.set_incapacitated(&"knockout", 20.0)
	enemy.on_noise(NoiseEventScript.create(
		Vector3(0.0, 1.5, 0.0),
		6.0,
		Enums.NoiseKind.COMBAT,
		source,
	))
	assert_false(brain.is_incapacitated())
	brain._physics_process(0.016)
	assert_eq(brain.alert_state(), Enums.AlertState.SEARCHING)


func test_continuous_target_visibility_keeps_combat_until_lost() -> void:
	var enemy := _spawn_enemy()
	var brain := enemy.get_node("Brain") as EnemyBrain
	brain.force_state(Enums.AlertState.COMBAT, &"visible_target")
	for _index in 4:
		brain.set_target_visible(true)
		brain._physics_process(1.0)
	assert_eq(brain.alert_state(), Enums.AlertState.COMBAT)

	brain.set_target_visible(false)
	brain._physics_process(EnemyBrain.COMBAT_LOST_SIGHT_DURATION)
	assert_eq(brain.alert_state(), Enums.AlertState.SEARCHING)


func test_incapacitation_api_reports_validation_and_wake_results() -> void:
	var unstarted_brain := EnemyBrainScript.new() as EnemyBrain
	assert_false(unstarted_brain.set_incapacitated(&"sleep"))
	assert_false(unstarted_brain.set_incapacitated(&"sleep", -1.0))
	assert_false(unstarted_brain.set_incapacitated(&"sleep", INF))
	unstarted_brain.free()

	var enemy := _spawn_enemy()
	var brain := enemy.get_node("Brain") as EnemyBrain
	assert_false(enemy.set_incapacitated(&"unknown", 0.0))
	assert_false(enemy.set_incapacitated(&"sleep", -1.0))
	assert_false(enemy.set_incapacitated(&"sleep", NAN))
	assert_true(enemy.set_incapacitated(&"knockout", 20.0))
	assert_true(brain.is_incapacitated())
	assert_true(enemy.set_incapacitated(&""))
	assert_false(enemy.set_incapacitated(&""))


func _spawn_enemy() -> EnemyBase:
	var enemy := EnemyScene.instantiate() as EnemyBase
	add_child_autofree(enemy)
	return enemy


func _add_routine_target(enemy: EnemyBase, position: Vector3) -> Node3D:
	var target := Marker3D.new()
	target.name = "RoutineTarget"
	target.position = position
	enemy.add_child(target)
	return target


func _stimulus(priority: int, position: Vector3) -> PerceptionStimulus:
	return PerceptionStimulusScript.create(
		Enums.StimulusKind.NOISE,
		priority,
		position,
		1.0,
	)
