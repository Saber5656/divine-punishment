extends GutTest

func after_each() -> void:
	WeatherSystem.start(MissionDefinition.Weather.CLEAR)

func test_audible_bell_marks_only_the_shared_sutra_window() -> void:
	var level: Node3D = load("res://src/levels/rainy_temple/temple_population.tscn").instantiate()
	add_child_autofree(level)
	var population := level.get_node("Population")
	population.set_physics_process(false)
	assert_true(population.has_node("SutraBell"),"Patrol rhythm needs an audible cue")
	if not population.has_node("SutraBell"): return
	var bell := population.get_node("SutraBell") as AudioStreamPlayer3D
	assert_true(bell.playing)
	assert_almost_eq(bell.stream.get_length(),4.0,0.001)
	population.call("advance_schedule",5.0)
	assert_false(bell.playing)
	population.call("advance_schedule",31.0)
	assert_true(bell.playing)
	assert_eq(GameState.area_alert_level,0,"Normal sutra does not create an anomaly")
