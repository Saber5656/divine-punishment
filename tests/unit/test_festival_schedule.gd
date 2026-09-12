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
