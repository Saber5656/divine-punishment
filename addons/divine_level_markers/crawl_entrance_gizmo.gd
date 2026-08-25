@tool
extends EditorNode3DGizmoPlugin


const MATERIAL_NAME := "crawl_entrance_gizmo"


func _init() -> void:
	create_material(MATERIAL_NAME, Color(0.25, 0.75, 1.0, 1.0))


func _has_gizmo(for_node_3d: Node3D) -> bool:
	return for_node_3d is CrawlEntrance


func _get_gizmo_name() -> String:
	return "CrawlEntrance"


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var entrance := gizmo.get_node_3d() as CrawlEntrance
	if entrance == null:
		return
	var segments := entrance.gizmo_segments()
	if segments.is_empty():
		return
	gizmo.add_lines(segments, get_material(MATERIAL_NAME, gizmo), false)
	gizmo.add_collision_segments(segments)
