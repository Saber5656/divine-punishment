extends GutTest


const PLAYER_SCENE_PATH := "res://src/player/player.tscn"


func test_hidden_player_is_excluded_until_interact_exit() -> void:
	var hide_spot := HideSpot.new()
	add_child_autofree(hide_spot)
	_add_floor()
	var player := (load(PLAYER_SCENE_PATH) as PackedScene).instantiate() as PlayerController
	add_child_autofree(player)
	await _await_player_grounded(player)

	assert_true(player.try_enter_hide_spot(hide_spot))
	assert_true(player.is_visibility_excluded())
	assert_eq(player.current_movement_params().get(&"visibility_mod"), 0.0)
	assert_true(player.try_exit_hide_spot())
	assert_false(player.is_visibility_excluded())
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_CROUCH)


func test_interact_enters_and_exits_hide_spot() -> void:
	var hide_spot := HideSpot.new()
	add_child_autofree(hide_spot)
	_add_floor()
	var player := (load(PLAYER_SCENE_PATH) as PackedScene).instantiate() as PlayerController
	add_child_autofree(player)

	Input.action_release(&"interact")
	await _await_player_grounded(player)
	player._update_state_from_input()
	Input.action_press(&"interact")
	player._update_state_from_input()
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_HIDDEN)

	Input.action_release(&"interact")
	player._update_state_from_input()
	Input.action_press(&"interact")
	player._update_state_from_input()
	Input.action_release(&"interact")
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_CROUCH)


func _add_floor() -> StaticBody3D:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	floor_body.position = Vector3(0.0, -0.95, 0.0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(10.0, 0.2, 10.0)
	collision.shape = shape
	floor_body.add_child(collision)
	add_child_autofree(floor_body)
	return floor_body


func _await_player_grounded(player: PlayerController) -> void:
	for _frame in 8:
		await get_tree().physics_frame
		if player.is_on_floor():
			return
	assert_true(player.is_on_floor())
