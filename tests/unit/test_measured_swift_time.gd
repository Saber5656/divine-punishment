extends GutTest

func test_residence_swift_uses_measured_three_minute_limit() -> void:
	var definition = load("res://data/missions/m02.tres")
	var config = load("res://data/tuning/scoring.tres")
	var stats := MissionStats.new()
	stats.elapsed_sec = 180.0
	assert_true(MissionDirector.compute_score(stats, config, definition).flags[&"swift"])
	stats.elapsed_sec = 180.001
	assert_false(MissionDirector.compute_score(stats, config, definition).flags[&"swift"], "Measured route limit replaces the unmeasured 18-minute placeholder")

func test_unmeasured_mission_retains_authored_time() -> void:
	var definition := MissionDefinition.new()
	definition.id = &"custom"
	definition.par_time_minutes = 2.0
	var stats := MissionStats.new()
	stats.elapsed_sec = 120.0
	assert_true(MissionDirector.compute_score(stats, ScoringConfig.new(), definition).flags[&"swift"])
	stats.elapsed_sec = 120.01
	assert_false(MissionDirector.compute_score(stats, ScoringConfig.new(), definition).flags[&"swift"])

func test_tutorial_measured_limit_is_two_minutes() -> void:
	var definition = load("res://data/missions/tutorial.tres")
	var config = load("res://data/tuning/scoring.tres")
	var stats := MissionStats.new()
	stats.elapsed_sec = 120.0
	assert_true(MissionDirector.compute_score(stats, config, definition).flags[&"swift"])
	stats.elapsed_sec = 120.001
	assert_false(MissionDirector.compute_score(stats, config, definition).flags[&"swift"])
