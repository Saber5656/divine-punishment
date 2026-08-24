extends GutTest


const PLAYER_SCENE_PATH := "res://src/player/player.tscn"


func test_player_enters_and_exits_hide_spot_with_visibility_exclusion() -> void:
	var hide_spot := HideSpot.new()
	add_child_autofree(hide_spot)
	_add_floor()
	var player := (load(PLAYER_SCENE_PATH) as PackedScene).instantiate() as PlayerController
	add_child_autofree(player)
	await get_tree().physics_frame

	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_GROUND)
	assert_false(player.is_visibility_excluded())
	assert_true(player.try_enter_hide_spot(hide_spot))
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_HIDDEN)
	assert_true(player.state_machine.is_hidden())
	assert_true(player.is_visibility_excluded())
	assert_eq(player.active_hide_spot(), hide_spot)
	assert_false(player.state_machine.change_state(PlayerStateMachine.STATE_GROUND))
	assert_true(player.try_exit_hide_spot())
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_CROUCH)
	assert_false(player.is_visibility_excluded())
	assert_null(player.active_hide_spot())


func test_player_can_enter_hide_spot_from_crouch() -> void:
	var hide_spot := HideSpot.new()
	add_child_autofree(hide_spot)
	_add_floor()
	var player := (load(PLAYER_SCENE_PATH) as PackedScene).instantiate() as PlayerController
	add_child_autofree(player)
	await get_tree().physics_frame

	assert_true(player.state_machine.change_state(PlayerStateMachine.STATE_CROUCH))
	assert_true(player.try_enter_hide_spot(hide_spot))
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_HIDDEN)
	assert_true(player.try_exit_hide_spot())
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_CROUCH)


func test_close_range_seen_invalidates_an_active_hidden_player() -> void:
	var hide_spot := HideSpot.new()
	add_child_autofree(hide_spot)
	_add_floor()
	var player := (load(PLAYER_SCENE_PATH) as PackedScene).instantiate() as PlayerController
	add_child_autofree(player)
	await get_tree().physics_frame

	assert_true(player.try_enter_hide_spot(hide_spot))
	assert_false(player.invalidate_hidden_if_close_range_seen(false))
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_HIDDEN)
	assert_true(player.invalidate_hidden_if_close_range_seen(true))
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_CROUCH)
	assert_false(player.is_visibility_excluded())


func test_same_radius_entry_shape_replacement_invalidates_hidden_contract() -> void:
	var hide_spot := HideSpot.new()
	add_child_autofree(hide_spot)
	_add_floor()
	var player := (load(PLAYER_SCENE_PATH) as PackedScene).instantiate() as PlayerController
	add_child_autofree(player)
	await get_tree().physics_frame
	assert_true(player.try_enter_hide_spot(hide_spot))
	var collision := hide_spot.get_node(
		NodePath(String(HideSpot.ENTRY_COLLISION_SHAPE_NODE_NAME)),
	) as CollisionShape3D
	var replacement := SphereShape3D.new()
	replacement.radius = hide_spot.entry_radius
	collision.shape = replacement
	assert_false(player._maintain_hide_contract())
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_CROUCH)
	assert_false(player.is_visibility_excluded())


func test_close_range_seen_blocks_entry_before_hidden_state() -> void:
	var hide_spot := HideSpot.new()
	add_child_autofree(hide_spot)
	var player := (load(PLAYER_SCENE_PATH) as PackedScene).instantiate() as PlayerController
	add_child_autofree(player)

	assert_false(player.try_enter_hide_spot(hide_spot, true))
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_GROUND)
	assert_false(player.is_visibility_excluded())


func test_close_range_seen_flag_is_used_by_interact_entry_path() -> void:
	var hide_spot := HideSpot.new()
	add_child_autofree(hide_spot)
	var player := (load(PLAYER_SCENE_PATH) as PackedScene).instantiate() as PlayerController
	add_child_autofree(player)
	player.set_close_range_seen(true)
	assert_false(player.try_enter_hide_spot(null, player.close_range_seen()))
	assert_false(player.is_visibility_excluded())


func test_airborne_player_cannot_enter_hide_spot() -> void:
	var hide_spot := HideSpot.new()
	add_child_autofree(hide_spot)
	var player := (load(PLAYER_SCENE_PATH) as PackedScene).instantiate() as PlayerController
	add_child_autofree(player)
	player.velocity.y = -1.0
	assert_false(player.try_enter_hide_spot(hide_spot))


func test_airborne_apex_cannot_enter_hide_spot() -> void:
	var hide_spot := HideSpot.new()
	add_child_autofree(hide_spot)
	var player := (load(PLAYER_SCENE_PATH) as PackedScene).instantiate() as PlayerController
	add_child_autofree(player)
	player.velocity = Vector3.ZERO
	assert_false(player.try_enter_hide_spot(hide_spot))


func _add_floor() -> StaticBody3D:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	floor_body.position = Vector3(0.0, -1.0, 0.0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(10.0, 0.2, 10.0)
	collision.shape = shape
	floor_body.add_child(collision)
	add_child_autofree(floor_body)
	return floor_body


func test_hidden_state_has_sneak_stance_and_only_exits_to_crouch() -> void:
	var state_machine := PlayerStateMachine.new()
	add_child_autofree(state_machine)

	assert_true(state_machine.change_state(PlayerStateMachine.STATE_HIDDEN))
	assert_eq(state_machine.stance(), Enums.Stance.SNEAK)
	assert_true(state_machine.is_visibility_excluded())
	assert_eq(state_machine.movement_params().get(&"visibility_mod"), 0.0)
	assert_false(state_machine.change_state(PlayerStateMachine.STATE_GROUND))
	assert_true(state_machine.change_state(PlayerStateMachine.STATE_CROUCH))
