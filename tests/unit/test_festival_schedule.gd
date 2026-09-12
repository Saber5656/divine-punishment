extends GutTest

func test_phase_boundaries_wrap_and_reject_invalid_schedule_inputs() -> void:
	var path := "res://src/levels/festival_night/festival_population.gd"
	assert_true(ResourceLoader.exists(path))
	if not ResourceLoader.exists(path): return
	var script: Script = load(path)
	for spec in [[0.0,&"dais"],[179.9,&"dais"],[180.0,&"shrine"],[299.9,&"shrine"],[300.0,&"stalls"],[359.9,&"stalls"],[360.0,&"dais"],[540.0,&"shrine"]]:
		assert_eq(script.phase_at(spec[0],Vector3(180,120,60)),spec[1])
	for elapsed in [-1.0,NAN,INF]: assert_eq(script.phase_at(elapsed,Vector3(180,120,60)),&"")
	for durations in [Vector3.ZERO,Vector3(180,-1,60),Vector3(INF,120,60)]: assert_eq(script.phase_at(0,durations),&"")


func test_firework_phase_has_bounded_three_second_windows() -> void:
	var path := "res://src/levels/festival_night/festival_fireworks.gd"
	assert_true(ResourceLoader.exists(path))
	if not ResourceLoader.exists(path): return
	var script: Script = load(path)
	for spec in [[0.0,false],[41.999,false],[42.0,true],[44.999,true],[45.0,false],[87.0,true],[90.0,false]]:
		assert_eq(script.burst_active_at(spec[0],45.0,3.0),spec[1])
	for elapsed in [-1.0,NAN,INF]: assert_false(script.burst_active_at(elapsed,45.0,3.0))
	for timing in [Vector2.ZERO,Vector2(45,-1),Vector2(45,45),Vector2(INF,3)]: assert_false(script.burst_active_at(42,timing.x,timing.y))
