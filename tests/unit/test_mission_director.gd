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
