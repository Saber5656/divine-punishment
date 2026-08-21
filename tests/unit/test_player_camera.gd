extends GutTest


const PLAYER_SCENE_PATH := "res://src/player/player.tscn"

var original_camera_config: CameraConfig


func before_each() -> void:
	original_camera_config = Tuning.camera()


func after_each() -> void:
	if Tuning.camera() != original_camera_config:
		Tuning._camera = original_camera_config
		Tuning.reloaded.emit()


func test_player_scene_has_follow_camera_with_spring_arm_collision() -> void:
	var player := _add_player()
	var camera_rig := player.get_node("CameraRig") as PlayerCameraRig
	var spring_arm := camera_rig.get_node("SpringArm3D") as SpringArm3D
	var camera := spring_arm.get_node("Camera3D") as Camera3D

	assert_eq(camera_rig.position, Vector3(0.0, 1.5, 0.0))
	assert_almost_eq(spring_arm.spring_length, 3.5, 0.0001)
	assert_almost_eq(spring_arm.margin, 0.1, 0.0001)
	assert_eq(spring_arm.collision_mask, 1)
	assert_true(spring_arm.shape is SphereShape3D)
	assert_true(camera.current)
	assert_eq(camera_rig.camera_config(), Tuning.camera())

	var initial_relative_position := camera_rig.position
	player.position = Vector3(3.0, 0.0, 4.0)
	assert_eq(camera_rig.global_position, player.global_position + initial_relative_position)


func test_spring_arm_shortens_camera_path_at_world_collision() -> void:
	var player := _add_player()
	var spring_arm := player.get_node("CameraRig/SpringArm3D") as SpringArm3D
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var wall_collision := CollisionShape3D.new()
	var wall_shape := BoxShape3D.new()
	wall_shape.size = Vector3(2.0, 2.0, 0.2)
	wall_collision.shape = wall_shape
	wall.add_child(wall_collision)
	wall.position = Vector3(0.0, 1.5, 2.0)
	add_child_autofree(wall)

	await get_tree().physics_frame
	await get_tree().process_frame

	assert_gt(spring_arm.get_hit_length(), 0.0)
	assert_lt(spring_arm.get_hit_length(), spring_arm.spring_length)


func test_camera_look_uses_reloaded_tuning_sensitivity() -> void:
	var player := _add_player()
	var camera_rig := player.get_node("CameraRig") as PlayerCameraRig
	var replacement := CameraConfig.new()
	replacement.mouse_look_sensitivity = 0.01
	replacement.gamepad_look_speed = 4.0
	Tuning._camera = replacement
	Tuning.reloaded.emit()

	var mouse_motion := InputEventMouseMotion.new()
	mouse_motion.screen_relative = Vector2(20.0, -10.0)
	player._unhandled_input(mouse_motion)

	assert_almost_eq(player.rotation.y, -0.2, 0.0001)
	assert_almost_eq(camera_rig.rotation.x, 0.1, 0.0001)
	assert_eq(camera_rig.camera_config(), replacement)
	assert_almost_eq(camera_rig.apply_gamepad_look(Vector2(0.5, 0.0), 0.5), -1.0, 0.0001)


func test_peek_offset_api_clamps_camera_without_moving_player_body() -> void:
	var player := _add_player()
	var initial_player_position := player.position

	player.set_camera_peek_offset(Vector3(2.0, -1.0, 4.0))

	var resolved_offset := player.camera_peek_offset()
	assert_almost_eq(resolved_offset.x, 0.75, 0.0001)
	assert_almost_eq(resolved_offset.y, -0.3, 0.0001)
	assert_almost_eq(resolved_offset.z, 0.0, 0.0001)
	assert_eq(player.position, initial_player_position)

	player.reset_camera_peek_offset()
	assert_eq(player.camera_peek_offset(), Vector3.ZERO)


func test_peek_offset_rejects_non_finite_components() -> void:
	var player := _add_player()

	player.set_camera_peek_offset(Vector3(NAN, INF, -INF))

	assert_eq(player.camera_peek_offset(), Vector3.ZERO)


func _add_player() -> PlayerController:
	var player := (load(PLAYER_SCENE_PATH) as PackedScene).instantiate() as PlayerController
	add_child_autofree(player)
	return player
