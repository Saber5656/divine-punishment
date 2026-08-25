@tool
extends EditorNode3DGizmoPlugin


const MATERIAL_NAME := "search_point_gizmo"


func _init() -> void:
	create_material(MATERIAL_NAME, Color(0.95, 0.72, 0.18, 1.0))


func _has_gizmo(for_node_3d: Node3D) -> bool:
	return for_node_3d is SearchPoint


func _get_gizmo_name() -> String:
	return "SearchPoint"


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var point := gizmo.get_node_3d() as SearchPoint
	if point == null:
		return
	var segments := point.gizmo_segments()
	if segments.is_empty():
		return
	gizmo.add_lines(segments, get_material(MATERIAL_NAME, gizmo), false)
	gizmo.add_collision_segments(segments)
