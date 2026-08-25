extends GutTest


const ResolverScript := preload("res://src/player/assassination_resolver.gd")
const ConfigScript := preload("res://src/core/tuning/assassination_config.gd")
const PlayerScene := preload("res://src/player/player.tscn")
const EnemyScene := preload("res://src/enemies/enemy_base.tscn")
const CONFIG_PATH := "res://data/tuning/assassination.tres"


func test_static_resolve_accepts_all_four_tuned_contexts() -> void:
	var config := load(CONFIG_PATH) as Resource
	if config == null or config.get("back_max_distance_m") == null:
		# Godot 4.3 may finish the clean-import script cache after this test
		# starts.  Exercise the same bounded defaults used by the resolver when
		# the optional tuning resource is not available yet.
		config = ConfigScript.new() as Resource
	assert_not_null(config)
	assert_eq(config.get("presentation_duration_seconds"), 1.0)
	assert_eq(config.get("back_max_distance_m"), 1.5)
	assert_eq(config.get("above_max_distance_m"), 4.0)
	assert_eq(config.get("below_max_angle_degrees"), 45.0)
	assert_eq(config.get("corner_max_angle_degrees"), 60.0)
	assert_eq(
		ResolverScript.resolve(&"Ground", Vector3(0.0, 0.0, 1.0), Enums.AlertState.UNAWARE, false, config),
		&"back",
	)
	assert_eq(
		ResolverScript.resolve(&"Beam", Vector3(0.0, -3.0, 0.0), Enums.AlertState.SUSPICIOUS, false, config),
		&"above",
	)
	assert_eq(
		ResolverScript.resolve(&"Crawlspace", Vector3(0.0, 1.0, 0.0), Enums.AlertState.SEARCHING, false, config),
		&"below",
	)
	assert_eq(
		ResolverScript.resolve(&"WallCling", Vector3(1.0, 0.0, 0.0), Enums.AlertState.RETURN, false, config),
		&"corner",
	)


func test_resolver_provides_a_fallback_config_when_resource_load_is_unavailable() -> void:
	var player := PlayerScene.instantiate() as PlayerController
	add_child_autofree(player)
	await get_tree().process_frame

	var resolver := player.get_node("AssassinationResolver") as AssassinationResolver
	assert_not_null(resolver.config)
	assert_true(resolver.config is Resource)
	assert_eq(resolver.config.get("back_max_distance_m"), 1.5)
	assert_eq(resolver.config.get("above_max_distance_m"), 4.0)


func test_static_resolve_enforces_distance_and_angle_boundaries() -> void:
	var config := ConfigScript.new() as AssassinationConfig
	assert_eq(
		ResolverScript.resolve(&"Ground", Vector3(0.0, 0.0, 1.5), Enums.AlertState.UNAWARE, false, config),
		&"back",
	)
	assert_eq(
		ResolverScript.resolve(&"Ground", Vector3(0.0, 0.0, 1.501), Enums.AlertState.UNAWARE, false, config),
		&"",
	)
	assert_eq(
		ResolverScript.resolve(&"Ground", Vector3(1.3, 0.0, 0.4), Enums.AlertState.UNAWARE, false, config),
		&"",
	)
	assert_eq(
		ResolverScript.resolve(&"Beam", Vector3(0.0, -4.001, 0.0), Enums.AlertState.UNAWARE, false, config),
		&"",
	)


func test_static_resolve_rejects_combat_seen_and_invalid_contexts() -> void:
	var config := load(CONFIG_PATH) as AssassinationConfig
	for state: Enums.AlertState in [
		Enums.AlertState.UNAWARE,
		Enums.AlertState.SUSPICIOUS,
		Enums.AlertState.SEARCHING,
		Enums.AlertState.RETURN,
	]:
		assert_eq(
			ResolverScript.resolve(&"Ground", Vector3(0.0, 0.0, 1.0), Enums.AlertState.COMBAT, false, config),
			&"",
		)
		assert_eq(
			ResolverScript.resolve(&"Ground", Vector3(0.0, 0.0, 1.0), state, true, config),
			&"",
		)
	assert_eq(
		ResolverScript.resolve(&"Sprint", Vector3(0.0, 0.0, 1.0), Enums.AlertState.UNAWARE, false, config),
		&"",
	)
	assert_eq(
		ResolverScript.resolve(&"Ground", Vector3(NAN, 0.0, 1.0), Enums.AlertState.UNAWARE, false, config),
		&"",
	)


func test_prompt_and_one_input_execution_lock_both_sides() -> void:
	var player := PlayerScene.instantiate() as PlayerController
	add_child_autofree(player)
	var enemy := EnemyScene.instantiate() as EnemyBase
	enemy.position = Vector3(0.0, 0.0, 1.0)
	enemy.rotation.y = PI
	add_child_autofree(enemy)
	var resolver := player.get_node("AssassinationResolver") as AssassinationResolver
	watch_signals(resolver)
	var interactor := player.get_node("Interactor") as Area3D
	var target_area := enemy.get_node("AssassinateTarget") as Area3D
	var overlaps_target := false
	for _i in range(4):
		await get_tree().physics_frame
		overlaps_target = interactor.get_overlapping_areas().has(target_area)
		if overlaps_target:
			break
	assert_true(overlaps_target)
	assert_eq(resolver.evaluate(enemy), &"back")
	assert_eq(resolver.prompt_enemy(), enemy)
	assert_eq(resolver.prompt_context(), &"back")
	assert_signal_emitted_with_parameters(resolver, "prompt_changed", [enemy, &"back"])

	assert_true(resolver.confirm())
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_ASSASSINATE)
	assert_true(enemy.is_assassinating())
	assert_true(enemy.is_assassinated())
	assert_eq(enemy.assassination_context(), &"back")
	assert_true((enemy.get_node("Brain") as EnemyBrain).is_incapacitated())
	assert_eq((enemy.get_node("Brain") as EnemyBrain).incapacitated_kind(), &"dead")
	assert_false(resolver.confirm())
	assert_true(resolver.release())
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_GROUND)


func test_prompt_and_evaluate_reject_enemy_in_combat() -> void:
	var player := PlayerScene.instantiate() as PlayerController
	add_child_autofree(player)
	var enemy := EnemyScene.instantiate() as EnemyBase
	enemy.position = Vector3(0.0, 0.0, 1.0)
	add_child_autofree(enemy)
	await get_tree().process_frame
	(enemy.get_node("Brain") as EnemyBrain).force_state(Enums.AlertState.COMBAT, &"test")

	var resolver := player.get_node("AssassinationResolver") as AssassinationResolver
	assert_eq(resolver.evaluate(enemy), &"")
	assert_eq(resolver.prompt_context(), &"")
	assert_false(resolver.confirm())


func test_prompt_and_evaluate_reject_enemy_seen_by_perception() -> void:
	var player := PlayerScene.instantiate() as PlayerController
	add_child_autofree(player)
	var enemy := EnemyScene.instantiate() as EnemyBase
	enemy.position = Vector3(0.0, 0.0, 1.0)
	add_child_autofree(enemy)
	await get_tree().process_frame
	var perception := enemy.get_node("Perception") as EnemyPerception
	perception.set("_target_visible", true)

	var resolver := player.get_node("AssassinationResolver") as AssassinationResolver
	assert_eq(resolver.evaluate(enemy), &"")
	assert_eq(resolver.prompt_context(), &"")
	assert_false(resolver.confirm())


func test_presentation_lock_completes_through_production_release_path() -> void:
	var player := PlayerScene.instantiate() as PlayerController
	add_child_autofree(player)
	var enemy := _add_valid_back_enemy()
	var resolver := player.get_node("AssassinationResolver") as AssassinationResolver
	await _wait_for_sensor_overlap(player, enemy)
	assert_eq(resolver.evaluate(enemy), &"back")
	resolver.config.set("presentation_duration_seconds", 0.1)

	assert_true(resolver.confirm())
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_ASSASSINATE)
	# Invalid sub-second tuning is clamped to the presentation's authored
	# one-second minimum.  A bounded real timer lets the production process
	# driver accumulate that duration even when headless process_frame runs at
	# an unbounded rate.
	var completion_timer := get_tree().create_timer(1.1, true, false, false)
	await completion_timer.timeout
	await get_tree().process_frame
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_GROUND)
	assert_null(resolver.active_enemy())
	assert_true(enemy.is_assassinated())


func test_presentation_completion_clears_lock_after_player_enters_dead_state() -> void:
	var player := PlayerScene.instantiate() as PlayerController
	add_child_autofree(player)
	var enemy := _add_valid_back_enemy()
	var resolver := player.get_node("AssassinationResolver") as AssassinationResolver
	await _wait_for_sensor_overlap(player, enemy)
	assert_eq(resolver.evaluate(enemy), &"back")
	assert_true(resolver.confirm())
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_ASSASSINATE)
	assert_true(player.state_machine.change_state(PlayerStateMachine.STATE_DEAD))

	# Completion must clear resolver ownership without restoring Ground over a
	# terminal player state.  This simulates a scene/state interruption between
	# the authored presentation and its completion callback.
	var presentation := resolver.get_node("AssassinationPresentation") as AssassinationPresentation
	assert_true(presentation.complete())
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_DEAD)
	assert_null(resolver.active_enemy())
	assert_eq(resolver.active_context(), &"")
	assert_false(resolver.release())


func test_no_presentation_fallback_consumes_a_large_frame_delta() -> void:
	var player := PlayerScene.instantiate() as PlayerController
	add_child_autofree(player)
	var enemy := _add_valid_back_enemy()
	var resolver := player.get_node("AssassinationResolver") as AssassinationResolver
	# Custom player scenes may omit the presentation node.  The resolver's
	# fallback must still release on one finite frame without the old 0.5-second
	# per-frame clamp stretching the lock.
	(resolver.get_node("AssassinationPresentation") as Node).free()
	await _wait_for_sensor_overlap(player, enemy)
	assert_eq(resolver.evaluate(enemy), &"back")
	assert_true(resolver.confirm())
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_ASSASSINATE)
	resolver._process(10.0)
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_GROUND)
	assert_null(resolver.active_enemy())


func test_back_context_requires_enemy_to_face_away_from_player() -> void:
	var player := PlayerScene.instantiate() as PlayerController
	add_child_autofree(player)
	var enemy := EnemyScene.instantiate() as EnemyBase
	enemy.position = Vector3(0.0, 0.0, 1.0)
	add_child_autofree(enemy)
	var resolver := player.get_node("AssassinationResolver") as AssassinationResolver
	await _wait_for_sensor_overlap(player, enemy)

	assert_eq(resolver.evaluate(enemy), &"")
	enemy.rotation.y = PI
	await get_tree().physics_frame
	assert_eq(resolver.evaluate(enemy), &"back")


func test_assassination_requires_sensor_overlap() -> void:
	var player := PlayerScene.instantiate() as PlayerController
	add_child_autofree(player)
	var enemy := _add_valid_back_enemy()
	var resolver := player.get_node("AssassinationResolver") as AssassinationResolver
	var interactor := player.get_node("Interactor") as Area3D
	await _wait_for_sensor_overlap(player, enemy)
	interactor.monitoring = false
	assert_eq(resolver.evaluate(enemy), &"")
	interactor.monitoring = true
	await _wait_for_sensor_overlap(player, enemy)
	assert_eq(resolver.evaluate(enemy), &"back")


func test_assassination_evaluates_explicit_target_after_overlap_candidate_cap() -> void:
	var player := PlayerScene.instantiate() as PlayerController
	add_child_autofree(player)
	# Create unrelated overlap areas before the real enemy so the target is
	# beyond the bounded prompt-discovery candidate window.
	for index in ResolverScript.MAX_TARGET_CANDIDATES:
		var decoy := Area3D.new()
		decoy.collision_layer = 1 << 11
		decoy.collision_mask = 0
		var decoy_shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.1
		decoy_shape.shape = sphere
		decoy.add_child(decoy_shape)
		decoy.position = Vector3(
			(float(index % 8) - 3.5) * 0.08,
			0.0,
			(float(index / 8) - 3.5) * 0.08,
		)
		add_child_autofree(decoy)
	var enemy := _add_valid_back_enemy()
	var resolver := player.get_node("AssassinationResolver") as AssassinationResolver
	var interactor := player.get_node("Interactor") as Area3D
	var target_area := enemy.get_node("AssassinateTarget") as Area3D
	await _wait_for_sensor_overlap(player, enemy)
	var overlaps := interactor.get_overlapping_areas()
	assert_true(overlaps.has(target_area))
	assert_gt(overlaps.size(), ResolverScript.MAX_TARGET_CANDIDATES)
	assert_eq(resolver.evaluate(enemy), &"back")


func test_assassination_requires_clear_world_path() -> void:
	var player := PlayerScene.instantiate() as PlayerController
	add_child_autofree(player)
	var enemy := _add_valid_back_enemy()
	var resolver := player.get_node("AssassinationResolver") as AssassinationResolver
	await _wait_for_sensor_overlap(player, enemy)
	var blocker := _add_occluder(Vector3(0.0, 0.5, 0.5))
	await get_tree().physics_frame
	assert_eq(resolver.evaluate(enemy), &"")
	blocker.queue_free()
	await get_tree().physics_frame
	assert_eq(resolver.evaluate(enemy), &"back")


func test_above_assassination_skips_immediate_support_but_not_world_blocker() -> void:
	var player := PlayerScene.instantiate() as PlayerController
	player.position = Vector3(0.0, 2.0, 0.0)
	add_child_autofree(player)
	var support := _add_world_box(Vector3(0.0, 1.45, 0.0), Vector3(4.0, 0.2, 4.0))
	var wall := _add_world_box(Vector3(0.4, 1.5, 0.0), Vector3(0.2, 1.0, 1.0))
	var enemy := EnemyScene.instantiate() as EnemyBase
	enemy.position = Vector3(0.8, 0.0, 0.0)
	add_child_autofree(enemy)
	var resolver := player.get_node("AssassinationResolver") as AssassinationResolver
	assert_true(player.state_machine.change_state(PlayerStateMachine.STATE_CLIMB))
	assert_true(player.state_machine.change_state(PlayerStateMachine.STATE_BEAM))
	# This isolated judgment fixture has no authored BeamPath.  Keep the
	# traversal state stable while the physics server refreshes Area3D pairs.
	player.set_physics_process(false)
	await _wait_for_sensor_overlap(player, enemy)
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_BEAM)
	assert_eq(resolver.evaluate(enemy), &"")
	wall.queue_free()
	await get_tree().physics_frame
	assert_eq(resolver.evaluate(enemy), &"above")
	support.queue_free()


func test_resolver_refreshes_assassination_tuning_on_reload() -> void:
	var player := PlayerScene.instantiate() as PlayerController
	add_child_autofree(player)
	await get_tree().process_frame
	var resolver := player.get_node("AssassinationResolver") as AssassinationResolver
	var tuning := get_node("/root/Tuning") as TuningService
	var original := tuning.assassination()
	var replacement := ConfigScript.new() as Resource
	replacement.set("back_max_distance_m", 0.75)
	tuning._assassination = replacement
	Tuning.reloaded.emit()
	assert_eq(resolver.config.get("back_max_distance_m"), 0.75)
	tuning._assassination = original
	Tuning.reloaded.emit()


func test_resolver_preserves_an_explicit_compatible_config_override() -> void:
	var player := PlayerScene.instantiate() as PlayerController
	var explicit := ConfigScript.new() as Resource
	explicit.set("back_max_distance_m", 0.75)
	var resolver := player.get_node("AssassinationResolver") as AssassinationResolver
	resolver.config = explicit
	add_child_autofree(player)
	await get_tree().process_frame
	var tuning := get_node("/root/Tuning") as TuningService
	assert_eq(resolver.config, explicit)
	var original := tuning.assassination()
	tuning._assassination = ConfigScript.new() as Resource
	tuning._assassination.set("back_max_distance_m", 0.25)
	Tuning.reloaded.emit()
	assert_eq(resolver.config, explicit)
	tuning._assassination = original
	Tuning.reloaded.emit()


func test_crawl_posture_is_preserved_while_assassination_is_locked() -> void:
	var entrance := CrawlEntrance.new()
	entrance.inside_offset = Vector3(0.0, 0.0, -1.0)
	add_child_autofree(entrance)
	var player := PlayerScene.instantiate() as PlayerController
	player.position = entrance.outside_world_position()
	add_child_autofree(player)
	assert_true(player.try_enter_crawlspace(entrance))
	var enemy := EnemyScene.instantiate() as EnemyBase
	enemy.position = Vector3(0.0, 1.0, -1.0)
	add_child_autofree(enemy)
	var resolver := player.get_node("AssassinationResolver") as AssassinationResolver
	var collision := player.get_node("CollisionShape3D") as CollisionShape3D
	var capsule := collision.shape as CapsuleShape3D
	await _wait_for_sensor_overlap(player, enemy)
	assert_eq(resolver.evaluate(enemy), &"below")
	assert_true(resolver.confirm())
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_ASSASSINATE)
	assert_almost_eq(capsule.height, player.crawl_capsule_height, 0.0001)
	assert_almost_eq(player.camera_rig.posture_drop(), player.crawl_camera_drop, 0.0001)
	assert_true(resolver.release())
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_CRAWLSPACE)
	assert_almost_eq(capsule.height, player.crawl_capsule_height, 0.0001)


func _add_valid_back_enemy() -> EnemyBase:
	var enemy := EnemyScene.instantiate() as EnemyBase
	enemy.position = Vector3(0.0, 0.0, 1.0)
	enemy.rotation.y = PI
	add_child_autofree(enemy)
	return enemy


func _wait_for_sensor_overlap(player: PlayerController, enemy: EnemyBase) -> void:
	var interactor := player.get_node("Interactor") as Area3D
	var target_area := enemy.get_node("AssassinateTarget") as Area3D
	for _i in range(8):
		await get_tree().physics_frame
		if interactor.get_overlapping_areas().has(target_area):
			return
	assert_true(interactor.get_overlapping_areas().has(target_area))


func _add_occluder(at: Vector3) -> StaticBody3D:
	return _add_world_box(at, Vector3(0.5, 1.5, 0.2))


func _add_world_box(at: Vector3, size: Vector3) -> StaticBody3D:
	var blocker := StaticBody3D.new()
	blocker.collision_layer = 1
	blocker.collision_mask = 0
	blocker.position = at
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	blocker.add_child(collision)
	add_child_autofree(blocker)
	return blocker
