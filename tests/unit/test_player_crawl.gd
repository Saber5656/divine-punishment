extends GutTest


const CrawlRules := preload("res://src/player/player_crawl.gd")


func test_crawl_world_positions_fail_closed() -> void:
	assert_true(CrawlRules.is_finite_vector(Vector3(1.0, 2.0, 3.0)))
	assert_false(CrawlRules.is_finite_vector(Vector3(NAN, 0.0, 0.0)))
	assert_true(CrawlRules.is_safe_world_position(
		Vector3(CrawlRules.MAX_WORLD_COORDINATE, 0.0, 0.0)
	))
	assert_false(CrawlRules.is_safe_world_position(
		Vector3(CrawlRules.MAX_WORLD_COORDINATE + 0.01, 0.0, 0.0)
	))
	assert_false(CrawlRules.is_safe_world_position(Vector3(INF, 0.0, 0.0)))


func test_crawl_capsule_height_requires_a_finite_supported_capsule() -> void:
	assert_true(CrawlRules.is_capsule_height_valid(0.7, 0.35, 1.8))
	assert_true(CrawlRules.is_capsule_height_valid(1.8, 0.35, 1.8))
	assert_false(CrawlRules.is_capsule_height_valid(0.69, 0.35, 1.8))
	assert_false(CrawlRules.is_capsule_height_valid(1.81, 0.35, 1.8))
	assert_false(CrawlRules.is_capsule_height_valid(NAN, 0.35, 1.8))
	assert_false(CrawlRules.is_capsule_height_valid(0.7, 0.0, 1.8))


func test_camera_posture_drop_is_bounded_and_finite() -> void:
	assert_almost_eq(CrawlRules.bounded_posture_drop(0.9, 1.1), 0.9, 0.0001)
	assert_almost_eq(CrawlRules.bounded_posture_drop(-1.0, 1.1), 0.0, 0.0001)
	assert_almost_eq(CrawlRules.bounded_posture_drop(2.0, 1.1), 1.1, 0.0001)
	assert_almost_eq(CrawlRules.bounded_posture_drop(NAN, 1.1), 0.0, 0.0001)
	assert_almost_eq(CrawlRules.bounded_posture_drop(0.5, INF), 0.0, 0.0001)
