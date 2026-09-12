extends GutTest

func after_each() -> void:
	MissionDirector.start_mission(null)
	GameState.area_alert_level = 0
	GameState.checkpoint_ref.clear()
	PlayerRetryFlow.pending_scene = ""

func test_port_lights_and_search_points_match_the_map_contract() -> void:
	var level: Node3D = load("res://src/levels/port_storehouse/port_mission.tscn").instantiate()
	add_child_autofree(level)
	var environment := level.get_node_or_null("PortEnvironment")
	assert_not_null(environment,"The mission needs authored gameplay lights and search points")
	if environment == null: return
	var outdoor := 0
	var outdoor_switches := 0
	var indoor := 0
	for light: LightSource in environment.get_node("Lights").get_children():
		assert_true(light.is_geometry_valid())
		assert_not_null(light.render_light)
		if light.get_meta(&"indoor",false): indoor += 1
		else:
			outdoor += 1
			if light.extinguishable: outdoor_switches += 1
	assert_eq([outdoor,outdoor_switches,indoor],[6,4,2])
	var zones := {}
	for point: SearchPoint in environment.get_node("Search").get_children():
		assert_true(point.is_searchable())
		zones[point.area_id] = int(zones.get(point.area_id,0))+1
	assert_eq(zones.size(),6)
	for count in zones.values(): assert_eq(count,2)

func test_port_retry_restores_lights_and_rejects_a_partial_lighting_snapshot() -> void:
	var level: Node3D = load("res://src/levels/port_storehouse/port_mission.tscn").instantiate()
	add_child_autofree(level)
	var environment := level.get_node_or_null("PortEnvironment")
	assert_not_null(environment)
	if environment == null: return
	for frame in range(5): await get_tree().physics_frame
	var lamp := environment.get_node("Lights/PierWestLamp") as LightSource
	lamp.set_extinguished(true)
	var flow := level.get_node("Player/RetryFlow") as PlayerRetryFlow
	assert_true(flow.capture_checkpoint(&"dark_pier"))
	var snapshot := GameState.checkpoint_ref.duplicate(true)
	lamp.set_extinguished(false)
	assert_true(level.get_node("Mission").restore_checkpoint_world(snapshot))
	assert_false(lamp.is_on())
	var corrupt := snapshot.duplicate(true)
	corrupt.mission_world.lights.erase("PierWestLamp")
	lamp.set_extinguished(false)
	assert_false(level.get_node("Mission").restore_checkpoint_world(corrupt))
	assert_true(lamp.is_on(),"Invalid world must not partially restore lighting")

func test_port_spawn_is_outside_civilian_reporting_and_guard_vision_ranges() -> void:
	var level: Node3D = load("res://src/levels/port_storehouse/port_mission.tscn").instantiate()
	add_child_autofree(level)
	for frame in range(5): await get_tree().physics_frame
	var player := level.get_node("Player") as PlayerController
	for civilian: CivilianNPC in level.get_node("Population/Civilians").get_children():
		assert_gt(player.global_position.distance_to(civilian.global_position),civilian.view_distance)
		assert_false(civilian.can_see_player(player))
	for enemy: EnemyBase in level.get_node("Population/Guards").get_children():
		assert_gt(player.global_position.distance_to(enemy.global_position),(enemy.get_node("Perception") as EnemyPerception).perception_config.view_distance_m)
