extends GutTest


const PLAYER_SCENE_PATH := "res://src/player/player.tscn"


func after_each() -> void:
	for action: StringName in [
		&"interact",
		&"move_forward",
		&"move_backward",
		&"move_left",
		&"move_right",
	]:
		Input.action_release(action)


func test_player_enters_and_exits_crawlspace_through_explicit_entrance() -> void:
	var entrance := _add_entrance(Vector3.ZERO, Vector3(0.0, 0.0, -1.0))
	var player := _add_player(entrance.outside_world_position())
	var collision := player.collision_shape.shape as CapsuleShape3D

	assert_true(player.try_enter_crawlspace(entrance))
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_CRAWLSPACE)
	assert_eq(player.state_machine.stance(), Enums.Stance.CRAWL)
	assert_eq(player.active_crawl_entrance(), entrance)
	assert_eq(player.global_position, entrance.inside_world_position())
	assert_almost_eq(collision.height, player.crawl_capsule_height, 0.0001)
	assert_almost_eq(player.camera_rig.posture_drop(), player.crawl_camera_drop, 0.0001)

	assert_true(player.try_exit_crawlspace(entrance))
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_CROUCH)
	assert_null(player.active_crawl_entrance())
	assert_eq(player.global_position, entrance.outside_world_position())
	assert_almost_eq(collision.height, player.crouch_capsule_height, 0.0001)
	assert_almost_eq(player.camera_rig.posture_drop(), 0.0, 0.0001)


func test_crawlspace_uses_crawl_tuning_for_planar_movement_and_keeps_camera_look() -> void:
	var entrance := _add_entrance(Vector3.ZERO, Vector3(0.0, 0.0, -1.0))
	var player := _add_player(entrance.outside_world_position())
	assert_true(player.try_enter_crawlspace(entrance))
	assert_eq(player.current_movement_params(), {
		&"speed": 1.0,
		&"noise_radius": 1.0,
		&"visibility_mod": 0.3,
	})

	Input.action_press(&"move_forward")
	player._apply_movement()
	assert_almost_eq(Vector2(player.velocity.x, player.velocity.z).length(), 1.0, 0.0001)
	var posture_before := player.camera_rig.posture_drop()
	var motion := InputEventMouseMotion.new()
	motion.screen_relative = Vector2(20.0, -10.0)
	player._unhandled_input(motion)
	assert_false(is_equal_approx(player.rotation.y, 0.0))
	assert_false(is_equal_approx(player.camera_rig.rotation.x, 0.0))
	assert_almost_eq(player.camera_rig.posture_drop(), posture_before, 0.0001)


func test_interact_discovers_entrance_at_each_endpoint() -> void:
	var entrance := _add_entrance(Vector3.ZERO, Vector3(0.0, 0.0, -1.0))
	var player := _add_player(entrance.outside_world_position())
	await get_tree().physics_frame

	Input.action_press(&"interact")
	player._update_state_from_input()
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_CRAWLSPACE)
	Input.action_release(&"interact")
	player._update_state_from_input()
	Input.action_press(&"interact")
	player._update_state_from_input()
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_CROUCH)
	assert_eq(player.global_position, entrance.outside_world_position())


func test_crawlspace_rejects_non_exit_state_changes_until_an_exit_is_used() -> void:
	var entrance := _add_entrance(Vector3.ZERO, Vector3(0.0, 0.0, -1.0))
	var player := _add_player(entrance.outside_world_position())
	assert_true(player.try_enter_crawlspace(entrance))
	player.global_position += Vector3.RIGHT * (entrance.entry_radius + 0.1)

	assert_false(player.state_machine.change_state(PlayerStateMachine.STATE_SPRINT))
	assert_false(player.state_machine.change_state(PlayerStateMachine.STATE_GROUND))
	Input.action_press(&"interact")
	player._update_state_from_input()
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_CRAWLSPACE)
	assert_false(player.try_exit_crawlspace(entrance))


func test_entry_and_exit_fail_closed_when_destination_clearance_is_blocked() -> void:
	var entrance := _add_entrance(Vector3.ZERO, Vector3(0.0, 0.0, -1.0))
	var player := _add_player(entrance.outside_world_position())
	var inside_blocker := _add_world_blocker(entrance.inside_world_position(), Vector3.ONE)
	await get_tree().physics_frame
	assert_false(player.try_enter_crawlspace(entrance))
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_GROUND)
	inside_blocker.free()
	await get_tree().physics_frame
	assert_true(player.try_enter_crawlspace(entrance))

	var outside_blocker := _add_world_blocker(entrance.outside_world_position(), Vector3.ONE)
	await get_tree().physics_frame
	var crawl_position := player.global_position
	assert_false(player.try_exit_crawlspace(entrance))
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_CRAWLSPACE)
	assert_eq(player.global_position, crawl_position)
	outside_blocker.free()


func test_mid_passage_blocker_rejects_entry_and_exit_with_clear_endpoints() -> void:
	var entrance := _add_entrance(Vector3.ZERO, Vector3(0.0, 0.0, -2.0))
	var player := _add_player(entrance.outside_world_position())
	player.set_physics_process(false)
	var blocker_position := Vector3(0.0, -0.55, -1.0)
	var blocker_size := Vector3(1.0, 0.7, 0.2)
	var blocker := _add_world_blocker(blocker_position, blocker_size)
	await get_tree().physics_frame

	var entry_position := player.global_position
	var entry_velocity := player.velocity
	assert_true(player._has_capsule_clearance_at(
		player.crawl_capsule_height,
		entrance.outside_world_position(),
	))
	assert_true(player._has_capsule_clearance_at(
		player.crawl_capsule_height,
		entrance.inside_world_position(),
	))
	assert_false(player.try_enter_crawlspace(entrance))
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_GROUND)
	assert_eq(player.global_position, entry_position)
	assert_null(player.active_crawl_entrance())
	assert_eq(player.velocity, entry_velocity)

	blocker.free()
	await get_tree().physics_frame
	assert_true(player.try_enter_crawlspace(entrance))
	blocker = _add_world_blocker(blocker_position, blocker_size)
	await get_tree().physics_frame
	var crawl_position := player.global_position
	var crawl_posture := player.camera_rig.posture_drop()
	var crawl_velocity := player.velocity
	assert_true(player._has_capsule_clearance_at(player.crawl_capsule_height, crawl_position))
	assert_true(player._has_capsule_clearance_at(
		player.crouch_capsule_height,
		entrance.outside_world_position(),
	))
	assert_false(player.try_exit_crawlspace(entrance))
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_CRAWLSPACE)
	assert_eq(player.global_position, crawl_position)
	assert_eq(player.active_crawl_entrance(), entrance)
	assert_almost_eq(player.camera_rig.posture_drop(), crawl_posture, 0.0001)
	assert_eq(player.velocity, crawl_velocity)
	blocker.free()


func test_deleted_active_crawl_entrance_recovers_to_crouch() -> void:
	var entrance := _add_entrance(Vector3.ZERO, Vector3(0.0, 0.0, -1.0))
	var player := _add_player(entrance.outside_world_position())
	var outside_position := entrance.outside_world_position()
	assert_true(player.try_enter_crawlspace(entrance))

	entrance.free()
	assert_true(player._maintain_crawlspace_contract())
	_assert_crawl_recovered(player, outside_position)


func test_detached_and_reattached_active_crawl_entrance_recovers_to_crouch() -> void:
	var entrance := _add_entrance(Vector3.ZERO, Vector3(0.0, 0.0, -1.0))
	var player := _add_player(entrance.outside_world_position())
	var outside_position := entrance.outside_world_position()
	assert_true(player.try_enter_crawlspace(entrance))

	remove_child(entrance)
	add_child(entrance)
	assert_true(player._maintain_crawlspace_contract())
	_assert_crawl_recovered(player, outside_position)


func test_active_crawl_entrance_geometry_and_layer_mutations_recover() -> void:
	var entrance := _add_entrance(Vector3.ZERO, Vector3(0.0, 0.0, -1.0))
	var player := _add_player(entrance.outside_world_position())
	var outside_position := entrance.outside_world_position()
	assert_true(player.try_enter_crawlspace(entrance))

	entrance.inside_offset = Vector3(0.0, 0.0, -2.0)
	assert_true(player._maintain_crawlspace_contract())
	_assert_crawl_recovered(player, outside_position)

	player.global_position = entrance.outside_world_position()
	assert_true(player.try_enter_crawlspace(entrance))
	outside_position = entrance.outside_world_position()
	entrance.position += Vector3.RIGHT * 0.25
	assert_true(player._maintain_crawlspace_contract())
	_assert_crawl_recovered(player, outside_position)

	entrance.position = outside_position
	player.global_position = entrance.outside_world_position()
	assert_true(player.try_enter_crawlspace(entrance))
	entrance.collision_layer = 0
	assert_true(player._maintain_crawlspace_contract())
	_assert_crawl_recovered(player, outside_position)

	entrance.collision_layer = CrawlEntrance.CRAWL_MARKER_LAYER
	player.global_position = entrance.outside_world_position()
	assert_true(player.try_enter_crawlspace(entrance))
	entrance.entry_radius = 1.0
	assert_true(player._maintain_crawlspace_contract())
	_assert_crawl_recovered(player, outside_position)

	entrance.entry_radius = 0.75
	player.global_position = entrance.outside_world_position()
	assert_true(player.try_enter_crawlspace(entrance))
	entrance.collision_mask = 0
	assert_false(player.try_exit_crawlspace(entrance))
	_assert_crawl_recovered(player, outside_position)


func test_active_crawl_configuration_mutation_recovers_to_crouch() -> void:
	var entrance := _add_entrance(Vector3.ZERO, Vector3(0.0, 0.0, -1.0))
	var player := _add_player(entrance.outside_world_position())
	var outside_position := entrance.outside_world_position()
	assert_true(player.try_enter_crawlspace(entrance))

	player.crawl_camera_drop = INF
	assert_true(player._maintain_crawlspace_contract())
	_assert_crawl_recovered(player, outside_position)

	player.crawl_camera_drop = 0.9
	player.global_position = entrance.outside_world_position()
	assert_true(player.try_enter_crawlspace(entrance))
	player.crawl_capsule_height = 0.8
	assert_true(player._maintain_crawlspace_contract())
	_assert_crawl_recovered(player, outside_position)


func test_invalid_crawl_configuration_and_marker_mutation_are_rejected() -> void:
	var entrance := _add_entrance(Vector3.ZERO, Vector3(0.0, 0.0, -1.0))
	var player := _add_player(entrance.outside_world_position())
	player.crawl_camera_drop = INF
	assert_false(player.try_enter_crawlspace(entrance))
	player.crawl_camera_drop = 0.9
	entrance.collision_mask = 0
	assert_false(player.try_enter_crawlspace(entrance))
	entrance.collision_mask = CrawlEntrance.PLAYER_BODY_LAYER
	entrance.inside_offset = Vector3(NAN, 0.0, 0.0)
	assert_false(player.try_enter_crawlspace(entrance))


func test_nearest_valid_crawl_entrance_wins_overlap() -> void:
	var farther := _add_entrance(Vector3(0.3, 0.0, 0.0), Vector3(0.0, 0.0, -1.0))
	var nearer := _add_entrance(Vector3(0.1, 0.0, 0.0), Vector3(0.0, 0.0, -2.0))
	var player := _add_player(Vector3.ZERO)
	await get_tree().physics_frame

	assert_true(player.try_enter_crawlspace())
	assert_eq(player.active_crawl_entrance(), nearer)
	assert_eq(player.global_position, nearer.inside_world_position())
	assert_ne(player.active_crawl_entrance(), farther)


func test_crawl_candidate_search_fails_closed_above_nearby_budget() -> void:
	for index: int in PlayerController.MAX_CRAWL_ENTRANCE_CANDIDATES + 1:
		_add_entrance(Vector3.ZERO, Vector3(0.0, 0.0, -1.0 - float(index) * 0.01))
	var player := _add_player(Vector3.ZERO)
	await get_tree().physics_frame

	assert_false(player.try_enter_crawlspace())
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_GROUND)


func test_crawl_candidate_search_accepts_exact_nearby_budget() -> void:
	for index: int in PlayerController.MAX_CRAWL_ENTRANCE_CANDIDATES:
		_add_entrance(Vector3.ZERO, Vector3(0.0, 0.0, -1.0 - float(index) * 0.01))
	var player := _add_player(Vector3.ZERO)
	await get_tree().physics_frame

	assert_true(player.try_enter_crawlspace())
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_CRAWLSPACE)


func test_crawl_candidate_budget_deduplicates_overlapping_endpoint_shapes() -> void:
	for _index: int in PlayerController.MAX_CRAWL_ENTRANCE_CANDIDATES:
		var entrance := _add_entrance(Vector3.ZERO, Vector3(0.0, 0.0, -0.5))
		entrance.entry_radius = CrawlEntrance.MAX_ENTRY_RADIUS
	var player := _add_player(Vector3.ZERO)
	await get_tree().physics_frame

	assert_true(player.try_enter_crawlspace())
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_CRAWLSPACE)


func test_crawl_candidate_budget_rejects_too_many_unique_overlapping_markers() -> void:
	for _index: int in PlayerController.MAX_CRAWL_ENTRANCE_CANDIDATES + 1:
		var entrance := _add_entrance(Vector3.ZERO, Vector3(0.0, 0.0, -0.5))
		entrance.entry_radius = CrawlEntrance.MAX_ENTRY_RADIUS
	var player := _add_player(Vector3.ZERO)
	await get_tree().physics_frame

	assert_false(player.try_enter_crawlspace())
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_GROUND)


func test_crawl_spatial_query_fails_closed_above_raw_result_budget() -> void:
	for index: int in PlayerController.MAX_CRAWL_ENTRANCE_SPATIAL_RESULTS + 1:
		var forged := Area3D.new()
		forged.name = StringName("Forged%d" % index)
		forged.collision_layer = CrawlEntrance.CRAWL_MARKER_LAYER
		forged.collision_mask = CrawlEntrance.PLAYER_BODY_LAYER
		var collision := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.5
		collision.shape = sphere
		forged.add_child(collision)
		add_child_autofree(forged)
	_add_entrance(Vector3.ZERO, Vector3(0.0, 0.0, -1.0))
	var player := _add_player(Vector3.ZERO)
	await get_tree().physics_frame

	assert_false(player.try_enter_crawlspace())
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_GROUND)


func _add_player(world_position: Vector3) -> PlayerController:
	var player := (load(PLAYER_SCENE_PATH) as PackedScene).instantiate() as PlayerController
	player.position = world_position
	add_child_autofree(player)
	return player


func _add_entrance(world_position: Vector3, inside_offset: Vector3) -> CrawlEntrance:
	var entrance := CrawlEntrance.new()
	entrance.position = world_position
	entrance.inside_offset = inside_offset
	add_child_autofree(entrance)
	return entrance


func _add_world_blocker(world_position: Vector3, size: Vector3) -> StaticBody3D:
	var blocker := StaticBody3D.new()
	blocker.collision_layer = PlayerController.WORLD_COLLISION_MASK
	blocker.collision_mask = 0
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	blocker.add_child(collision)
	blocker.position = world_position
	add_child_autofree(blocker)
	return blocker


func _assert_crawl_recovered(player: PlayerController, outside_position: Vector3) -> void:
	var collision := player.collision_shape.shape as CapsuleShape3D
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_CROUCH)
	assert_eq(player.global_position, outside_position)
	assert_true(PlayerCrawlRules.is_safe_world_position(player.global_position))
	assert_null(player.active_crawl_entrance())
	assert_eq(player.velocity, Vector3.ZERO)
	assert_almost_eq(collision.height, player.crouch_capsule_height, 0.0001)
	assert_almost_eq(player.camera_rig.posture_drop(), 0.0, 0.0001)
