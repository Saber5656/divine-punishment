extends GutTest


const PLAYER_SCENE_PATH := "res://src/player/player.tscn"
const WallClingRules := preload("res://src/player/player_wall_cling.gd")


func after_each() -> void:
	_send_physical_key(KEY_A, false)
	_send_physical_key(KEY_D, false)
	_send_physical_key(KEY_W, false)
	for action: StringName in [&"interact", &"sprint", &"peek", &"move_left", &"move_right", &"move_forward", &"move_backward"]:
		Input.action_release(action)


func test_wall_cling_rules_reject_invalid_normals_and_inputs() -> void:
	assert_eq(WallClingRules.normalized_wall_normal(Vector3.ZERO), Vector3.ZERO)
	assert_eq(WallClingRules.normalized_wall_normal(Vector3.UP), Vector3.ZERO)
	assert_eq(WallClingRules.normalized_wall_normal(Vector3(NAN, 0.0, 0.0)), Vector3.ZERO)

	var normalized := WallClingRules.normalized_wall_normal(Vector3(2.0, 0.1, 0.0))
	assert_almost_eq(normalized.x, 1.0, 0.0001)
	assert_almost_eq(normalized.y, 0.0, 0.0001)
	assert_almost_eq(normalized.z, 0.0, 0.0001)
	assert_eq(WallClingRules.project_movement(Vector3(NAN, 0.0, 0.0), Vector3.FORWARD), Vector3.ZERO)
	assert_almost_eq(WallClingRules.sanitize_axis(2.0), 1.0, 0.0001)
	assert_almost_eq(WallClingRules.sanitize_axis(-2.0), -1.0, 0.0001)
	assert_almost_eq(WallClingRules.sanitize_axis(INF), 0.0, 0.0001)


func test_wall_cling_rules_project_movement_onto_wall_tangent() -> void:
	var wall_normal := Vector3.BACK
	var projected := WallClingRules.project_movement(Vector3(1.0, 0.0, -1.0), wall_normal)

	assert_almost_eq(projected.x, 1.0, 0.0001)
	assert_almost_eq(projected.y, 0.0, 0.0001)
	assert_almost_eq(projected.z, 0.0, 0.0001)
	assert_eq(WallClingRules.project_movement(Vector3.FORWARD, wall_normal), Vector3.ZERO)
	assert_almost_eq(WallClingRules.wall_tangent(wall_normal).dot(wall_normal), 0.0, 0.0001)


func test_interact_enters_wall_cling_only_near_world_geometry() -> void:
	var player := _add_player()
	_add_box_body(Vector3(0.0, 0.0, -0.7), Vector3(2.0, 2.0, 0.2), 1)
	await get_tree().physics_frame

	Input.action_press(&"interact")
	player._update_state_from_input()
	Input.action_release(&"interact")

	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_WALL_CLING)
	assert_gt(player.wall_cling_normal().z, 0.9)

	var isolated_player := _add_player(Vector3(4.0, 0.0, 0.0))
	_add_box_body(Vector3(4.0, 0.0, -0.7), Vector3(2.0, 2.0, 0.2), 4)
	await get_tree().physics_frame

	assert_false(isolated_player.try_enter_wall_cling())
	assert_eq(isolated_player.state_machine.current_state(), PlayerStateMachine.STATE_GROUND)


func test_player_clings_to_column_from_the_side() -> void:
	var player := _add_player()
	_add_column(Vector3(0.75, 0.0, 0.0))
	await get_tree().physics_frame

	assert_true(player.try_enter_wall_cling())
	assert_lt(player.wall_cling_normal().x, -0.9)


func test_crouch_requires_standing_clearance_before_wall_cling() -> void:
	var player := _add_player()
	_add_box_body(Vector3(0.0, 0.0, -0.7), Vector3(2.0, 2.0, 0.2), 1)
	assert_true(player.state_machine.change_state(PlayerStateMachine.STATE_CROUCH))
	_add_box_body(Vector3(0.0, 0.75, 0.0), Vector3(2.0, 0.2, 2.0), 1)
	await get_tree().physics_frame

	assert_false(player.try_enter_wall_cling())
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_CROUCH)


func test_crouch_enters_wall_cling_when_standing_clearance_is_available() -> void:
	var player := _add_player()
	_add_box_body(Vector3(0.0, 0.0, -0.7), Vector3(2.0, 2.0, 0.2), 1)
	assert_true(player.state_machine.change_state(PlayerStateMachine.STATE_CROUCH))
	await get_tree().physics_frame

	assert_true(player.try_enter_wall_cling())
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_WALL_CLING)
	assert_gt(player.wall_cling_normal().z, 0.9)


func test_invalid_wall_probe_configuration_fails_closed() -> void:
	var player := _add_player()
	_add_box_body(Vector3(0.0, 0.0, -0.7), Vector3(2.0, 2.0, 0.2), 1)
	await get_tree().physics_frame

	player.wall_probe_distance = INF
	assert_false(player.try_enter_wall_cling())
	player.wall_probe_distance = 2.01
	assert_false(player.try_enter_wall_cling())
	player.wall_probe_distance = 0.75
	player.wall_probe_height = NAN
	assert_false(player.try_enter_wall_cling())
	player.wall_probe_height = 2.01
	assert_false(player.try_enter_wall_cling())
	player.wall_probe_height = 0.5
	assert_true(player.try_enter_wall_cling())


func test_wall_refresh_retains_current_surface_at_concave_corner() -> void:
	var player := _add_player()
	_add_box_body(Vector3(0.0, 0.0, -0.7), Vector3(2.0, 2.0, 0.2), 1)
	await get_tree().physics_frame
	assert_true(player.try_enter_wall_cling())
	assert_gt(player.wall_cling_normal().z, 0.9)

	_add_box_body(Vector3(0.55, 0.0, 0.0), Vector3(0.2, 2.0, 2.0), 1)
	await get_tree().physics_frame
	player._update_state_from_input()

	assert_gt(player.wall_cling_normal().z, 0.9)
	assert_almost_eq(player.wall_cling_normal().x, 0.0, 0.0001)


func test_wall_cling_longitudinal_movement_is_orientation_independent() -> void:
	var cases: Array[Dictionary] = [
		{
			&"position": Vector3(0.0, 0.0, 0.0),
			&"wall_position": Vector3(0.0, 0.0, -0.7),
			&"wall_size": Vector3(2.0, 2.0, 0.2),
			&"normal": Vector3.BACK,
			&"movement": Vector3.LEFT,
			&"yaw": 0.37,
		},
		{
			&"position": Vector3(4.0, 0.0, 0.0),
			&"wall_position": Vector3(4.0, 0.0, 0.7),
			&"wall_size": Vector3(2.0, 2.0, 0.2),
			&"normal": Vector3.FORWARD,
			&"movement": Vector3.RIGHT,
			&"yaw": -0.61,
		},
		{
			&"position": Vector3(8.0, 0.0, 0.0),
			&"wall_position": Vector3(8.7, 0.0, 0.0),
			&"wall_size": Vector3(0.2, 2.0, 2.0),
			&"normal": Vector3.LEFT,
			&"movement": Vector3.FORWARD,
			&"yaw": 0.83,
		},
		{
			&"position": Vector3(12.0, 0.0, 0.0),
			&"wall_position": Vector3(11.3, 0.0, 0.0),
			&"wall_size": Vector3(0.2, 2.0, 2.0),
			&"normal": Vector3.RIGHT,
			&"movement": Vector3.BACK,
			&"yaw": -1.1,
		},
	]
	var players: Array[PlayerController] = []
	var initial_positions: Array[Vector3] = []
	for case: Dictionary in cases:
		var player := _add_player(case[&"position"])
		player.rotation.y = float(case[&"yaw"])
		players.append(player)
		initial_positions.append(player.global_position)
		_add_box_body(case[&"wall_position"], case[&"wall_size"], 1)
	await get_tree().physics_frame

	_send_physical_key(KEY_W, true)
	_send_physical_key(KEY_D, true)
	assert_true(Input.is_action_pressed(&"move_forward"))
	assert_true(Input.is_action_pressed(&"peek"))
	for index: int in players.size():
		var player := players[index]
		var expected_normal: Vector3 = cases[index][&"normal"]
		var expected_movement: Vector3 = cases[index][&"movement"]
		assert_true(player.try_enter_wall_cling())
		assert_gt(player.wall_cling_normal().dot(expected_normal), 0.9)
		player._update_state_from_input()
		player._apply_movement()
		assert_almost_eq(player.camera_peek_offset().x, 0.75, 0.0001)
		assert_almost_eq(player.velocity.x, expected_movement.x * 1.5, 0.0001)
		assert_almost_eq(player.velocity.z, expected_movement.z * 1.5, 0.0001)
		player.move_and_slide()
		var displacement := player.global_position - initial_positions[index]
		assert_gt(displacement.dot(expected_movement), 0.0)
		assert_almost_eq(displacement.dot(expected_normal), 0.0, 0.0001)


func test_physical_peek_input_does_not_move_player_or_detect_points() -> void:
	var player := _add_player()
	_add_box_body(Vector3(0.0, 0.0, -0.7), Vector3(2.0, 2.0, 0.2), 1)
	await get_tree().physics_frame
	assert_true(player.try_enter_wall_cling())

	var player_transform := player.global_transform
	var detect_points := player.get_node("DetectPoints") as Node3D
	var detect_transforms: Array[Transform3D] = []
	for marker: Node3D in detect_points.get_children():
		detect_transforms.append(marker.global_transform)

	_send_physical_key(KEY_D, true)
	assert_true(Input.is_action_pressed(&"move_right"))
	assert_true(Input.is_action_pressed(&"peek"))
	player._update_state_from_input()
	player._apply_movement()
	player.move_and_slide()

	assert_almost_eq(player.velocity.x, 0.0, 0.0001)
	assert_almost_eq(player.velocity.z, 0.0, 0.0001)
	assert_almost_eq(player.camera_peek_offset().x, 0.75, 0.0001)
	assert_eq(player.global_transform, player_transform)
	for index: int in detect_transforms.size():
		assert_eq((detect_points.get_child(index) as Node3D).global_transform, detect_transforms[index])

	_send_physical_key(KEY_D, false)
	_send_physical_key(KEY_A, true)
	assert_true(Input.is_action_pressed(&"move_left"))
	assert_true(Input.is_action_pressed(&"peek"))
	player._update_state_from_input()
	player._apply_movement()
	player.move_and_slide()
	assert_almost_eq(player.camera_peek_offset().x, -0.75, 0.0001)
	assert_eq(player.global_transform, player_transform)
	for index: int in detect_transforms.size():
		assert_eq((detect_points.get_child(index) as Node3D).global_transform, detect_transforms[index])


func test_sprint_and_wall_loss_release_cling_and_clear_peek() -> void:
	var player := _add_player()
	var wall := _add_box_body(Vector3(0.0, 0.0, -0.7), Vector3(2.0, 2.0, 0.2), 1)
	await get_tree().physics_frame
	assert_true(player.try_enter_wall_cling())

	Input.action_press(&"peek")
	Input.action_press(&"move_right")
	player._update_state_from_input()
	assert_ne(player.camera_peek_offset(), Vector3.ZERO)
	Input.action_press(&"sprint")
	player._update_state_from_input()
	Input.action_release(&"sprint")
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_GROUND)
	assert_eq(player.camera_peek_offset(), Vector3.ZERO)
	assert_eq(player.wall_cling_normal(), Vector3.ZERO)

	assert_true(player.try_enter_wall_cling())
	player._update_state_from_input()
	assert_ne(player.camera_peek_offset(), Vector3.ZERO)
	wall.position = Vector3(0.0, 0.0, -5.0)
	await get_tree().physics_frame
	player._update_state_from_input()

	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_GROUND)
	assert_eq(player.camera_peek_offset(), Vector3.ZERO)
	assert_eq(player.wall_cling_normal(), Vector3.ZERO)


func _add_player(at: Vector3 = Vector3.ZERO) -> PlayerController:
	var player := (load(PLAYER_SCENE_PATH) as PackedScene).instantiate() as PlayerController
	player.position = at
	add_child_autofree(player)
	player.set_process(false)
	player.set_physics_process(false)
	return player


func _add_box_body(at: Vector3, size: Vector3, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = at
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child_autofree(body)
	return body


func _add_column(at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = at
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.3
	shape.height = 2.0
	collision.shape = shape
	body.add_child(collision)
	add_child_autofree(body)
	return body


func _send_physical_key(keycode: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
