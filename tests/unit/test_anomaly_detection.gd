extends GutTest


const EnemyScene := preload("res://src/enemies/enemy_base.tscn")


func test_anomaly_marker_is_bounded_and_can_be_disabled() -> void:
	var marker := AnomalyMarker.new()
	marker.position = Vector3(0.0, 1.5, -3.0)
	add_child_autofree(marker)
	assert_true(marker.is_geometry_valid())
	assert_eq(marker.kind, Enums.AnomalyKind.DOOR_OPEN)
	assert_eq(marker.current_anomaly().kind, Enums.AnomalyKind.DOOR_OPEN)

	marker.severity = AnomalyMarker.MAX_SEVERITY + 1
	assert_eq(marker.severity, AnomalyMarker.MAX_SEVERITY)
	marker.position = Vector3(NAN, 0.0, 0.0)
	assert_false(marker.is_geometry_valid())
	assert_null(marker.current_anomaly())
	marker.position = Vector3(0.0, 1.5, -3.0)
	marker.set_active(false)
	assert_false(marker.is_active())
	assert_null(marker.current_anomaly())


func test_malformed_or_expired_anomaly_is_rejected() -> void:
	var enemy := EnemyScene.instantiate() as EnemyBase
	add_child_autofree(enemy)
	var perception := enemy.get_node(^"Perception") as EnemyPerception
	var invalid := Anomaly.create(
		Enums.AnomalyKind.DOOR_OPEN,
		Vector3(0.0, 1.5, -3.0),
		null,
		3,
	)
	invalid.severity = 0
	perception.on_anomaly(invalid)
	invalid.severity = 3
	invalid.expires_at = NAN
	perception.on_anomaly(invalid)
	invalid.expires_at = Time.get_ticks_msec() / 1000.0 - 1.0
	perception.on_anomaly(invalid)
	assert_eq(enemy.brain().pending_stimulus_count(), 0)


func test_persistent_door_anomaly_is_seen_when_observer_enters_later() -> void:
	var marker := AnomalyMarker.new()
	marker.position = Vector3(0.0, 1.5, -3.0)
	add_child_autofree(marker)
	await get_tree().process_frame

	var enemy := EnemyScene.instantiate() as EnemyBase
	add_child_autofree(enemy)
	await get_tree().physics_frame
	var brain := enemy.brain()
	brain.tick(0.1)

	assert_eq(brain.alert_state(), Enums.AlertState.SUSPICIOUS)
	assert_eq(brain.investigation_position(), marker.global_position)
	brain.tick(0.1)
	assert_eq(brain.pending_stimulus_count(), 0)


func test_persistent_extinguished_light_is_seen_when_observer_enters_later() -> void:
	var light := LightSource.new()
	light.position = Vector3(0.0, 1.5, -3.0)
	add_child_autofree(light)
	await get_tree().physics_frame
	assert_true(light.is_geometry_valid())
	light.set_extinguished(true)

	var enemy := EnemyScene.instantiate() as EnemyBase
	add_child_autofree(enemy)
	await get_tree().physics_frame
	var brain := enemy.brain()
	brain.tick(0.1)

	assert_eq(brain.alert_state(), Enums.AlertState.SUSPICIOUS)
	assert_true(brain.is_relight_pending())


func test_persistent_corpse_increases_area_alert_once() -> void:
	var original_alert := GameState.area_alert_level
	GameState.area_alert_level = 0
	var observer := EnemyScene.instantiate() as EnemyBase
	add_child_autofree(observer)
	var corpse := EnemyScene.instantiate() as EnemyBase
	corpse.position = Vector3(0.0, 0.0, -3.0)
	add_child_autofree(corpse)
	assert_true(corpse.set_incapacitated(&"dead"))
	await get_tree().physics_frame

	var brain := observer.brain()
	brain.tick(0.1)
	assert_eq(brain.alert_state(), Enums.AlertState.SEARCHING)
	assert_eq(GameState.area_alert_level, 1)
	assert_eq(corpse.brain().pending_stimulus_count(), 0)
	brain.tick(0.1)
	assert_eq(GameState.area_alert_level, 1)
	GameState.area_alert_level = original_alert


func test_routine_stops_switch_when_area_alert_changes() -> void:
	var original_alert := GameState.area_alert_level
	GameState.area_alert_level = 0
	var enemy := EnemyScene.instantiate() as EnemyBase
	add_child_autofree(enemy)
	var path := PatrolPath.new()
	add_child_autofree(path)
	var calm := _add_stop(path, 0, Vector3.ZERO)
	var strict := _add_stop(path, 1, Vector3(2.0, 0.0, 0.0))
	strict.min_alert_level = 1
	assert_eq(path.stops_for_alert_level(0).size(), 1)
	assert_eq(path.stops_for_alert_level(1).size(), 2)
	var brain := enemy.brain()
	assert_true(brain.set_patrol_path(path))
	assert_eq(brain.current_routine_stop(), calm)

	GameState.area_alert_level = 1
	EventBus.area_alert_changed.emit(1)
	assert_eq(brain.current_routine_stop(), strict)

	GameState.area_alert_level = 0
	EventBus.area_alert_changed.emit(0)
	assert_eq(brain.current_routine_stop(), calm)
	GameState.area_alert_level = original_alert


func test_patrol_alert_queries_skip_disabled_stops() -> void:
	var path := PatrolPath.new()
	add_child_autofree(path)
	var calm := _add_stop(path, 0, Vector3.ZERO)
	var disabled := _add_stop(path, 1, Vector3(1.0, 0.0, 0.0))
	disabled.enabled = false
	var strict := _add_stop(path, 2, Vector3(2.0, 0.0, 0.0))
	strict.min_alert_level = 1

	var calm_stops := path.stops_for_alert_level(0)
	assert_true(calm_stops.has(calm))
	assert_false(calm_stops.has(disabled))
	assert_false(calm_stops.has(strict))
	assert_eq(path.next_stop_index_for_alert(0, 0, true), 0)

	var alert_stops := path.stops_for_alert_level(1)
	assert_true(alert_stops.has(calm))
	assert_false(alert_stops.has(disabled))
	assert_true(alert_stops.has(strict))
	assert_eq(path.next_stop_index_for_alert(0, 1, true), 2)


func test_late_routine_binding_applies_existing_alert_level() -> void:
	var original_alert := GameState.area_alert_level
	GameState.area_alert_level = 1
	var enemy := EnemyScene.instantiate() as EnemyBase
	add_child_autofree(enemy)
	var path := PatrolPath.new()
	add_child_autofree(path)
	_add_stop(path, 0, Vector3.ZERO)
	var strict := _add_stop(path, 1, Vector3(2.0, 0.0, 0.0))
	strict.min_alert_level = 1

	assert_true(enemy.brain().set_patrol_path(path))
	assert_eq(enemy.brain().current_routine_stop(), strict)
	GameState.area_alert_level = original_alert


func _add_stop(path: PatrolPath, index: int, position: Vector3) -> RoutineStop:
	var stop := RoutineStop.new()
	stop.route_index = index
	stop.dwell_seconds = 0.0
	stop.position = position
	path.add_child(stop)
	return stop
