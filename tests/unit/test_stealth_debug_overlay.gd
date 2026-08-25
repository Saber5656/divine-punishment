extends GutTest


const OverlayScript := preload("res://src/ui/stealth_debug_overlay.gd")
const NoiseEventScript := preload("res://src/core/noise_event.gd")


class VisibilityProvider:
	extends Node

	var value := 0.0

	func visibility() -> float:
		return value


class EnemyDebugProvider:
	extends Node3D

	var debug_payload: Dictionary = {}
	var detection_meter := 0.0

	func debug_vision_cone() -> Dictionary:
		return debug_payload

	func meter() -> float:
		return detection_meter


func test_toggle_is_explicit_and_input_action_is_bound_to_f3() -> void:
	var overlay := OverlayScript.new()
	add_child_autofree(overlay)
	assert_false(overlay.is_debug_visible())
	overlay.set_debug_visible(true)
	assert_true(overlay.is_debug_visible())
	assert_true(InputMap.has_action(OverlayScript.DEBUG_TOGGLE_ACTION))
	var f3_bound := false
	for event in InputMap.action_get_events(OverlayScript.DEBUG_TOGGLE_ACTION):
		if event is InputEventKey:
			var key_event := event as InputEventKey
			if key_event.keycode == KEY_F3 and key_event.physical_keycode == KEY_F3:
				f3_bound = true
	assert_true(f3_bound)


func test_player_visibility_is_exposed_in_overlay_status() -> void:
	var overlay := OverlayScript.new()
	var player := Node3D.new()
	var visibility := VisibilityProvider.new()
	visibility.value = 0.42
	player.name = "Player"
	visibility.name = "Visibility"
	player.add_child(visibility)
	add_child_autofree(overlay)
	add_child_autofree(player)
	overlay.set_player(player)
	overlay.set_debug_visible(true)
	assert_almost_eq(overlay.player_visibility_value(), 0.42, 0.0001)
	assert_string_contains(overlay.status_text(), "Player V: 0.420")


func test_light_gameplay_radius_is_discovered_from_lights_group() -> void:
	var overlay := OverlayScript.new()
	var light := LightSource.new()
	light.gameplay_radius = 8.0
	add_child_autofree(overlay)
	add_child_autofree(light)
	await get_tree().process_frame
	var snapshot := overlay.light_radius_snapshot()
	assert_eq(snapshot.size(), 1)
	assert_eq(snapshot[0].get(&"radius"), 8.0)
	assert_true(snapshot[0].get(&"active"))


func test_noise_radii_are_recorded_and_bounded() -> void:
	var overlay := OverlayScript.new()
	add_child_autofree(overlay)
	var source := Node.new()
	add_child_autofree(source)
	for index in 65:
		overlay.record_noise_event(
			NoiseEventScript.create(Vector3(index, 0.0, 0.0), 4.0, Enums.NoiseKind.FOOTSTEP, source),
		)
	assert_eq(overlay.active_noise_count(), OverlayScript.MAX_NOISE_RINGS)
	assert_eq(overlay.active_noise_radii()[0].get(&"position"), Vector3(1.0, 0.0, 0.0))


func test_enemy_provider_exposes_vision_cone_and_meter_extension_points() -> void:
	var overlay := OverlayScript.new()
	var enemy := EnemyDebugProvider.new()
	enemy.debug_payload = {
		&"origin": Vector3(2.0, 1.0, 3.0),
		&"forward": Vector3.FORWARD,
		&"fov_degrees": 110.0,
		&"view_distance": 15.0,
	}
	enemy.detection_meter = 1.25
	add_child_autofree(overlay)
	add_child_autofree(enemy)
	overlay.register_enemy(enemy)
	var snapshot := overlay.enemy_debug_snapshot()
	assert_eq(snapshot.size(), 1)
	assert_eq(snapshot[0].get(&"fov_degrees"), 110.0)
	assert_eq(snapshot[0].get(&"view_distance"), 15.0)
	assert_eq(snapshot[0].get(&"meter"), 1.25)
	assert_eq(overlay.debug_geometry_snapshot().get(&"vision_cones"), 1)
	assert_eq(overlay.debug_geometry_snapshot().get(&"meter_values"), 1)


func test_enemy_provider_preserves_meter_without_vision_cone() -> void:
	var overlay := OverlayScript.new()
	var enemy := EnemyDebugProvider.new()
	enemy.detection_meter = 1.5
	add_child_autofree(overlay)
	add_child_autofree(enemy)
	overlay.register_enemy(enemy)

	var snapshot := overlay.enemy_debug_snapshot()
	assert_eq(snapshot.size(), 1)
	assert_false(snapshot[0].has(&"fov_degrees"))
	assert_eq(snapshot[0].get(&"meter"), 1.5)
	assert_eq(overlay.debug_geometry_snapshot().get(&"vision_cones"), 0)
	assert_eq(overlay.debug_geometry_snapshot().get(&"meter_values"), 1)


func test_enemy_provider_preserves_requested_vision_color() -> void:
	var overlay := OverlayScript.new()
	var enemy := EnemyDebugProvider.new()
	var expected_color := Color(0.1, 0.8, 0.3, 0.7)
	enemy.debug_payload = {
		&"forward": Vector3.FORWARD,
		&"fov_degrees": 90.0,
		&"view_distance": 10.0,
		&"color": expected_color,
	}
	add_child_autofree(overlay)
	add_child_autofree(enemy)
	overlay.register_enemy(enemy)

	var snapshot := overlay.enemy_debug_snapshot()
	assert_eq(snapshot.size(), 1)
	assert_eq(snapshot[0].get(&"color"), expected_color)


func test_noise_event_telemetry_is_received_without_changing_enemy_dispatch() -> void:
	var overlay := OverlayScript.new()
	add_child_autofree(overlay)
	var source := Node.new()
	add_child_autofree(source)
	var event := NoiseEventScript.create(Vector3.ZERO, 6.0, Enums.NoiseKind.LANDING, source)
	EventBus.noise_emitted.emit(event)
	assert_eq(overlay.active_noise_count(), 1)
	assert_eq(overlay.active_noise_radii()[0].get(&"radius"), 6.0)
