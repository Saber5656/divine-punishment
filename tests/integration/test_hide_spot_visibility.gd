extends GutTest


const PLAYER_SCENE_PATH := "res://src/player/player.tscn"


func test_hidden_player_is_excluded_until_interact_exit() -> void:
	var hide_spot := HideSpot.new()
	add_child_autofree(hide_spot)
	var player := (load(PLAYER_SCENE_PATH) as PackedScene).instantiate() as PlayerController
	add_child_autofree(player)

	assert_true(player.try_enter_hide_spot(hide_spot))
	assert_true(player.is_visibility_excluded())
	assert_eq(player.current_movement_params().get(&"visibility_mod"), 0.0)
	assert_true(player.try_exit_hide_spot())
	assert_false(player.is_visibility_excluded())
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_CROUCH)


func test_interact_enters_and_exits_hide_spot() -> void:
	var hide_spot := HideSpot.new()
	add_child_autofree(hide_spot)
	var player := (load(PLAYER_SCENE_PATH) as PackedScene).instantiate() as PlayerController
	add_child_autofree(player)

	Input.action_release(&"interact")
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
