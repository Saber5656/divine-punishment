extends GutTest


func test_production_enemy_eye_follows_translated_and_rotated_actor() -> void:
	var enemy := load("res://src/enemies/target_npc.tscn").instantiate() as TargetNpc
	add_child_autofree(enemy)
	enemy.position = Vector3(12, 2, -7)
	enemy.rotation.y = PI * 0.5
	var eye := enemy.get_node("Perception/EyePoint") as Marker3D
	assert_eq(eye.global_position, enemy.to_global(Vector3(0, 0.7, 0)))
	enemy.position += Vector3(-3, 1, 5)
	assert_eq(eye.global_position, enemy.to_global(Vector3(0, 0.7, 0)))


func test_body_detection_samples_follow_every_capsule_posture() -> void:
	var player := load("res://src/player/player.tscn").instantiate() as PlayerController
	add_child_autofree(player)
	await get_tree().process_frame
	for posture in [PlayerStateMachine.STATE_GROUND, PlayerStateMachine.STATE_CROUCH, PlayerStateMachine.STATE_CRAWLSPACE, PlayerStateMachine.STATE_SWIM_SURFACE, PlayerStateMachine.STATE_SWIM_UNDERWATER, PlayerStateMachine.STATE_HIDDEN]:
		player._apply_collision_shape_for_state(posture)
		var shape := player.collision_shape.shape as CapsuleShape3D
		var bottom := player.collision_shape.position.y - shape.height * 0.5
		var top := bottom + shape.height
		var previous := top
		for name in ["Head", "Chest", "Hips"]:
			var point := player.get_node("DetectPoints/" + name) as Node3D
			assert_between(point.position.y, bottom, top, "body sample inside " + String(posture))
			assert_lt(point.position.y, previous)
			previous = point.position.y
	player._apply_collision_shape_for_state(PlayerStateMachine.STATE_GROUND)
	var standing_head := (player.get_node("DetectPoints/Head") as Node3D).position.y
	player._apply_collision_shape_for_state(PlayerStateMachine.STATE_CROUCH)
	assert_lt((player.get_node("DetectPoints/Head") as Node3D).position.y, standing_head)
