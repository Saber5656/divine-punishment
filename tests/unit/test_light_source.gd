extends GutTest


const PLAYER_SCENE_PATH := "res://src/player/player.tscn"


func test_adjacent_extinguish_synchronizes_render_gameplay_and_anomaly() -> void:
	var light := _add_light()
	var render_light := OmniLight3D.new()
	light.render_light = render_light
	light.add_child(render_light)
	var player := _add_player_body(Vector3(0.5, 0.0, 0.0))
	await get_tree().physics_frame

	assert_true(light.is_geometry_valid())
	assert_true(light.can_interact(player))
	assert_true(render_light.visible)
	watch_signals(EventBus)

	assert_true(light.try_extinguish(player))
	assert_false(light.is_on())
	assert_false(render_light.visible)
	assert_eq(light.gameplay_contribution(0.0, false), 0.0)
	assert_signal_emit_count(EventBus, "anomaly_registered", 1)
	assert_signal_emit_count(EventBus, "light_extinguished", 1)

	var anomaly_parameters: Array = get_signal_parameters(EventBus, "anomaly_registered", 0)
	var anomaly := anomaly_parameters[0] as Anomaly
	assert_not_null(anomaly)
	assert_eq(anomaly.kind, Enums.AnomalyKind.LIGHT_OUT)
	assert_eq(anomaly.position, light.global_position)
	assert_eq(anomaly.node, light)
	assert_eq(anomaly.severity, 1)

	light.set_extinguished(false)
	assert_true(light.is_on())
	assert_true(render_light.visible)
	assert_gt(light.gameplay_contribution(0.0, false), 0.0)


func test_extinguish_rejects_out_of_range_and_invalid_targets() -> void:
	var light := _add_light()
	var player := _add_player_body(Vector3(1.01, 0.0, 0.0))
	await get_tree().physics_frame

	assert_false(light.can_interact(player))
	assert_false(light.try_extinguish(player))
	assert_true(light.is_on())

	player.global_position = Vector3.ZERO
	var enemy := CharacterBody3D.new()
	enemy.collision_layer = LightSource.ENEMY_BODY_LAYER
	add_child_autofree(enemy)
	assert_false(light.can_interact(enemy))
	assert_false(light.try_extinguish(enemy))

	var invalid_target := Node3D.new()
	add_child_autofree(invalid_target)
	assert_false(light.can_interact(invalid_target))
	assert_false(light.try_extinguish(invalid_target))

	var shape := light.get_node(
		NodePath(String(LightSource.INTERACTION_SHAPE_NODE_NAME)),
	) as CollisionShape3D
	shape.shape = SphereShape3D.new()
	assert_false(light.is_geometry_valid())
	assert_false(light.can_interact(player))


func test_non_extinguishable_light_rejects_player_interaction() -> void:
	var light := _add_light()
	light.extinguishable = false
	var player := _add_player_body(Vector3.ZERO)
	await get_tree().physics_frame

	assert_true(light.is_on())
	assert_false(light.can_interact(player))
	assert_false(light.try_extinguish(player))
	assert_true(light.is_on())


func test_player_adjacent_interaction_chooses_light_source() -> void:
	var player := (load(PLAYER_SCENE_PATH) as PackedScene).instantiate() as PlayerController
	player.set_physics_process(false)
	add_child_autofree(player)
	player.global_position = Vector3.ZERO
	var light := _add_light(Vector3(0.75, 0.0, 0.0))
	await get_tree().physics_frame

	assert_true(player.try_extinguish_adjacent_light())
	assert_false(light.is_on())
	assert_false(player.try_extinguish_adjacent_light())


func test_player_light_discovery_fails_closed_on_raw_query_overflow() -> void:
	var player := (load(PLAYER_SCENE_PATH) as PackedScene).instantiate() as PlayerController
	player.set_physics_process(false)
	add_child_autofree(player)
	for _index: int in PlayerController.MAX_LIGHT_SOURCE_SPATIAL_RESULTS + 1:
		_add_light()
	await get_tree().physics_frame

	assert_null(player._nearest_light_source())


func test_player_light_discovery_fails_closed_on_valid_candidate_overflow() -> void:
	var player := (load(PLAYER_SCENE_PATH) as PackedScene).instantiate() as PlayerController
	player.set_physics_process(false)
	add_child_autofree(player)
	for _index: int in PlayerController.MAX_LIGHT_SOURCE_CANDIDATES + 1:
		_add_light()
	await get_tree().physics_frame

	assert_null(player._nearest_light_source())


func test_relight_request_is_typed_and_does_not_change_state_until_accepted() -> void:
	var light := _add_light()
	var requester := Node.new()
	add_child_autofree(requester)
	await get_tree().physics_frame
	light.set_extinguished(true)

	watch_signals(EventBus)
	assert_true(light.request_relight(requester))

	var request_parameters: Array = get_signal_parameters(EventBus, "light_relight_requested", 0)
	assert_not_null(request_parameters)
	assert_eq(request_parameters.size(), 1)
	var captured := request_parameters[0] as RelightRequest
	assert_not_null(captured)
	assert_eq(captured.light, light)
	assert_eq(captured.requester, requester)
	assert_eq(captured.position, light.global_position)
	assert_false(light.is_on())
	assert_true(light.request_relight(requester))
	light.set_extinguished(false)
	assert_true(light.is_on())
	assert_false(light.request_relight(requester))


func _add_light(at: Vector3 = Vector3.ZERO) -> LightSource:
	var light := LightSource.new()
	light.position = at
	add_child_autofree(light)
	return light


func _add_player_body(at: Vector3) -> CharacterBody3D:
	var player := CharacterBody3D.new()
	player.collision_layer = LightSource.PLAYER_BODY_LAYER
	player.position = at
	add_child_autofree(player)
	return player
