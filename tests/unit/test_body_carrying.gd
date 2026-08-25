extends GutTest


const EnemyScene := preload("res://src/enemies/enemy_base.tscn")
const PlayerScene := preload("res://src/player/player.tscn")


func test_dead_body_carry_slows_player_and_blocks_ninja_tools() -> void:
	_add_floor()
	var player := PlayerScene.instantiate() as PlayerController
	player.position = Vector3(0.0, 1.0, 0.0)
	add_child_autofree(player)
	var body := _add_dead_body(Vector3(0.0, 1.0, -0.5))
	await get_tree().physics_frame
	await get_tree().physics_frame

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
	var remaining := player.tool_rig.remaining_count()
	assert_false(player.tool_rig.use_selected(player))
	assert_eq(player.tool_rig.remaining_count(), remaining)

	assert_true(player.try_drop_carried_body())
	assert_false(player.is_carrying_body())
	assert_ne(body.get_parent(), player)
	assert_true(body.is_inside_tree())
	assert_not_null(body.corpse_anomaly())


func test_hide_spot_stores_one_body_and_suppresses_corpse_anomaly() -> void:
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
	assert_false(player.is_carrying_body())
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
	assert_not_null(body.corpse_anomaly())


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
