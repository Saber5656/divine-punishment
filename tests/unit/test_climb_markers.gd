extends GutTest


class ForgedTraversalMarker:
	extends Area3D

	var calls := 0

	func is_geometry_valid() -> bool:
		calls += 1
		return true

	func path_length() -> float:
		calls += 1
		return 1.0

	func world_position_at_distance(_distance: float) -> Vector3:
		calls += 1
		return Vector3.ZERO

	func top_world_position() -> Vector3:
		calls += 1
		return Vector3.ZERO

	func connection_radius() -> float:
		calls += 1
		return 1.0


func test_climb_edge_enforces_span_rise_radius_and_collision_contract() -> void:
	var edge := ClimbEdge.new()
	edge.top_offset = Vector3(0.0, ClimbEdge.MIN_SPAN, 0.0)
	edge.entry_radius = ClimbEdge.MIN_ENTRY_RADIUS
	add_child_autofree(edge)

	assert_true(edge.is_geometry_valid())
	assert_eq(edge.collision_layer, ClimbEdge.CLIMB_MARKER_LAYER)
	assert_eq(edge.collision_mask, ClimbEdge.PLAYER_BODY_LAYER)
	assert_true(edge.is_in_group(&"climb_edges"))
	assert_almost_eq(edge.span_length(), ClimbEdge.MIN_SPAN, 0.0001)
	assert_eq(edge.world_position_at_distance(INF), edge.bottom_world_position())

	edge.top_offset = Vector3(0.0, ClimbEdge.MAX_SPAN, 0.0)
	edge.entry_radius = ClimbEdge.MAX_ENTRY_RADIUS
	assert_true(edge.is_geometry_valid())
	edge.top_offset = Vector3(0.0, ClimbEdge.MAX_SPAN + 0.01, 0.0)
	assert_false(edge.is_geometry_valid())
	edge.top_offset = Vector3(ClimbEdge.MIN_SPAN, 0.0, 0.0)
	assert_false(edge.is_geometry_valid())
	edge.top_offset = Vector3(0.5, ClimbEdge.MIN_VERTICAL_RISE, 0.0)
	assert_true(edge.is_geometry_valid())
	edge.top_offset = Vector3(0.5, ClimbEdge.MIN_VERTICAL_RISE - 0.01, 0.0)
	assert_false(edge.is_geometry_valid())
	edge.top_offset = Vector3(NAN, 2.0, 0.0)
	assert_false(edge.is_geometry_valid())
	edge.top_offset = Vector3(0.0, 2.0, 0.0)
	edge.entry_radius = ClimbEdge.MIN_ENTRY_RADIUS - 0.01
	assert_false(edge.is_geometry_valid())
	edge.entry_radius = ClimbEdge.MAX_ENTRY_RADIUS + 0.01
	assert_false(edge.is_geometry_valid())
	edge.entry_radius = 1.0
	edge.top_offset = Vector3(0.0, ClimbEdge.MAX_SPAN + 0.01, 0.0)
	assert_true(edge.gizmo_segments().is_empty())
	edge.top_offset = Vector3(0.0, 2.0, 0.0)
	edge.position = Vector3(PlayerClimbRules.MAX_WORLD_COORDINATE, 0.0, 0.0)
	assert_true(edge.is_geometry_valid())
	edge.position.x += 0.01
	assert_false(edge.is_geometry_valid())


func test_climb_edge_accepts_only_player_bodies() -> void:
	var edge := _add_edge()
	var player := CharacterBody3D.new()
	player.collision_layer = ClimbEdge.PLAYER_BODY_LAYER
	add_child_autofree(player)
	var enemy := CharacterBody3D.new()
	enemy.collision_layer = BeamPath.ENEMY_BODY_LAYER
	add_child_autofree(enemy)

	assert_true(edge.can_accept_body(player))
	assert_false(edge.can_accept_body(enemy))
	player.collision_layer |= ClimbEdge.ENEMY_BODY_LAYER
	assert_false(edge.can_accept_body(player))
	assert_true(edge.is_near_bottom(edge.bottom_world_position()))
	assert_false(edge.is_near_bottom(edge.bottom_world_position() + Vector3.RIGHT * (edge.entry_radius + 0.01)))


func test_beam_path_enforces_point_length_bake_and_tangent_bounds() -> void:
	var path := _add_beam(Vector3(BeamPath.MIN_PATH_LENGTH, 0.0, 0.0))
	assert_true(path.is_geometry_valid())
	assert_almost_eq(path.path_length(), BeamPath.MIN_PATH_LENGTH, 0.0001)
	assert_eq(path.collision_layer, BeamPath.CLIMB_MARKER_LAYER)
	assert_eq(path.collision_mask, BeamPath.PLAYER_BODY_LAYER)
	assert_true(path.is_in_group(&"beam_paths"))

	path.path_curve = _line_curve(Vector3(BeamPath.MAX_PATH_LENGTH, 0.0, 0.0))
	assert_true(path.is_geometry_valid())
	path.path_curve = _line_curve(Vector3(BeamPath.MAX_PATH_LENGTH + 0.01, 0.0, 0.0))
	assert_false(path.is_geometry_valid())
	assert_almost_eq(path.path_length(), 0.0, 0.0001)
	path.path_curve = _line_curve(Vector3(BeamPath.MIN_PATH_LENGTH - 0.01, 0.0, 0.0))
	assert_false(path.is_geometry_valid())
	path.path_curve = _line_curve(Vector3.ZERO)
	assert_false(path.is_geometry_valid())
	path.path_curve = _line_curve(Vector3(NAN, 0.0, 0.0))
	assert_false(path.is_geometry_valid())
	var one_point_curve := Curve3D.new()
	one_point_curve.add_point(Vector3.ZERO)
	path.path_curve = one_point_curve
	assert_false(path.is_geometry_valid())
	assert_eq(path.last_bake_evaluation_count(), 0)


func test_beam_path_invalidates_geometry_across_tree_lifecycle() -> void:
	var path := _add_beam(Vector3.RIGHT)
	assert_true(path.is_geometry_valid())
	assert_almost_eq(path.path_length(), 1.0, 0.0001)

	remove_child(path)
	assert_almost_eq(path.path_length(), 0.0, 0.0001)
	path.path_curve.set_point_position(1, Vector3.ZERO)
	add_child(path)

	assert_false(path.is_geometry_valid())
	assert_almost_eq(path.path_length(), 0.0, 0.0001)


func test_beam_path_enforces_local_point_handle_and_prebake_work_bounds() -> void:
	var path := BeamPath.new()
	add_child_autofree(path)
	assert_true(BeamPath.is_local_control_value_valid(Vector3(BeamPath.MAX_LOCAL_POINT_DISTANCE, 0.0, 0.0)))
	assert_false(BeamPath.is_local_control_value_valid(Vector3(BeamPath.MAX_LOCAL_POINT_DISTANCE + 0.01, 0.0, 0.0)))
	assert_false(BeamPath.is_local_control_value_valid(Vector3(INF, 0.0, 0.0)))

	var exact_point_curve := Curve3D.new()
	exact_point_curve.bake_interval = 0.2
	exact_point_curve.add_point(Vector3(99.5, 0.0, 0.0))
	exact_point_curve.add_point(Vector3(BeamPath.MAX_LOCAL_POINT_DISTANCE, 0.0, 0.0))
	path.path_curve = exact_point_curve
	assert_true(path.is_geometry_valid())

	var overflow_point_curve := Curve3D.new()
	overflow_point_curve.bake_interval = 0.2
	overflow_point_curve.add_point(Vector3(99.5, 0.0, 0.0))
	overflow_point_curve.add_point(Vector3(BeamPath.MAX_LOCAL_POINT_DISTANCE + 0.01, 0.0, 0.0))
	path.path_curve = overflow_point_curve
	assert_false(path.is_geometry_valid())
	assert_eq(path.last_bake_evaluation_count(), 0)

	var overflow_handle_curve := _line_curve(Vector3.RIGHT)
	overflow_handle_curve.set_point_out(0, Vector3(BeamPath.MAX_LOCAL_POINT_DISTANCE + 0.01, 0.0, 0.0))
	path.path_curve = overflow_handle_curve
	assert_false(path.is_geometry_valid())
	assert_eq(path.last_bake_evaluation_count(), 0)

	var excessive_control_polygon := Curve3D.new()
	excessive_control_polygon.bake_interval = BeamPath.MIN_BAKE_INTERVAL
	for index: int in BeamPath.MAX_POINT_COUNT:
		var x := BeamPath.MAX_LOCAL_POINT_DISTANCE if index % 2 == 0 else -BeamPath.MAX_LOCAL_POINT_DISTANCE
		excessive_control_polygon.add_point(Vector3(x, 0.0, 0.0))
	path.path_curve = excessive_control_polygon
	assert_almost_eq(path.path_length(), 0.0, 0.0001)
	assert_false(path.is_geometry_valid())
	assert_gt(path.last_control_polygon_length(), BeamPath.MAX_CONTROL_POLYGON_LENGTH)
	assert_eq(path.last_bake_evaluation_count(), 0)


func test_beam_path_enforces_point_count_and_bake_interval_boundaries() -> void:
	var path := BeamPath.new()
	add_child_autofree(path)
	var maximum_curve := Curve3D.new()
	maximum_curve.bake_interval = BeamPath.MIN_BAKE_INTERVAL
	for index: int in BeamPath.MAX_POINT_COUNT:
		maximum_curve.add_point(Vector3(float(index), 0.0, 0.0))
	path.path_curve = maximum_curve
	assert_true(path.is_geometry_valid())
	assert_lte(path.gizmo_segments().size(), BeamPath.MAX_GIZMO_SEGMENTS * 2)
	assert_eq(BeamPath.MAX_GEOMETRY_VALIDATION_POINTS, BeamPath.MAX_POINT_COUNT)
	assert_eq(path.last_geometry_validation_sample_count(), BeamPath.MAX_GEOMETRY_VALIDATION_SAMPLES)
	assert_eq(path.last_bake_evaluation_count(), BeamPath.MAX_BAKE_EVALUATIONS)
	var runtime_sample := path.world_sample_at_distance(1.0)
	assert_true(runtime_sample[&"valid"])
	assert_eq(path.last_runtime_position_sample_count(), BeamPath.MAX_RUNTIME_POSITION_SAMPLES)
	assert_lte(
		ceili(path.last_control_polygon_length() / path.path_curve.bake_interval),
		BeamPath.MAX_BAKE_WORK_SEGMENTS,
	)

	maximum_curve.add_point(Vector3(float(BeamPath.MAX_POINT_COUNT), 0.0, 0.0))
	assert_false(path.is_geometry_valid())
	path.path_curve = _line_curve(Vector3.RIGHT)
	path.path_curve.bake_interval = BeamPath.MIN_BAKE_INTERVAL - 0.01
	assert_false(path.is_geometry_valid())
	path.path_curve.bake_interval = BeamPath.MAX_BAKE_INTERVAL
	assert_true(path.is_geometry_valid())
	path.path_curve.bake_interval = BeamPath.MAX_BAKE_INTERVAL + 0.01
	assert_false(path.is_geometry_valid())


func test_beam_path_is_player_only_and_rejects_navigation_links() -> void:
	var path := _add_beam(Vector3(4.0, 0.0, 0.0))
	var player := CharacterBody3D.new()
	player.collision_layer = BeamPath.PLAYER_BODY_LAYER
	add_child_autofree(player)
	var enemy := CharacterBody3D.new()
	enemy.collision_layer = BeamPath.ENEMY_BODY_LAYER
	add_child_autofree(enemy)

	assert_true(path.can_accept_body(player))
	assert_false(path.can_accept_body(enemy))
	assert_true(path.is_enemy_navigation_safe())
	var navigation_link := NavigationLink3D.new()
	path.add_child(navigation_link)
	assert_false(path.is_enemy_navigation_safe())
	assert_false(path.can_accept_body(player))
	path.remove_child(navigation_link)
	navigation_link.free()
	path.collision_mask = 0
	assert_false(path.can_accept_body(player))


func test_beam_path_rejects_navigation_ancestors_regions_and_descendant_overflow() -> void:
	var region := NavigationRegion3D.new()
	add_child_autofree(region)
	var region_path := BeamPath.new()
	region_path.path_curve = _line_curve(Vector3.RIGHT)
	region.add_child(region_path)
	assert_false(region_path.is_enemy_navigation_safe())

	var link := NavigationLink3D.new()
	add_child_autofree(link)
	var link_path := BeamPath.new()
	link_path.path_curve = _line_curve(Vector3.RIGHT)
	link.add_child(link_path)
	assert_false(link_path.is_enemy_navigation_safe())

	var crowded_path := _add_beam(Vector3.RIGHT)
	for _index: int in BeamPath.MAX_NAVIGATION_DESCENDANTS + 1:
		crowded_path.add_child(Node.new())
	assert_false(crowded_path.is_enemy_navigation_safe())


func test_beam_sampling_and_nearest_progress_are_bounded() -> void:
	var path := _add_beam(Vector3(4.0, 0.0, 0.0))
	path.position = Vector3(2.0, 3.0, 4.0)

	assert_eq(path.world_position_at_distance(-1.0), Vector3(2.0, 3.0, 4.0))
	assert_eq(path.world_position_at_distance(10.0), Vector3(6.0, 3.0, 4.0))
	assert_almost_eq(path.nearest_distance(Vector3(4.0, 3.0, 5.0)), 2.0, 0.05)
	assert_gt(path.tangent_at_distance(2.0).dot(Vector3.RIGHT), 0.99)
	assert_eq(path.world_position_at_distance(NAN), Vector3(2.0, 3.0, 4.0))
	assert_eq(path.last_runtime_position_sample_count(), 1)


func test_beam_world_transform_contract_rejects_nonfinite_origin_and_scale() -> void:
	assert_true(BeamPath.is_world_transform_within_contract(Transform3D.IDENTITY))
	assert_true(BeamPath.is_world_transform_within_contract(
		Transform3D(Basis.IDENTITY, Vector3(PlayerClimbRules.MAX_WORLD_COORDINATE, 0.0, 0.0))
	))
	assert_false(BeamPath.is_world_transform_within_contract(
		Transform3D(Basis.IDENTITY, Vector3(PlayerClimbRules.MAX_WORLD_COORDINATE + 0.01, 0.0, 0.0))
	))
	assert_false(BeamPath.is_world_transform_within_contract(
		Transform3D(Basis.IDENTITY, Vector3(NAN, 0.0, 0.0))
	))
	assert_false(BeamPath.is_world_transform_within_contract(
		Transform3D(Basis.IDENTITY.scaled(Vector3(2.0, 1.0, 1.0)), Vector3.ZERO)
	))
	assert_false(BeamPath.is_world_transform_within_contract(
		Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)
	))

	var path := _add_beam(Vector3.RIGHT)
	assert_true(path.is_geometry_valid())
	path.scale = Vector3(2.0, 1.0, 1.0)
	assert_false(path.is_geometry_valid())
	assert_eq(path.last_geometry_validation_sample_count(), 0)
	path.scale = Vector3.ONE
	path.position = Vector3(PlayerClimbRules.MAX_WORLD_COORDINATE, 0.0, 0.0)
	assert_false(path.is_geometry_valid())
	assert_eq(path.last_bake_evaluation_count(), 0)


func test_marker_links_require_world_space_endpoint_alignment() -> void:
	var edge := _add_edge()
	edge.name = &"Edge"
	var path := _add_beam(Vector3(4.0, 0.0, 0.0))
	path.name = &"Beam"
	path.position = edge.top_world_position()
	edge.connected_beam_path = NodePath("../Beam")
	path.start_climb_edge = NodePath("../Edge")

	assert_eq(edge.connected_beam(), path)
	assert_eq(path.connected_climb_at_start(), edge)
	path.position += Vector3.RIGHT * (edge.entry_radius + 0.01)
	assert_null(edge.connected_beam())
	assert_null(path.connected_climb_at_start())


func test_marker_links_reject_forged_group_nodes_before_method_calls() -> void:
	var edge := _add_edge()
	edge.name = &"TypedEdge"
	var path := _add_beam(Vector3.RIGHT)
	path.name = &"TypedBeam"
	path.position = edge.top_world_position()
	var forged := ForgedTraversalMarker.new()
	forged.name = &"Forged"
	add_child_autofree(forged)
	forged.add_to_group(&"beam_paths")
	forged.add_to_group(&"climb_edges")

	edge.connected_beam_path = NodePath("../Forged")
	path.start_climb_edge = NodePath("../Forged")
	assert_null(edge.connected_beam())
	assert_null(path.connected_climb_at_start())
	assert_eq(forged.calls, 0)


func _add_edge() -> ClimbEdge:
	var edge := ClimbEdge.new()
	edge.top_offset = Vector3(0.0, 2.0, 0.0)
	add_child_autofree(edge)
	return edge


func _add_beam(endpoint: Vector3) -> BeamPath:
	var path := BeamPath.new()
	path.path_curve = _line_curve(endpoint)
	add_child_autofree(path)
	return path


func _line_curve(endpoint: Vector3) -> Curve3D:
	var curve := Curve3D.new()
	curve.bake_interval = 0.2
	curve.add_point(Vector3.ZERO)
	curve.add_point(endpoint)
	return curve
