extends GutTest


const RESIDENCE_SCENE_PATH := "res://src/levels/samurai_residence/samurai_residence.tscn"
const RESIDENCE_SCRIPT := preload("res://src/levels/samurai_residence/samurai_residence.gd")


func test_residence_builds_bounded_four_layer_graybox_contract() -> void:
	var residence := _add_residence()
	await get_tree().physics_frame

	assert_true(
		residence.is_contract_valid(),
		"Samurai Residence contract errors: %s" % [residence.validation_errors()],
	)
	assert_eq(
		residence.route_waypoints(&"A_ground").size(),
		5,
		"Ground route must include the source-of-truth approach, veranda, corridor, and shoin points",
	)
	for route_id: StringName in RESIDENCE_SCRIPT.REQUIRED_ROUTE_IDS:
		assert_true(residence.route_is_traversable(route_id))
		assert_ne(residence.route_layer(route_id), &"")

	assert_eq(
		residence.floor_materials(),
		RESIDENCE_SCRIPT.REQUIRED_FLOOR_MATERIALS,
		"Graybox floors must expose every authored residence material",
	)
	assert_eq(
		residence.navigation_regions().size(),
		3,
		"Ground, overhead, and crawlspace navigation regions are authored separately",
	)
	for region: NavigationRegion3D in residence.navigation_regions():
		assert_true(region.enabled)
		assert_not_null(region.navigation_mesh)

	var north_wall := residence.get_node(^"Geometry/OuterPerimeter/NorthPerimeterWall") as StaticBody3D
	assert_true(
		(north_wall.collision_layer & RESIDENCE_SCRIPT.SOUND_BLOCKER_LAYER) != 0,
		"Residence walls must participate in hearing occlusion",
	)


func test_residence_routes_have_observation_and_restealth_options_per_area() -> void:
	var residence := _add_residence()
	await get_tree().physics_frame

	for area_id: StringName in RESIDENCE_SCRIPT.REQUIRED_AREAS:
		var observation := residence.observation_points(area_id)
		var re_stealth := residence.re_stealth_route(area_id)
		assert_gte(observation.size(), 2, "%s must have two observation points" % [area_id])
		assert_gte(re_stealth.size(), 3, "%s must have a re-stealth route" % [area_id])
		for position: Vector3 in observation + re_stealth:
			assert_true(
				RESIDENCE_SCRIPT.MAP_BOUNDS.has_point(Vector2(position.x, position.z)),
				"Marker %s must remain inside the authored 100x64 m map" % [position],
			)


func test_residence_route_geometry_keeps_veranda_and_crawlspace_open() -> void:
	var residence := _add_residence()
	await get_tree().physics_frame

	var north_wall := residence.get_node(^"Geometry/MainHouseFirstFloor/WestHouseWallNorth") as StaticBody3D
	var south_wall := residence.get_node(^"Geometry/MainHouseFirstFloor/WestHouseWallSouth") as StaticBody3D
	assert_false(
		_box_contains(north_wall, Vector3(43.0, 0.5, 17.0)),
		"Route A must have a clear west-wall opening at the south veranda",
	)
	assert_false(
		_box_contains(south_wall, Vector3(43.0, 0.5, 17.0)),
		"Route A must have a clear west-wall opening at the south veranda",
	)

	var crawl_floor := residence.get_node(^"Geometry/Crawlspace/CrawlUnderHouseFloor") as StaticBody3D
	var crawl_roof := residence.get_node(^"Geometry/Crawlspace/CrawlUnderHouseRoof") as StaticBody3D
	assert_true(
		_box_contains(crawl_floor, Vector3(58.0, -0.92, 20.0)),
		"Route C must reach the shoin crawl gap",
	)
	assert_true(
		_box_contains(crawl_roof, Vector3(58.0, 0.5, 20.0)),
		"Route C must retain crawl clearance at the shoin crawl gap",
	)


func test_residence_uses_existing_marker_contracts_and_light_ratio() -> void:
	var residence := _add_residence()
	await get_tree().physics_frame

	var counts := residence.marker_counts()
	assert_gte(counts[&"hide_spots"], 10)
	assert_eq(counts[&"climb_edges"], 4)
	assert_eq(counts[&"beam_paths"], 2)
	assert_eq(counts[&"crawl_entrances"], 3)
	assert_eq(counts[&"water_volumes"], 2)
	assert_eq(counts[&"search_points"], 12)
	assert_eq(counts[&"checkpoints"], 3)
	assert_eq(counts[&"anomaly_markers"], 4)

	var lights := residence.light_counts()
	assert_eq(lights[&"outdoor"], 6)
	assert_eq(lights[&"outdoor_extinguishable"], 4)
	assert_eq(lights[&"indoor"], 3)
	assert_true((residence.get_node(^"Markers/Lights/L1_LanternNorth") as LightSource).extinguishable)
	assert_false((residence.get_node(^"Markers/Lights/L5_GateBonfireWest") as LightSource).extinguishable)
	assert_false((residence.get_node(^"Markers/Lights/L6_GateBonfireEast") as LightSource).extinguishable)

	var entry := residence.get_node(^"Markers/ClimbEdges/C1_NorthWallEntry") as ClimbEdge
	var first_beam := residence.get_node(^"Markers/BeamPaths/B_Overhead_North") as BeamPath
	var first_exit := residence.get_node(^"Markers/ClimbEdges/C1_NorthRoofExit") as ClimbEdge
	assert_true(entry.is_geometry_valid())
	assert_true(first_beam.is_geometry_valid())
	assert_true(first_exit.is_geometry_valid())
	assert_eq(entry.connected_beam(), first_beam)
	assert_eq(first_beam.connected_climb_at_end(), first_exit)

	for node: Node in residence.find_children("*", "Area3D", true, false):
		if node is CrawlEntrance or node is WaterVolume or node is HideSpot:
			assert_true((node as Area3D).is_geometry_valid(), "Invalid marker: %s" % [node.name])


func _add_residence() -> SamuraiResidence:
	var scene := load(RESIDENCE_SCENE_PATH) as PackedScene
	assert_not_null(scene)
	var residence := scene.instantiate() as SamuraiResidence
	assert_not_null(residence)
	add_child_autofree(residence)
	return residence


func _box_contains(body: StaticBody3D, point: Vector3) -> bool:
	if body == null:
		return false
	var size := body.get_meta(&"graybox_bounds", Vector3.ZERO) as Vector3
	var local_point := body.to_local(point)
	var half_size := size * 0.5
	return (
		absf(local_point.x) <= half_size.x
		and absf(local_point.y) <= half_size.y
		and absf(local_point.z) <= half_size.z
	)
