extends GutTest


func test_crawl_entrance_builds_two_bounded_player_interaction_shapes() -> void:
	var entrance := _add_entrance(Vector3(0.0, 0.0, -1.0))
	entrance.entry_radius = 0.6

	assert_true(entrance.is_geometry_valid())
	assert_eq(entrance.collision_layer, CrawlEntrance.CRAWL_MARKER_LAYER)
	assert_eq(entrance.collision_mask, CrawlEntrance.PLAYER_BODY_LAYER)
	assert_true(entrance.is_in_group(&"crawl_entrances"))
	var outside_shape := entrance.get_node(
		NodePath(String(CrawlEntrance.OUTSIDE_COLLISION_SHAPE_NODE_NAME))
	) as CollisionShape3D
	var inside_shape := entrance.get_node(
		NodePath(String(CrawlEntrance.INSIDE_COLLISION_SHAPE_NODE_NAME))
	) as CollisionShape3D
	assert_true(outside_shape.shape is SphereShape3D)
	assert_true(inside_shape.shape is SphereShape3D)
	assert_almost_eq((outside_shape.shape as SphereShape3D).radius, 0.6, 0.0001)
	assert_almost_eq((inside_shape.shape as SphereShape3D).radius, 0.6, 0.0001)
	assert_eq(outside_shape.position, Vector3.ZERO)
	assert_eq(inside_shape.position, entrance.inside_offset)


func test_crawl_entrance_enforces_length_radius_and_world_bounds() -> void:
	var entrance := _add_entrance(Vector3(0.0, 0.0, -CrawlEntrance.MIN_PASSAGE_LENGTH))
	entrance.entry_radius = CrawlEntrance.MIN_ENTRY_RADIUS
	assert_true(entrance.is_geometry_valid())

	entrance.inside_offset = Vector3(0.0, 0.0, -CrawlEntrance.MAX_PASSAGE_LENGTH)
	entrance.entry_radius = CrawlEntrance.MAX_ENTRY_RADIUS
	assert_true(entrance.is_geometry_valid())
	entrance.inside_offset.z -= 0.01
	assert_false(entrance.is_geometry_valid())
	entrance.inside_offset = Vector3.ZERO
	assert_false(entrance.is_geometry_valid())
	entrance.inside_offset = Vector3(NAN, 0.0, -1.0)
	assert_false(entrance.is_geometry_valid())
	entrance.inside_offset = Vector3(0.0, 0.0, -1.0)
	entrance.entry_radius = CrawlEntrance.MIN_ENTRY_RADIUS - 0.01
	assert_false(entrance.is_geometry_valid())
	entrance.entry_radius = 0.75
	entrance.position = Vector3(PlayerCrawlRules.MAX_WORLD_COORDINATE, 0.0, 0.0)
	assert_true(entrance.is_geometry_valid())
	entrance.position.x += 0.01
	assert_false(entrance.is_geometry_valid())


func test_crawl_entrance_world_transform_must_be_unit_scale() -> void:
	assert_true(CrawlEntrance.is_world_transform_within_contract(Transform3D.IDENTITY))
	assert_false(CrawlEntrance.is_world_transform_within_contract(
		Transform3D(Basis.IDENTITY.scaled(Vector3(2.0, 1.0, 1.0)), Vector3.ZERO)
	))
	var parent := Node3D.new()
	add_child_autofree(parent)
	var entrance := CrawlEntrance.new()
	parent.add_child(entrance)
	parent.scale = Vector3(0.5, 0.5, 0.5)
	assert_false(entrance.is_geometry_valid())


func test_crawl_entrance_accepts_only_player_bodies_in_same_tree() -> void:
	var entrance := _add_entrance(Vector3(0.0, 0.0, -1.0))
	var player := CharacterBody3D.new()
	player.collision_layer = CrawlEntrance.PLAYER_BODY_LAYER
	add_child_autofree(player)
	var enemy := CharacterBody3D.new()
	enemy.collision_layer = CrawlEntrance.ENEMY_BODY_LAYER
	add_child_autofree(enemy)

	assert_true(entrance.can_accept_body(player))
	assert_false(entrance.can_accept_body(enemy))
	player.collision_layer |= CrawlEntrance.ENEMY_BODY_LAYER
	assert_false(entrance.can_accept_body(player))
	entrance.collision_mask = 0
	player.collision_layer = CrawlEntrance.PLAYER_BODY_LAYER
	assert_false(entrance.can_accept_body(player))


func test_crawl_entrance_endpoints_use_world_space_and_independent_proximity() -> void:
	var entrance := _add_entrance(Vector3(0.0, 0.0, -2.0))
	entrance.position = Vector3(2.0, 1.0, 3.0)
	entrance.rotate_y(PI * 0.5)
	var expected_inside := entrance.to_global(entrance.inside_offset)

	assert_eq(entrance.outside_world_position(), entrance.global_position)
	assert_eq(entrance.inside_world_position(), expected_inside)
	assert_true(entrance.is_near_outside(entrance.outside_world_position()))
	assert_false(entrance.is_near_inside(entrance.outside_world_position()))
	assert_true(entrance.is_near_inside(entrance.inside_world_position()))
	assert_false(entrance.is_near_outside(
		entrance.outside_world_position() + Vector3.RIGHT * (entrance.entry_radius + 0.01)
	))


func test_invalid_crawl_entrance_has_no_gizmo_segments() -> void:
	var entrance := _add_entrance(Vector3.ZERO)
	assert_true(entrance.gizmo_segments().is_empty())
	entrance.inside_offset = Vector3(0.0, 0.0, -1.0)
	assert_eq(entrance.gizmo_segments().size(), 10)


func _add_entrance(offset: Vector3) -> CrawlEntrance:
	var entrance := CrawlEntrance.new()
	entrance.inside_offset = offset
	add_child_autofree(entrance)
	return entrance
