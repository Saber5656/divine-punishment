extends GutTest


func test_swim_world_positions_and_breath_inputs_fail_closed() -> void:
	assert_true(PlayerSwimRules.is_safe_world_position(Vector3.ZERO))
	assert_true(PlayerSwimRules.is_safe_world_position(
		Vector3(PlayerSwimRules.MAX_WORLD_COORDINATE, 0.0, 0.0),
	))
	assert_false(PlayerSwimRules.is_safe_world_position(
		Vector3(PlayerSwimRules.MAX_WORLD_COORDINATE + 0.01, 0.0, 0.0),
	))
	assert_false(PlayerSwimRules.is_safe_world_position(Vector3(NAN, 0.0, 0.0)))
	assert_true(PlayerSwimRules.is_breath_capacity_valid(20.0))
	assert_false(PlayerSwimRules.is_breath_capacity_valid(0.0))
	assert_false(PlayerSwimRules.is_breath_capacity_valid(INF))


func test_breath_consumption_is_finite_and_bounded() -> void:
	assert_almost_eq(PlayerSwimRules.consume_breath(20.0, 0.25, 20.0), 19.75, 0.0001)
	assert_eq(PlayerSwimRules.consume_breath(0.1, 1.0, 20.0), 0.0)
	assert_eq(PlayerSwimRules.consume_breath(30.0, 0.0, 20.0), 20.0)
	assert_eq(PlayerSwimRules.consume_breath(20.0, -1.0, 20.0), 0.0)
	assert_eq(PlayerSwimRules.consume_breath(NAN, 0.1, 20.0), 0.0)


func test_exhaustion_noise_radius_has_a_finite_upper_bound() -> void:
	assert_true(PlayerSwimRules.is_exhaustion_noise_radius_valid(8.0))
	assert_false(PlayerSwimRules.is_exhaustion_noise_radius_valid(0.0))
	assert_false(PlayerSwimRules.is_exhaustion_noise_radius_valid(
		PlayerSwimRules.MAX_EXHAUSTION_NOISE_RADIUS + 0.01,
	))
	assert_false(PlayerSwimRules.is_exhaustion_noise_radius_valid(NAN))


func test_swim_speed_and_physics_delta_have_named_finite_bounds() -> void:
	assert_true(PlayerSwimRules.is_swim_speed_valid(PlayerSwimRules.MIN_SWIM_SPEED))
	assert_true(PlayerSwimRules.is_swim_speed_valid(PlayerSwimRules.MAX_SWIM_SPEED))
	assert_false(PlayerSwimRules.is_swim_speed_valid(-0.01))
	assert_false(PlayerSwimRules.is_swim_speed_valid(
		PlayerSwimRules.MAX_SWIM_SPEED + 0.01,
	))
	assert_false(PlayerSwimRules.is_swim_speed_valid(NAN))
	assert_false(PlayerSwimRules.is_swim_speed_valid(INF))
	assert_true(PlayerSwimRules.is_physics_delta_valid(PlayerSwimRules.MAX_PHYSICS_DELTA))
	assert_false(PlayerSwimRules.is_physics_delta_valid(
		PlayerSwimRules.MAX_PHYSICS_DELTA + 0.01,
	))
