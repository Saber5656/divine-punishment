extends GutTest


const EnemyScene := preload("res://src/enemies/enemy_base.tscn")
const PlayerScene := preload("res://src/player/player.tscn")
const HideRules := preload("res://src/player/player_hide.gd")


func test_dead_body_carry_slows_player_and_blocks_ninja_tools() -> void:
	_add_floor()
	var player := PlayerScene.instantiate() as PlayerController
	player.position = Vector3(0.0, 1.0, 0.0)
	add_child_autofree(player)
	var body := _add_dead_body(Vector3(0.0, 1.0, -0.5))
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(body.collision_layer, EnemyBase.CORPSE_LAYER)

	assert_true(player.is_on_floor())
	var normal_speed := float(player.state_machine.movement_params().get(&"speed", 0.0))
	assert_true(player.try_pick_up_body(body))
	assert_true(player.is_carrying_body())
	assert_eq(player.carried_body(), body)
	assert_almost_eq(player.movement_speed(), normal_speed * PlayerController.CARRY_SPEED_MULTIPLIER, 0.0001)
	assert_eq(body.get_parent(), player)
	assert_eq(body.collision_layer, 0)
	assert_eq(body.collision_mask, 0)
	assert_false(player.can_use_ninja_tools())
	assert_false(player.tool_rig.set_aiming(true))
	assert_false(player.tool_rig.is_aiming())
	Input.action_press(&"sprint")
	player._update_state_from_input()
	assert_ne(player.state_machine.current_state(), PlayerStateMachine.STATE_SPRINT)
	Input.action_release(&"sprint")
	var remaining := player.tool_rig.remaining_count()
	assert_false(player.tool_rig.use_selected(player))
	var alternate_actor := Node3D.new()
	add_child_autofree(alternate_actor)
	assert_false(player.tool_rig.use_selected(alternate_actor))
	assert_eq(player.tool_rig.remaining_count(), remaining)

	assert_true(player.try_drop_carried_body())
	assert_false(player.is_carrying_body())
	assert_ne(body.get_parent(), player)
	assert_true(body.is_inside_tree())
	assert_not_null(body.corpse_anomaly())


func test_carrying_body_blocks_assassination_targeting_and_state() -> void:
	_add_floor()
	var player := _add_player(Vector3(0.0, 1.0, 0.0))
	var body := _add_dead_body(Vector3(0.0, 1.0, -0.5))
	var enemy := EnemyScene.instantiate() as EnemyBase
	enemy.position = Vector3(0.0, 1.0, 1.0)
	enemy.rotation.y = PI
	add_child_autofree(enemy)
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_true(player.try_pick_up_body(body))
	var resolver := player.get_node(^"AssassinationResolver") as AssassinationResolver
	assert_eq(resolver.evaluate(enemy), &"")
	assert_false(resolver.try_execute(enemy, &"back"))
	assert_true(player.state_machine.change_state(PlayerStateMachine.STATE_ASSASSINATE))
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_GROUND)
	assert_false(enemy.is_assassinated())


func test_carrying_body_can_enter_crawlspace_without_dropping() -> void:
	_add_world_box(Vector3(0.0, -0.5, 0.0), Vector3(8.0, 1.0, 8.0))
	var player := _add_player(Vector3(0.0, 0.9, 0.0))
	var entrance := CrawlEntrance.new()
	entrance.position = Vector3(0.0, 0.9, 0.0)
	entrance.inside_offset = Vector3(0.0, 0.0, -1.0)
	add_child_autofree(entrance)
	var body := _add_dead_body(Vector3(0.0, 0.9, -0.5))
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_true(player.try_pick_up_body(body))
	assert_true(player.try_enter_crawlspace(entrance))
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_CRAWLSPACE)
	assert_true(player.is_carrying_body())
	assert_eq(body.get_parent(), player)


func test_hide_spot_stores_one_body_and_suppresses_corpse_anomaly() -> void:
	_add_floor()
	var player := _add_player(Vector3(0.0, 1.0, 0.0))
	var hide_spot := HideSpot.new()
	hide_spot.position = Vector3(0.0, 1.0, 0.0)
	add_child_autofree(hide_spot)
	var body := _add_dead_body(Vector3(0.0, 1.0, -0.5))
	await get_tree().physics_frame
	await get_tree().physics_frame
	var original_anomaly := body.corpse_anomaly()
	assert_not_null(original_anomaly)

	assert_true(player.try_pick_up_body(body))
	assert_true(player.try_store_carried_body(hide_spot))
	assert_false(player.is_carrying_body())
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_CROUCH)
	assert_true(hide_spot.has_stored_body())
	assert_eq(hide_spot.stored_body(), body)
	assert_eq(body.get_parent(), hide_spot)
	assert_true(body.is_stored())
	assert_null(body.corpse_anomaly())
	assert_false(hide_spot.can_store_body(body))

	assert_true(player.try_retrieve_stored_body(hide_spot))
	assert_true(player.is_carrying_body())
	assert_false(hide_spot.has_stored_body())
	assert_true(body.is_being_carried())
	assert_null(body.corpse_anomaly())

	assert_true(player.try_drop_carried_body())
	assert_eq(body.corpse_anomaly(), original_anomaly)


func test_explicit_storage_rejects_distant_hide_spot() -> void:
	_add_floor()
	var player := _add_player(Vector3(0.0, 1.0, 0.0))
	var distant_hide_spot := HideSpot.new()
	distant_hide_spot.position = Vector3(20.0, 1.0, 0.0)
	add_child_autofree(distant_hide_spot)
	var body := _add_dead_body(Vector3(0.0, 1.0, -0.5))
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_true(player.try_pick_up_body(body))
	assert_false(player.try_store_carried_body(distant_hide_spot))
	assert_true(player.is_carrying_body())
	assert_true(body.is_being_carried())
	assert_false(distant_hide_spot.has_stored_body())


func test_drop_rejects_a_blocked_path_without_exposing_the_body() -> void:
	_add_floor()
	var player := _add_player(Vector3(0.0, 1.0, 0.0))
	var wall := _add_world_box(Vector3(0.0, 1.0, -0.8), Vector3(1.0, 2.0, 0.2))
	var body := _add_dead_body(Vector3(0.0, 1.0, -0.5))
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_true(player.try_pick_up_body(body))
	assert_false(player.try_drop_carried_body())
	assert_true(player.is_carrying_body())
	assert_eq(body.get_parent(), player)

	wall.queue_free()
	await get_tree().physics_frame
	assert_true(player.try_drop_carried_body())
	assert_false(player.is_carrying_body())


func test_storage_lookup_filters_spots_by_operation() -> void:
	_add_floor()
	var player := _add_player(Vector3(0.0, 1.0, 0.0))
	var near_empty := HideSpot.new()
	near_empty.position = Vector3(0.0, 1.0, 0.0)
	add_child_autofree(near_empty)
	var far_empty := HideSpot.new()
	far_empty.position = Vector3(0.5, 1.0, 0.0)
	add_child_autofree(far_empty)
	var first_body := _add_dead_body(Vector3(0.0, 1.0, -0.5))
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_true(player.try_pick_up_body(first_body))
	assert_true(player.try_store_carried_body(far_empty))
	assert_false(near_empty.has_stored_body())
	assert_true(far_empty.has_stored_body())
	assert_true(player.try_retrieve_stored_body())
	assert_true(player.is_carrying_body())
	assert_eq(player.carried_body(), first_body)
	assert_true(player.try_store_carried_body())
	assert_true(near_empty.has_stored_body())
	assert_false(far_empty.has_stored_body())

	var second_body := _add_dead_body(Vector3(0.0, 1.0, -0.5))
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(player.try_pick_up_body(second_body))
	assert_true(player.try_store_carried_body())
	assert_true(near_empty.has_stored_body())
	assert_true(far_empty.has_stored_body())


func test_drop_rejects_out_of_bounds_world_position() -> void:
	_add_floor()
	var player := _add_player(Vector3(0.0, 1.0, 0.0))
	var body := _add_dead_body(Vector3(0.0, 1.0, -0.5))
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_true(player.try_pick_up_body(body))
	assert_false(body.end_carry(Vector3(HideRules.MAX_WORLD_COORDINATE + 1.0, 0.0, 0.0)))
	assert_true(body.is_being_carried())
	assert_true(player.is_carrying_body())


func test_queued_corpse_anomaly_is_invalidated_when_body_is_carried() -> void:
	_add_floor()
	var player := _add_player(Vector3(0.0, 1.0, 0.0))
	var observer := EnemyScene.instantiate() as EnemyBase
	observer.position = Vector3(0.0, 1.0, 3.0)
	add_child_autofree(observer)
	var body := _add_dead_body(Vector3(0.0, 1.0, -0.5))
	await get_tree().physics_frame
	await get_tree().physics_frame

	var anomaly := body.corpse_anomaly()
	assert_not_null(anomaly)
	var perception := observer.get_node(^"Perception") as EnemyPerception
	perception.on_anomaly(anomaly)
	var brain := observer.brain()
	assert_gt(brain.pending_stimulus_count(), 0)
	assert_true(player.try_pick_up_body(body))

	brain.tick(0.1)
	assert_eq(brain.pending_stimulus_count(), 0)
	var memory := brain.stimulus_memory()
	assert_true(memory == null or memory.anomaly != anomaly)


func test_invalid_storage_rolls_back_without_exposing_carried_body() -> void:
	_add_floor()
	var player := _add_player(Vector3(0.0, 1.0, 0.0))
	var hide_spot := HideSpot.new()
	hide_spot.position = Vector3(0.0, 1.0, 0.0)
	add_child_autofree(hide_spot)
	var body := _add_dead_body(Vector3(0.0, 1.0, -0.5))
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_true(player.try_pick_up_body(body))
	var original_parent := body.get_parent()
	hide_spot.storage_offset = Vector3(INF, 0.0, 0.0)

	assert_false(body.begin_storage(hide_spot))
	assert_eq(body.get_parent(), player)
	assert_eq(body.get_parent(), original_parent)
	assert_true(body.is_being_carried())
	assert_false(body.is_stored())
	assert_eq(body.collision_layer, 0)
	assert_eq(body.collision_mask, 0)
	assert_eq(body.process_mode, Node.PROCESS_MODE_DISABLED)
	assert_false(hide_spot.has_stored_body())
	assert_true(player.is_carrying_body())


func test_failed_retrieval_keeps_hide_spot_occupancy_consistent() -> void:
	_add_floor()
	var player := _add_player(Vector3(0.0, 1.0, 0.0))
	var hide_spot := HideSpot.new()
	hide_spot.position = Vector3(0.0, 1.0, 0.0)
	add_child_autofree(hide_spot)
	var body := _add_dead_body(Vector3(0.0, 1.0, -0.5))
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_true(player.try_pick_up_body(body))
	assert_true(player.try_store_carried_body(hide_spot))
	var detached_receiver := Node3D.new()
	assert_null(hide_spot.retrieve_body(detached_receiver))
	assert_true(hide_spot.has_stored_body())
	assert_eq(hide_spot.stored_body(), body)
	assert_eq(body.get_parent(), hide_spot)
	assert_true(body.is_stored())
	detached_receiver.free()

	# A body ending storage through the production API must also clear a stale
	# HideSpot pointer when the transition is no longer owned by that spot.
	assert_true(body.end_storage())
	assert_false(hide_spot.has_stored_body())
	assert_null(hide_spot.stored_body())
	assert_false(body.is_stored())
	assert_not_null(body.corpse_anomaly())


func test_body_carry_and_storage_reject_invalid_owners_and_duplicates() -> void:
	var live_body := EnemyScene.instantiate() as EnemyBase
	add_child_autofree(live_body)
	assert_false(live_body.is_body_carryable())
	assert_false(live_body.begin_carry(null))

	var hide_spot := HideSpot.new()
	add_child_autofree(hide_spot)
	var dead_body := _add_dead_body(Vector3.ZERO)
	assert_false(hide_spot.can_store_body(dead_body))
	assert_false(hide_spot.store_body(dead_body))
	assert_false(hide_spot.can_retrieve_body())

	var detached_carrier := Node3D.new()
	assert_false(dead_body.begin_carry(detached_carrier))
	assert_ne(dead_body.get_parent(), detached_carrier)
	assert_true(dead_body.is_inside_tree())
	detached_carrier.free()
	assert_lte(PlayerController.MAX_CARRYABLE_BODY_CANDIDATES, 64)
	assert_lte(PlayerController.MAX_STORAGE_HIDE_SPOT_CANDIDATES, 64)


func test_exposed_body_produces_anomaly_for_enemy_perception() -> void:
	var observer := EnemyScene.instantiate() as EnemyBase
	observer.position = Vector3(0.0, 0.0, 0.0)
	add_child_autofree(observer)
	var body := _add_dead_body(Vector3(0.0, 0.0, -3.0))
	await get_tree().physics_frame

	var anomaly := body.corpse_anomaly()
	assert_not_null(anomaly)
	assert_eq(anomaly.kind, Enums.AnomalyKind.CORPSE)
	var perception := observer.get_node(^"Perception") as EnemyPerception
	perception.on_anomaly(anomaly)
	assert_gt(observer.brain().pending_stimulus_count(), 0)


func _add_player(world_position: Vector3) -> PlayerController:
	var player := PlayerScene.instantiate() as PlayerController
	player.position = world_position
	add_child_autofree(player)
	return player


func _add_dead_body(world_position: Vector3) -> EnemyBase:
	var body := EnemyScene.instantiate() as EnemyBase
	body.position = world_position
	add_child_autofree(body)
	assert_true(body.set_incapacitated(&"dead"))
	return body


func _add_floor() -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.collision_layer = PlayerController.WORLD_COLLISION_MASK
	floor.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(8.0, 1.0, 8.0)
	collision.shape = shape
	floor.add_child(collision)
	floor.position = Vector3(0.0, 0.0, 0.0)
	add_child_autofree(floor)
	return floor


func _add_world_box(at: Vector3, size: Vector3) -> StaticBody3D:
	var blocker := StaticBody3D.new()
	blocker.collision_layer = PlayerController.WORLD_COLLISION_MASK
	blocker.collision_mask = 0
	blocker.position = at
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	blocker.add_child(collision)
	add_child_autofree(blocker)
	return blocker
