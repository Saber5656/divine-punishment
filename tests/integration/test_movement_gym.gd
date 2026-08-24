extends GutTest


const GYM_SCENE_PATH := "res://src/levels/gym/movement_gym.tscn"
const MOVEMENT_CONFIG_PATH := "res://data/tuning/movement.tres"


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
	player.set_physics_process(false)

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
	assert_true(player.try_exit_crawlspace(crawl_entrance))
	assert_eq(state_machine.current_state(), PlayerStateMachine.STATE_CROUCH)

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
	await get_tree().physics_frame
	assert_true(player.try_enter_water(water_volume))
	assert_eq(state_machine.current_state(), PlayerStateMachine.STATE_SWIM_SURFACE)
	assert_true(player.try_dive_underwater())
	assert_eq(state_machine.current_state(), PlayerStateMachine.STATE_SWIM_UNDERWATER)
	assert_true(player.try_surface_from_underwater())
	assert_eq(state_machine.current_state(), PlayerStateMachine.STATE_SWIM_SURFACE)


func _add_gym() -> MovementGym:
	var scene := load(GYM_SCENE_PATH) as PackedScene
	assert_not_null(scene)
	var gym := scene.instantiate() as MovementGym
	add_child_autofree(gym)
	return gym


func _await_player_grounded(player: PlayerController) -> void:
	for _frame: int in 8:
		await get_tree().physics_frame
		if player.is_on_floor():
			return
	assert_true(player.is_on_floor())
