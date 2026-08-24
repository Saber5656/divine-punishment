extends GutTest


const GYM_SCENE_PATH := "res://src/levels/gym/movement_gym.tscn"
const MOVEMENT_CONFIG_PATH := "res://data/tuning/movement.tres"


func after_each() -> void:
	for action: StringName in [&"move_forward", &"move_backward", &"move_left", &"move_right"]:
		Input.action_release(action)


func test_movement_gym_exposes_bounded_routes_and_floor_materials() -> void:
	var gym := _add_gym()
	await get_tree().physics_frame

	assert_true(gym.is_contract_valid(), "Gym contract errors: %s" % [gym.validation_errors()])
	assert_eq(
		gym.floor_materials(),
		MovementGym.REQUIRED_FLOOR_MATERIALS,
		"Every movement tuning floor material must have a graybox sample",
	)

	var edge := gym.get_node(^"Markers/ClimbBeam/EntryEdge") as ClimbEdge
	var beam := gym.get_node(^"Markers/ClimbBeam/BeamPath") as BeamPath
	var exit_edge := gym.get_node(^"Markers/ClimbBeam/ExitEdge") as ClimbEdge
	var crawl_entrance := gym.get_node(^"Markers/Crawlspace/CrawlEntrance") as CrawlEntrance
	var water_volume := gym.get_node(^"Markers/Water/WaterVolume") as WaterVolume
	var hide_spot := gym.get_node(^"Markers/HideSpot/HideSpot") as HideSpot

	assert_eq(edge.connected_beam(), beam)
	assert_eq(beam.connected_climb_at_end(), exit_edge)
	assert_true(crawl_entrance.is_geometry_valid())
	assert_true(water_volume.is_geometry_valid())
	assert_false(
		water_volume.contains_world_position(crawl_entrance.outside_world_position()),
		"Crawl outside endpoint must not overlap the water volume",
	)
	assert_false(
		water_volume.contains_world_position(crawl_entrance.inside_world_position()),
		"Crawl inside endpoint must not overlap the water volume",
	)
	assert_true(hide_spot.is_geometry_valid())

	var movement_config := load(MOVEMENT_CONFIG_PATH) as MovementConfig
	assert_not_null(movement_config)
	for sample: Node in gym.get_node(^"Geometry/FloorSamples").get_children():
		# Metadata is the level-authored surface key; the tuning Resource owns its multiplier.
		var material: Variant = sample.get_meta(&"floor_material", &"")
		assert_true(material is StringName)
		assert_true(movement_config.material_noise_multipliers.has(material))


func test_gym_player_can_try_stances_hide_crawl_beam_and_underwater_routes() -> void:
	var gym := _add_gym()
	var player := gym.get_node(^"Player") as PlayerController
	await _await_player_grounded(player)

	var state_machine := player.state_machine
	assert_eq(state_machine.current_state(), PlayerStateMachine.STATE_GROUND)
	assert_true(state_machine.change_state(PlayerStateMachine.STATE_CROUCH))
	assert_true(state_machine.change_state(PlayerStateMachine.STATE_SPRINT))
	assert_true(state_machine.resume_from_sprint())
	assert_eq(state_machine.current_state(), PlayerStateMachine.STATE_CROUCH)
	assert_true(state_machine.change_state(PlayerStateMachine.STATE_GROUND))

	var hide_spot := gym.get_node(^"Markers/HideSpot/HideSpot") as HideSpot
	player.global_position = hide_spot.entry_world_position()
	await get_tree().physics_frame
	assert_true(player.try_enter_hide_spot(hide_spot))
	assert_eq(state_machine.current_state(), PlayerStateMachine.STATE_HIDDEN)
	assert_true(player.try_exit_hide_spot(hide_spot))
	assert_eq(state_machine.current_state(), PlayerStateMachine.STATE_CROUCH)

	var crawl_entrance := gym.get_node(^"Markers/Crawlspace/CrawlEntrance") as CrawlEntrance
	assert_true(state_machine.change_state(PlayerStateMachine.STATE_GROUND))
	player.global_position = crawl_entrance.outside_world_position()
	await get_tree().physics_frame
	assert_true(player.try_enter_crawlspace(crawl_entrance))
	assert_eq(state_machine.current_state(), PlayerStateMachine.STATE_CRAWLSPACE)
	await _await_player_grounded(player)
	var inside_position := crawl_entrance.inside_world_position()
	var crawl_position_before_motion := player.global_position
	Input.action_press(&"move_backward")
	for _frame: int in 30:
		await get_tree().physics_frame
		assert_eq(state_machine.current_state(), PlayerStateMachine.STATE_CRAWLSPACE)
		assert_true(player.is_on_floor(), "Crawlspace must remain supported by the continuous graybox floor")
	Input.action_release(&"move_backward")
	assert_gt(
		player.global_position.distance_to(crawl_position_before_motion),
		0.25,
		"Crawl route must advance under live physics before exit",
	)
	assert_lte(
		player.global_position.distance_to(inside_position),
		crawl_entrance.entry_radius,
		"The sustained crawl leg must remain close enough to the authored inside endpoint for exit",
	)
	Input.action_press(&"move_forward")
	for _frame: int in 30:
		await get_tree().physics_frame
		assert_eq(state_machine.current_state(), PlayerStateMachine.STATE_CRAWLSPACE)
		assert_true(player.is_on_floor(), "Crawl return must remain supported by the continuous graybox floor")
	Input.action_release(&"move_forward")
	assert_lte(
		player.global_position.distance_to(inside_position),
		0.25,
		"Crawl movement must return to the authored inside endpoint before exit",
	)
	assert_true(player.try_exit_crawlspace(crawl_entrance))
	assert_eq(state_machine.current_state(), PlayerStateMachine.STATE_CROUCH)
	await get_tree().physics_frame
	assert_true(player.is_on_floor(), "Crawl exit must return to the supported floor")

	var edge := gym.get_node(^"Markers/ClimbBeam/EntryEdge") as ClimbEdge
	var beam := gym.get_node(^"Markers/ClimbBeam/BeamPath") as BeamPath
	assert_true(state_machine.change_state(PlayerStateMachine.STATE_GROUND))
	player.global_position = edge.bottom_world_position()
	await get_tree().physics_frame
	assert_true(player.try_enter_climb(edge))
	assert_eq(state_machine.current_state(), PlayerStateMachine.STATE_CLIMB)
	player.advance_traversal(1.0, 2.0)
	assert_eq(state_machine.current_state(), PlayerStateMachine.STATE_BEAM)
	assert_eq(player.active_beam_path(), beam)
	assert_true(player.drop_from_beam())
	assert_eq(state_machine.current_state(), PlayerStateMachine.STATE_GROUND)

	var water_volume := gym.get_node(^"Markers/Water/WaterVolume") as WaterVolume
	player.global_position = Vector3(8.0, 0.0, 3.0)
	var entered_water := false
	for _frame: int in 8:
		await get_tree().physics_frame
		if state_machine.current_state() == PlayerStateMachine.STATE_SWIM_SURFACE:
			entered_water = true
			break
	assert_true(entered_water, "Live physics must discover entry into the authored water volume")
	assert_eq(
		player.active_water_volume(),
		water_volume,
		"Entering the authored water volume must be discovered by live physics",
	)
	assert_true(player.try_dive_underwater())
	assert_eq(state_machine.current_state(), PlayerStateMachine.STATE_SWIM_UNDERWATER)
	assert_true(player.try_surface_from_underwater())
	assert_eq(state_machine.current_state(), PlayerStateMachine.STATE_SWIM_SURFACE)
	assert_true(state_machine.change_state(PlayerStateMachine.STATE_GROUND))

	# Leave the water and walk on the connected support walkway to a material panel.
	player.global_position = Vector3(8.0, 0.0, 6.5)
	await _await_player_grounded(player)
	Input.action_press(&"move_backward")
	for _frame: int in 90:
		await get_tree().physics_frame
	Input.action_release(&"move_backward")
	Input.action_press(&"move_right")
	for _frame: int in 45:
		await get_tree().physics_frame
	Input.action_release(&"move_right")
	assert_true(player.is_on_floor(), "The material sample walkway must remain physically reachable")
	assert_gte(player.global_position.x, 9.5)
	assert_lte(player.global_position.x, 10.75)
	assert_gte(player.global_position.z, 9.75)
	assert_lte(player.global_position.z, 11.25)
	var floor_hit := _floor_hit_below(player)
	assert_false(floor_hit.is_empty(), "The reachable material sample must have a world support hit")
	var floor_body := floor_hit.get(&"collider") as Node
	assert_not_null(floor_body)
	assert_eq(floor_body.get_meta(&"floor_material", &""), &"shallow_water")


func _add_gym() -> MovementGym:
	var scene := load(GYM_SCENE_PATH) as PackedScene
	assert_not_null(scene)
	var gym := scene.instantiate() as MovementGym
	add_child_autofree(gym)
	return gym


func _await_player_grounded(player: PlayerController) -> void:
	for _frame: int in 20:
		await get_tree().physics_frame
		if player.is_on_floor():
			return
	assert_true(player.is_on_floor())


func _floor_hit_below(player: PlayerController) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(
		player.global_position + Vector3.UP,
		player.global_position + Vector3.DOWN * 2.0,
		PlayerController.WORLD_COLLISION_MASK,
		[player.get_rid()],
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return player.get_world_3d().direct_space_state.intersect_ray(query)
