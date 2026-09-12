extends GutTest

func after_each() -> void:
	GameState.area_alert_level = 0

func _brain() -> EnemyBrain:
	var region := NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	mesh.vertices = PackedVector3Array([Vector3(-10,0,-10),Vector3(10,0,-10),Vector3(10,0,10),Vector3(-10,0,10)])
	mesh.add_polygon(PackedInt32Array([0,1,2,3]))
	region.navigation_mesh = mesh
	add_child_autofree(region)
	var enemy: EnemyBase = load("res://src/enemies/enemy_base.tscn").instantiate()
	add_child_autofree(enemy)
	enemy.set_physics_process(false)
	enemy.get_node("Perception").set_process(false)
	var brain := enemy.brain()
	brain.set_physics_process(false)
	var route := PatrolPath.new()
	enemy.add_child(route)
	for index in range(2):
		var stop := RoutineStop.new()
		stop.route_index = index
		stop.position = Vector3(index*4,0,0)
		stop.active_from_seconds = 0 if index == 0 else 4
		stop.active_until_seconds = 4 if index == 0 else 36
		stop.dwell_seconds = 100
		stop.routine_action = &"chant" if index == 0 else &"walk"
		route.add_child(stop)
	brain.set_routine_path(route)
	brain.set_routine_type(&"patrol")
	brain.set_routine_cycle_seconds(36)
	return brain

func test_shared_clock_selects_the_current_window_without_moving_the_actor() -> void:
	var brain := _brain()
	assert_true(brain.has_method(&"synchronize_routine_clock"))
	if not brain.has_method(&"synchronize_routine_clock"): return
	var before: Vector3 = brain.get_parent().position
	assert_true(brain.call(&"synchronize_routine_clock",44.0))
	assert_almost_eq(brain.routine_clock(),8.0,0.001)
	assert_eq(brain.current_routine_stop_index(),1)
	assert_eq(brain.get_parent().position,before)
	assert_true(brain.call(&"synchronize_routine_clock",72.5))
	assert_eq(brain.current_routine_stop_index(),0)

func test_same_window_sync_preserves_arrival_dwell_and_rejects_invalid_time() -> void:
	var brain := _brain()
	for frame in range(3): await get_tree().physics_frame
	assert_true(brain.has_method(&"synchronize_routine_clock"))
	if not brain.has_method(&"synchronize_routine_clock"): return
	brain._physics_process(0.2)
	var dwell := brain.routine_stop_elapsed()
	assert_gt(dwell,0.0)
	assert_true(brain.call(&"synchronize_routine_clock",1.0))
	assert_eq(brain.routine_stop_elapsed(),dwell)
	for invalid in [-1.0,NAN,INF,86401.0]:
		assert_false(brain.call(&"synchronize_routine_clock",invalid))
		assert_eq(brain.routine_clock(),1.0)

func test_shared_clock_does_not_cancel_combat() -> void:
	var brain := _brain()
	assert_true(brain.has_method(&"synchronize_routine_clock"))
	if not brain.has_method(&"synchronize_routine_clock"): return
	var stimulus := PerceptionStimulus.create(Enums.StimulusKind.DAMAGE,4,Vector3(3,0,0),1.0)
	brain.submit_stimulus(stimulus)
	brain._physics_process(0.01)
	assert_eq(brain.alert_state(),Enums.AlertState.COMBAT)
	var target := brain.last_known_position()
	assert_true(brain.call(&"synchronize_routine_clock",10.0))
	assert_eq(brain.alert_state(),Enums.AlertState.COMBAT)
	assert_eq(brain.last_known_position(),target)
