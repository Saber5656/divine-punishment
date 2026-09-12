extends GutTest

const SCENE := "res://src/levels/port_storehouse/port_storehouse.tscn"

func test_port_has_four_layers_three_routes_and_valid_traversal_markers() -> void:
	assert_true(ResourceLoader.exists(SCENE))
	if not ResourceLoader.exists(SCENE): return
	var level = load(SCENE).instantiate()
	add_child_autofree(level)
	for layer in ["Ground","Roofs","Interiors","Water"]: assert_true(level.has_node("Geometry/"+layer))
	for id in [&"A_pier",&"B_roofs",&"C_water"]: assert_gt(level.route_waypoints(id).size(),2)
	assert_eq(level.get_node("Markers/Water").get_child_count(),4)
	for marker in level.get_node("Markers/Traversal").get_children(): assert_true(marker.is_geometry_valid(),marker.name)

func test_port_ground_route_supports_a_real_player_capsule() -> void:
	await _check_capsule_route(&"A_pier")

func test_port_ladder_roofs_and_overhead_approach_have_capsule_clearance() -> void:
	await _check_capsule_route(&"B_roofs")

func _check_capsule_route(id: StringName) -> void:
	assert_true(ResourceLoader.exists(SCENE))
	if not ResourceLoader.exists(SCENE): return
	var level = load(SCENE).instantiate()
	add_child_autofree(level)
	var player := level.get_node("Player") as PlayerController
	player.set_physics_process(false)
	for frame in range(3): await get_tree().physics_frame
	var route: Array[Vector3] = level.route_waypoints(id)
	player.global_position = route[0]
	for target in route.slice(1):
		for step in range(2000):
			var difference: Vector3 = target-player.global_position
			if difference.length() < 0.06: break
			player.move_and_collide(difference.normalized()*minf(0.03,difference.length()),false,0.001)
		assert_lt(player.global_position.distance_to(target),0.1,"Continuous capsule passage at "+str(target))

func test_port_rear_shore_leaves_swimming_before_the_rising_bank() -> void:
	var level = load(SCENE).instantiate()
	add_child_autofree(level)
	var player := level.get_node("Player") as PlayerController
	for frame in range(3): await get_tree().physics_frame
	player.global_position = Vector3(88,-1.65,18)
	assert_true(player.try_enter_water(level.get_node("Markers/Water/RearPool")))
	player.rotation.y = PI/2.0
	for frame in range(360):
		Input.action_press(&"move_forward")
		await get_tree().physics_frame
		if player.global_position.x < 83.0: break
	Input.action_release(&"move_forward")
	assert_lt(player.global_position.x,83.0,"Swimmer can walk up the rear shore without a teleport")
	assert_eq(player.state_machine.current_state(),&"Ground")

func test_port_has_observation_points_and_restealth_cover_on_each_approach() -> void:
	var level = load(SCENE).instantiate()
	add_child_autofree(level)
	var observations: Node = level.get_node_or_null("Markers/Observation")
	assert_not_null(observations)
	if observations == null: return
	assert_gte(observations.get_child_count(),4)
	assert_gte(level.get_node("Markers/Cover").get_child_count(),6)
	assert_true(level.has_node("Geometry/Roofs/LadderVisual"))

func test_port_crawl_passage_uses_the_real_reduced_capsule() -> void:
	var level = load(SCENE).instantiate()
	add_child_autofree(level)
	var player := level.get_node("Player") as PlayerController
	player.set_physics_process(false)
	for frame in range(3): await get_tree().physics_frame
	player.global_position = Vector3(78.5,1.72,14)
	assert_true(player.try_enter_crawlspace(level.get_node("Markers/Traversal/RearCrawl")))
	for step in range(500):
		if player.global_position.x <= 66.04: break
		player.move_and_collide(Vector3(-0.03,0,0),false,0.001)
	assert_lt(player.global_position.x,66.1)
	assert_eq(player.state_machine.current_state(),&"Crawlspace")

func test_port_water_covers_the_east_channel_beside_the_land() -> void:
	var level = load(SCENE).instantiate()
	add_child_autofree(level)
	for point in [Vector3(83,-1.65,30),Vector3(83,-1.65,8),Vector3(88,-1.65,18)]:
		var covered := false
		for volume: WaterVolume in level.get_node("Markers/Water").get_children():
			covered = covered or volume.contains_world_position(point)
		assert_true(covered,"Continuous water at "+str(point))

func test_port_rear_dock_approaches_the_low_end_of_the_crawl_ramp() -> void:
	var level = load(SCENE).instantiate()
	add_child_autofree(level)
	var player := level.get_node("Player") as PlayerController
	for frame in range(3): await get_tree().physics_frame
	player.global_position = Vector3(80,0.02,18)
	for destination in [Vector3(80,0,16),Vector3(85,0,16),Vector3(85,0,14),Vector3(78.5,1.72,14)]:
		for frame in range(300):
			var direction: Vector3 = destination-player.global_position
			direction.y = 0
			if direction.length() < 0.15: break
			player.rotation.y = atan2(-direction.x,-direction.z)
			Input.action_press(&"move_forward")
			await get_tree().physics_frame
		Input.action_release(&"move_forward")
		assert_lt(Vector2(player.global_position.x,player.global_position.z).distance_to(Vector2(destination.x,destination.z)),0.2)
	assert_true(player.try_enter_crawlspace(level.get_node("Markers/Traversal/RearCrawl")))
