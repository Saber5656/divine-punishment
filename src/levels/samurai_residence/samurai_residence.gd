@tool
class_name SamuraiResidence
extends Node3D


## Asset-free graybox for M2 (the Samurai Residence).
##
## The map drawing in docs/maps/m02-yashiki.md is expressed in x/z metres.  This
## scene keeps those coordinates in one place and builds only bounded primitive
## geometry.  Gameplay systems consume the authored marker contracts; the
## scene does not depend on a model, texture, or external level asset.

const MAP_BOUNDS := Rect2(0.0, 0.0, 100.0, 64.0)
const GROUND_SURFACE_Y := -1.0
const PLAYER_CENTER_Y := 0.0
const OVERHEAD_Y := 4.0
const CRAWL_ROOF_Y := 0.5
const WORLD_COLLISION_LAYER := 1
const VISION_BLOCKER_LAYER := 1 << 4
const SOUND_BLOCKER_LAYER := 1 << 5
const GEOMETRY_COLLISION_LAYERS := WORLD_COLLISION_LAYER | VISION_BLOCKER_LAYER | SOUND_BLOCKER_LAYER
const MISSION_TRIGGER_LAYER := 1 << 14
const UNIT_EPSILON := 0.001
const ROUTE_CLEARANCE_HEIGHT := 0.2
const ROUTE_SUPPORT_RAY_LENGTH := 2.0
const NAVIGATION_Y_TOLERANCE := 1.25

const REQUIRED_ROUTE_IDS: Array[StringName] = [&"A_ground", &"B_overhead", &"C_crawlspace"]
const REQUIRED_AREAS: Array[StringName] = [
	&"outer_perimeter",
	&"garden",
	&"main_house_first_floor",
	&"overhead",
	&"crawlspace",
]
const REQUIRED_FLOOR_MATERIALS: Array[StringName] = [
	&"world",
	&"gravel",
	&"wood",
	&"creaky_wood",
	&"tatami",
	&"soil",
	&"shallow_water",
]
const OUTDOOR_LIGHT_COUNT := 6
const OUTDOOR_EXTINGUISHABLE_LIGHT_COUNT := 4
const INDOOR_LIGHT_COUNT := 3
const REQUIRED_HIDE_SPOT_COUNT := 10
const REQUIRED_CLIMB_EDGE_COUNT := 4
const REQUIRED_BEAM_PATH_COUNT := 2
const REQUIRED_CRAWL_ENTRANCE_COUNT := 3
const REQUIRED_WATER_VOLUME_COUNT := 2
const REQUIRED_SEARCH_POINT_COUNT := 12
const REQUIRED_CHECKPOINT_COUNT := 3
const REQUIRED_ANOMALY_MARKER_COUNT := 4

const ROUTE_WAYPOINTS: Dictionary = {
	&"A_ground": [
		Vector3(8.0, PLAYER_CENTER_Y, 8.0),
		Vector3(20.0, PLAYER_CENTER_Y, 8.0),
		Vector3(32.0, PLAYER_CENTER_Y, 17.0),
		Vector3(46.0, PLAYER_CENTER_Y, 17.0),
		Vector3(58.0, PLAYER_CENTER_Y, 19.0),
	],
	&"B_overhead": [
		Vector3(12.0, OVERHEAD_Y, 2.0),
		Vector3(40.0, OVERHEAD_Y, 8.0),
		Vector3(58.0, OVERHEAD_Y, 19.0),
	],
	&"C_crawlspace": [
		Vector3(84.0, PLAYER_CENTER_Y, 52.0),
		Vector3(78.0, PLAYER_CENTER_Y, 44.0),
		Vector3(70.0, PLAYER_CENTER_Y, 37.0),
		Vector3(58.0, PLAYER_CENTER_Y, 20.0),
	],
}

const OBSERVATION_POINTS: Dictionary = {
	&"outer_perimeter": [Vector3(6.0, PLAYER_CENTER_Y, 8.0), Vector3(50.0, PLAYER_CENTER_Y, 2.0)],
	&"garden": [Vector3(24.0, PLAYER_CENTER_Y, 10.0), Vector3(40.0, PLAYER_CENTER_Y, 26.0)],
	&"main_house_first_floor": [Vector3(34.0, PLAYER_CENTER_Y, 17.0), Vector3(48.0, PLAYER_CENTER_Y, 23.0)],
	&"overhead": [Vector3(20.0, OVERHEAD_Y, 4.0), Vector3(52.0, OVERHEAD_Y, 14.0)],
	&"crawlspace": [Vector3(78.0, PLAYER_CENTER_Y, 44.0), Vector3(64.0, PLAYER_CENTER_Y, 24.0)],
}

const RE_STEALTH_ROUTES: Dictionary = {
	&"outer_perimeter": [Vector3(8.0, PLAYER_CENTER_Y, 8.0), Vector3(4.0, PLAYER_CENTER_Y, 14.0), Vector3(16.0, PLAYER_CENTER_Y, 24.0)],
	&"garden": [Vector3(24.0, PLAYER_CENTER_Y, 10.0), Vector3(16.0, PLAYER_CENTER_Y, 22.0), Vector3(34.0, PLAYER_CENTER_Y, 26.0)],
	&"main_house_first_floor": [Vector3(48.0, PLAYER_CENTER_Y, 23.0), Vector3(42.0, PLAYER_CENTER_Y, 17.0), Vector3(34.0, PLAYER_CENTER_Y, 17.0)],
	&"overhead": [Vector3(52.0, OVERHEAD_Y, 14.0), Vector3(66.0, OVERHEAD_Y, 8.0), Vector3(76.0, OVERHEAD_Y, 4.0)],
	&"crawlspace": [Vector3(64.0, PLAYER_CENTER_Y, 24.0), Vector3(72.0, PLAYER_CENTER_Y, 35.0), Vector3(78.0, PLAYER_CENTER_Y, 44.0)],
}

const MATERIAL_COLORS: Dictionary = {
	&"world": Color(0.18, 0.20, 0.22),
	&"gravel": Color(0.30, 0.32, 0.34),
	&"wood": Color(0.43, 0.24, 0.12),
	&"creaky_wood": Color(0.28, 0.15, 0.08),
	&"tatami": Color(0.62, 0.55, 0.35),
	&"soil": Color(0.24, 0.17, 0.11),
	&"shallow_water": Color(0.10, 0.42, 0.52),
	&"wall": Color(0.27, 0.29, 0.31),
	&"roof": Color(0.20, 0.12, 0.08),
	&"marker": Color(0.20, 0.85, 0.35),
}

var _layout_built := false
var _materials: Dictionary = {}


func _enter_tree() -> void:
	_build_layout_if_needed()
	if not is_in_group(&"level_grayboxes"):
		add_to_group(&"level_grayboxes")


func _ready() -> void:
	_build_layout_if_needed()
	_update_editor_state()


func route_waypoints(route_id: StringName) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for value: Variant in ROUTE_WAYPOINTS.get(route_id, []):
		if value is Vector3:
			result.append(value as Vector3)
	return result


func observation_points(area_id: StringName) -> Array[Vector3]:
	return _vector_array_for(OBSERVATION_POINTS.get(area_id, []))


func re_stealth_route(area_id: StringName) -> Array[Vector3]:
	return _vector_array_for(RE_STEALTH_ROUTES.get(area_id, []))


func route_is_traversable(route_id: StringName) -> bool:
	var points := route_waypoints(route_id)
	if points.size() < 2:
		return false
	var total_length := 0.0
	for point: Vector3 in points:
		if not _is_map_position(point):
			return false
	for index: int in range(1, points.size()):
		var segment_length := points[index - 1].distance_to(points[index])
		if not is_finite(segment_length) or segment_length <= UNIT_EPSILON:
			return false
		total_length += segment_length
	if not is_finite(total_length) or total_length <= 1.0 or total_length > 200.0:
		return false
	# Editor-time validation may run before a World3D exists. Runtime/CI
	# validation additionally checks physical support, segment clearance, and
	# coverage by the authored navigation layer.
	if is_inside_tree() and get_world_3d() != null:
		return (
			_route_points_have_support(points)
			and _route_segments_are_clear(points, route_id)
			and _route_navigation_covers(points, route_id)
		)
	return true


func route_layer(route_id: StringName) -> StringName:
	match route_id:
		&"A_ground":
			return &"ground"
		&"B_overhead":
			return &"overhead"
		&"C_crawlspace":
			return &"crawlspace"
	return &""


func floor_materials() -> Array[StringName]:
	var authored: Array[StringName] = []
	for node: Node in find_children("*", "StaticBody3D", true, false):
		var material: Variant = node.get_meta(&"floor_material", &"")
		if material is StringName and not material.is_empty() and not authored.has(material):
			authored.append(material as StringName)
	var materials: Array[StringName] = []
	for required: StringName in REQUIRED_FLOOR_MATERIALS:
		if authored.has(required):
			materials.append(required)
	for material: StringName in authored:
		if not materials.has(material):
			materials.append(material)
	return materials


func light_counts() -> Dictionary:
	var outdoor := 0
	var outdoor_extinguishable := 0
	var indoor := 0
	for node: Node in find_children("*", "Area3D", true, false):
		if not node is LightSource:
			continue
		var light := node as LightSource
		var indoor_flag: Variant = light.get_meta(&"indoor", false)
		if bool(indoor_flag):
			indoor += 1
		else:
			outdoor += 1
			if bool(light.get_meta(&"extinguishable", false)):
				outdoor_extinguishable += 1
	return {
		&"outdoor": outdoor,
		&"outdoor_extinguishable": outdoor_extinguishable,
		&"indoor": indoor,
	}


func marker_counts() -> Dictionary:
	var counts := {
		&"hide_spots": 0,
		&"climb_edges": 0,
		&"beam_paths": 0,
		&"crawl_entrances": 0,
		&"water_volumes": 0,
		&"search_points": 0,
		&"checkpoints": 0,
		&"anomaly_markers": 0,
	}
	for node: Node in find_children("*", "Node", true, false):
		if node.is_in_group(&"hide_spots"):
			counts[&"hide_spots"] += 1
		if node.is_in_group(&"climb_edges"):
			counts[&"climb_edges"] += 1
		if node.is_in_group(&"beam_paths"):
			counts[&"beam_paths"] += 1
		if node.is_in_group(&"crawl_entrances"):
			counts[&"crawl_entrances"] += 1
		if node.is_in_group(&"water_volumes"):
			counts[&"water_volumes"] += 1
		if node.is_in_group(&"search_points"):
			counts[&"search_points"] += 1
		if node.is_in_group(&"checkpoint_areas"):
			counts[&"checkpoints"] += 1
		if node.is_in_group(&"anomaly_markers"):
			counts[&"anomaly_markers"] += 1
	return counts


func navigation_regions() -> Array[NavigationRegion3D]:
	var result: Array[NavigationRegion3D] = []
	for node: Node in find_children("*", "NavigationRegion3D", true, false):
		result.append(node as NavigationRegion3D)
	return result


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if not _layout_built:
		errors.append("Samurai Residence layout has not been built.")
	for route_id: StringName in REQUIRED_ROUTE_IDS:
		if not route_is_traversable(route_id):
			errors.append("Route %s is not a bounded traversable route." % [route_id])
	for area_id: StringName in REQUIRED_AREAS:
		if observation_points(area_id).is_empty():
			errors.append("Area %s has no observation point." % [area_id])
		if re_stealth_route(area_id).size() < 2:
			errors.append("Area %s has no re-stealth route." % [area_id])
	for material: StringName in REQUIRED_FLOOR_MATERIALS:
		if not floor_materials().has(material):
			errors.append("Residence floor material %s is not authored." % [material])
	var counts := marker_counts()
	if int(counts[&"hide_spots"]) < REQUIRED_HIDE_SPOT_COUNT:
		errors.append("Residence requires at least %d HideSpot markers." % REQUIRED_HIDE_SPOT_COUNT)
	if int(counts[&"climb_edges"]) < REQUIRED_CLIMB_EDGE_COUNT:
		errors.append("Residence requires four ClimbEdge markers.")
	if int(counts[&"beam_paths"]) < REQUIRED_BEAM_PATH_COUNT:
		errors.append("Residence requires two BeamPath markers.")
	if int(counts[&"crawl_entrances"]) < REQUIRED_CRAWL_ENTRANCE_COUNT:
		errors.append("Residence requires three CrawlEntrance markers.")
	if int(counts[&"water_volumes"]) < REQUIRED_WATER_VOLUME_COUNT:
		errors.append("Residence requires W1 and W2 water volumes.")
	if int(counts[&"search_points"]) < REQUIRED_SEARCH_POINT_COUNT:
		errors.append("Residence requires twelve SearchPoint markers.")
	if int(counts[&"checkpoints"]) < REQUIRED_CHECKPOINT_COUNT:
		errors.append("Residence requires three CheckpointArea markers.")
	if int(counts[&"anomaly_markers"]) < REQUIRED_ANOMALY_MARKER_COUNT:
		errors.append("Residence requires four AnomalyMarker markers.")
	var lights := light_counts()
	if int(lights[&"outdoor"]) != OUTDOOR_LIGHT_COUNT:
		errors.append("Residence must place exactly six outdoor lights.")
	if int(lights[&"outdoor_extinguishable"]) != OUTDOOR_EXTINGUISHABLE_LIGHT_COUNT:
		errors.append("Residence outdoor lights must have a 4/6 extinguishable ratio.")
	if int(lights[&"indoor"]) != INDOOR_LIGHT_COUNT:
		errors.append("Residence must place three indoor extinguishable lights.")
	for region: NavigationRegion3D in navigation_regions():
		if not region.enabled or region.navigation_mesh == null:
			errors.append("All residence layers require an enabled NavigationMesh.")
	for node: Node in find_children("*", "Area3D", true, false):
		if node is ClimbEdge and not (node as ClimbEdge).is_geometry_valid():
			errors.append("Invalid ClimbEdge marker: %s" % [node.name])
		if node is BeamPath and not (node as BeamPath).is_geometry_valid():
			errors.append("Invalid BeamPath marker: %s" % [node.name])
		if node is CrawlEntrance and not (node as CrawlEntrance).is_geometry_valid():
			errors.append("Invalid CrawlEntrance marker: %s" % [node.name])
		if node is HideSpot and not (node as HideSpot).is_geometry_valid():
			errors.append("Invalid HideSpot marker: %s" % [node.name])
		if node is WaterVolume and not (node as WaterVolume).is_geometry_valid():
			errors.append("Invalid WaterVolume marker: %s" % [node.name])
	return errors


func is_contract_valid() -> bool:
	return validation_errors().is_empty()


func _build_layout_if_needed() -> void:
	if _layout_built:
		return
	if get_node_or_null(^"Geometry") != null:
		_layout_built = true
		return
	_layout_built = true
	_build_geometry()
	_build_navigation()
	_build_routes()
	_build_area_markers()
	_build_spawn_and_enemy_markers()
	_build_lights()


func _build_geometry() -> void:
	var geometry := Node3D.new()
	geometry.name = &"Geometry"
	add_child(geometry)
	var outer := _new_layer(geometry, &"OuterPerimeter")
	var garden := _new_layer(geometry, &"Garden")
	var house := _new_layer(geometry, &"MainHouseFirstFloor")
	var overhead := _new_layer(geometry, &"Overhead")
	var crawlspace := _new_layer(geometry, &"Crawlspace")

	_add_box(outer, &"GroundSupport", Vector3(50.0, -1.1, 32.0), Vector3(100.0, 0.2, 64.0), &"world", &"world")
	_add_box(outer, &"NorthPerimeterWall", Vector3(50.0, 0.5, 0.0), Vector3(100.0, 3.0, 0.4), &"", &"wall")
	_add_box(outer, &"SouthPerimeterWall", Vector3(50.0, 0.5, 64.0), Vector3(100.0, 3.0, 0.4), &"", &"wall")
	_add_box(outer, &"EastPerimeterWall", Vector3(100.0, 0.5, 32.0), Vector3(0.4, 3.0, 64.0), &"", &"wall")
	_add_box(outer, &"WestPerimeterWall", Vector3(0.0, 0.5, 32.0), Vector3(0.4, 3.0, 64.0), &"", &"wall")
	_add_box(outer, &"CollapsedNorthWall", Vector3(12.0, 0.5, 0.0), Vector3(12.0, 1.2, 0.4), &"", &"wall")

	_add_box(garden, &"GardenGravel", Vector3(50.0, -0.9, 28.0), Vector3(86.0, 0.2, 42.0), &"gravel", &"gravel")
	_add_box(garden, &"GardenSoil", Vector3(18.0, -0.78, 40.0), Vector3(20.0, 0.2, 12.0), &"soil", &"soil")
	_add_box(garden, &"GardenSteppingStones", Vector3(37.0, -0.72, 20.0), Vector3(26.0, 0.2, 1.4), &"wood", &"wood")
	_add_box(garden, &"PoolBed", Vector3(22.0, -0.70, 13.0), Vector3(16.0, 0.2, 9.0), &"shallow_water", &"shallow_water")

	_add_box(house, &"MainHouseFloor", Vector3(58.0, -0.9, 19.0), Vector3(30.0, 0.2, 20.0), &"tatami", &"tatami")
	_add_box(house, &"SouthVeranda", Vector3(40.0, -0.78, 17.0), Vector3(26.0, 0.2, 3.0), &"wood", &"wood")
	_add_box(house, &"CreakyCorridor", Vector3(51.0, -0.68, 17.0), Vector3(12.0, 0.2, 2.0), &"creaky_wood", &"creaky_wood")
	_add_box(house, &"NorthHouseWall", Vector3(58.0, 0.5, 9.0), Vector3(30.0, 3.0, 0.4), &"", &"wall")
	_add_box(house, &"EastHouseWall", Vector3(73.0, 0.5, 19.0), Vector3(0.4, 3.0, 20.0), &"", &"wall")
	# Leave the south-veranda opening clear so Route A can enter the house.
	_add_box(house, &"WestHouseWallNorth", Vector3(43.0, 0.5, 12.0), Vector3(0.4, 3.0, 6.0), &"", &"wall")
	_add_box(house, &"WestHouseWallSouth", Vector3(43.0, 0.5, 24.0), Vector3(0.4, 3.0, 10.0), &"", &"wall")
	_add_box(house, &"ShoinNorthWall", Vector3(58.0, 0.5, 29.0), Vector3(30.0, 3.0, 0.4), &"", &"wall")
	_add_box(house, &"ShoinGapFloor", Vector3(58.0, -0.58, 19.8), Vector3(5.0, 0.15, 0.8), &"creaky_wood", &"creaky_wood")

	_add_box(overhead, &"OuterRoofPlatform", Vector3(26.0, 3.9, 5.0), Vector3(32.0, 0.2, 3.0), &"wood", &"roof")
	_add_box(overhead, &"HouseRoofPlatform", Vector3(58.0, 3.9, 19.0), Vector3(30.0, 0.2, 20.0), &"wood", &"roof")
	_add_box(overhead, &"ShoinBeamSupport", Vector3(58.0, 3.7, 19.0), Vector3(4.0, 0.2, 16.0), &"creaky_wood", &"roof")

	_add_box(crawlspace, &"CrawlSoilFloor", Vector3(70.0, -0.92, 38.0), Vector3(24.0, 0.2, 8.0), &"soil", &"soil")
	_add_box(crawlspace, &"CrawlRoof", Vector3(70.0, CRAWL_ROOF_Y, 38.0), Vector3(24.0, 0.4, 8.0), &"", &"wall")
	# Extend the crawl layer beneath the house to the shoin gap at (58, 20).
	_add_box(crawlspace, &"CrawlUnderHouseFloor", Vector3(69.0, -0.92, 26.0), Vector3(26.0, 0.2, 20.0), &"soil", &"soil")
	_add_box(crawlspace, &"CrawlUnderHouseRoof", Vector3(69.0, CRAWL_ROOF_Y, 26.0), Vector3(26.0, 0.4, 20.0), &"", &"wall")
	# Bridge the C route's W2 waterway start into the crawl layer with bounded
	# collision and crawl clearance rather than a marker-only transition.
	_add_box(crawlspace, &"CrawlWaterEntryFloor", Vector3(80.0, -0.92, 48.0), Vector3(8.0, 0.2, 12.0), &"soil", &"soil")
	_add_box(crawlspace, &"CrawlWaterEntryRoof", Vector3(80.0, CRAWL_ROOF_Y, 48.0), Vector3(8.0, 0.4, 12.0), &"", &"wall")
	_add_box(crawlspace, &"CreakySupportOne", Vector3(66.0, -0.70, 36.0), Vector3(2.0, 0.2, 0.8), &"creaky_wood", &"creaky_wood")
	_add_box(crawlspace, &"CreakySupportTwo", Vector3(70.0, -0.70, 38.0), Vector3(2.0, 0.2, 0.8), &"creaky_wood", &"creaky_wood")
	_add_box(crawlspace, &"CreakySupportThree", Vector3(74.0, -0.70, 40.0), Vector3(2.0, 0.2, 0.8), &"creaky_wood", &"creaky_wood")


func _build_navigation() -> void:
	var navigation := Node3D.new()
	navigation.name = &"Navigation"
	add_child(navigation)
	# Keep the enemy ground mesh out of the solid house and perimeter walls. The
	# narrow west-wall bridge is the authored south-veranda opening used by A.
	var ground_vertices := PackedVector3Array([
		Vector3(1.0, GROUND_SURFACE_Y, 1.0), Vector3(99.0, GROUND_SURFACE_Y, 1.0),
		Vector3(99.0, GROUND_SURFACE_Y, 9.0), Vector3(1.0, GROUND_SURFACE_Y, 9.0),
		Vector3(1.0, GROUND_SURFACE_Y, 29.0), Vector3(99.0, GROUND_SURFACE_Y, 29.0),
		Vector3(99.0, GROUND_SURFACE_Y, 63.0), Vector3(1.0, GROUND_SURFACE_Y, 63.0),
		Vector3(1.0, GROUND_SURFACE_Y, 9.0), Vector3(42.8, GROUND_SURFACE_Y, 9.0),
		Vector3(42.8, GROUND_SURFACE_Y, 15.5), Vector3(1.0, GROUND_SURFACE_Y, 15.5),
		Vector3(1.0, GROUND_SURFACE_Y, 15.5), Vector3(42.8, GROUND_SURFACE_Y, 15.5),
		Vector3(42.8, GROUND_SURFACE_Y, 18.5), Vector3(1.0, GROUND_SURFACE_Y, 18.5),
		Vector3(1.0, GROUND_SURFACE_Y, 18.5), Vector3(42.8, GROUND_SURFACE_Y, 18.5),
		Vector3(42.8, GROUND_SURFACE_Y, 29.0), Vector3(1.0, GROUND_SURFACE_Y, 29.0),
		Vector3(42.8, GROUND_SURFACE_Y, 15.5), Vector3(43.2, GROUND_SURFACE_Y, 15.5),
		Vector3(43.2, GROUND_SURFACE_Y, 18.5), Vector3(42.8, GROUND_SURFACE_Y, 18.5),
		Vector3(43.2, GROUND_SURFACE_Y, 9.2), Vector3(72.8, GROUND_SURFACE_Y, 9.2),
		Vector3(72.8, GROUND_SURFACE_Y, 15.5), Vector3(43.2, GROUND_SURFACE_Y, 15.5),
		Vector3(43.2, GROUND_SURFACE_Y, 15.5), Vector3(72.8, GROUND_SURFACE_Y, 15.5),
		Vector3(72.8, GROUND_SURFACE_Y, 18.5), Vector3(43.2, GROUND_SURFACE_Y, 18.5),
		Vector3(43.2, GROUND_SURFACE_Y, 18.5), Vector3(72.8, GROUND_SURFACE_Y, 18.5),
		Vector3(72.8, GROUND_SURFACE_Y, 28.8), Vector3(43.2, GROUND_SURFACE_Y, 28.8),
		Vector3(73.2, GROUND_SURFACE_Y, 9.0), Vector3(99.0, GROUND_SURFACE_Y, 9.0),
		Vector3(99.0, GROUND_SURFACE_Y, 29.0), Vector3(73.2, GROUND_SURFACE_Y, 29.0),
	])
	var ground_polygons: Array[PackedInt32Array] = [
		PackedInt32Array([0, 1, 2, 3]),
		PackedInt32Array([4, 5, 6, 7]),
		PackedInt32Array([8, 9, 10, 11]),
		PackedInt32Array([12, 13, 14, 15]),
		PackedInt32Array([16, 17, 18, 19]),
		PackedInt32Array([20, 21, 22, 23]),
		PackedInt32Array([24, 25, 26, 27]),
		PackedInt32Array([28, 29, 30, 31]),
		PackedInt32Array([32, 33, 34, 35]),
		PackedInt32Array([36, 37, 38, 39]),
	]
	_add_navigation_region_with_polygons(navigation, &"GroundNavigation", ground_vertices, ground_polygons)
	_add_navigation_region(navigation, &"OverheadNavigation", PackedVector3Array([
		Vector3(10.0, OVERHEAD_Y, 1.0), Vector3(76.0, OVERHEAD_Y, 1.0),
		Vector3(76.0, OVERHEAD_Y, 22.0), Vector3(10.0, OVERHEAD_Y, 22.0),
	]))
	_add_navigation_region(navigation, &"CrawlspaceNavigation", PackedVector3Array([
		Vector3(56.0, GROUND_SURFACE_Y, 16.0), Vector3(84.0, GROUND_SURFACE_Y, 16.0),
		Vector3(84.0, GROUND_SURFACE_Y, 54.0), Vector3(56.0, GROUND_SURFACE_Y, 54.0),
	]))


func _build_routes() -> void:
	var markers := _new_marker_root(&"Routes")
	for route_id: StringName in REQUIRED_ROUTE_IDS:
		var route := Node3D.new()
		route.name = route_id
		route.set_meta(&"route_id", route_id)
		route.set_meta(&"layer", route_layer(route_id))
		route.set_meta(&"traversable", true)
		route.add_to_group(&"route_paths")
		markers.add_child(route)
		var index := 0
		for point: Vector3 in route_waypoints(route_id):
			var waypoint := Marker3D.new()
			waypoint.name = "Waypoint%02d" % index
			waypoint.position = point
			waypoint.set_meta(&"route_id", route_id)
			waypoint.set_meta(&"waypoint_index", index)
			waypoint.add_to_group(&"route_waypoints")
			route.add_child(waypoint)
			index += 1

	var climb_edges := _new_marker_root(&"ClimbEdges")
	var beam_paths := _new_marker_root(&"BeamPaths")
	_add_overhead_segment(
		climb_edges,
		beam_paths,
		&"C1_NorthWallEntry",
		&"C1_NorthRoofExit",
		&"B_Overhead_North",
		Vector3(12.0, PLAYER_CENTER_Y, 2.0),
		Vector3(40.0, OVERHEAD_Y, 8.0),
		Vector3(28.0, 0.0, 6.0),
	)
	_add_overhead_segment(
		climb_edges,
		beam_paths,
		&"C2_VerandaRoofEntry",
		&"C2_ShoinBeamExit",
		&"B_Overhead_Shoin",
		Vector3(40.0, PLAYER_CENTER_Y, 8.0),
		Vector3(58.0, OVERHEAD_Y, 19.0),
		Vector3(18.0, 0.0, 11.0),
	)

	var crawl_entrances := _new_marker_root(&"CrawlEntrances")
	# Keep the crawl capsule's lower extent above the authored floor at the inside endpoint.
	_add_crawl_entrance(crawl_entrances, &"U1_WestWaterEntry", Vector3(78.0, PLAYER_CENTER_Y, 44.0), Vector3(0.0, 0.1, -3.0))
	_add_crawl_entrance(crawl_entrances, &"U2_VerandaEntry", Vector3(36.0, PLAYER_CENTER_Y, 18.0), Vector3(0.0, 0.1, 2.5))
	_add_crawl_entrance(crawl_entrances, &"U3_LatrineEntry", Vector3(68.0, PLAYER_CENTER_Y, 25.0), Vector3(-2.5, 0.1, 0.0))

	var water := _new_marker_root(&"Water")
	_add_water_volume(water, &"W1_Pond", Vector3(22.0, 0.0, 13.0), Vector3(16.0, 4.0, 9.0))
	_add_water_volume(water, &"W2_WestWaterway", Vector3(84.0, 0.0, 52.0), Vector3(12.0, 4.0, 12.0))


func _build_area_markers() -> void:
	var observation_root := _new_marker_root(&"Observation")
	var re_stealth_root := _new_marker_root(&"ReStealth")
	for area_id: StringName in REQUIRED_AREAS:
		var area_name := _area_node_name(area_id)
		var observation_area := Node3D.new()
		observation_area.name = area_name
		observation_area.set_meta(&"area_id", area_id)
		observation_area.add_to_group(&"observation_areas")
		observation_root.add_child(observation_area)
		var observation_index := 0
		for point: Vector3 in observation_points(area_id):
			var marker := _add_marker(observation_area, "Observation%02d" % observation_index, point, area_id, &"observation")
			marker.add_to_group(&"observation_points")
			observation_index += 1

		var re_stealth_area := Node3D.new()
		re_stealth_area.name = area_name
		re_stealth_area.set_meta(&"area_id", area_id)
		re_stealth_area.add_to_group(&"re_stealth_areas")
		re_stealth_root.add_child(re_stealth_area)
		var re_stealth_index := 0
		for point: Vector3 in re_stealth_route(area_id):
			var marker := _add_marker(re_stealth_area, "Escape%02d" % re_stealth_index, point, area_id, &"re_stealth")
			marker.add_to_group(&"re_stealth_routes")
			re_stealth_index += 1

	var hide_spots := _new_marker_root(&"HideSpots")
	var hide_positions := [
		Vector3(6.0, PLAYER_CENTER_Y, 8.0), Vector3(24.0, PLAYER_CENTER_Y, 10.0),
		Vector3(40.0, PLAYER_CENTER_Y, 25.0), Vector3(66.0, PLAYER_CENTER_Y, 25.0),
		Vector3(80.0, PLAYER_CENTER_Y, 14.0), Vector3(48.0, PLAYER_CENTER_Y, 13.0),
		Vector3(64.0, PLAYER_CENTER_Y, 13.0), Vector3(70.0, PLAYER_CENTER_Y, 37.0),
		Vector3(76.0, PLAYER_CENTER_Y, 37.0), Vector3(64.0, PLAYER_CENTER_Y, 24.0),
	]
	for index: int in hide_positions.size():
		var hide := HideSpot.new()
		hide.name = "HideSpot%02d" % (index + 1)
		hide.position = hide_positions[index]
		hide.entry_radius = 0.75
		hide.set_meta(&"area_id", _area_for_position(hide_positions[index]))
		hide.add_to_group(&"hide_spots")
		hide_positions[index] # Keep the source-of-truth position adjacent to the marker.
		hide_spots.add_child(hide)

	var search_points := _new_marker_root(&"SearchPoints")
	var search_positions := [
		Vector3(10.0, PLAYER_CENTER_Y, 5.0), Vector3(30.0, PLAYER_CENTER_Y, 5.0),
		Vector3(18.0, PLAYER_CENTER_Y, 18.0), Vector3(36.0, PLAYER_CENTER_Y, 28.0),
		Vector3(48.0, PLAYER_CENTER_Y, 17.0), Vector3(56.0, PLAYER_CENTER_Y, 24.0),
		Vector3(68.0, PLAYER_CENTER_Y, 17.0), Vector3(70.0, PLAYER_CENTER_Y, 27.0),
		Vector3(18.0, OVERHEAD_Y, 5.0), Vector3(46.0, OVERHEAD_Y, 9.0),
		Vector3(64.0, OVERHEAD_Y, 15.0), Vector3(70.0, PLAYER_CENTER_Y, 38.0),
	]
	for index: int in search_positions.size():
		var marker := _add_marker(search_points, "SearchPoint%02d" % (index + 1), search_positions[index], _area_for_position(search_positions[index]), &"search")
		marker.add_to_group(&"search_points")

	var checkpoints := _new_marker_root(&"Checkpoints")
	_add_checkpoint(checkpoints, &"CheckpointInsidePerimeter", Vector3(16.0, PLAYER_CENTER_Y, 24.0), &"perimeter_reached")
	_add_checkpoint(checkpoints, &"CheckpointMainHouse", Vector3(40.0, PLAYER_CENTER_Y, 17.0), &"house_reached")
	_add_checkpoint(checkpoints, &"CheckpointTarget", Vector3(58.0, PLAYER_CENTER_Y, 19.0), &"assassination_complete")

	var anomaly_markers := _new_marker_root(&"AnomalyMarkers")
	_add_marker(anomaly_markers, &"AnomalyShutter01", Vector3(46.0, PLAYER_CENTER_Y, 17.0), &"main_house_first_floor", &"door")
	_add_marker(anomaly_markers, &"AnomalyShutter02", Vector3(50.0, PLAYER_CENTER_Y, 17.0), &"main_house_first_floor", &"door")
	_add_marker(anomaly_markers, &"AnomalyFusuma01", Vector3(52.0, PLAYER_CENTER_Y, 13.0), &"main_house_first_floor", &"door")
	_add_marker(anomaly_markers, &"AnomalyFusuma02", Vector3(64.0, PLAYER_CENTER_Y, 13.0), &"main_house_first_floor", &"door")
	for marker: Node in anomaly_markers.get_children():
		marker.add_to_group(&"anomaly_markers")


func _build_spawn_and_enemy_markers() -> void:
	var spawns := _new_marker_root(&"SpawnPoints")
	_add_marker(spawns, &"PlayerSpawn", Vector3(8.0, PLAYER_CENTER_Y, 8.0), &"outer_perimeter", &"player")
	_add_marker(spawns, &"RouteAStart", Vector3(8.0, PLAYER_CENTER_Y, 8.0), &"outer_perimeter", &"route_a")
	_add_marker(spawns, &"RouteBStart", Vector3(12.0, OVERHEAD_Y, 2.0), &"overhead", &"route_b")
	_add_marker(spawns, &"RouteCStart", Vector3(84.0, PLAYER_CENTER_Y, 52.0), &"crawlspace", &"route_c")
	_add_marker(spawns, &"TargetSpawn", Vector3(58.0, PLAYER_CENTER_Y, 19.0), &"main_house_first_floor", &"target")
	for marker: Node in spawns.get_children():
		marker.add_to_group(&"spawn_points")

	var enemies := _new_marker_root(&"EnemySpawns")
	var enemy_data := [
		[&"E1_GateGuard", Vector3(32.0, PLAYER_CENTER_Y, 50.0), &"sentry"],
		[&"E2_GateGuard", Vector3(36.0, PLAYER_CENTER_Y, 50.0), &"sentry"],
		[&"E3_GardenPatrol", Vector3(20.0, PLAYER_CENTER_Y, 8.0), &"patrol"],
		[&"E4_GardenPatrol", Vector3(56.0, PLAYER_CENTER_Y, 22.0), &"patrol"],
		[&"E5_LanternBearer", Vector3(48.0, PLAYER_CENTER_Y, 16.0), &"lantern_bearer"],
		[&"E6_VerandaSentry", Vector3(34.0, PLAYER_CENTER_Y, 17.0), &"sentry"],
		[&"E7_CorridorPatrol", Vector3(66.0, PLAYER_CENTER_Y, 17.0), &"patrol"],
		[&"E8_RoomRest", Vector3(52.0, PLAYER_CENTER_Y, 13.0), &"routine_stop"],
		[&"G1_TargetGuard", Vector3(56.0, PLAYER_CENTER_Y, 19.0), &"escort"],
		[&"G2_TargetGuard", Vector3(60.0, PLAYER_CENTER_Y, 19.0), &"escort"],
		[&"TGT_Toyama", Vector3(58.0, PLAYER_CENTER_Y, 19.0), &"target"],
	]
	for entry: Array in enemy_data:
		var marker := _add_marker(enemies, entry[0], entry[1], _area_for_position(entry[1]), entry[2])
		marker.add_to_group(&"enemy_spawn_points")
		marker.set_meta(&"routine_cycle_seconds", 360.0 if entry[2] == &"target" else 90.0)


func _build_lights() -> void:
	var lights := _new_marker_root(&"Lights")
	var outdoor := [
		[&"L1_LanternNorth", Vector3(24.0, 0.0, 10.0), true],
		[&"L2_LanternGarden", Vector3(36.0, 0.0, 20.0), true],
		[&"L3_LanternSouth", Vector3(52.0, 0.0, 22.0), true],
		[&"L4_LanternEast", Vector3(70.0, 0.0, 12.0), true],
		[&"L5_GateBonfireWest", Vector3(30.0, 0.0, 52.0), false],
		[&"L6_GateBonfireEast", Vector3(38.0, 0.0, 52.0), false],
	]
	for entry: Array in outdoor:
		_add_light(lights, entry[0], entry[1], false, bool(entry[2]), 6.0 if entry[2] else 9.0)
	var indoor := [
		[&"L8_HallLantern", Vector3(48.0, 0.0, 17.0)],
		[&"L9_ShoinLantern", Vector3(56.0, 0.0, 13.0)],
		[&"L10_LatrineLantern", Vector3(66.0, 0.0, 19.0)],
	]
	for entry: Array in indoor:
		_add_light(lights, entry[0], entry[1], true, true, 4.0)


func _add_overhead_segment(
	climb_edges: Node3D,
	beam_paths: Node3D,
	entry_name: StringName,
	exit_name: StringName,
	beam_name: StringName,
	entry_bottom: Vector3,
	exit_position: Vector3,
	local_end: Vector3,
) -> void:
	var entry := ClimbEdge.new()
	entry.name = entry_name
	entry.position = entry_bottom
	entry.top_offset = Vector3(0.0, OVERHEAD_Y, 0.0)
	entry.entry_radius = 1.0
	entry.connected_beam_path = NodePath("../../BeamPaths/%s" % beam_name)
	entry.connected_beam_endpoint = 0
	climb_edges.add_child(entry)

	var exit := ClimbEdge.new()
	exit.name = exit_name
	exit.position = exit_position - Vector3.UP * OVERHEAD_Y
	exit.top_offset = Vector3(0.0, OVERHEAD_Y, 0.0)
	exit.entry_radius = 1.0
	exit.connected_beam_path = NodePath("../../BeamPaths/%s" % beam_name)
	exit.connected_beam_endpoint = 1
	climb_edges.add_child(exit)

	var beam := BeamPath.new()
	beam.name = beam_name
	beam.position = entry_bottom + Vector3.UP * OVERHEAD_Y
	var curve := Curve3D.new()
	curve.bake_interval = 0.25
	curve.add_point(Vector3.ZERO)
	curve.add_point(local_end)
	beam.path_curve = curve
	beam.start_climb_edge = NodePath("../../ClimbEdges/%s" % entry_name)
	beam.end_climb_edge = NodePath("../../ClimbEdges/%s" % exit_name)
	beam_paths.add_child(beam)


func _add_crawl_entrance(parent: Node3D, marker_name: StringName, position: Vector3, inside_offset: Vector3) -> void:
	var entrance := CrawlEntrance.new()
	entrance.name = marker_name
	entrance.position = position
	entrance.inside_offset = inside_offset
	entrance.entry_radius = 0.75
	entrance.set_meta(&"route_id", &"C_crawlspace")
	parent.add_child(entrance)


func _add_water_volume(parent: Node3D, marker_name: StringName, position: Vector3, volume_size: Vector3) -> void:
	var volume := WaterVolume.new()
	volume.name = marker_name
	volume.position = position
	volume.size = volume_size
	volume.surface_body_depth = 0.75
	volume.underwater_body_depth = 1.5
	parent.add_child(volume)


func _add_light(parent: Node3D, marker_name: StringName, position: Vector3, indoor: bool, extinguishable: bool, radius: float) -> void:
	var light := LightSource.new()
	light.name = marker_name
	light.position = position
	light.gameplay_radius = radius
	light.gameplay_intensity = 1.0
	light.interaction_radius = 1.0
	light.starts_extinguished = false
	light.extinguishable = extinguishable
	light.set_meta(&"indoor", indoor)
	light.set_meta(&"extinguishable", extinguishable)
	light.set_meta(&"rain_fragile", extinguishable)
	light.set_meta(&"source_id", marker_name)
	var render_light := OmniLight3D.new()
	render_light.omni_range = radius
	render_light.light_energy = 0.6 if indoor else 0.8
	light.render_light = render_light
	light.add_child(render_light)
	parent.add_child(light)


func _add_navigation_region(parent: Node3D, region_name: StringName, vertices: PackedVector3Array) -> void:
	_add_navigation_region_with_polygons(
		parent,
		region_name,
		vertices,
		[PackedInt32Array([0, 1, 2, 3])],
	)


func _add_navigation_region_with_polygons(
	parent: Node3D,
	region_name: StringName,
	vertices: PackedVector3Array,
	polygons: Array[PackedInt32Array],
) -> void:
	var region := NavigationRegion3D.new()
	region.name = region_name
	region.enabled = true
	region.set_meta(&"layer", region_name)
	var navigation_mesh := NavigationMesh.new()
	navigation_mesh.vertices = vertices
	for polygon: PackedInt32Array in polygons:
		navigation_mesh.add_polygon(polygon)
	region.navigation_mesh = navigation_mesh
	parent.add_child(region)


func _route_points_have_support(points: Array[Vector3]) -> bool:
	var world := get_world_3d()
	if world == null:
		return false
	for point: Vector3 in points:
		var query := PhysicsRayQueryParameters3D.create(
			point + Vector3.UP * ROUTE_CLEARANCE_HEIGHT,
			point + Vector3.DOWN * ROUTE_SUPPORT_RAY_LENGTH,
			WORLD_COLLISION_LAYER,
		)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		if world.direct_space_state.intersect_ray(query).is_empty():
			return false
	return true


func _route_segments_are_clear(points: Array[Vector3], route_id: StringName) -> bool:
	var world := get_world_3d()
	if world == null:
		return false
	# Probe above the support plane. Overhead paths use a slightly higher probe
	# so the platform below is not mistaken for a blocker.
	var ray_offset := ROUTE_CLEARANCE_HEIGHT
	if route_layer(route_id) == &"overhead":
		ray_offset = 0.3
	for index: int in range(1, points.size()):
		var query := PhysicsRayQueryParameters3D.create(
			points[index - 1] + Vector3.UP * ray_offset,
			points[index] + Vector3.UP * ray_offset,
			WORLD_COLLISION_LAYER,
		)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		if not world.direct_space_state.intersect_ray(query).is_empty():
			return false
	return true


func _route_navigation_covers(points: Array[Vector3], route_id: StringName) -> bool:
	var expected_name := StringName("%sNavigation" % String(route_layer(route_id)).capitalize())
	for region: NavigationRegion3D in navigation_regions():
		if region.name != expected_name or region.navigation_mesh == null:
			continue
		var vertices: PackedVector3Array = region.navigation_mesh.vertices
		if vertices.size() < 4:
			return false
		var min_x := INF
		var max_x := -INF
		var min_y := INF
		var max_y := -INF
		var min_z := INF
		var max_z := -INF
		for vertex: Vector3 in vertices:
			min_x = minf(min_x, vertex.x)
			max_x = maxf(max_x, vertex.x)
			min_y = minf(min_y, vertex.y)
			max_y = maxf(max_y, vertex.y)
			min_z = minf(min_z, vertex.z)
			max_z = maxf(max_z, vertex.z)
		for point: Vector3 in points:
			if (
				point.x < min_x - UNIT_EPSILON
				or point.x > max_x + UNIT_EPSILON
				or point.y < min_y - NAVIGATION_Y_TOLERANCE
				or point.y > max_y + NAVIGATION_Y_TOLERANCE
				or point.z < min_z - UNIT_EPSILON
				or point.z > max_z + UNIT_EPSILON
			):
				return false
		return true
	return false


func _add_checkpoint(parent: Node3D, marker_name: StringName, position: Vector3, checkpoint_id: StringName) -> void:
	var checkpoint := Area3D.new()
	checkpoint.name = marker_name
	checkpoint.position = position
	checkpoint.collision_layer = MISSION_TRIGGER_LAYER
	checkpoint.collision_mask = 1 << 1
	checkpoint.monitoring = true
	checkpoint.monitorable = true
	checkpoint.set_meta(&"checkpoint_id", checkpoint_id)
	checkpoint.set_meta(&"area_id", _area_for_position(position))
	checkpoint.add_to_group(&"checkpoint_areas")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, 2.0, 3.0)
	shape.shape = box
	checkpoint.add_child(shape)
	parent.add_child(checkpoint)


func _add_marker(parent: Node3D, marker_name: StringName, position: Vector3, area_id: StringName, role: StringName) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = marker_name
	marker.position = position
	marker.set_meta(&"area_id", area_id)
	marker.set_meta(&"role", role)
	return _attach_marker(parent, marker)


func _attach_marker(parent: Node3D, marker: Marker3D) -> Marker3D:
	parent.add_child(marker)
	return marker


func _new_layer(parent: Node3D, layer_name: StringName) -> Node3D:
	var layer := Node3D.new()
	layer.name = layer_name
	layer.set_meta(&"layer_id", layer_name)
	layer.add_to_group(&"residence_layers")
	parent.add_child(layer)
	return layer


func _new_marker_root(root_name: StringName) -> Node3D:
	var markers := get_node_or_null(^"Markers") as Node3D
	if markers == null:
		markers = Node3D.new()
		markers.name = &"Markers"
		add_child(markers)
	var root := Node3D.new()
	root.name = root_name
	markers.add_child(root)
	return root


func _add_box(
	parent: Node3D,
	box_name: StringName,
	position: Vector3,
	size: Vector3,
	floor_material: StringName,
	visual_material: StringName,
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = box_name
	body.position = position
	body.collision_layer = GEOMETRY_COLLISION_LAYERS
	body.collision_mask = 0
	if not floor_material.is_empty():
		body.set_meta(&"floor_material", floor_material)
	body.set_meta(&"graybox_bounds", size)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material_for(visual_material)
	visual.mesh = mesh
	body.add_child(visual)
	parent.add_child(body)
	return body


func _material_for(material_key: StringName) -> StandardMaterial3D:
	if _materials.has(material_key):
		return _materials[material_key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = MATERIAL_COLORS.get(material_key, Color.WHITE)
	material.roughness = 0.9
	if material_key == &"shallow_water":
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color.a = 0.48
	_materials[material_key] = material
	return material


func _vector_array_for(values: Variant) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if not values is Array:
		return result
	for value: Variant in values as Array:
		if value is Vector3:
			result.append(value as Vector3)
	return result


func _is_map_position(position: Vector3) -> bool:
	return (
		is_finite(position.x)
		and is_finite(position.y)
		and is_finite(position.z)
		and MAP_BOUNDS.has_point(Vector2(position.x, position.z))
		and absf(position.y) <= 12.0
	)


func _area_for_position(position: Vector3) -> StringName:
	if position.y >= OVERHEAD_Y - 0.5:
		return &"overhead"
	if position.x >= 43.0 and position.x <= 73.0 and position.z >= 9.0 and position.z <= 29.0:
		return &"main_house_first_floor"
	if position.x >= 58.0 and position.z >= 32.0:
		return &"crawlspace"
	if position.x <= 15.0 or position.z <= 4.0 or position.z >= 50.0:
		return &"outer_perimeter"
	return &"garden"


func _area_node_name(area_id: StringName) -> StringName:
	match area_id:
		&"outer_perimeter":
			return &"OuterPerimeter"
		&"main_house_first_floor":
			return &"MainHouseFirstFloor"
	return StringName(String(area_id).capitalize())


func _get_configuration_warnings() -> PackedStringArray:
	return validation_errors()


func _update_editor_state() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		update_configuration_warnings()
