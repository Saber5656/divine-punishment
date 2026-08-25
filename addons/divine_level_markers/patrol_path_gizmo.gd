@tool
extends EditorNode3DGizmoPlugin


const MATERIAL_NAME := "patrol_path_gizmo"


func _init() -> void:
	create_material(MATERIAL_NAME, Color(0.25, 0.85, 0.95, 1.0))


func _has_gizmo(for_node_3d: Node3D) -> bool:
	return for_node_3d is PatrolPath


func _get_gizmo_name() -> String:
	return "PatrolPath"


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var path := gizmo.get_node_3d() as PatrolPath
	if path == null:
		return
	var segments := path.gizmo_segments()
	if segments.is_empty():
		return
	gizmo.add_lines(segments, get_material(MATERIAL_NAME, gizmo), false)
	gizmo.add_collision_segments(segments)
