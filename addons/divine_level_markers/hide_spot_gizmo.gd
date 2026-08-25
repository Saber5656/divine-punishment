@tool
extends EditorNode3DGizmoPlugin


const MATERIAL_NAME := "hide_spot_gizmo"


func _init() -> void:
	create_material(MATERIAL_NAME, Color(0.45, 0.85, 0.25, 1.0))


func _has_gizmo(for_node_3d: Node3D) -> bool:
	return for_node_3d is HideSpot


func _get_gizmo_name() -> String:
	return "HideSpot"


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var hide_spot := gizmo.get_node_3d() as HideSpot
	if hide_spot == null:
		return
	var segments := hide_spot.gizmo_segments()
	if segments.is_empty():
		return
	gizmo.add_lines(segments, get_material(MATERIAL_NAME, gizmo), false)
	gizmo.add_collision_segments(segments)
