extends GutTest


func test_hide_spot_builds_a_bounded_player_entry_area() -> void:
	var hide_spot := _add_hide_spot()

	assert_true(hide_spot.is_geometry_valid())
	assert_eq(hide_spot.collision_layer, HideSpot.HIDE_SPOT_LAYER)
	assert_eq(hide_spot.collision_mask, HideSpot.PLAYER_BODY_LAYER)
	assert_true(hide_spot.is_in_group(&"hide_spots"))
	var collision := hide_spot.get_node(
		NodePath(String(HideSpot.ENTRY_COLLISION_SHAPE_NODE_NAME)),
	) as CollisionShape3D
	assert_true(collision.shape is SphereShape3D)
	assert_almost_eq((collision.shape as SphereShape3D).radius, hide_spot.entry_radius, 0.0001)
	assert_eq(collision.transform, Transform3D.IDENTITY)


func test_hide_spot_rejects_invalid_radius_and_non_unit_world_transform() -> void:
	var hide_spot := _add_hide_spot()
	assert_true(hide_spot.is_geometry_valid())

	hide_spot.entry_radius = HideSpot.MIN_ENTRY_RADIUS - 0.01
	assert_false(hide_spot.is_geometry_valid())
	hide_spot.entry_radius = 0.75
	hide_spot.entry_radius = HideSpot.MAX_ENTRY_RADIUS + 0.01
	assert_false(hide_spot.is_geometry_valid())
	hide_spot.entry_radius = 0.75
	hide_spot.scale = Vector3(2.0, 1.0, 1.0)
	assert_false(hide_spot.is_geometry_valid())


func test_hide_spot_accepts_only_player_bodies_in_the_same_tree() -> void:
	var hide_spot := _add_hide_spot()
	var player := CharacterBody3D.new()
	player.collision_layer = HideSpot.PLAYER_BODY_LAYER
	add_child_autofree(player)
	var enemy := CharacterBody3D.new()
	enemy.collision_layer = HideSpot.ENEMY_BODY_LAYER
	add_child_autofree(enemy)

	assert_true(hide_spot.can_accept_body(player))
	assert_false(hide_spot.can_accept_body(enemy))
	player.collision_layer |= HideSpot.ENEMY_BODY_LAYER
	assert_false(hide_spot.can_accept_body(player))
	player.collision_layer = HideSpot.PLAYER_BODY_LAYER
	hide_spot.collision_mask = 0
	assert_false(hide_spot.can_accept_body(player))


func test_close_range_seen_invalidates_entry_without_mutating_marker() -> void:
	var hide_spot := _add_hide_spot()
	var player := CharacterBody3D.new()
	player.collision_layer = HideSpot.PLAYER_BODY_LAYER
	add_child_autofree(player)

	assert_true(hide_spot.can_enter(player))
	assert_false(hide_spot.can_enter(player, true))
	assert_true(hide_spot.is_geometry_valid())


func test_hide_spot_entry_proximity_is_world_space_and_bounded() -> void:
	var hide_spot := _add_hide_spot()
	hide_spot.position = Vector3(2.0, 1.0, 3.0)
	hide_spot.rotate_y(PI * 0.5)
	assert_eq(hide_spot.entry_world_position(), hide_spot.global_position)
	assert_true(hide_spot.is_near_entry(hide_spot.global_position))
	assert_false(
		hide_spot.is_near_entry(
			hide_spot.global_position + Vector3.RIGHT * (hide_spot.entry_radius + 0.01),
		)
	)


func _add_hide_spot() -> HideSpot:
	var hide_spot := HideSpot.new()
	add_child_autofree(hide_spot)
	return hide_spot
