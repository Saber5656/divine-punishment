extends GutTest


const PLAYER_SCENE_PATH := "res://src/player/player.tscn"


func after_each() -> void:
	for action: StringName in [&"interact", &"sprint", &"move_forward", &"move_backward"]:
		Input.action_release(action)


func test_climb_reaches_connected_beam_and_beam_can_fall() -> void:
	var route := _add_route()
	var edge := _add_edge(route, &"Ascent", Vector3.ZERO)
	var beam := _add_beam(route, &"Beam", Vector3(0.0, 2.0, 0.0), Vector3(4.0, 0.0, 0.0))
	edge.connected_beam_path = NodePath("../Beam")
	var player := _add_player(edge.bottom_world_position())

	assert_true(player.try_enter_climb())
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_CLIMB)
	assert_eq(player.active_climb_edge(), edge)
	var samples_before := beam.runtime_position_sample_total()
	player.advance_traversal(1.0, 2.0)
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_BEAM)
	assert_eq(player.active_beam_path(), beam)
	assert_eq(player.global_position, Vector3(0.0, 2.0, 0.0))
	assert_eq(
		beam.runtime_position_sample_total() - samples_before,
		BeamPath.MAX_RUNTIME_POSITION_SAMPLES,
		"Climb-to-Beam transition must consume one runtime position sample",
	)

	var expected_beam_position := beam.world_position_at_distance(1.5)
	samples_before = beam.runtime_position_sample_total()
	player.advance_traversal(1.0, 1.0)
	assert_almost_eq(player.traversal_distance(), 1.5, 0.0001)
	assert_eq(player.global_position, expected_beam_position)
	assert_eq(
		beam.runtime_position_sample_total() - samples_before,
		BeamPath.MAX_RUNTIME_POSITION_SAMPLES,
		"Beam movement update must consume one runtime position sample",
	)
	Input.action_press(&"sprint")
	player._update_state_from_input()
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_GROUND)
	assert_null(player.active_beam_path())


func test_beam_endpoint_descends_through_linked_climb_edge() -> void:
	var route := _add_route()
	var ascent := _add_edge(route, &"Ascent", Vector3.ZERO)
	var beam := _add_beam(route, &"Beam", Vector3(0.0, 2.0, 0.0), Vector3(4.0, 0.0, 0.0))
	var descent := _add_edge(route, &"Descent", Vector3(4.0, 0.0, 0.0))
	ascent.connected_beam_path = NodePath("../Beam")
	beam.end_climb_edge = NodePath("../Descent")
	var player := _add_player(ascent.bottom_world_position())

	assert_true(player.try_enter_climb(ascent))
	player.advance_traversal(1.0, 2.0)
	player.advance_traversal(1.0, 10.0)
	assert_almost_eq(player.traversal_distance(), beam.path_length(), 0.0001)
	assert_true(player.try_descend_from_beam())
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_CLIMB)
	assert_eq(player.active_climb_edge(), descent)
	assert_eq(player.global_position, descent.top_world_position())

	player.advance_traversal(-1.0, 2.0)
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_GROUND)
	assert_eq(player.global_position, descent.bottom_world_position())


func test_beam_end_entry_maps_forward_input_into_path() -> void:
	var route := _add_route()
	var beam := _add_beam(route, &"Beam", Vector3(0.0, 2.0, 0.0), Vector3(4.0, 0.0, 0.0))
	var edge := _add_edge(route, &"EndAscent", Vector3(4.0, 0.0, 0.0))
	edge.connected_beam_path = NodePath("../Beam")
	edge.connected_beam_endpoint = 1
	var player := _add_player(edge.bottom_world_position())

	assert_true(player.try_enter_climb(edge))
	player.advance_traversal(1.0, 2.0)
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_BEAM)
	assert_almost_eq(player.traversal_distance(), beam.path_length(), 0.0001)

	var expected_distance := beam.path_length() - 1.5
	var expected_position := beam.world_position_at_distance(expected_distance)
	player.advance_traversal(1.0, 1.0)
	assert_almost_eq(player.traversal_distance(), expected_distance, 0.0001)
	assert_eq(player.global_position, expected_position)


func test_invalid_marker_aborts_traversal_safely() -> void:
	var route := _add_route()
	var edge := _add_edge(route, &"Ascent", Vector3.ZERO)
	var player := _add_player(edge.bottom_world_position())
	assert_true(player.try_enter_climb(edge))

	edge.top_offset = Vector3(NAN, 2.0, 0.0)
	player.advance_traversal(1.0, 0.1)
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_GROUND)
	assert_null(player.active_climb_edge())
	assert_eq(player.velocity, Vector3.ZERO)
	assert_almost_eq(player.traversal_distance(), 0.0, 0.0001)


func test_deleted_active_climb_edge_aborts_without_moving_player() -> void:
	var route := _add_route()
	var edge := _add_edge(route, &"Ascent", Vector3.ZERO)
	var player := _add_player(edge.bottom_world_position())
	assert_true(player.try_enter_climb(edge))
	var safe_position := player.global_position

	edge.free()
	player.advance_traversal(1.0, 0.1)
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_GROUND)
	assert_null(player.active_climb_edge())
	assert_almost_eq(player.traversal_distance(), 0.0, 0.0001)
	assert_eq(player.velocity, Vector3.ZERO)
	assert_eq(player.global_position, safe_position)
	assert_true(PlayerClimbRules.is_safe_world_position(player.global_position))


func test_deleted_active_beam_path_aborts_without_moving_player() -> void:
	var route := _add_route()
	var edge := _add_edge(route, &"Ascent", Vector3.ZERO)
	var beam := _add_beam(route, &"Beam", Vector3(0.0, 2.0, 0.0), Vector3(4.0, 0.0, 0.0))
	edge.connected_beam_path = NodePath("../Beam")
	var player := _add_player(edge.bottom_world_position())
	assert_true(player.try_enter_climb(edge))
	player.advance_traversal(1.0, 2.0)
	var safe_position := player.global_position

	beam.free()
	player.advance_traversal(1.0, 0.1)
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_GROUND)
	assert_null(player.active_beam_path())
	assert_almost_eq(player.traversal_distance(), 0.0, 0.0001)
	assert_eq(player.velocity, Vector3.ZERO)
	assert_eq(player.global_position, safe_position)
	assert_true(PlayerClimbRules.is_safe_world_position(player.global_position))


func test_curve_change_invalidates_active_beam_and_aborts_safely() -> void:
	var route := _add_route()
	var edge := _add_edge(route, &"Ascent", Vector3.ZERO)
	var beam := _add_beam(route, &"Beam", Vector3(0.0, 2.0, 0.0), Vector3(4.0, 0.0, 0.0))
	edge.connected_beam_path = NodePath("../Beam")
	var player := _add_player(edge.bottom_world_position())
	assert_true(player.try_enter_climb(edge))
	player.advance_traversal(1.0, 2.0)
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_BEAM)

	beam.path_curve.set_point_position(1, Vector3.ZERO)
	player.advance_traversal(1.0, 0.1)
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_GROUND)
	assert_null(player.active_beam_path())


func test_active_beam_rechecks_player_layer_navigation_and_parent_scale() -> void:
	var route := _add_route()
	var edge := _add_edge(route, &"Ascent", Vector3.ZERO)
	var beam := _add_beam(route, &"Beam", Vector3(0.0, 2.0, 0.0), Vector3(4.0, 0.0, 0.0))
	edge.connected_beam_path = NodePath("../Beam")
	var player := _add_player(edge.bottom_world_position())
	assert_true(player.try_enter_climb(edge))
	player.advance_traversal(1.0, 2.0)
	var safe_position := player.global_position
	player.collision_layer |= BeamPath.ENEMY_BODY_LAYER
	player.advance_traversal(1.0, 0.1)
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_GROUND)
	assert_eq(player.global_position, safe_position)

	player.collision_layer = BeamPath.PLAYER_BODY_LAYER
	player.global_position = edge.bottom_world_position()
	assert_true(player.try_enter_climb(edge))
	player.advance_traversal(1.0, 2.0)
	var navigation_link := NavigationLink3D.new()
	beam.add_child(navigation_link)
	player.advance_traversal(1.0, 0.1)
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_GROUND)
	navigation_link.free()

	player.global_position = edge.bottom_world_position()
	assert_true(player.try_enter_climb(edge))
	player.advance_traversal(1.0, 2.0)
	safe_position = player.global_position
	route.scale = Vector3(2.0, 1.0, 1.0)
	player.advance_traversal(1.0, 0.1)
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_GROUND)
	assert_eq(player.global_position, safe_position)


func test_active_beam_rechecks_marker_collision_and_parent_origin() -> void:
	var route := _add_route()
	var edge := _add_edge(route, &"Ascent", Vector3.ZERO)
	var beam := _add_beam(route, &"Beam", Vector3(0.0, 2.0, 0.0), Vector3(4.0, 0.0, 0.0))
	edge.connected_beam_path = NodePath("../Beam")
	var player := _add_player(edge.bottom_world_position())
	assert_true(player.try_enter_climb(edge))
	player.advance_traversal(1.0, 2.0)
	var safe_position := player.global_position

	beam.collision_mask = 0
	player.advance_traversal(1.0, 0.1)
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_GROUND)
	assert_eq(player.global_position, safe_position)

	beam.collision_mask = BeamPath.PLAYER_BODY_LAYER
	player.global_position = edge.bottom_world_position()
	assert_true(player.try_enter_climb(edge))
	player.advance_traversal(1.0, 2.0)
	safe_position = player.global_position
	route.position = Vector3(PlayerClimbRules.MAX_WORLD_COORDINATE + 1.0, 0.0, 0.0)
	player.advance_traversal(1.0, 0.1)
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_GROUND)
	assert_eq(player.global_position, safe_position)
	assert_true(PlayerClimbRules.is_safe_world_position(player.global_position))


func test_beam_entry_rejects_unsafe_supplied_sample() -> void:
	var route := _add_route()
	var beam := _add_beam(route, &"Beam", Vector3.ZERO, Vector3(4.0, 0.0, 0.0))
	var player := _add_player(Vector3.ZERO)

	assert_false(
		player._enter_beam_with_sample(
			beam,
			0.0,
			{&"valid": true, &"position": Vector3(INF, 0.0, 0.0)},
		)
	)
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_GROUND)
	assert_null(player.active_beam_path())
	assert_true(PlayerClimbRules.is_safe_world_position(player.global_position))


func test_climb_candidate_search_fails_closed_above_budget() -> void:
	var route := _add_route()
	for index: int in PlayerController.MAX_CLIMB_EDGE_CANDIDATES + 1:
		_add_edge(route, StringName("Edge%d" % index), Vector3.ZERO)
	var player := _add_player(Vector3.ZERO)

	assert_false(player.try_enter_climb())
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_GROUND)


func test_climb_candidate_search_accepts_exact_budget() -> void:
	var route := _add_route()
	for index: int in PlayerController.MAX_CLIMB_EDGE_CANDIDATES:
		_add_edge(route, StringName("Edge%d" % index), Vector3.ZERO)
	var player := _add_player(Vector3.ZERO)

	assert_true(player.try_enter_climb())
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_CLIMB)


func _add_player(world_position: Vector3) -> PlayerController:
	var player := (load(PLAYER_SCENE_PATH) as PackedScene).instantiate() as PlayerController
	player.position = world_position
	add_child_autofree(player)
	return player


func _add_route() -> Node3D:
	var route := Node3D.new()
	add_child_autofree(route)
	return route


func _add_edge(parent: Node3D, node_name: StringName, world_position: Vector3) -> ClimbEdge:
	var edge := ClimbEdge.new()
	edge.name = node_name
	edge.position = world_position
	edge.top_offset = Vector3(0.0, 2.0, 0.0)
	parent.add_child(edge)
	return edge


func _add_beam(
	parent: Node3D,
	node_name: StringName,
	world_position: Vector3,
	local_endpoint: Vector3,
) -> BeamPath:
	var beam := BeamPath.new()
	beam.name = node_name
	beam.position = world_position
	var curve := Curve3D.new()
	curve.bake_interval = 0.2
	curve.add_point(Vector3.ZERO)
	curve.add_point(local_endpoint)
	beam.path_curve = curve
	parent.add_child(beam)
	return beam
