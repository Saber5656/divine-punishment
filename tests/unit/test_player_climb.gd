extends GutTest


const ClimbRules := preload("res://src/player/player_climb.gd")


func test_finite_vector_and_axis_inputs_fail_closed() -> void:
	assert_true(ClimbRules.is_finite_vector(Vector3(1.0, 2.0, 3.0)))
	assert_false(ClimbRules.is_finite_vector(Vector3(NAN, 0.0, 0.0)))
	assert_almost_eq(ClimbRules.sanitize_axis(2.0), 1.0, 0.0001)
	assert_almost_eq(ClimbRules.sanitize_axis(-2.0), -1.0, 0.0001)
	assert_almost_eq(ClimbRules.sanitize_axis(INF), 0.0, 0.0001)
	assert_true(ClimbRules.is_safe_world_position(Vector3(ClimbRules.MAX_WORLD_COORDINATE, 0.0, 0.0)))
	assert_false(ClimbRules.is_safe_world_position(Vector3(ClimbRules.MAX_WORLD_COORDINATE + 0.01, 0.0, 0.0)))
	assert_false(ClimbRules.is_safe_world_position(Vector3(NAN, 0.0, 0.0)))


func test_distance_and_progress_are_bounded() -> void:
	assert_almost_eq(ClimbRules.bounded_distance(-1.0, 5.0), 0.0, 0.0001)
	assert_almost_eq(ClimbRules.bounded_distance(8.0, 5.0), 5.0, 0.0001)
	assert_almost_eq(ClimbRules.bounded_distance(NAN, 5.0), 0.0, 0.0001)
	assert_almost_eq(ClimbRules.bounded_distance(2.0, INF), 0.0, 0.0001)
	assert_almost_eq(ClimbRules.advance_distance(1.0, 1.0, 2.0, 0.5, 5.0), 2.0, 0.0001)
	assert_almost_eq(ClimbRules.advance_distance(4.5, 1.0, 2.0, 1.0, 5.0), 5.0, 0.0001)
	assert_almost_eq(ClimbRules.advance_distance(0.5, -1.0, 2.0, 1.0, 5.0), 0.0, 0.0001)
	assert_almost_eq(ClimbRules.advance_distance(2.0, 1.0, -1.0, 1.0, 5.0), 2.0, 0.0001)
	assert_almost_eq(ClimbRules.advance_distance(2.0, 1.0, 1.0, NAN, 5.0), 2.0, 0.0001)


func test_finite_direction_rejects_degenerate_and_nonfinite_segments() -> void:
	assert_eq(ClimbRules.finite_direction(Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)
	assert_eq(ClimbRules.finite_direction(Vector3.ZERO, Vector3(INF, 0.0, 0.0)), Vector3.ZERO)
	assert_eq(ClimbRules.finite_direction(Vector3.ZERO, Vector3(2.0, 0.0, 0.0)), Vector3.RIGHT)
