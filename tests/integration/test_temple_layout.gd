extends GutTest

const SCENE := "res://src/levels/rainy_temple/rainy_temple.tscn"

func after_each() -> void:
	for action in [&"move_forward",&"move_backward",&"interact"]: Input.action_release(action)
	MissionDirector.start_mission(null)
	GameState.checkpoint_ref.clear()
	GameState.area_alert_level = 0

func _level() -> Node3D:
	assert_true(ResourceLoader.exists(SCENE),"M4 needs its own layered temple scene")
	if not ResourceLoader.exists(SCENE): return null
	var level := load(SCENE).instantiate() as Node3D
	add_child_autofree(level)
	return level

func test_temple_has_authored_layers_safe_introduction_and_three_routes() -> void:
	var level := _level()
	if level == null: return
	for section in ["Ground","Terraces","Roofs","Interiors","Water"]: assert_true(level.has_node("Geometry/"+section))
	for route in [&"A_steps",&"B_cliff",&"C_stream"]: assert_gt(level.route_waypoints(route).size(),4)
	assert_gte(level.get_node("Markers/Observation").get_child_count(),6)
	assert_gte(level.get_node("Markers/Cover").get_child_count(),6)
	for marker in level.get_node("Markers/Traversal").get_children(): assert_true(marker.is_geometry_valid(),marker.name)
	assert_lt(level.get_node("Player").position.distance_to(Vector3(12,0.02,88)),0.1)

func test_front_stair_route_and_retainer_return_support_continuous_capsule_passage() -> void:
	var level := _level()
	if level == null: return
	var player := level.get_node("Player") as PlayerController
	player.set_physics_process(false)
	for frame in range(3): await get_tree().physics_frame
	for route in [level.route_waypoints(&"A_steps"),level.rescue_return_waypoints()]:
		player.position = route[0]
		for target: Vector3 in route.slice(1):
			for step in range(2500):
				var difference := target-player.position
				if difference.length() < 0.06: break
				player.move_and_collide(difference.normalized()*minf(0.03,difference.length()),false,0.001)
			assert_lt(player.position.distance_to(target),0.1,"Continuous route to "+str(target))

func test_stream_covers_the_rescue_approach_and_both_crawl_ends_exist() -> void:
	var level := _level()
	if level == null: return
	var stream := level.get_node("Markers/Water/Stream") as WaterVolume
	for point in [Vector3(94,-1.65,92),Vector3(94,-1.65,60),Vector3(94,-1.65,44)]:
		assert_true(stream.contains_world_position(point))
	assert_true(level.has_node("Markers/Traversal/MillCrawl"))
	assert_true(level.has_node("Markers/Traversal/CellCrawl"))
	assert_true(level.has_node("Markers/Traversal/HallBeam"))

func test_roof_bridge_and_mill_ramp_support_the_standing_approach() -> void:
	var level := _level()
	if level == null: return
	var player := level.get_node("Player") as PlayerController
	player.set_physics_process(false)
	for frame in range(3): await get_tree().physics_frame
	for route in [[Vector3(28,8.12,44),Vector3(44,11.72,32),Vector3(44,11.62,30),Vector3(51,11.62,24)],[Vector3(84,0.12,44),Vector3(86.75,0.12,44),Vector3(86.75,3.84,33),Vector3(86.75,3.84,32)],[Vector3(74,3.84,32),Vector3(72,5.12,32)]]:
		player.position = route[0]
		for target: Vector3 in route.slice(1):
			for step in range(2500):
				var difference := target-player.position
				if difference.length() < 0.06: break
				player.move_and_collide(difference.normalized()*minf(0.03,difference.length()),false,0.001)
			assert_lt(player.position.distance_to(target),0.1,"Standing approach clearance to "+str(target))

func test_swimmer_can_leave_the_stream_and_walk_onto_the_mill_bank() -> void:
	var level := _level()
	if level == null: return
	var player := level.get_node("Player") as PlayerController
	for frame in range(3): await get_tree().physics_frame
	player.position = Vector3(94,-1.65,44)
	assert_true(player.try_enter_water(level.get_node("Markers/Water/Stream")))
	player.rotation.y = PI/2
	for frame in range(360):
		Input.action_press(&"move_forward")
		await get_tree().physics_frame
		if player.position.x < 87.8: break
	Input.action_release(&"move_forward")
	assert_lt(player.position.x,88.0,"Swimming must release its fixed depth before the rising bank")
	assert_eq(player.state_machine.current_state(),&"Ground")

func test_mill_crawlspace_reaches_the_cell_hatch_and_internal_step() -> void:
	var level := _level()
	if level == null: return
	var player := level.get_node("Player") as PlayerController
	player.set_physics_process(false)
	for frame in range(3): await get_tree().physics_frame
	player.position = level.get_node("Markers/Traversal/MillCrawl").position
	assert_true(player.try_enter_crawlspace(level.get_node("Markers/Traversal/MillCrawl")))
	assert_eq(player.state_machine.current_state(),&"Crawlspace")
	for step in range(600):
		if player.position.x <= 76.04: break
		player.move_and_collide(Vector3(-0.03,0,0),false,0.001)
	assert_lt(player.position.x,76.1)
	assert_true(player.try_exit_crawlspace(level.get_node("Markers/Traversal/CellCrawl")))
	assert_eq(player.state_machine.current_state(),&"Crouch")
	for step in range(300):
		var difference := Vector3(72,5.12,32)-player.position
		if difference.length() < 0.06: break
		player.move_and_collide(difference.normalized()*minf(0.03,difference.length()),false,0.001)
	assert_lt(player.position.distance_to(Vector3(72,5.12,32)),0.1)

func test_hall_beam_exposes_an_above_assassination_approach() -> void:
	var level := _level()
	if level == null: return
	var player := level.get_node("Player") as PlayerController
	var target: TargetNpc = load("res://src/enemies/target_npc.tscn").instantiate()
	target.position = Vector3(51,8.02,22)
	level.add_child(target)
	for frame in range(3): await get_tree().physics_frame
	player.position = Vector3(51,11.62,24)
	assert_true(player.try_enter_climb(level.get_node("Markers/Traversal/HallBeamGrip")))
	for frame in range(180):
		Input.action_press(&"move_forward")
		await get_tree().physics_frame
		if player.position.distance_to(Vector3(51,11.9,22)) < 0.08: break
	Input.action_release(&"move_forward")
	assert_eq(player.state_machine.current_state(),&"Beam")
	assert_lt(player.position.distance_to(Vector3(51,11.9,22)),0.1)
	for frame in range(3): await get_tree().process_frame
	assert_eq((player.get_node("AssassinationResolver") as AssassinationResolver).prompt_context(),&"above")
