extends GutTest


const PlayerProfileScript := preload("res://src/player/player_profile.gd")
const PlayerStateMachineScript := preload("res://src/player/player_state_machine.gd")
const PLAYER_SCENE_PATH := "res://src/player/player.tscn"
const DEFAULT_PROFILE_PATH := "res://data/profiles/default.tres"
const MOVEMENT_PATH := "res://data/tuning/movement.tres"

var state_machine: PlayerStateMachine
var original_tuning_movement: MovementConfig


func before_each() -> void:
	original_tuning_movement = Tuning.movement()
	state_machine = PlayerStateMachineScript.new()
	add_child_autofree(state_machine)


func after_each() -> void:
	Input.action_release(&"stance_toggle")
	Input.action_release(&"sprint")
	Input.action_release(&"interact")
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	if Tuning.movement() != original_tuning_movement:
		Tuning._movement = original_tuning_movement
		Tuning.reloaded.emit()


func test_initial_state_and_ground_params_come_from_tuning() -> void:
	assert_eq(state_machine.current_state(), &"Ground")
	assert_eq(state_machine.stance(), Enums.Stance.WALK)
	assert_eq(state_machine.movement_params(), {
		&"speed": 3.0,
		&"noise_radius": 4.0,
		&"visibility_mod": 1.0,
	})


func test_ground_crouch_and_sprint_transitions_emit_state_changes() -> void:
	watch_signals(state_machine)

	assert_true(state_machine.change_state(&"Crouch"))
	assert_true(state_machine.change_state(&"Sprint"))
	assert_true(state_machine.resume_from_sprint())

	assert_eq(state_machine.current_state(), &"Crouch")
	assert_signal_emit_count(state_machine, "state_changed", 3)
	assert_signal_emitted_with_parameters(state_machine, "state_changed", [&"Ground", &"Crouch"], 0)
	assert_signal_emitted_with_parameters(state_machine, "state_changed", [&"Crouch", &"Sprint"], 1)
	assert_signal_emitted_with_parameters(state_machine, "state_changed", [&"Sprint", &"Crouch"], 2)


func test_sprint_release_restores_ground_origin() -> void:
	assert_true(state_machine.change_state(&"Sprint"))
	assert_true(state_machine.resume_from_sprint())
	assert_eq(state_machine.current_state(), &"Ground")


func test_wall_cling_transitions_use_sneak_params_and_release_to_ground() -> void:
	watch_signals(state_machine)

	assert_true(state_machine.change_state(PlayerStateMachine.STATE_WALL_CLING))
	assert_eq(state_machine.current_state(), PlayerStateMachine.STATE_WALL_CLING)
	assert_eq(state_machine.stance(), Enums.Stance.SNEAK)
	assert_eq(state_machine.movement_params(), {
		&"speed": 1.5,
		&"noise_radius": 1.0,
		&"visibility_mod": 0.6,
	})
	assert_false(state_machine.change_state(PlayerStateMachine.STATE_CROUCH))
	assert_true(state_machine.change_state(PlayerStateMachine.STATE_GROUND))
	assert_true(state_machine.change_state(PlayerStateMachine.STATE_CROUCH))
	assert_true(state_machine.change_state(PlayerStateMachine.STATE_WALL_CLING))
	assert_true(state_machine.change_state(PlayerStateMachine.STATE_GROUND))
	assert_true(state_machine.change_state(PlayerStateMachine.STATE_SPRINT))
	assert_false(state_machine.change_state(PlayerStateMachine.STATE_WALL_CLING))

	assert_signal_emit_count(state_machine, "state_changed", 6)


func test_climb_and_beam_transitions_follow_marker_contract() -> void:
	assert_true(state_machine.change_state(PlayerStateMachine.STATE_CLIMB))
	assert_eq(state_machine.stance(), Enums.Stance.SNEAK)
	assert_false(state_machine.change_state(PlayerStateMachine.STATE_CROUCH))
	assert_true(state_machine.change_state(PlayerStateMachine.STATE_BEAM))
	assert_eq(state_machine.stance(), Enums.Stance.SNEAK)
	assert_false(state_machine.change_state(PlayerStateMachine.STATE_SPRINT))
	assert_true(state_machine.change_state(PlayerStateMachine.STATE_CLIMB))
	assert_true(state_machine.change_state(PlayerStateMachine.STATE_GROUND))
	assert_true(state_machine.change_state(PlayerStateMachine.STATE_WALL_CLING))
	assert_true(state_machine.change_state(PlayerStateMachine.STATE_CLIMB))


func test_invalid_transition_is_rejected_and_same_state_is_a_no_op() -> void:
	watch_signals(state_machine)

	assert_false(state_machine.change_state(&"Invalid"))
	assert_true(state_machine.change_state(&"Ground"))

	assert_eq(state_machine.current_state(), &"Ground")
	assert_signal_not_emitted(state_machine, "state_changed")


func test_crouch_and_sprint_params_come_from_tuning() -> void:
	state_machine.change_state(&"Crouch")
	assert_eq(state_machine.movement_params(), {
		&"speed": 1.5,
		&"noise_radius": 1.0,
		&"visibility_mod": 0.6,
	})

	state_machine.change_state(&"Sprint")
	assert_eq(state_machine.movement_params(), {
		&"speed": 6.0,
		&"noise_radius": 12.0,
		&"visibility_mod": 1.3,
	})


func test_default_profile_matches_schema_and_current_movement_tuning() -> void:
	var profile := load(DEFAULT_PROFILE_PATH)
	var movement := load(MOVEMENT_PATH) as MovementConfig

	assert_not_null(profile)
	assert_eq((profile.get_script() as Script).resource_path, PlayerProfileScript.resource_path)
	assert_eq(profile.get("move_speeds"), _profile_values(movement.move_speeds))
	assert_eq(profile.get("noise_radii"), _profile_values(movement.noise_radii))
	assert_eq(profile.get("visibility_mods"), _profile_values(movement.visibility_mods))
	assert_false(profile.get("move_speeds").has(&"walk"))
	assert_false(profile.get("noise_radii").has(&"walk"))
	assert_false(profile.get("visibility_mods").has(&"walk"))
	assert_eq(profile.get("stationary_visibility_mod"), movement.stationary_visibility_mod)
	assert_eq(profile.get("breath_seconds"), movement.breath_seconds)
	assert_eq(profile.get("max_health"), 3)
	assert_eq(profile.get("tool_slots"), 3)
	assert_eq(profile.get("allowed_actions"), [
		&"move_forward",
		&"move_backward",
		&"move_left",
		&"move_right",
		&"camera_up",
		&"camera_down",
		&"camera_left",
		&"camera_right",
		&"stance_toggle",
		&"sprint",
		&"interact",
		&"assassinate",
		&"tool_use",
		&"tool_cycle",
		&"aim",
		&"peek",
		&"attack",
		&"parry",
		&"dodge",
		&"pause",
		&"sword",
		&"assassinate_lethal",
		&"dart",
	])


func test_default_profile_tracks_tuning_reload() -> void:
	var replacement := MovementConfig.new()
	replacement.move_speeds = {&"walk": 9.0}
	replacement.noise_radii = {&"walk": 8.0}
	replacement.visibility_mods = {&"walk": 0.25}

	Tuning._movement = replacement
	Tuning.reloaded.emit()

	assert_eq(state_machine.movement_params(), {
		&"speed": 9.0,
		&"noise_radius": 8.0,
		&"visibility_mod": 0.25,
	})


func test_player_injects_an_explicit_profile_into_the_state_machine() -> void:
	var profile := PlayerProfileScript.new()
	profile.move_speeds = {Enums.Stance.WALK: 7.0}
	profile.noise_radii = {Enums.Stance.WALK: 2.0}
	profile.visibility_mods = {Enums.Stance.WALK: 0.5}
	var player := (load(PLAYER_SCENE_PATH) as PackedScene).instantiate() as PlayerController
	player.player_profile = profile
	add_child_autofree(player)

	assert_eq(player.current_movement_params(), {
		&"speed": 7.0,
		&"noise_radius": 2.0,
		&"visibility_mod": 0.5,
	})


func test_player_scene_matches_the_contracted_skeleton() -> void:
	var packed_scene := load(PLAYER_SCENE_PATH) as PackedScene
	assert_not_null(packed_scene)
	var player := packed_scene.instantiate() as CharacterBody3D
	add_child_autofree(player)

	assert_eq(player.collision_layer, 2)
	assert_eq(player.collision_mask, 1)
	assert_eq(player.get_child_count(), 10)
	assert_eq(player.get_child(0).name, &"CollisionShape3D")
	assert_eq(player.get_child(1).name, &"Visual")
	assert_eq(player.get_child(2).name, &"StateMachine")
	assert_eq(player.get_child(3).name, &"Visibility")
	assert_eq(player.get_child(4).name, &"AssassinationResolver")
	assert_eq(player.get_child(5).name, &"Interactor")
	assert_eq(player.get_child(6).name, &"NoiseEmitter")
	assert_eq(player.get_child(7).name, &"ToolRig")
	assert_eq(player.get_child(8).name, &"CameraRig")
	assert_eq(player.get_child(9).name, &"DetectPoints")
	assert_true(player.get_node("StateMachine") is PlayerStateMachine)
	assert_eq((player.get_node("Interactor") as Area3D).collision_layer, 0)
	assert_eq((player.get_node("Interactor") as Area3D).collision_mask, 22976)
	assert_true((player.get_node("DetectPoints") as Node3D).is_in_group(&"player_detect_points"))


func test_controller_drives_crouch_and_sprint_from_input() -> void:
	var player := (load(PLAYER_SCENE_PATH) as PackedScene).instantiate() as PlayerController
	add_child_autofree(player)
	var player_state_machine := player.get_node("StateMachine") as PlayerStateMachine

	Input.action_press(&"stance_toggle")
	player._update_state_from_input()
	Input.action_release(&"stance_toggle")
	assert_eq(player_state_machine.current_state(), &"Crouch")

	Input.action_press(&"sprint")
	player._update_state_from_input()
	assert_eq(player_state_machine.current_state(), &"Sprint")

	Input.action_release(&"sprint")
	player._update_state_from_input()
	assert_eq(player_state_machine.current_state(), &"Crouch")


func test_controller_resizes_collision_shape_for_crouch() -> void:
	var player := (load(PLAYER_SCENE_PATH) as PackedScene).instantiate() as PlayerController
	add_child_autofree(player)
	var player_state_machine := player.get_node("StateMachine") as PlayerStateMachine
	var collision_shape := player.get_node("CollisionShape3D") as CollisionShape3D
	var capsule := collision_shape.shape as CapsuleShape3D
	var standing_height := capsule.height
	var standing_y := collision_shape.position.y

	assert_true(player_state_machine.change_state(PlayerStateMachine.STATE_CROUCH))
	assert_almost_eq(capsule.height, player.crouch_capsule_height, 0.0001)
	assert_lt(collision_shape.position.y, standing_y)

	assert_true(player._try_enter_standing_state(PlayerStateMachine.STATE_GROUND))
	assert_eq(capsule.height, standing_height)
	assert_eq(collision_shape.position.y, standing_y)


func test_controller_blocks_standing_when_ceiling_has_no_clearance() -> void:
	var player := (load(PLAYER_SCENE_PATH) as PackedScene).instantiate() as PlayerController
	add_child_autofree(player)
	var player_state_machine := player.get_node("StateMachine") as PlayerStateMachine
	var collision_shape := player.get_node("CollisionShape3D") as CollisionShape3D
	var capsule := collision_shape.shape as CapsuleShape3D
	assert_true(player_state_machine.change_state(PlayerStateMachine.STATE_CROUCH))

	var ceiling := StaticBody3D.new()
	var ceiling_shape := CollisionShape3D.new()
	var ceiling_box := BoxShape3D.new()
	ceiling_box.size = Vector3(2.0, 0.2, 2.0)
	ceiling_shape.shape = ceiling_box
	ceiling.add_child(ceiling_shape)
	ceiling.position = Vector3(0.0, 0.75, 0.0)
	add_child_autofree(ceiling)
	await get_tree().physics_frame

	assert_false(player._try_enter_standing_state(PlayerStateMachine.STATE_GROUND))
	assert_eq(player_state_machine.current_state(), PlayerStateMachine.STATE_CROUCH)
	assert_almost_eq(capsule.height, player.crouch_capsule_height, 0.0001)


func test_controller_applies_project_gravity_while_airborne() -> void:
	var player := (load(PLAYER_SCENE_PATH) as PackedScene).instantiate() as PlayerController
	player.position = Vector3(0.0, 2.0, 0.0)
	add_child_autofree(player)
	var initial_height := player.position.y

	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_false(player.is_on_floor())
	assert_lt(player.velocity.y, 0.0)
	assert_lt(player.position.y, initial_height)


func test_controller_processes_mouse_motion_for_camera_look() -> void:
	var player := (load(PLAYER_SCENE_PATH) as PackedScene).instantiate() as PlayerController
	add_child_autofree(player)
	var camera_rig := player.get_node("CameraRig") as Node3D
	var mouse_motion := InputEventMouseMotion.new()
	mouse_motion.screen_relative = Vector2(20.0, -10.0)

	player._unhandled_input(mouse_motion)

	assert_false(is_equal_approx(player.rotation.y, 0.0))
	assert_false(is_equal_approx(camera_rig.rotation.x, 0.0))


func test_input_map_defines_kbm_and_gamepad_bindings() -> void:
	var profile := load(DEFAULT_PROFILE_PATH) as PlayerProfile
	for action: StringName in profile.allowed_actions:
		assert_true(InputMap.has_action(action), "%s must be registered in InputMap" % action)

	assert_true(_has_physical_key(&"move_forward", KEY_W))
	assert_true(_has_joy_motion(&"move_forward", JOY_AXIS_LEFT_Y, -1.0))
	assert_true(_has_physical_key(&"move_backward", KEY_S))
	assert_true(_has_joy_motion(&"move_backward", JOY_AXIS_LEFT_Y, 1.0))
	assert_true(_has_physical_key(&"move_left", KEY_A))
	assert_true(_has_joy_motion(&"move_left", JOY_AXIS_LEFT_X, -1.0))
	assert_true(_has_physical_key(&"move_right", KEY_D))
	assert_true(_has_joy_motion(&"move_right", JOY_AXIS_LEFT_X, 1.0))
	assert_true(_has_physical_key(&"stance_toggle", KEY_C))
	assert_true(_has_joy_button(&"stance_toggle", JOY_BUTTON_B))
	assert_true(_has_physical_key(&"sprint", KEY_SHIFT))
	assert_true(_has_joy_button(&"sprint", JOY_BUTTON_LEFT_STICK))
	assert_true(_has_joy_motion(&"camera_up", JOY_AXIS_RIGHT_Y, -1.0))
	assert_true(_has_joy_motion(&"camera_down", JOY_AXIS_RIGHT_Y, 1.0))
	assert_true(_has_joy_motion(&"camera_left", JOY_AXIS_RIGHT_X, -1.0))
	assert_true(_has_joy_motion(&"camera_right", JOY_AXIS_RIGHT_X, 1.0))
	assert_true(_has_physical_key(&"interact", KEY_E))
	assert_true(_has_joy_button(&"interact", JOY_BUTTON_A))
	assert_true(_has_physical_key(&"assassinate", KEY_F))
	assert_true(_has_joy_button(&"assassinate", JOY_BUTTON_X))
	assert_true(_has_mouse_button(&"tool_use", MOUSE_BUTTON_LEFT))
	assert_true(_has_joy_motion(&"tool_use", JOY_AXIS_TRIGGER_RIGHT, 1.0))
	assert_true(_has_physical_key(&"tool_cycle", KEY_Q))
	assert_true(_has_mouse_button(&"tool_cycle", MOUSE_BUTTON_WHEEL_UP))
	assert_true(_has_mouse_button(&"tool_cycle", MOUSE_BUTTON_WHEEL_DOWN))
	assert_true(_has_joy_button(&"tool_cycle", JOY_BUTTON_RIGHT_SHOULDER))
	assert_true(_has_mouse_button(&"aim", MOUSE_BUTTON_RIGHT))
	assert_true(_has_joy_motion(&"aim", JOY_AXIS_TRIGGER_LEFT, 1.0))
	assert_true(_has_physical_key(&"peek", KEY_A))
	assert_true(_has_physical_key(&"peek", KEY_D))
	assert_true(_has_joy_motion(&"peek", JOY_AXIS_LEFT_X, -1.0))
	assert_true(_has_joy_motion(&"peek", JOY_AXIS_LEFT_X, 1.0))
	assert_true(_has_mouse_button(&"attack", MOUSE_BUTTON_LEFT))
	assert_true(_has_joy_button(&"attack", JOY_BUTTON_X))
	assert_true(_has_mouse_button(&"parry", MOUSE_BUTTON_RIGHT))
	assert_true(_has_joy_button(&"parry", JOY_BUTTON_LEFT_SHOULDER))
	assert_true(_has_physical_key(&"dodge", KEY_SPACE))
	assert_true(_has_joy_button(&"dodge", JOY_BUTTON_A))
	assert_true(_has_physical_key(&"pause", KEY_ESCAPE))
	assert_true(_has_joy_button(&"pause", JOY_BUTTON_START))


func _has_physical_key(action: StringName, keycode: int) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == keycode:
			return true
	return false


func _has_joy_motion(action: StringName, axis: int, value: float) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion:
			var motion := event as InputEventJoypadMotion
			if motion.axis == axis and is_equal_approx(motion.axis_value, value):
				return true
	return false


func _has_joy_button(action: StringName, button: int) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == button:
			return true
	return false


func _has_mouse_button(action: StringName, button: int) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == button:
			return true
	return false


func _profile_values(tuning_values: Dictionary) -> Dictionary:
	return {
		Enums.Stance.SNEAK: tuning_values.get(&"sneak"),
		Enums.Stance.WALK: tuning_values.get(&"walk"),
		Enums.Stance.SPRINT: tuning_values.get(&"sprint"),
		Enums.Stance.CRAWL: tuning_values.get(&"crawl"),
		Enums.Stance.SWIM: tuning_values.get(&"swim"),
	}
