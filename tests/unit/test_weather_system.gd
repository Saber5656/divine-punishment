extends GutTest

func after_each() -> void:
	var weather = get_node_or_null("/root/WeatherSystem")
	if weather != null: weather.start(MissionDefinition.Weather.CLEAR)

func test_rain_modifiers_and_m8_timed_clear_event() -> void:
	var weather = get_node_or_null("/root/WeatherSystem")
	assert_not_null(weather)
	if weather == null: return
	weather.start(MissionDefinition.Weather.RAIN_THEN_CLEAR)
	assert_eq(weather.current,&"rain")
	assert_eq(weather.noise_multiplier(),0.5)
	assert_eq(weather.view_multiplier(),0.8)
	weather.advance(899.0)
	assert_eq(weather.current,&"rain")
	weather.advance(1.0)
	assert_eq(weather.current,&"clear")
	assert_eq(weather.noise_multiplier(),1.0)
	assert_eq(load("res://data/missions/m08.tres").weather,MissionDefinition.Weather.RAIN_THEN_CLEAR)
	assert_eq(load("res://data/missions/m10.tres").weather,MissionDefinition.Weather.SNOW)

func test_footprint_spacing_expiry_exclusions_and_ring_capacity() -> void:
	var path := "res://src/core/footprint_trail.gd"
	assert_true(FileAccess.file_exists(path))
	if not FileAccess.file_exists(path): return
	var trail = load(path).new()
	trail.sample(1,Vector3.ZERO,&"snow",0.0)
	trail.sample(1,Vector3(0.79,0,0),&"snow",0.0)
	assert_eq(trail.entries.size(),0)
	trail.sample(1,Vector3(0.8,0,0),&"snow",0.0)
	assert_eq(trail.entries.size(),1)
	trail.expire(89.9)
	assert_eq(trail.entries.size(),1)
	trail.expire(90.0)
	assert_eq(trail.entries.size(),0)
	for i in range(1,80): trail.sample(2,Vector3(i,0,0),&"snow",100.0)
	assert_eq(trail.entries.size(),60)
	var count: int = trail.entries.size()
	trail.sample(3,Vector3.ZERO,&"wood",100.0)
	trail.sample(3,Vector3(2,0,0),&"wood",100.0)
	assert_eq(trail.entries.size(),count)

func test_excluded_to_snow_transition_does_not_backfill_excluded_ground() -> void:
	var trail := FootprintTrail.new()
	trail.sample(1,Vector3.ZERO,&"wood",0.0)
	trail.sample(1,Vector3(2,0,0),&"snow",0.0)
	assert_eq(trail.entries.size(),0)
	trail.sample(1,Vector3(2.8,0,0),&"snow",0.0)
	assert_eq(trail.entries.size(),1)

func test_reduced_interval_never_places_marks_behind_latest_sample() -> void:
	var trail := FootprintTrail.new()
	trail.sample(1,Vector3.ZERO,&"snow",0.0)
	trail.sample(1,Vector3(0.7,0,0),&"snow",0.0)
	trail.interval_m = 0.2
	trail.sample(1,Vector3(0.9,0,0),&"snow",0.0)
	for entry in trail.entries:
		assert_gte(entry.position.x,0.7)
