@tool
extends EditorPlugin


const ClimbEdgeGizmo := preload("res://addons/divine_level_markers/climb_edge_gizmo.gd")
const BeamPathGizmo := preload("res://addons/divine_level_markers/beam_path_gizmo.gd")

var _climb_edge_gizmo: EditorNode3DGizmoPlugin
var _beam_path_gizmo: EditorNode3DGizmoPlugin


func _enter_tree() -> void:
	_climb_edge_gizmo = ClimbEdgeGizmo.new()
	_beam_path_gizmo = BeamPathGizmo.new()
	add_node_3d_gizmo_plugin(_climb_edge_gizmo)
	add_node_3d_gizmo_plugin(_beam_path_gizmo)


func _exit_tree() -> void:
	if _beam_path_gizmo != null:
		remove_node_3d_gizmo_plugin(_beam_path_gizmo)
	if _climb_edge_gizmo != null:
		remove_node_3d_gizmo_plugin(_climb_edge_gizmo)
	_beam_path_gizmo = null
	_climb_edge_gizmo = null
