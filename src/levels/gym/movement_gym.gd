@tool
class_name MovementGym
extends Node3D


const REQUIRED_FLOOR_MATERIALS: Array[StringName] = [
	&"tatami",
	&"wood",
	&"creaky_wood",
	&"gravel",
	&"shallow_water",
]
const BEAM_BAKE_INTERVAL := 0.25
const BEAM_END_OFFSET := Vector3(6.0, 0.0, 0.0)


func _enter_tree() -> void:
	_ensure_beam_curve()


func _ready() -> void:
	_ensure_beam_curve()
	_update_editor_state()


func floor_materials() -> Array[StringName]:
	var materials: Array[StringName] = []
	var samples := get_node_or_null(^"Geometry/FloorSamples")
	if samples == null:
		return materials
	for sample: Node in samples.get_children():
		# Metadata is authored on StaticBody3D nodes and intentionally accepts a missing key.
		var material: Variant = sample.get_meta(&"floor_material", &"")
		if material is StringName and not materials.has(material):
			materials.append(material)
	return materials


func required_floor_materials_present() -> bool:
	var available := floor_materials()
	for material: StringName in REQUIRED_FLOOR_MATERIALS:
		if not available.has(material):
			return false
	return true


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if not required_floor_materials_present():
		errors.append("Gym floor samples must include tatami, wood, creaky_wood, gravel, and shallow_water.")

	var edge := get_node_or_null(^"Markers/ClimbBeam/EntryEdge") as ClimbEdge
	var beam := get_node_or_null(^"Markers/ClimbBeam/BeamPath") as BeamPath
	var exit_edge := get_node_or_null(^"Markers/ClimbBeam/ExitEdge") as ClimbEdge
	if edge == null or not edge.is_geometry_valid():
		errors.append("Gym climb entry edge must satisfy the ClimbEdge contract.")
	if beam == null or not beam.is_geometry_valid():
		errors.append("Gym beam path must satisfy the BeamPath contract.")
	if exit_edge == null or not exit_edge.is_geometry_valid():
		errors.append("Gym climb exit edge must satisfy the ClimbEdge contract.")
	if edge != null and beam != null and edge.connected_beam() != beam:
		errors.append("Gym climb entry edge must resolve to the beam path.")
	if exit_edge != null and beam != null and beam.connected_climb_at_end() != exit_edge:
		errors.append("Gym beam end must resolve to the climb exit edge.")

	var crawl_entrance := get_node_or_null(^"Markers/Crawlspace/CrawlEntrance") as CrawlEntrance
	if crawl_entrance == null or not crawl_entrance.is_geometry_valid():
		errors.append("Gym crawl entrance must satisfy the CrawlEntrance contract.")

	var water_volume := get_node_or_null(^"Markers/Water/WaterVolume") as WaterVolume
	if water_volume == null or not water_volume.is_geometry_valid():
		errors.append("Gym water volume must satisfy the WaterVolume contract.")

	var hide_spot := get_node_or_null(^"Markers/HideSpot/HideSpot") as HideSpot
	if hide_spot == null or not hide_spot.is_geometry_valid():
		errors.append("Gym hide spot must satisfy the HideSpot contract.")
	return errors


func is_contract_valid() -> bool:
	return validation_errors().is_empty()


func _ensure_beam_curve() -> void:
	var beam := get_node_or_null(^"Markers/ClimbBeam/BeamPath") as BeamPath
	if beam == null:
		return
	var curve := beam.path_curve
	if curve != null and curve.point_count >= BeamPath.MIN_POINT_COUNT:
		return
	curve = Curve3D.new()
	curve.bake_interval = BEAM_BAKE_INTERVAL
	curve.add_point(Vector3.ZERO)
	curve.add_point(BEAM_END_OFFSET)
	beam.path_curve = curve


func _get_configuration_warnings() -> PackedStringArray:
	return validation_errors()


func _update_editor_state() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		update_configuration_warnings()
