extends GutTest


const TuningScript := preload("res://src/autoload/tuning.gd")

var tuning: Node


func before_each() -> void:
	tuning = TuningScript.new()
	add_child(tuning)
	tuning.reload()


func after_each() -> void:
	tuning.free()


func test_perception_resources_load_with_contract_values() -> void:
	assert_not_null(tuning.perception(&"ashigaru"))
	assert_eq(tuning.perception(&"ashigaru").fov_degrees, 110.0)
	assert_eq(tuning.perception(&"archer").view_distance_m, 25.0)
	assert_eq(tuning.perception(&"shinobi").hearing_multiplier, 1.5)
	assert_true(tuning.perception(&"sogen").dart_immune)


func test_movement_scoring_and_weather_resources_load() -> void:
	assert_eq(tuning.movement().move_speeds[&"sprint"], 6.0)
	assert_eq(tuning.movement().material_noise_multipliers[&"tatami"], 0.5)
	assert_eq(tuning.scoring().shadow_walker_points, 40)
	assert_eq(tuning.scoring().epilogue_a_condition, 12)
	assert_eq(tuning.weather().player_noise_mult[&"rain"], 0.5)


func test_reload_keeps_resources_available() -> void:
	tuning.reload()
	assert_eq(tuning.perception(&"ashigaru").combat_threshold, 3.0)
