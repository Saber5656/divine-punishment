extends GutTest


const PLAYER_SCENE_PATH := "res://src/player/player.tscn"
const DEFAULT_PROFILE_PATH := "res://data/profiles/default.tres"


func after_each() -> void:
	Input.action_release(&"stance_toggle")
	Input.action_release(&"move_forward")
	Input.action_release(&"move_backward")
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")


func test_player_switches_between_surface_and_underwater_swim_states() -> void:
	var volume := _add_volume()
	var player := _add_player(_surface_start(volume))
	player.set_physics_process(false)
	var capsule := player.collision_shape.shape as CapsuleShape3D
	var camera_rotation := player.camera_rig.rotation
	var camera_peek := player.camera_peek_offset()

	assert_true(player.try_enter_water(volume))
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_SWIM_SURFACE)
	assert_eq(player.state_machine.stance(), Enums.Stance.SWIM)
	assert_eq(player.current_movement_params(), {
		&"speed": 1.2,
		&"noise_radius": 0.0,
		&"visibility_mod": 0.2,
	})
	assert_eq(player.global_position, volume.surface_body_position_for(player.global_position))
	assert_almost_eq(capsule.height, player.swim_capsule_height, 0.0001)
	assert_true(player.player_model.visible)
	assert_false(player.surface_ripples.visible)
	assert_false(player.swim_hud.is_breath_gauge_visible())
	Input.action_press(&"move_forward")
	player._apply_movement()
	assert_almost_eq(Vector2(player.velocity.x, player.velocity.z).length(), 1.2, 0.0001)
	Input.action_release(&"move_forward")

	assert_true(player.try_dive_underwater())
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_SWIM_UNDERWATER)
	assert_eq(player.global_position, volume.underwater_body_position_for(player.global_position))
	assert_false(player.player_model.visible)
	assert_true(player.surface_ripples.visible)
	assert_true(player.swim_hud.is_breath_gauge_visible())
	assert_true(player.swim_hud.is_ripple_cue_visible())
	assert_almost_eq(player.swim_hud.breath_ratio(), 1.0, 0.0001)
	Input.action_press(&"move_forward")
	player._apply_movement()
	assert_almost_eq(Vector2(player.velocity.x, player.velocity.z).length(), 1.2, 0.0001)
	Input.action_release(&"move_forward")

	player._update_breath(5.0)
	assert_almost_eq(player.breath_remaining(), 15.0, 0.0001)
	assert_almost_eq(player.swim_hud.breath_ratio(), 0.75, 0.0001)
	assert_true(player.try_surface_from_underwater())
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_SWIM_SURFACE)
	assert_almost_eq(player.breath_remaining(), 20.0, 0.0001)
	assert_true(player.player_model.visible)
	assert_false(player.surface_ripples.visible)
	assert_false(player.swim_hud.is_breath_gauge_visible())
	assert_false(player.swim_hud.is_ripple_cue_visible())
	assert_eq(player.camera_rig.rotation, camera_rotation)
	assert_eq(player.camera_peek_offset(), camera_peek)


func test_stance_toggle_drives_dive_and_manual_surface() -> void:
	var volume := _add_volume()
	var player := _add_player(_surface_start(volume))
	player.set_physics_process(false)
	assert_true(player.try_enter_water(volume))

	_send_action_event(player, &"stance_toggle", true)
	player._update_state_from_input()
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_SWIM_UNDERWATER)
	_send_action_event(player, &"stance_toggle", false)
	player._update_state_from_input()
	_send_action_event(player, &"stance_toggle", true)
	player._update_state_from_input()
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_SWIM_SURFACE)


func test_stance_tap_between_physics_ticks_is_not_dropped() -> void:
	var volume := _add_volume()
	var player := _add_player(_surface_start(volume))
	player.set_physics_process(false)
	assert_true(player.try_enter_water(volume))

	_send_action_event(player, &"stance_toggle", true)
	_send_action_event(player, &"stance_toggle", false)
	player._update_state_from_input()

	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_SWIM_UNDERWATER)


func test_breath_exhaustion_forces_surface_and_emits_one_larger_noise() -> void:
	var volume := _add_volume()
	var profile := (load(DEFAULT_PROFILE_PATH) as PlayerProfile).duplicate(true) as PlayerProfile
	profile.breath_seconds = 0.1
	var player := _add_player(_surface_start(volume), profile)
	player.set_physics_process(false)
	var events: Array[NoiseEvent] = []
	var capture := func(event: NoiseEvent) -> void: events.append(event)
	EventBus.noise_emitted.connect(capture)

	assert_true(player.try_enter_water(volume))
	assert_true(player.try_dive_underwater())
	player._update_breath(0.1)
	EventBus.noise_emitted.disconnect(capture)

	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_SWIM_SURFACE)
	assert_false(player.is_forced_surfacing())
	assert_eq(events.size(), 1)
	assert_eq(events[0].kind, Enums.NoiseKind.LANDING)
	assert_eq(events[0].radius, 12.0)
	assert_gt(events[0].radius, player.state_machine.swim_noise_radius())
	assert_eq(events[0].source, player)


func test_twenty_second_breath_cycle_emits_once_per_dive() -> void:
	var volume := _add_volume()
	var player := _add_player(_surface_start(volume))
	player.set_physics_process(false)
	var events: Array[NoiseEvent] = []
	var capture := func(event: NoiseEvent) -> void: events.append(event)
	EventBus.noise_emitted.connect(capture)

	assert_true(player.try_enter_water(volume))
	assert_true(player.try_dive_underwater())
	player._update_breath(10.0)
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_SWIM_UNDERWATER)
	assert_eq(events.size(), 0)
	player._update_breath(10.0)
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_SWIM_SURFACE)
	assert_eq(events.size(), 1)

	assert_true(player.try_dive_underwater())
	assert_almost_eq(player.breath_remaining(), 20.0, 0.0001)
	player._update_breath(20.0)
	EventBus.noise_emitted.disconnect(capture)
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_SWIM_SURFACE)
	assert_eq(events.size(), 2)


func test_blocked_forced_surface_stays_underwater_and_retries_without_duplicate_noise() -> void:
	var volume := _add_volume()
	var profile := (load(DEFAULT_PROFILE_PATH) as PlayerProfile).duplicate(true) as PlayerProfile
	profile.breath_seconds = 0.1
	var player := _add_player(_surface_start(volume), profile)
	player.set_physics_process(false)
	assert_true(player.try_enter_water(volume))
	assert_true(player.try_dive_underwater())
	var underwater_position := player.global_position
	var surface_position := volume.surface_body_position_for(underwater_position)
	var blocker_position := Vector3(
		underwater_position.x,
		(underwater_position.y + surface_position.y - player.swim_capsule_height) * 0.5,
		underwater_position.z,
	)
	var blocker := _add_world_blocker(
		blocker_position,
		Vector3(2.0, 0.2, 2.0),
	)
	await get_tree().physics_frame
	assert_true(player._has_capsule_clearance_at(player.swim_capsule_height, underwater_position))
	assert_true(player._has_capsule_clearance_at(player.swim_capsule_height, surface_position))
	assert_false(player._has_capsule_path_clear(
		player.swim_capsule_height,
		underwater_position,
		surface_position,
		PlayerController.MAX_WATER_SWEEP_DISTANCE,
	))
	var events: Array[NoiseEvent] = []
	var capture := func(event: NoiseEvent) -> void: events.append(event)
	EventBus.noise_emitted.connect(capture)

	player._update_breath(0.1)
	player._update_breath(1.0)
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_SWIM_UNDERWATER)
	assert_true(player.is_forced_surfacing())
	assert_eq(player.global_position, underwater_position)
	assert_eq(events.size(), 1)

	blocker.free()
	await get_tree().physics_frame
	player._update_breath(0.1)
	EventBus.noise_emitted.disconnect(capture)
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_SWIM_SURFACE)
	assert_false(player.is_forced_surfacing())
	assert_eq(events.size(), 1)


func test_forced_surface_endpoint_obstruction_stays_underwater_until_clear() -> void:
	var volume := _add_volume()
	var profile := (load(DEFAULT_PROFILE_PATH) as PlayerProfile).duplicate(true) as PlayerProfile
	profile.breath_seconds = 0.1
	var player := _add_player(_surface_start(volume), profile)
	player.set_physics_process(false)
	assert_true(player.try_enter_water(volume))
	assert_true(player.try_dive_underwater())
	var underwater_position := player.global_position
	var surface_position := volume.surface_body_position_for(underwater_position)
	var blocker := _add_world_blocker(
		surface_position - Vector3.UP * 0.1,
		Vector3(1.0, 0.2, 1.0),
	)
	await get_tree().physics_frame
	assert_false(player._has_capsule_clearance_at(player.swim_capsule_height, surface_position))

	player._update_breath(0.1)
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_SWIM_UNDERWATER)
	assert_true(player.is_forced_surfacing())
	assert_eq(player.global_position, underwater_position)

	blocker.free()
	await get_tree().physics_frame
	player._update_breath(0.1)
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_SWIM_SURFACE)
	assert_false(player.is_forced_surfacing())


func test_water_membership_enters_automatically_and_exits_at_the_boundary() -> void:
	var volume := _add_volume()
	var player := _add_player(_surface_start(volume))
	player.set_physics_process(false)
	await get_tree().physics_frame

	player._refresh_water_membership()
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_SWIM_SURFACE)
	assert_eq(player.active_water_volume(), volume)

	player.global_position.x = volume.global_position.x + volume.size.x
	player._refresh_water_membership()
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_GROUND)
	assert_null(player.active_water_volume())


func test_crouch_and_sprint_auto_enter_but_crawl_and_climb_do_not() -> void:
	for entry_state: StringName in [
		PlayerStateMachine.STATE_CROUCH,
		PlayerStateMachine.STATE_SPRINT,
	]:
		var volume := _add_volume()
		var player := _add_player(_surface_start(volume))
		player.set_physics_process(false)
		assert_true(player.state_machine.change_state(entry_state))
		await get_tree().physics_frame
		player._refresh_water_membership()
		assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_SWIM_SURFACE)
		player.free()
		volume.free()

	for blocked_state: StringName in [
		PlayerStateMachine.STATE_CRAWLSPACE,
		PlayerStateMachine.STATE_CLIMB,
	]:
		var volume := _add_volume()
		var player := _add_player(_surface_start(volume))
		player.set_physics_process(false)
		assert_true(player.state_machine.change_state(blocked_state))
		await get_tree().physics_frame
		player._refresh_water_membership()
		assert_eq(player.state_machine.current_state(), blocked_state)
		assert_null(player.active_water_volume())
		player.free()
		volume.free()


func test_swim_configuration_rejects_a_non_larger_exhaustion_noise() -> void:
	var volume := _add_volume()
	var profile := (load(DEFAULT_PROFILE_PATH) as PlayerProfile).duplicate(true) as PlayerProfile
	profile.noise_radii[Enums.Stance.SPRINT] = profile.noise_radii[Enums.Stance.SWIM]
	var player := _add_player(_surface_start(volume), profile)
	player.set_physics_process(false)

	assert_false(player.try_enter_water(volume))
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_GROUND)


func test_swim_configuration_rejects_invalid_speed_before_entry() -> void:
	for invalid_speed: float in [
		NAN,
		INF,
		-0.01,
		PlayerSwimRules.MAX_SWIM_SPEED + 0.01,
	]:
		var volume := _add_volume()
		var profile := (load(DEFAULT_PROFILE_PATH) as PlayerProfile).duplicate(true) as PlayerProfile
		profile.move_speeds[Enums.Stance.SWIM] = invalid_speed
		var player := _add_player(_surface_start(volume), profile)
		player.set_physics_process(false)
		assert_false(player.try_enter_water(volume))
		assert_eq(player.velocity, Vector3.ZERO)
		assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_GROUND)
		player.free()
		volume.free()


func test_active_swim_speed_mutation_fails_closed() -> void:
	var volume := _add_volume()
	var profile := (load(DEFAULT_PROFILE_PATH) as PlayerProfile).duplicate(true) as PlayerProfile
	var player := _add_player(_surface_start(volume), profile)
	player.set_physics_process(false)
	assert_true(player.try_enter_water(volume))
	assert_true(player.try_dive_underwater())
	player.velocity = Vector3(1.0, 2.0, 3.0)

	profile.move_speeds[Enums.Stance.SWIM] = INF
	player._refresh_water_membership()
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_GROUND)
	assert_eq(player.velocity, Vector3.ZERO)
	assert_null(player.active_water_volume())


func test_active_swim_capsule_mutation_keeps_last_valid_compact_shape_when_blocked() -> void:
	var volume := _add_volume()
	var player := _add_player(_surface_start(volume))
	player.set_physics_process(false)
	assert_true(player.try_enter_water(volume))
	assert_true(player.try_dive_underwater())
	var capsule := player.collision_shape.shape as CapsuleShape3D
	var captured_height := capsule.height
	var blocker := _add_low_overhead_blocker(player.global_position)
	await get_tree().physics_frame

	player.swim_capsule_height = INF
	player._refresh_water_membership()
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_SWIM_UNDERWATER)
	assert_true(player.is_water_recovery_pending())
	assert_almost_eq(capsule.height, captured_height, 0.0001)
	assert_eq(player.velocity, Vector3.ZERO)

	blocker.free()
	await get_tree().physics_frame
	player._refresh_water_membership()
	_assert_water_recovered_to_ground(player)


func test_water_discovery_is_bounded_and_deduplicates_instances() -> void:
	var volume := _add_volume()
	for index: int in 4:
		var extra_collision := CollisionShape3D.new()
		var extra_box := BoxShape3D.new()
		extra_box.size = volume.size
		extra_collision.shape = extra_box
		volume.add_child(extra_collision)
	var player := _add_player(_surface_start(volume))
	player.set_physics_process(false)
	await get_tree().physics_frame
	assert_eq(player._nearest_water_volume(), volume)

	for index: int in PlayerController.MAX_WATER_VOLUME_CANDIDATES:
		_add_volume()
	await get_tree().physics_frame
	assert_null(player._nearest_water_volume())


func test_water_discovery_accepts_exact_unique_candidate_budget() -> void:
	for _index: int in PlayerController.MAX_WATER_VOLUME_CANDIDATES:
		_add_volume()
	var player := _add_player(Vector3(0.0, 3.25, 0.0))
	player.set_physics_process(false)
	await get_tree().physics_frame
	assert_not_null(player._nearest_water_volume())


func test_raw_water_query_overflow_fails_closed() -> void:
	var volume := _add_volume()
	for index: int in PlayerController.MAX_WATER_VOLUME_SPATIAL_RESULTS:
		var extra_collision := CollisionShape3D.new()
		var extra_box := BoxShape3D.new()
		extra_box.size = volume.size
		extra_collision.shape = extra_box
		volume.add_child(extra_collision)
	var player := _add_player(_surface_start(volume))
	player.set_physics_process(false)
	await get_tree().physics_frame
	assert_null(player._nearest_water_volume())


func test_raw_water_query_accepts_exact_spatial_result_budget() -> void:
	var volume := _add_volume()
	for _index: int in PlayerController.MAX_WATER_VOLUME_SPATIAL_RESULTS - 1:
		var extra_collision := CollisionShape3D.new()
		var extra_box := BoxShape3D.new()
		extra_box.size = volume.size
		extra_collision.shape = extra_box
		volume.add_child(extra_collision)
	var player := _add_player(_surface_start(volume))
	player.set_physics_process(false)
	await get_tree().physics_frame
	assert_eq(player._nearest_water_volume(), volume)


func test_active_water_contract_mutation_aborts_to_ground() -> void:
	var volume := _add_volume()
	var player := _add_player(_surface_start(volume))
	player.set_physics_process(false)
	assert_true(player.try_enter_water(volume))
	assert_true(player.try_dive_underwater())

	volume.underwater_body_depth += 0.25
	player._refresh_water_membership()
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_GROUND)
	assert_null(player.active_water_volume())
	assert_true(player.player_model.visible)
	assert_false(player.surface_ripples.visible)
	assert_false(player.swim_hud.is_breath_gauge_visible())


func test_active_water_contract_rejects_transform_layer_mask_shape_and_disabled_mutations() -> void:
	for mutation: StringName in [&"transform", &"layer", &"mask", &"shape", &"disabled"]:
		var volume := _add_volume()
		var player := _add_player(_surface_start(volume))
		player.set_physics_process(false)
		assert_true(player.try_enter_water(volume))
		assert_true(player.try_dive_underwater())
		var collision := volume.get_node(
			NodePath(String(WaterVolume.VOLUME_SHAPE_NODE_NAME)),
		) as CollisionShape3D
		match mutation:
			&"transform":
				volume.position += Vector3.RIGHT * 0.25
			&"layer":
				volume.collision_layer = 0
			&"mask":
				volume.collision_mask = 0
			&"shape":
				var replacement := BoxShape3D.new()
				replacement.size = volume.size
				collision.shape = replacement
			&"disabled":
				collision.disabled = true
		player._refresh_water_membership()
		_assert_water_recovered_to_ground(player)
		player.free()
		volume.free()


func test_deleted_active_water_volume_recovers_to_ground() -> void:
	var volume := _add_volume()
	var player := _add_player(_surface_start(volume))
	player.set_physics_process(false)
	assert_true(player.try_enter_water(volume))
	assert_true(player.try_dive_underwater())

	volume.free()
	player._refresh_water_membership()
	_assert_water_recovered_to_ground(player)


func test_detached_and_reattached_active_water_volume_recovers_to_ground() -> void:
	var volume := _add_volume()
	var player := _add_player(_surface_start(volume))
	player.set_physics_process(false)
	assert_true(player.try_enter_water(volume))
	assert_true(player.try_dive_underwater())

	remove_child(volume)
	add_child(volume)
	player._refresh_water_membership()
	_assert_water_recovered_to_ground(player)


func test_invalid_marker_keeps_compact_capsule_until_standing_clearance_returns() -> void:
	var volume := _add_volume()
	var player := _add_player(_surface_start(volume))
	player.set_physics_process(false)
	assert_true(player.try_enter_water(volume))
	assert_true(player.try_dive_underwater())
	var capsule := player.collision_shape.shape as CapsuleShape3D
	var blocker := _add_low_overhead_blocker(player.global_position)
	await get_tree().physics_frame
	assert_true(player._has_capsule_clearance_at(player.swim_capsule_height, player.global_position))
	assert_false(player._has_capsule_clearance_at(player._standing_capsule_height, player.global_position))

	volume.collision_mask = 0
	player._refresh_water_membership()
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_SWIM_UNDERWATER)
	assert_true(player.is_water_recovery_pending())
	assert_null(player.active_water_volume())
	assert_eq(player.velocity, Vector3.ZERO)
	assert_almost_eq(capsule.height, player.swim_capsule_height, 0.0001)

	blocker.free()
	await get_tree().physics_frame
	player._refresh_water_membership()
	_assert_water_recovered_to_ground(player)


func test_boundary_exit_keeps_compact_capsule_until_standing_clearance_returns() -> void:
	var volume := _add_volume()
	var player := _add_player(_surface_start(volume))
	player.set_physics_process(false)
	assert_true(player.try_enter_water(volume))
	player.global_position.x = volume.global_position.x + volume.size.x
	var capsule := player.collision_shape.shape as CapsuleShape3D
	var blocker := _add_low_overhead_blocker(player.global_position)
	await get_tree().physics_frame

	player._refresh_water_membership()
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_SWIM_SURFACE)
	assert_true(player.is_water_recovery_pending())
	assert_null(player.active_water_volume())
	assert_almost_eq(capsule.height, player.swim_capsule_height, 0.0001)

	blocker.free()
	await get_tree().physics_frame
	player._refresh_water_membership()
	_assert_water_recovered_to_ground(player)


func test_swim_motion_restores_the_state_depth_and_stays_planar_at_a_slope() -> void:
	var volume := _add_volume()
	var player := _add_player(_surface_start(volume))
	player.set_physics_process(false)
	assert_true(player.try_enter_water(volume))
	assert_true(player.try_dive_underwater())
	var expected_y := player.global_position.y
	player.global_position.y += 0.25
	player._move_swimming(0.0)
	assert_almost_eq(player.global_position.y, expected_y, 0.0001)

	var ramp := _add_world_blocker(
		Vector3(player.global_position.x, expected_y - 0.9, player.global_position.z - 1.0),
		Vector3(2.0, 0.2, 2.0),
	)
	ramp.rotation.x = -PI * 0.2
	await get_tree().physics_frame
	var start_z := player.global_position.z
	Input.action_press(&"move_forward")
	player._apply_movement()
	player._move_swimming(1.0)
	Input.action_release(&"move_forward")
	assert_almost_eq(player.global_position.y, expected_y, 0.0001)
	var travelled := absf(player.global_position.z - start_z)
	assert_gt(travelled, 0.0)
	assert_lt(travelled, player.state_machine.swim_speed())


func test_moving_platform_does_not_carry_swimmer_off_depth_plane() -> void:
	var volume := _add_volume()
	var player := _add_player(_surface_start(volume))
	player.set_physics_process(false)
	assert_true(player.try_enter_water(volume))
	assert_true(player.try_dive_underwater())
	var start := player.global_position
	var platform := _add_moving_platform(
		start - Vector3.UP,
		Vector3(2.0, 0.2, 2.0),
	)
	await get_tree().physics_frame
	player.set_physics_process(true)
	platform.position.x += 0.5
	await get_tree().physics_frame
	player.set_physics_process(false)
	assert_almost_eq(player.global_position.y, start.y, 0.0001)
	assert_almost_eq(player.global_position.x, start.x, 0.0001)


func _add_volume() -> WaterVolume:
	var volume := WaterVolume.new()
	volume.position = Vector3(0.0, 2.0, 0.0)
	add_child_autofree(volume)
	return volume


func _send_action_event(player: PlayerController, action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	player._unhandled_input(event)


func _surface_start(volume: WaterVolume) -> Vector3:
	return Vector3(0.0, volume.surface_world_y() - volume.surface_body_depth, 0.0)


func _add_player(position: Vector3, profile: PlayerProfile = null) -> PlayerController:
	var player := (load(PLAYER_SCENE_PATH) as PackedScene).instantiate() as PlayerController
	player.position = position
	player.player_profile = profile
	add_child_autofree(player)
	return player


func _add_world_blocker(position: Vector3, size: Vector3) -> StaticBody3D:
	var blocker := StaticBody3D.new()
	blocker.collision_layer = PlayerController.WORLD_COLLISION_MASK
	blocker.collision_mask = 0
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	blocker.add_child(collision)
	blocker.position = position
	add_child_autofree(blocker)
	return blocker


func _add_low_overhead_blocker(position: Vector3) -> StaticBody3D:
	return _add_world_blocker(position + Vector3.UP * 0.6, Vector3(2.0, 0.4, 2.0))


func _add_moving_platform(position: Vector3, size: Vector3) -> AnimatableBody3D:
	var platform := AnimatableBody3D.new()
	platform.collision_layer = PlayerController.WORLD_COLLISION_MASK
	platform.collision_mask = 0
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	platform.add_child(collision)
	platform.position = position
	add_child_autofree(platform)
	return platform


func _assert_water_recovered_to_ground(player: PlayerController) -> void:
	var capsule := player.collision_shape.shape as CapsuleShape3D
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_GROUND)
	assert_false(player.is_water_recovery_pending())
	assert_null(player.active_water_volume())
	assert_eq(player.velocity, Vector3.ZERO)
	assert_almost_eq(capsule.height, player._standing_capsule_height, 0.0001)
	assert_true(player.player_model.visible)
	assert_false(player.surface_ripples.visible)
	assert_false(player.swim_hud.is_breath_gauge_visible())
