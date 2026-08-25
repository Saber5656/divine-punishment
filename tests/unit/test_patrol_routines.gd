extends GutTest


const EnemyScene := preload("res://src/enemies/enemy_base.tscn")
const AshigaruScene := preload("res://src/enemies/ashigaru_patrol.tscn")
const GuardScene := preload("res://src/enemies/guard.tscn")
const LanternBearerScene := preload("res://src/enemies/lantern_bearer.tscn")
const MissionDirectorScript := preload("res://src/autoload/mission_director.gd")


func test_routine_stop_bounds_schedule_facing_and_gizmo_contract() -> void:
	var stop := RoutineStop.new()
	add_child_autofree(stop)
	assert_true(stop.is_in_group(&"routine_stops"))
	assert_true(stop.is_geometry_valid())
	stop.dwell_seconds = RoutineStop.MAX_DWELL_SECONDS + 1.0
	assert_eq(stop.dwell_duration(), RoutineStop.MAX_DWELL_SECONDS)
	stop.active_from_seconds = 10.0
	stop.active_until_seconds = 5.0
	assert_false(stop.is_geometry_valid())
	assert_false(stop.is_active_at(10.0))
	stop.active_until_seconds = 20.0
	stop.facing_direction = Vector3.RIGHT
	assert_true(stop.is_geometry_valid())
	assert_true(stop.is_active_at(15.0))
	assert_false(stop.is_active_at(21.0))
	assert_gt(stop.gizmo_segments().size(), 0)


func test_patrol_path_orders_bounded_stops_and_loops() -> void:
	var path := PatrolPath.new()
	add_child_autofree(path)
	var late := _add_stop(path, 2, Vector3(4.0, 0.0, 0.0))
	var first := _add_stop(path, 0, Vector3.ZERO)
	var middle := _add_stop(path, 1, Vector3(2.0, 0.0, 0.0))
	late.dwell_seconds = 0.0
	first.dwell_seconds = 0.0
	middle.dwell_seconds = 0.0
	assert_true(path.is_geometry_valid())
	assert_eq(path.ordered_stops()[0], first)
	assert_eq(path.ordered_stops()[1], middle)
	assert_eq(path.ordered_stops()[2], late)
	assert_eq(path.next_stop_index(2), 0)
	assert_eq(path.next_stop_index(0, false), 2)
	assert_eq(path.world_position_for_stop(1), Vector3(2.0, 0.0, 0.0))
	assert_gt(path.route_length(), 0.0)
	assert_lte(path.gizmo_segments().size(), PatrolPath.MAX_GIZMO_SEGMENTS * 2)

	path.looped = false
	assert_eq(path.next_stop_index(2), 2)
	assert_eq(path.next_stop_index(0, false), 0)


func test_patrol_path_supports_curve_only_routes_with_bounded_gizmo() -> void:
	var path := PatrolPath.new()
	add_child_autofree(path)
	var route := Curve3D.new()
	route.bake_interval = 0.2
	route.add_point(Vector3.ZERO)
	route.add_point(Vector3(3.0, 0.0, 0.0))
	path.path_curve = route
	assert_true(path.is_geometry_valid())
	assert_almost_eq(path.route_length(), 3.0, 0.05)
	assert_eq(path.stop_count(), 0)
	assert_eq(path.world_position_at_distance(0.0), Vector3.ZERO)
	assert_gt(path.gizmo_segments().size(), 0)


func test_patrol_path_gizmo_rejects_unbounded_curve_controls() -> void:
	var path := PatrolPath.new()
	add_child_autofree(path)
	var route := Curve3D.new()
	route.bake_interval = 0.2
	route.add_point(Vector3.ZERO)
	route.add_point(Vector3(PatrolPath.MAX_LOCAL_POINT_DISTANCE + 1.0, 0.0, 0.0))
	path.path_curve = route

	assert_false(path.is_geometry_valid())
	assert_true(path.gizmo_segments().is_empty())


func test_patrol_path_gizmo_rejects_invalid_stop_coordinates() -> void:
	var path := PatrolPath.new()
	add_child_autofree(path)
	_add_stop(path, 0, Vector3(NAN, 0.0, 0.0))
	_add_stop(path, 1, Vector3(2.0, 0.0, 0.0))

	assert_false(path.is_geometry_valid())
	assert_true(path.gizmo_segments().is_empty())


func test_patrol_path_gizmo_rejects_huge_finite_stop_coordinates() -> void:
	var path := PatrolPath.new()
	add_child_autofree(path)
	_add_stop(path, 0, Vector3.ZERO)
	_add_stop(path, 1, Vector3(PatrolPath.MAX_LOCAL_POINT_DISTANCE + 1.0, 0.0, 0.0))

	assert_true(path.is_geometry_valid())
	assert_true(path.gizmo_segments().is_empty())


func test_patrol_path_gizmo_rejects_stop_marker_endpoint_overflow() -> void:
	var path := PatrolPath.new()
	add_child_autofree(path)
	var stop := _add_stop(path, 0, Vector3(PatrolPath.MAX_LOCAL_POINT_DISTANCE - 0.1, 0.0, 0.0))

	assert_true(stop.is_geometry_valid())
	assert_true(path.gizmo_segments().is_empty())


func test_enemy_brain_fails_closed_for_patrol_and_guard_without_navigation_map() -> void:
	var enemy := EnemyScene.instantiate() as EnemyBase
	add_child_autofree(enemy)
	var path := PatrolPath.new()
	add_child_autofree(path)
	_add_stop(path, 0, Vector3.ZERO, 0.0)
	_add_stop(path, 1, Vector3(2.0, 0.0, 0.0), 0.0)
	var brain := enemy.brain()
	var navigation_agent := enemy.get_node(^"NavigationAgent3D") as NavigationAgent3D
	var empty_map := NavigationServer3D.map_create()
	navigation_agent.set_navigation_map(empty_map)
	assert_true(brain.set_routine_type(&"patrol"))
	assert_true(brain.set_patrol_path(path))
	brain.tick(0.1)
	assert_eq(brain.routine_type(), &"ashigaru_patrol")
	assert_eq(brain.current_routine_stop_index(), 1)
	assert_eq(
		(enemy.get_node(^"NavigationAgent3D") as NavigationAgent3D).target_position,
		Vector3.ZERO,
	)
	assert_eq(enemy.global_position, Vector3.ZERO)
	for _index in 10:
		brain.tick(0.1)
	assert_eq(enemy.global_position, Vector3.ZERO)
	assert_true(brain.current_routine_stop_index() in [0, 1])
	for _index in 5:
		brain.tick(0.1)
	assert_eq(enemy.global_position, Vector3.ZERO)
	assert_true(brain.current_routine_stop_index() in [0, 1])

	var guard := GuardScene.instantiate() as EnemyBase
	add_child_autofree(guard)
	guard.global_position = Vector3(0.0, 0.0, 0.0)
	var guard_path := PatrolPath.new()
	add_child_autofree(guard_path)
	_add_stop(guard_path, 0, Vector3(1.0, 0.0, 0.0), 0.0)
	_add_stop(guard_path, 1, Vector3(4.0, 0.0, 0.0), 0.0)
	var guard_brain := guard.brain()
	(guard.get_node(^"NavigationAgent3D") as NavigationAgent3D).set_navigation_map(empty_map)
	assert_true(guard_brain.set_patrol_path(guard_path))
	for _index in 30:
		guard_brain.tick(0.1)
	assert_eq(guard.global_position, Vector3.ZERO)
	assert_eq(guard_brain.current_routine_stop_index(), 0)
	NavigationServer3D.free_rid(empty_map)


func test_lantern_bearer_variant_carries_light_without_navigation_map() -> void:
	var enemy := LanternBearerScene.instantiate() as EnemyBase
	add_child_autofree(enemy)
	var light := enemy.get_node(^"Lantern") as LightSource
	var path := PatrolPath.new()
	add_child_autofree(path)
	_add_stop(path, 0, Vector3.ZERO, 0.0)
	_add_stop(path, 1, Vector3(1.0, 0.0, 0.0), 0.0)
	var brain := enemy.brain()
	var empty_map := NavigationServer3D.map_create()
	(enemy.get_node(^"NavigationAgent3D") as NavigationAgent3D).set_navigation_map(empty_map)
	assert_eq(brain.routine_type(), &"lantern_bearer")
	assert_true(brain.is_lantern_bearer())
	assert_true(light.is_on())
	assert_true(brain.set_patrol_path(path))
	brain.tick(0.1)
	assert_almost_eq(light.global_position.x, enemy.global_position.x, 0.0001)
	assert_almost_eq(light.global_position.y, enemy.global_position.y + 1.4, 0.0001)
	for _index in 8:
		brain.tick(0.1)
	assert_eq(enemy.global_position, Vector3.ZERO)
	assert_almost_eq(light.global_position.x, enemy.global_position.x, 0.0001)
	assert_true(light.is_on())
	NavigationServer3D.free_rid(empty_map)


func test_navigation_arrival_fails_closed_before_map_sync() -> void:
	var enemy := EnemyScene.instantiate() as EnemyBase
	add_child_autofree(enemy)
	var agent := NavigationAgent3D.new()
	assert_false(EnemyBase._navigation_map_ready(agent))
	agent.free()
	var brain := enemy.brain() as EnemyBrain
	var enemy_agent := enemy.get_node(^"NavigationAgent3D") as NavigationAgent3D
	var empty_map := NavigationServer3D.map_create()
	enemy_agent.set_navigation_map(empty_map)
	assert_false(EnemyBase._navigation_map_ready(enemy_agent))
	assert_false(brain._navigation_has_reached(Vector3(20.0, 0.0, 0.0)))
	brain._set_navigation_target(Vector3(20.0, 0.0, 0.0))
	assert_eq(enemy_agent.target_position, Vector3.ZERO)
	var initial_position: Vector3 = enemy.global_position
	var moved := enemy.advance_navigation(0.1, Vector3(2.0, 0.0, 0.0), 1.5)
	assert_false(moved)
	assert_eq(enemy.global_position, initial_position)
	assert_eq(enemy.velocity, Vector3.ZERO)
	NavigationServer3D.free_rid(empty_map)


func test_navigation_candidate_rejects_non_improvement_and_invalid_vectors() -> void:
	var current := Vector3.ZERO
	var target := Vector3(4.0, 0.0, 0.0)
	assert_true(EnemyBase._navigation_candidate_is_progress(current, target, Vector3(1.0, 0.0, 0.0)))
	assert_false(EnemyBase._navigation_candidate_is_progress(current, target, current))
	assert_false(EnemyBase._navigation_candidate_is_progress(current, target, Vector3(-1.0, 0.0, 0.0)))
	assert_false(EnemyBase._navigation_candidate_is_progress(current, target, Vector3(INF, 0.0, 0.0)))


func test_corpse_alert_is_owned_by_mission_director_once() -> void:
	var director := MissionDirectorScript.new()
	add_child_autofree(director)
	director.start_mission(MissionDefinition.new())
	var enemy := EnemyScene.instantiate() as EnemyBase
	add_child_autofree(enemy)
	var corpse := Node3D.new()
	add_child_autofree(corpse)
	var anomaly := Anomaly.create(Enums.AnomalyKind.CORPSE, corpse.global_position, corpse, 3)
	var stimulus := PerceptionStimulus.create(
		Enums.StimulusKind.ANOMALY,
		3,
		anomaly.position,
		1.0,
		anomaly,
	)
	var original_alert := GameState.area_alert_level
	GameState.area_alert_level = 0
	var brain := enemy.brain()
	brain._raise_area_alert_if_severe(stimulus)
	assert_eq(GameState.area_alert_level, 0)
	director._on_anomaly_spotted(anomaly, enemy)
	director._on_anomaly_spotted(anomaly, enemy)
	assert_eq(director.stats().bodies_found, 1)
	assert_eq(GameState.area_alert_level, 1)
	GameState.area_alert_level = original_alert


func test_disabled_noise_wake_drops_stale_stimulus() -> void:
	var enemy := EnemyScene.instantiate() as EnemyBase
	add_child_autofree(enemy)
	var brain := enemy.brain()
	assert_true(brain.set_incapacitated(&"sleep", 20.0))
	brain.set_incapacitation_wake_by_noise(false)
	var source := Node.new()
	add_child_autofree(source)
	enemy.on_noise(NoiseEvent.create(Vector3.ZERO, 6.0, Enums.NoiseKind.COMBAT, source))
	assert_true(brain.is_incapacitated())
	assert_eq(brain.pending_stimulus_count(), 0)


func test_stimulus_confidence_rejects_values_outside_contract() -> void:
	var invalid := PerceptionStimulus.new()
	invalid.kind = Enums.StimulusKind.NOISE
	invalid.priority = 1
	invalid.position = Vector3.ZERO
	invalid.confidence = 1.1
	assert_false(EnemyBrain._valid_stimulus(invalid))
	invalid.confidence = -0.1
	assert_false(EnemyBrain._valid_stimulus(invalid))
	invalid.confidence = 0.5
	assert_true(EnemyBrain._valid_stimulus(invalid))


func _add_stop(path: PatrolPath, index: int, position: Vector3, dwell: float = 1.0) -> RoutineStop:
	var stop := RoutineStop.new()
	stop.route_index = index
	stop.dwell_seconds = dwell
	stop.position = position
	path.add_child(stop)
	return stop
