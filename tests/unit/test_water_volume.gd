extends GutTest


func test_water_volume_builds_a_bounded_player_interaction_shape() -> void:
	var volume := _add_volume()

	assert_true(volume.is_geometry_valid())
	assert_eq(volume.collision_layer, WaterVolume.WATER_LAYER)
	assert_eq(volume.collision_mask, WaterVolume.PLAYER_BODY_LAYER)
	assert_true(volume.is_in_group(&"water_volumes"))
	var collision := volume.get_node(
		NodePath(String(WaterVolume.VOLUME_SHAPE_NODE_NAME)),
	) as CollisionShape3D
	assert_true(collision.shape is BoxShape3D)
	assert_eq((collision.shape as BoxShape3D).size, volume.size)
	assert_eq(collision.transform, Transform3D.IDENTITY)


func test_water_volume_enforces_size_depth_transform_and_world_bounds() -> void:
	var volume := _add_volume()
	assert_true(volume.is_geometry_valid())

	volume.size.x = WaterVolume.MIN_HORIZONTAL_SIZE - 0.01
	assert_false(volume.is_geometry_valid())
	volume.size = Vector3(8.0, 4.0, 8.0)
	volume.underwater_body_depth = volume.surface_body_depth + WaterVolume.MIN_DIVE_DISTANCE - 0.01
	assert_false(volume.is_geometry_valid())
	volume.underwater_body_depth = 2.25
	volume.surface_body_depth = NAN
	assert_false(volume.is_geometry_valid())
	volume.surface_body_depth = 0.75
	volume.position = Vector3(
		PlayerSwimRules.MAX_WORLD_COORDINATE - volume.size.x * 0.5,
		0.0,
		0.0,
	)
	assert_true(volume.is_geometry_valid())
	volume.position.x += 0.01
	assert_false(volume.is_geometry_valid())
	volume.position = Vector3.ZERO
	volume.scale = Vector3(2.0, 1.0, 1.0)
	assert_false(volume.is_geometry_valid())
	volume.scale = Vector3.ONE
	volume.position.x = PlayerSwimRules.MAX_WORLD_COORDINATE - volume.size.x * 0.5
	volume.rotate_y(PI * 0.25)
	assert_false(volume.is_geometry_valid())


func test_water_volume_transition_distance_and_surface_entry_band_are_bounded() -> void:
	var volume := _add_volume()
	volume.size = Vector3(8.0, 9.5, 8.0)
	volume.surface_body_depth = 0.75
	volume.underwater_body_depth = (
		volume.surface_body_depth + PlayerSwimRules.MAX_TRANSITION_DISTANCE
	)
	assert_true(volume.is_geometry_valid())
	var surface_position := volume.surface_body_position_for(volume.global_position)
	assert_true(volume.can_enter_from_position(surface_position))
	var bottom_position := volume.global_position - Vector3.UP * (volume.size.y * 0.5 - 0.01)
	assert_true(volume.contains_world_position(bottom_position))
	assert_false(volume.can_enter_from_position(bottom_position))

	volume.underwater_body_depth += 0.01
	assert_false(volume.is_geometry_valid())


func test_water_volume_rejects_world_extent_beyond_vertical_boundary() -> void:
	var volume := _add_volume()
	volume.position.y = PlayerSwimRules.MAX_WORLD_COORDINATE - volume.size.y * 0.5
	assert_true(volume.is_geometry_valid())
	volume.position.y += 0.01
	assert_false(volume.is_geometry_valid())


func test_surface_and_underwater_positions_preserve_horizontal_location() -> void:
	var volume := _add_volume()
	volume.position = Vector3(2.0, 2.0, 3.0)
	volume.rotate_y(PI * 0.25)
	var source := Vector3(2.5, 2.0, 3.25)
	assert_true(volume.contains_world_position(source))

	var surface := volume.surface_body_position_for(source)
	var underwater := volume.underwater_body_position_for(source)
	assert_almost_eq(surface.x, source.x, 0.0001)
	assert_almost_eq(surface.z, source.z, 0.0001)
	assert_almost_eq(surface.y, volume.surface_world_y() - volume.surface_body_depth, 0.0001)
	assert_almost_eq(underwater.x, source.x, 0.0001)
	assert_almost_eq(underwater.z, source.z, 0.0001)
	assert_almost_eq(
		underwater.y,
		volume.surface_world_y() - volume.underwater_body_depth,
		0.0001,
	)
	assert_true(volume.contains_world_position(surface))
	assert_true(volume.contains_world_position(underwater))


func test_water_volume_accepts_only_player_bodies_in_the_same_tree() -> void:
	var volume := _add_volume()
	var player := CharacterBody3D.new()
	player.collision_layer = WaterVolume.PLAYER_BODY_LAYER
	add_child_autofree(player)
	var enemy := CharacterBody3D.new()
	enemy.collision_layer = WaterVolume.ENEMY_BODY_LAYER
	add_child_autofree(enemy)

	assert_true(volume.can_accept_body(player))
	assert_false(volume.can_accept_body(enemy))
	player.collision_layer |= 1 << 5
	assert_false(volume.can_accept_body(player))
	player.collision_layer = WaterVolume.PLAYER_BODY_LAYER
	player.collision_layer |= WaterVolume.ENEMY_BODY_LAYER
	assert_false(volume.can_accept_body(player))
	player.collision_layer = WaterVolume.PLAYER_BODY_LAYER
	volume.collision_mask = 0
	assert_false(volume.can_accept_body(player))


func test_water_volume_shape_mutation_invalidates_the_contract() -> void:
	var volume := _add_volume()
	var collision := volume.get_node(
		NodePath(String(WaterVolume.VOLUME_SHAPE_NODE_NAME)),
	) as CollisionShape3D
	var replacement := BoxShape3D.new()
	replacement.size = volume.size
	collision.shape = replacement
	assert_false(volume.is_geometry_valid())


func _add_volume() -> WaterVolume:
	var volume := WaterVolume.new()
	add_child_autofree(volume)
	return volume
