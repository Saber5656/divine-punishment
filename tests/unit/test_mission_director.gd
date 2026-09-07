extends GutTest


const MissionDirectorScript := preload("res://src/autoload/mission_director.gd")


func test_mission_director_contract_uses_mission_resource_types() -> void:
	var definition := MissionDefinition.new()
	var objective := ObjectiveData.new()
	definition.objectives = [objective]

	var director := MissionDirectorScript.new()
	director.start_mission(definition)
	var current: ObjectiveData = director.current_objective()
	var stats: MissionStats = director.stats()
	var result: MissionResult = director.build_result()

	assert_eq(current, objective)
	assert_true(stats is MissionStats)
	assert_true(result is MissionResult)
	director.free()


func test_missions_without_par_time_do_not_earn_swift_points() -> void:
	var stats := MissionStats.new()
	var definition := MissionDefinition.new()
	var config := ScoringConfig.new()
	var result: MissionResult = MissionDirectorScript.compute_score(stats, config, definition)

	assert_false(result.flags[&"swift"])
	assert_eq(result.score, config.shadow_walker_points + config.no_traces_points + config.one_strike_points)


func test_corpse_anomaly_updates_bodies_found_once_and_alerts_area() -> void:
	var director := MissionDirectorScript.new()
	add_child_autofree(director)
	director.start_mission(MissionDefinition.new())
	var callback := Callable(director, &"_on_anomaly_spotted")
	assert_true(EventBus.anomaly_spotted.is_connected(callback))

	var corpse := Node3D.new()
	add_child_autofree(corpse)
	var anomaly := Anomaly.create(
		Enums.AnomalyKind.CORPSE,
		corpse.global_position,
		corpse,
		3,
	)
	var original_alert := GameState.area_alert_level
	GameState.area_alert_level = 0
	director._on_anomaly_spotted(anomaly, corpse)
	director._on_anomaly_spotted(anomaly, corpse)
	assert_eq(director.stats().bodies_found, 1)
	assert_eq(GameState.area_alert_level, 1)
	GameState.area_alert_level = original_alert

	director.queue_free()
	await get_tree().process_frame
	assert_false(EventBus.anomaly_spotted.is_connected(callback))


var _events: Array[StringName] = []
var _payloads: Array[Dictionary] = []


func before_each() -> void:
	MissionDirector.start_mission(null)
	MissionDirector.set_process(false)
	_events.clear()
	_payloads.clear()
	EventBus.mission_event.connect(_capture_event)


func after_each() -> void:
	EventBus.mission_event.disconnect(_capture_event)
	MissionDirector.start_mission(null)
	MissionDirector.set_process(true)


func test_objectives_advance_in_order_and_finish_once() -> void:
	var definition := _mission()
	MissionDirector.start_mission(definition)
	assert_eq(_events, [EventBus.EV_OBJECTIVE_CHANGED])
	assert_eq(_payloads[0]["id"], &"kill_target")
	assert_false(MissionDirector.stats().one_strike, "A target has not been assassinated yet")
	MissionDirector.complete_objective(&"escape")
	MissionDirector.complete_objective(&"unknown")
	MissionDirector.complete_objective(&"")
	assert_eq(MissionDirector.current_objective().id, &"kill_target")

	MissionDirector.complete_objective(&"kill_target")
	assert_eq(MissionDirector.current_objective().id, &"escape")
	assert_eq(_events.count(EventBus.EV_ESCAPE_OPENED), 1)
	MissionDirector.complete_objective(&"kill_target")
	assert_eq(_events.count(EventBus.EV_OBJECTIVE_COMPLETED), 1)
	MissionDirector.complete_objective(&"escape")
	assert_null(MissionDirector.current_objective())
	assert_true(MissionDirector.build_result().flags[&"completed"])
	assert_eq(_payloads.back()["id"], &"")
	MissionDirector.complete_objective(&"escape")
	assert_eq(_events.count(EventBus.EV_OBJECTIVE_COMPLETED), 2)


func test_real_target_assassination_opens_escape_and_scores_perfect_result() -> void:
	MissionDirector.start_mission(_mission())
	var target := _target()
	assert_true(target.begin_assassination(&"back"))
	assert_eq(MissionDirector.current_objective().id, &"escape")
	assert_true(MissionDirector.stats().one_strike)
	assert_eq(MissionDirector.stats().nontarget_kills, 0)
	assert_eq(_events.count(EventBus.EV_OBJECTIVE_COMPLETED), 1)
	assert_eq(_events.count(EventBus.EV_ESCAPE_OPENED), 1)
	EventBus.enemy_killed.emit(target, "combat")
	assert_true(MissionDirector.stats().one_strike, "Duplicate kill must not overwrite the original method")
	MissionDirector.complete_objective(&"escape")
	var result: MissionResult = MissionDirector.build_result()
	var config: ScoringConfig = Tuning.scoring()
	assert_eq(result.score, config.shadow_walker_points + config.no_traces_points + config.one_strike_points + config.swift_points)
	assert_eq(result.rank, &"kaiden")


func test_real_target_combat_death_completes_objective_without_one_strike() -> void:
	MissionDirector.start_mission(_mission())
	var target := _target()
	var source := Node3D.new()
	add_child_autofree(source)
	assert_gt(target.receive_combat_damage(target.max_health(), source), 0)
	assert_eq(MissionDirector.current_objective().id, &"escape")
	assert_false(MissionDirector.stats().one_strike)
	assert_eq(MissionDirector.stats().nontarget_kills, 0)
	assert_eq(MissionDirector.stats().detections, 1)
	assert_eq(_events.count(EventBus.EV_OBJECTIVE_COMPLETED), 1)


func test_target_group_filters_and_multiple_target_methods_do_not_restore_one_strike() -> void:
	var definition := _mission()
	definition.objectives[0].target_group = &"first_target"
	definition.objectives.insert(1, _objective(&"second", &"KILL_TARGET", &"second_target"))
	MissionDirector.start_mission(definition)
	var unrelated := _target()
	EventBus.mission_event.emit(EventBus.EV_TARGET_KILLED, { "target": unrelated, "method": &"assassination" })
	assert_eq(MissionDirector.current_objective().id, &"kill_target")
	var first := _target()
	first.add_to_group(&"first_target")
	assert_true(first.set_incapacitated(&"dead"))
	assert_eq(MissionDirector.current_objective().id, &"second")
	var second := _target()
	second.add_to_group(&"second_target")
	assert_true(second.begin_assassination(&"back"))
	assert_eq(MissionDirector.current_objective().id, &"escape")
	assert_false(MissionDirector.stats().one_strike)


func test_real_guard_kill_counts_once_as_nontarget_and_leaves_primary_objective() -> void:
	MissionDirector.start_mission(_mission())
	var guard := preload("res://src/enemies/enemy_base.tscn").instantiate() as EnemyBase
	add_child_autofree(guard)
	assert_true(guard.begin_assassination(&"back"))
	EventBus.enemy_killed.emit(guard, "assassination")
	assert_eq(MissionDirector.stats().nontarget_kills, 1)
	assert_false(MissionDirector.stats().one_strike)
	assert_eq(MissionDirector.current_objective().id, &"kill_target")


func test_real_brain_combat_entry_increments_detection_once_per_transition() -> void:
	MissionDirector.start_mission(_mission())
	var guard := preload("res://src/enemies/enemy_base.tscn").instantiate() as EnemyBase
	add_child_autofree(guard)
	guard.brain().force_state(Enums.AlertState.COMBAT, &"test")
	assert_eq(MissionDirector.stats().detections, 1)
	guard.brain().force_state(Enums.AlertState.COMBAT, &"same_state")
	assert_eq(MissionDirector.stats().detections, 1)
	guard.brain().force_state(Enums.AlertState.SEARCHING, &"lost")
	guard.brain().force_state(Enums.AlertState.COMBAT, &"reacquired")
	assert_eq(MissionDirector.stats().detections, 2)


func test_civilian_and_knockout_events_are_deduplicated() -> void:
	MissionDirector.start_mission(_mission())
	var civilian := Node.new()
	add_child_autofree(civilian)
	civilian.add_to_group(&"civilians")
	EventBus.civilian_killed.emit(civilian)
	EventBus.enemy_killed.emit(civilian, "combat")
	EventBus.civilian_killed.emit(civilian)
	assert_eq(MissionDirector.stats().civilian_kills, 1)
	assert_eq(MissionDirector.stats().nontarget_kills, 0)
	var enemy := Node.new()
	add_child_autofree(enemy)
	EventBus.enemy_neutralized.emit(enemy, "dart_sleep")
	assert_eq(MissionDirector.stats().knockouts, 0)
	EventBus.enemy_neutralized.emit(enemy, "knockout")
	EventBus.enemy_neutralized.emit(enemy, "knockout")
	EventBus.enemy_neutralized.emit(enemy, "restrained")
	assert_eq(MissionDirector.stats().knockouts, 1)


func test_side_objective_is_independent_and_bonus_uses_tuning() -> void:
	var definition := _mission()
	definition.side_objective = _objective(&"letters", &"STEAL")
	MissionDirector.start_mission(definition)
	var before: int = MissionDirector.build_result().score
	MissionDirector.complete_objective(&"letters")
	MissionDirector.complete_objective(&"letters")
	assert_eq(MissionDirector.current_objective().id, &"kill_target")
	assert_true(MissionDirector.stats().side_objective_completed)
	assert_eq(MissionDirector.build_result().score, before + Tuning.scoring().side_objective_bonus)
	assert_true(MissionDirector.build_result().flags[&"side_objective"])
	assert_eq(_events.count(EventBus.EV_OBJECTIVE_COMPLETED), 1)
	assert_true(_payloads.back()["side_objective"])


func test_clock_and_counters_stop_after_completion_and_failure_and_reset_on_restart() -> void:
	var definition := _mission()
	MissionDirector._process(5.0)
	EventBus.player_detected.emit()
	assert_eq(MissionDirector.stats().elapsed_sec, 0.0)
	assert_eq(MissionDirector.stats().detections, 0)
	MissionDirector.start_mission(definition)
	MissionDirector._process(12.0)
	MissionDirector._process(NAN)
	MissionDirector._process(INF)
	MissionDirector._process(-1.0)
	assert_eq(MissionDirector.stats().elapsed_sec, 12.0)
	MissionDirector.complete_objective(&"kill_target")
	MissionDirector.complete_objective(&"escape")
	MissionDirector._process(10.0)
	EventBus.player_detected.emit()
	assert_eq(MissionDirector.stats().elapsed_sec, 12.0)
	assert_eq(MissionDirector.stats().detections, 0)
	MissionDirector.start_mission(definition)
	assert_eq(MissionDirector.stats().elapsed_sec, 0.0)
	assert_false(MissionDirector.build_result().flags[&"completed"])
	MissionDirector.fail_mission(&"player_defeated")
	MissionDirector.fail_mission(&"duplicate")
	MissionDirector.complete_objective(&"kill_target")
	MissionDirector._process(10.0)
	EventBus.player_detected.emit()
	assert_eq(_events.count(EventBus.EV_MISSION_FAILED), 1)
	assert_eq(MissionDirector.current_objective().id, &"kill_target")
	assert_eq(MissionDirector.build_result().flags[&"failed_reason"], &"player_defeated")
	assert_eq(MissionDirector.stats().elapsed_sec, 0.0)
	assert_eq(MissionDirector.stats().detections, 0)


func test_external_failure_event_stops_mission_without_reemitting() -> void:
	MissionDirector.start_mission(_mission())
	EventBus.mission_event.emit(EventBus.EV_MISSION_FAILED, { "reason": &"hostage_lost" })
	assert_eq(_events.count(EventBus.EV_MISSION_FAILED), 1)
	assert_eq(MissionDirector.build_result().flags[&"failed_reason"], &"hostage_lost")
	EventBus.player_detected.emit()
	assert_eq(MissionDirector.stats().detections, 0)


func test_corpse_wrappers_count_one_physical_body_and_restart_clears_count() -> void:
	MissionDirector.start_mission(_mission())
	var corpse := Node3D.new()
	add_child_autofree(corpse)
	var first := Anomaly.create(Enums.AnomalyKind.CORPSE, Vector3.ZERO, corpse, 3)
	var second := Anomaly.create(Enums.AnomalyKind.CORPSE, Vector3.ZERO, corpse, 3)
	EventBus.anomaly_spotted.emit(first, corpse)
	EventBus.anomaly_spotted.emit(second, corpse)
	assert_eq(MissionDirector.stats().bodies_found, 1)
	assert_eq(GameState.area_alert_level, 1)
	MissionDirector.start_mission(_mission())
	EventBus.anomaly_spotted.emit(first, corpse)
	assert_eq(MissionDirector.stats().bodies_found, 1)


func test_scoring_config_drives_rank_boundaries_and_penalty_cap() -> void:
	var config: ScoringConfig = Tuning.scoring().duplicate() as ScoringConfig
	var definition := _mission()
	var stats := MissionStats.new()
	stats.bodies_found = 1
	stats.one_strike = false
	definition.par_time_minutes = 0.0
	var scores := [config.rank_kaiden_threshold, config.rank_kaiden_threshold - 1, config.rank_okuden_threshold, config.rank_okuden_threshold - 1, config.rank_chuden_threshold, config.rank_chuden_threshold - 1]
	var ranks: Array[StringName] = [&"kaiden", &"okuden", &"okuden", &"chuden", &"chuden", &"shoden"]
	for index in scores.size():
		config.shadow_walker_points = scores[index]
		var result: MissionResult = MissionDirectorScript.compute_score(stats, config, definition)
		assert_eq(result.score, scores[index])
		assert_eq(result.rank, ranks[index])
	config.shadow_walker_points = 17
	config.nontarget_kill_penalty = -4
	config.nontarget_kill_penalty_cap = -11
	config.civilian_kill_penalty = -7
	stats.nontarget_kills = 10
	stats.civilian_kills = 2
	assert_eq(MissionDirectorScript.compute_score(stats, config, definition).score, 17 - 11 - 14)
	assert_eq(stats.nontarget_kills, 10, "Pure score computation must not mutate counters")


func test_swift_boundary_and_achievement_flags_explain_result() -> void:
	var definition := _mission()
	var stats := MissionStats.new()
	stats.elapsed_sec = definition.par_time_minutes * 60.0
	var config: ScoringConfig = Tuning.scoring()
	var exact: MissionResult = MissionDirectorScript.compute_score(stats, config, definition)
	assert_true(exact.flags[&"swift"])
	stats.elapsed_sec += 0.01
	stats.detections = 1
	stats.bodies_found = 1
	stats.one_strike = false
	var missed: MissionResult = MissionDirectorScript.compute_score(stats, config, definition)
	assert_false(missed.flags[&"swift"])
	assert_false(missed.flags[&"shadow_walker"])
	assert_false(missed.flags[&"no_traces"])
	assert_false(missed.flags[&"one_strike"])
	assert_eq(missed.score, 0)


func _mission() -> MissionDefinition:
	var definition := MissionDefinition.new()
	definition.id = &"m01"
	definition.par_time_minutes = 2.0
	definition.objectives = [_objective(&"kill_target", &"KILL_TARGET"), _objective(&"escape", &"ESCAPE")]
	return definition


func _objective(id: StringName, kind: StringName, target_group: StringName = &"") -> ObjectiveData:
	var objective := ObjectiveData.new()
	objective.id = id
	objective.kind = kind
	objective.target_group = target_group
	return objective


func _target() -> TargetNpc:
	var target := preload("res://src/enemies/target_npc.tscn").instantiate() as TargetNpc
	add_child_autofree(target)
	return target


func _capture_event(event_name: StringName, payload: Dictionary) -> void:
	_events.append(event_name)
	_payloads.append(payload.duplicate())
