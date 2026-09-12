extends GutTest

const SCENE := "res://src/levels/festival_night/festival_night.tscn"

func _level() -> Node3D:
	assert_true(ResourceLoader.exists(SCENE),"M5 needs its three-route festival graybox")
	if not ResourceLoader.exists(SCENE): return null
	var level: Node3D = load(SCENE).instantiate()
	add_child_autofree(level)
	for frame in range(4): await get_tree().physics_frame
	return level

func test_three_routes_have_safe_entry_and_ordinary_ground_escape() -> void:
	var level := await _level()
	if level == null: return
	for id in [&"A_crowd",&"B_roofs",&"C_well"]:
		var points: Array = level.route_waypoints(id)
		assert_gt(points.size(),6)
		assert_eq(points[0],Vector3(12,0.02,88))
	assert_gt(level.get_node("Markers/Observation").get_child_count(),4)
	assert_gt(level.escape_waypoints().size(),3)
	for point: Vector3 in level.route_waypoints(&"A_crowd"):
		var hit := _floor(level,point)
		assert_false(hit.is_empty(),"Actual route support at "+str(point))
		if not hit.is_empty(): assert_almost_eq(float(hit.position.y),point.y-0.9,0.25)

func test_well_and_roof_openings_are_real_collision_holes() -> void:
	var level := await _level()
	if level == null: return
	for spec in [[Vector3(12,1,88),-0.9],[Vector3(69,1,13),-3.9],[Vector3(83.4,7.5,32),2.1],[Vector3(82,7.5,32),5.7],[Vector3(78,1,38),-3.9]]:
		var query := PhysicsRayQueryParameters3D.create(spec[0],spec[0]+Vector3.DOWN*12,1)
		var hit := level.get_world_3d().direct_space_state.intersect_ray(query)
		assert_false(hit.is_empty(),"Ray reaches actual physical support")
		if not hit.is_empty(): assert_almost_eq(float(hit.position.y),float(spec[1]),0.03)

func test_roof_beam_and_crawl_exit_fit_existing_player_limits() -> void:
	var level := await _level()
	if level == null: return
	var player := level.get_node("Player") as PlayerController
	var beam := level.get_node("Markers/Traversal/DaisBeam") as BeamPath
	assert_lt((beam.global_position+beam.path_curve.get_point_position(beam.path_curve.point_count-1)).distance_to(Vector3(84,3.02,32)),4.0,"Keep the existing above-assassination reach")
	assert_true(player.can_restore_checkpoint_posture(&"Ground",Vector3(84,6.62,34)),"Roof arrival supports standing")
	assert_true(player.can_restore_checkpoint_posture(&"Crouch",Vector3(84,1.74,34.5)),"Hatch exit supports crouching")
	assert_true(player.can_restore_checkpoint_posture(&"Ground",Vector3(84,3.02,39)),"Dais landing supports standing")
	assert_not_null(level.get_node_or_null("Markers/Traversal/CanalCrawl"))
	assert_not_null(level.get_node_or_null("Markers/Traversal/DaisCrawl"))

func _floor(level: Node3D,point: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(point+Vector3.UP*0.1,point+Vector3.DOWN*1.2,1)
	return level.get_world_3d().direct_space_state.intersect_ray(query)

func test_undercroft_perimeter_blocks_ground_bypasses_and_below_ground_escape() -> void:
	var level := await _level()
	if level == null: return
	for segment in [[Vector3(75,0,28),Vector3(77,0,28)],[Vector3(93,0,32),Vector3(91,0,32)],[Vector3(84,0,41),Vector3(84,0,39)],[Vector3(84,0,23),Vector3(84,0,25)],[Vector3(78,-2,38),Vector3(78,-2,41)]]:
		var query := PhysicsRayQueryParameters3D.create(segment[0],segment[1],1)
		assert_false(level.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "Enclose the dais foundation at "+str(segment[0]))
	var canal := PhysicsRayQueryParameters3D.create(Vector3(84,-2.5,23),Vector3(84,-2.5,25),1)
	assert_true(level.get_world_3d().direct_space_state.intersect_ray(canal).is_empty(), "Keep the actual underground canal opening")

func test_actual_crawl_exit_reaches_a_clear_flat_landing() -> void:
	var level := await _level()
	if level == null: return
	var player := level.get_node("Player") as PlayerController
	player.global_position = Vector3(84,1.74,34.25)
	assert_true(player.restore_checkpoint_posture(&"Crawlspace",player.global_position))
	for frame in range(10): await get_tree().physics_frame
	var entrance := level.get_node("Markers/Traversal/DaisCrawl") as CrawlEntrance
	assert_true(player.try_exit_crawlspace(entrance),"The real E exit must be reachable from the flat canal landing")
	assert_eq(player.state_machine.current_state(),&"Crouch")
	assert_almost_eq(player.global_position,entrance.outside_world_position(),Vector3.ONE*0.01)
