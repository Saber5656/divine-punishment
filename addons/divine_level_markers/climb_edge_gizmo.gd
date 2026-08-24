@tool
extends EditorNode3DGizmoPlugin


const MATERIAL_NAME := "climb_edge_gizmo"


func _init() -> void:
	create_material(MATERIAL_NAME, Color(0.2, 0.9, 0.35, 1.0))


func _has_gizmo(for_node_3d: Node3D) -> bool:
	return for_node_3d is ClimbEdge


func _get_gizmo_name() -> String:
	return "ClimbEdge"


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var edge := gizmo.get_node_3d() as ClimbEdge
	if edge == null:
		return
	var segments := edge.gizmo_segments()
	if segments.is_empty():
		return
	gizmo.add_lines(segments, get_material(MATERIAL_NAME, gizmo), false)
	gizmo.add_collision_segments(segments)
