extends GutTest

func after_each() -> void:
	MissionDirector.start_mission(null)
	GameState.area_alert_level = 0
	GameState.checkpoint_ref.clear()
	PlayerRetryFlow.pending_scene = ""
	get_tree().paused = false

func _world() -> Node3D:
	var level: Node3D = load("res://src/levels/rainy_temple/temple_mission.tscn").instantiate()
	add_child_autofree(level)
	for frame in range(5): await get_tree().physics_frame
	return level

func test_temple_places_six_sheltered_lamps_two_braziers_and_ground_search_routes() -> void:
	var level := await _world()
	var environment := level.get_node_or_null("TempleEnvironment")
	assert_not_null(environment,"Temple needs gameplay lights and searchable areas")
	if environment == null: return
	var sheltered := 0
	var braziers := 0
	var space := level.get_world_3d().direct_space_state
	for light: LightSource in environment.get_node("Lights").get_children():
		assert_true(light.is_geometry_valid())
		assert_true(light.is_on(),"Sheltered lamps and braziers survive rain")
		assert_not_null(light.render_light)
		var ray := PhysicsRayQueryParameters3D.create(light.global_position,light.global_position+Vector3.UP*20,1|16)
		var hit := space.intersect_ray(ray)
		if light.extinguishable:
			sheltered += 1
			assert_false(hit.is_empty(),"Lanterns must be beneath a physical roof")
			if not hit.is_empty(): assert_true(String(hit.collider.name).contains("Roof"))
		else:
			braziers += 1
			assert_true(hit.is_empty(),"Outdoor sources are braziers")
	assert_eq([sheltered,braziers],[6,2])
	var zones := {}
	var map := level.get_world_3d().navigation_map
	for point: SearchPoint in environment.get_node("Search").get_children():
		assert_true(point.is_searchable())
		assert_lt(point.global_position.distance_to(NavigationServer3D.map_get_closest_point(map,point.global_position)),0.25,"Search points sit on the actual ground navigation mesh")
		zones[point.area_id] = int(zones.get(point.area_id,0))+1
	assert_eq(zones.size(),7)
	for count in zones.values(): assert_eq(count,2)

func test_lantern_changes_real_visibility_and_initial_rain_introduction_is_safe() -> void:
	var level := await _world()
	var environment := level.get_node_or_null("TempleEnvironment")
	assert_not_null(environment)
	if environment == null: return
	var player := level.get_node("Player") as PlayerController
	player.set_physics_process(false)
	var visibility := player.get_node("Visibility") as PlayerVisibility
	var entry_darkness := visibility.recompute()
	for actor: EnemyBase in level.get_node("Population/Duties").call("actors"):
		assert_gt(player.global_position.distance_to(actor.global_position),(actor.get_node("Perception") as EnemyPerception).perception_config.view_distance_m)
	player.global_position = Vector3(84,5.02,36.2)
	var lit := visibility.recompute()
	assert_gt(lit,entry_darkness+0.15,"Visible glow affects actual detection visibility")
	var lamp := environment.get_node("Lights/CellLamp") as LightSource
	lamp.set_extinguished(true)
	assert_lt(visibility.recompute(),lit-0.15)

func test_retry_preserves_extinguished_lights_and_rejects_partial_light_state_atomically() -> void:
	var level := await _world()
	var environment := level.get_node_or_null("TempleEnvironment")
	assert_not_null(environment)
	if environment == null: return
	var lamp := environment.get_node("Lights/CellLamp") as LightSource
	lamp.set_extinguished(true)
	assert_true((level.get_node("Player/RetryFlow") as PlayerRetryFlow).capture_checkpoint(&"dark_cell"))
	var snapshot := GameState.checkpoint_ref.duplicate(true)
	lamp.set_extinguished(false)
	assert_true(level.get_node("Mission").call("restore_checkpoint_world",snapshot))
	assert_false(lamp.is_on())
	var corrupt := snapshot.duplicate(true)
	assert_true(corrupt.mission_world.has("lights"))
	if not corrupt.mission_world.has("lights"): return
	corrupt.mission_world.lights.erase("CellLamp")
	lamp.set_extinguished(false)
	assert_false(level.get_node("Mission").call("restore_checkpoint_world",corrupt))
	assert_true(lamp.is_on(),"Invalid world must not partially alter a light")
