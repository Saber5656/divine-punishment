extends GutTest


const EnemyScene := preload("res://src/enemies/enemy_base.tscn")
const PlayerScene := preload("res://src/player/player.tscn")


func test_search_point_contract_bounds_group_and_gizmo() -> void:
	var point := SearchPoint.new()
	add_child_autofree(point)
	assert_true(point.is_in_group(&"search_points"))
	assert_true(point.is_geometry_valid())
	assert_true(point.is_searchable())
	assert_eq(point.gizmo_segments().size(), 8)

	point.confidence = 1.5
	assert_eq(point.confidence, SearchPoint.MAX_CONFIDENCE)
	point.confidence = NAN
	assert_eq(point.confidence, SearchPoint.MIN_CONFIDENCE)
	point.enabled = false
	assert_true(point.is_geometry_valid())
	assert_false(point.is_searchable())
	point.enabled = true
	point.enemy_accessible = false
	assert_false(point.is_searchable())
	point.scale = Vector3(2.0, 1.0, 1.0)
	assert_false(point.is_geometry_valid())
	assert_true(point.gizmo_segments().is_empty())


func test_search_route_orders_confidence_then_distance_and_advances_after_arrival() -> void:
	var enemy := _spawn_enemy()
	var brain := enemy.brain()
	var low := _add_search_point(&"Low", Vector3(0.0, 0.0, -3.0), 0.2, 2)
	var high_far := _add_search_point(&"HighFar", Vector3(0.0, 0.0, -5.0), 0.9, 1)
	var high_near := _add_search_point(&"HighNear", Vector3(0.0, 0.0, -1.0), 0.9, 0)
	var disabled := _add_search_point(&"Disabled", Vector3(0.0, 0.0, -2.0), 1.0, 3)
	disabled.enabled = false
	assert_eq(get_tree().get_nodes_in_group(&"search_points").size(), 4)
	brain.submit_stimulus(PerceptionStimulus.create(
		Enums.StimulusKind.NOISE,
		3,
		Vector3(0.0, 0.0, -1.0),
		1.0,
	))
	brain.tick(0.016)

	assert_eq(brain.alert_state(), Enums.AlertState.SEARCHING)
	assert_eq(brain.search_point_count(), 3)
	assert_eq(brain.search_point_order(), [&"HighNear", &"HighFar", &"Low"])
	assert_eq(brain.current_search_point(), high_near)

	enemy.global_position = high_near.global_position
	brain.tick(0.016)
	assert_eq(brain.current_search_point(), high_far)
	enemy.global_position = high_far.global_position
	brain.tick(0.016)
	assert_eq(brain.current_search_point(), low)


func test_search_route_keeps_best_candidates_after_irrelevant_markers() -> void:
	var enemy := _spawn_enemy()
	var brain := enemy.brain()
	for index in EnemyBrain.MAX_SEARCH_POINT_CANDIDATES + 8:
		_add_search_point("Far%03d" % index, Vector3(100.0 + float(index), 0.0, 0.0), 0.1, index)
	var valid := _add_search_point(&"Valid", Vector3(0.0, 0.0, -1.0), 1.0, 0)
	brain.submit_stimulus(PerceptionStimulus.create(
		Enums.StimulusKind.NOISE,
		3,
		valid.global_position,
		1.0,
	))
	brain.tick(0.016)

	assert_eq(brain.search_point_count(), 1)
	assert_eq(brain.current_search_point(), valid)


func test_search_faces_authored_direction_before_hide_spot_inspection() -> void:
	var enemy := _spawn_enemy()
	var brain := enemy.brain()
	var point := _add_search_point(&"Facing", Vector3(0.0, 0.0, -1.0), 1.0, 0)
	point.facing_direction = Vector3.RIGHT
	brain.submit_stimulus(PerceptionStimulus.create(
		Enums.StimulusKind.NOISE,
		3,
		point.global_position,
		1.0,
	))
	brain.tick(0.016)
	enemy.global_position = point.global_position
	brain.tick(0.016)

	assert_gt(absf(enemy.rotation.y), 0.1)


func test_search_route_rejects_inaccessible_and_overhead_points() -> void:
	var enemy := _spawn_enemy()
	var brain := enemy.brain()
	var inaccessible := _add_search_point(&"Inaccessible", Vector3(0.0, 0.0, -1.0), 1.0, 0)
	inaccessible.enemy_accessible = false
	var overhead := _add_search_point(&"Overhead", Vector3(0.0, 5.0, -2.0), 1.0, 1)
	overhead.enemy_accessible = false
	var valid := _add_search_point(&"Ground", Vector3(0.0, 0.0, -3.0), 0.5, 2)
	brain.submit_stimulus(PerceptionStimulus.create(
		Enums.StimulusKind.NOISE,
		3,
		valid.global_position,
		1.0,
	))
	brain.tick(0.016)

	assert_eq(brain.search_point_count(), 1)
	assert_eq(brain.current_search_point(), valid)


func test_search_inspects_bounded_hide_spots_through_perception_gate() -> void:
	var enemy := _spawn_enemy()
	var brain := enemy.brain()
	var point := _add_search_point(&"Search", Vector3(0.0, 0.0, -1.0), 1.0, 0)
	var visible_hide := _add_hide_spot(&"VisibleHide", Vector3(0.0, 0.0, -1.0))
	for index in 9:
		_add_hide_spot("Hide%02d" % index, Vector3(float(index + 1), 0.0, -1.0))
	brain.submit_stimulus(PerceptionStimulus.create(
		Enums.StimulusKind.VISUAL,
		3,
		point.global_position,
		1.0,
	))
	brain.tick(0.016)
	enemy.global_position = point.global_position
	brain.tick(0.016)

	assert_lte(brain.inspected_hide_spot_count(), EnemyBrain.MAX_SEARCH_HIDE_SPOTS)
	assert_gt(brain.inspected_hide_spot_count(), 0)
	assert_gte(brain.visible_search_hide_spot_count(), 1)


func test_search_inspection_reveals_hidden_player_and_enters_combat() -> void:
	var enemy := _spawn_enemy()
	var brain := enemy.brain()
	var hide_spot := _add_hide_spot(&"OccupiedHide", Vector3(0.0, 0.0, -1.0))
	_add_floor()
	var player := PlayerScene.instantiate() as PlayerController
	player.position = hide_spot.position
	add_child_autofree(player)
	await _await_player_grounded(player)
	assert_true(player.try_enter_hide_spot(hide_spot))
	assert_true(player.is_hidden())

	brain._inspect_hide_spots_at(hide_spot.global_position)
	assert_false(player.is_hidden())
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_CROUCH)
	brain.tick(0.016)
	assert_eq(brain.alert_state(), Enums.AlertState.COMBAT)


func test_search_visibility_gate_rejects_out_of_fov_position() -> void:
	var enemy := _spawn_enemy()
	var perception := enemy.get_node(^"Perception") as EnemyPerception
	assert_true(perception.can_see_position(Vector3(0.0, 0.0, -4.0)))
	assert_false(perception.can_see_position(Vector3(0.0, 0.0, 4.0)))


func _spawn_enemy(at: Vector3 = Vector3.ZERO) -> EnemyBase:
	var enemy := EnemyScene.instantiate() as EnemyBase
	enemy.position = at
	add_child_autofree(enemy)
	return enemy


func _add_search_point(point_name: StringName, position: Vector3, point_confidence: float, order: int) -> SearchPoint:
	var point := SearchPoint.new()
	point.name = point_name
	point.position = position
	point.confidence = point_confidence
	point.search_order = order
	add_child_autofree(point)
	return point


func _add_hide_spot(spot_name: StringName, position: Vector3) -> HideSpot:
	var hide_spot := HideSpot.new()
	hide_spot.name = spot_name
	hide_spot.position = position
	add_child_autofree(hide_spot)
	return hide_spot


func _add_floor() -> StaticBody3D:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	floor_body.position = Vector3(0.0, -0.95, 0.0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(10.0, 0.2, 10.0)
	collision.shape = shape
	floor_body.add_child(collision)
	add_child_autofree(floor_body)
	return floor_body


func _await_player_grounded(player: PlayerController) -> void:
	for _frame in 8:
		await get_tree().physics_frame
		if player.is_on_floor():
			return
	assert_true(player.is_on_floor())
