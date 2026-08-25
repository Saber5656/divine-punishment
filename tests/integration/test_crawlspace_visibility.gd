extends GutTest


const PLAYER_SCENE_PATH := "res://src/player/player.tscn"


func test_crawl_camera_has_clear_world_sightline_to_enemy_feet_through_floor_gap() -> void:
	var entrance := CrawlEntrance.new()
	entrance.position = Vector3(0.0, 0.0, 1.0)
	entrance.inside_offset = Vector3(0.0, 0.0, -1.0)
	add_child_autofree(entrance)
	var player := (load(PLAYER_SCENE_PATH) as PackedScene).instantiate() as PlayerController
	player.position = entrance.outside_world_position()
	add_child_autofree(player)
	assert_true(player.try_enter_crawlspace(entrance))

	_add_floor_panel(Vector3(-0.75, 1.0, 0.0), Vector3(1.2, 0.2, 8.0))
	_add_floor_panel(Vector3(0.75, 1.0, 0.0), Vector3(1.2, 0.2, 8.0))
	var enemy_feet := MeshInstance3D.new()
	enemy_feet.name = &"EnemyFeet"
	enemy_feet.position = Vector3(0.0, 1.35, 0.0)
	var feet_mesh := BoxMesh.new()
	feet_mesh.size = Vector3(0.45, 0.2, 0.3)
	enemy_feet.mesh = feet_mesh
	add_child_autofree(enemy_feet)
	await get_tree().physics_frame
	await get_tree().process_frame

	var camera := player.get_node("CameraRig/SpringArm3D/Camera3D") as Camera3D
	assert_lt(camera.global_position.y, 1.0, "Crawl camera must remain below the floor")
	assert_gt(enemy_feet.global_position.y, 1.0, "Enemy feet fixture must remain above the floor")
	camera.look_at(enemy_feet.global_position, Vector3.UP)
	assert_true(
		camera.is_position_in_frustum(enemy_feet.global_position),
		"Enemy feet must be inside the crawl camera frustum when the player aims through the gap",
	)
	var clear_query := PhysicsRayQueryParameters3D.create(
		camera.global_position,
		enemy_feet.global_position,
		PlayerController.WORLD_COLLISION_MASK,
		[player.get_rid()],
	)
	clear_query.collide_with_areas = false
	clear_query.collide_with_bodies = true
	assert_true(
		player.get_world_3d().direct_space_state.intersect_ray(clear_query).is_empty(),
		"The actual crawl camera-to-feet sightline must pass through the floor gap",
	)

	_add_floor_panel(Vector3.ZERO + Vector3.UP, Vector3(0.4, 0.2, 8.0))
	await get_tree().physics_frame
	assert_false(
		player.get_world_3d().direct_space_state.intersect_ray(clear_query).is_empty(),
		"Covering the authored gap must block the same sightline",
	)


func _add_floor_panel(world_position: Vector3, size: Vector3) -> StaticBody3D:
	var panel := StaticBody3D.new()
	panel.collision_layer = PlayerController.WORLD_COLLISION_MASK
	panel.collision_mask = 0
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	panel.add_child(collision)
	panel.position = world_position
	add_child_autofree(panel)
	return panel
