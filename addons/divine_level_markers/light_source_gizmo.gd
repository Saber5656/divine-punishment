@tool
extends EditorNode3DGizmoPlugin


const MATERIAL_NAME := "light_source_gizmo"


func _init() -> void:
	create_material(MATERIAL_NAME, Color(1.0, 0.8, 0.2, 1.0))


func _has_gizmo(for_node_3d: Node3D) -> bool:
	return for_node_3d is LightSource


func _get_gizmo_name() -> String:
	return "LightSource"


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var light := gizmo.get_node_3d() as LightSource
	if light == null:
		return
	var segments := light.gizmo_segments()
	if segments.is_empty():
		return
	gizmo.add_lines(segments, get_material(MATERIAL_NAME, gizmo), false)
	gizmo.add_collision_segments(segments)
