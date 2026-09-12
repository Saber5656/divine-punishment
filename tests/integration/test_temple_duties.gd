extends GutTest

const DUTIES := "res://src/levels/rainy_temple/temple_duties.gd"

func before_each() -> void:
	GameState.area_alert_level = 0

func after_each() -> void:
	GameState.area_alert_level = 0
	WeatherSystem.start(MissionDefinition.Weather.CLEAR)

func _world() -> Node3D:
	assert_true(ResourceLoader.exists(DUTIES),"Temple gathering/execution duties exist")
	if not ResourceLoader.exists(DUTIES): return null
	var level: Node3D = load("res://src/levels/rainy_temple/temple_population.tscn").instantiate()
	add_child_autofree(level)
	var population := level.get_node("Population")
	var duties: Node = load(DUTIES).new()
	duties.name = "Duties"
	population.add_child(duties)
	population.set_physics_process(false)
	duties.set_physics_process(false)
	for actor in duties.call("actors"): actor.brain().set_physics_process(false)
	for frame in range(4): await get_tree().physics_frame
	return level

func test_bell_is_one_use_and_does_not_revive_a_defeated_actor() -> void:
	var level := await _world()
	if level == null: return
	var duties := level.get_node("Population/Duties")
	var dead := level.get_node("Population/Monks/GateEast") as EnemyBase
	dead.set_incapacitated(&"dead")
	assert_true(duties.call("use_bell"))
	assert_eq(GameState.area_alert_level,1)
	assert_false(duties.call("use_bell"))
	assert_eq(GameState.area_alert_level,1)
	assert_eq(dead.brain().incapacitated_kind(),&"dead")
	for actor in duties.call("actors"):
		if actor == dead: continue
		assert_eq(actor.current_routine_stop().routine_action,&"gather")

func test_all_ten_actors_walk_to_the_hall_before_the_gathering_window_ends() -> void:
	var level := await _world()
	if level == null: return
	var population := level.get_node("Population")
	var duties := population.get_node("Duties")
	duties.call("use_bell")
	var arrivals := {}
	for frame in range(590):
		population.call("advance_schedule",0.1)
		duties.call("advance_duties")
		for actor in duties.call("actors"):
			actor.brain().tick(0.1)
			if actor.global_position.distance_to(duties.call("gathering_point",actor)) < 0.5:
				arrivals[actor.name] = true
		if arrivals.size() == 10: break
		await get_tree().physics_frame
	assert_eq(arrivals.size(),10,"Actual hall arrivals: "+str(arrivals.keys()))

func test_deadline_starts_real_party_travel_and_gathering_delays_that_duty() -> void:
	var level := await _world()
	if level == null: return
	var population := level.get_node("Population")
	var duties := population.get_node("Duties")
	var party := population.get_node("Monks/CourtWest") as EnemyBase
	var start := party.global_position
	population.call("advance_schedule",719.0)
	duties.call("advance_duties")
	assert_false(duties.call("execution_started"))
	population.call("advance_schedule",1.1)
	duties.call("advance_duties")
	assert_true(duties.call("execution_started"))
	assert_eq(party.current_routine_stop().routine_action,&"execute")
	assert_eq(party.global_position,start,"Deadline changes duty without teleporting")
	assert_false(duties.call("execution_ready",0))
	duties.call("use_bell")
	assert_eq(party.current_routine_stop().routine_action,&"gather")
	population.call("advance_schedule",61.0)
	duties.call("advance_duties")
	assert_eq(party.current_routine_stop().routine_action,&"execute")
	for frame in range(500):
		party.brain().tick(0.1)
		if duties.call("execution_ready",0): break
		await get_tree().physics_frame
	assert_true(duties.call("execution_ready",0),"Execution requires physical arrival: "+str(party.global_position))
	party.set_incapacitated(&"knockout",30)
	assert_false(duties.call("execution_ready",0),"An incapacitated executioner cannot attack a captive")
