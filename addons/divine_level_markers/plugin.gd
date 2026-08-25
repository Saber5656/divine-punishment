@tool
extends EditorPlugin


const ClimbEdgeGizmo := preload("res://addons/divine_level_markers/climb_edge_gizmo.gd")
const BeamPathGizmo := preload("res://addons/divine_level_markers/beam_path_gizmo.gd")
const CrawlEntranceGizmo := preload("res://addons/divine_level_markers/crawl_entrance_gizmo.gd")
const HideSpotGizmo := preload("res://addons/divine_level_markers/hide_spot_gizmo.gd")
const LightSourceGizmo := preload("res://addons/divine_level_markers/light_source_gizmo.gd")
const PatrolPathGizmo := preload("res://addons/divine_level_markers/patrol_path_gizmo.gd")
const RoutineStopGizmo := preload("res://addons/divine_level_markers/routine_stop_gizmo.gd")
const SearchPointGizmo := preload("res://addons/divine_level_markers/search_point_gizmo.gd")

var _climb_edge_gizmo: EditorNode3DGizmoPlugin
var _beam_path_gizmo: EditorNode3DGizmoPlugin
var _crawl_entrance_gizmo: EditorNode3DGizmoPlugin
var _hide_spot_gizmo: EditorNode3DGizmoPlugin
var _light_source_gizmo: EditorNode3DGizmoPlugin
var _patrol_path_gizmo: EditorNode3DGizmoPlugin
var _routine_stop_gizmo: EditorNode3DGizmoPlugin
var _search_point_gizmo: EditorNode3DGizmoPlugin


func _enter_tree() -> void:
	_climb_edge_gizmo = ClimbEdgeGizmo.new()
	_beam_path_gizmo = BeamPathGizmo.new()
	_crawl_entrance_gizmo = CrawlEntranceGizmo.new()
	_hide_spot_gizmo = HideSpotGizmo.new()
	add_node_3d_gizmo_plugin(_climb_edge_gizmo)
	add_node_3d_gizmo_plugin(_beam_path_gizmo)
	add_node_3d_gizmo_plugin(_crawl_entrance_gizmo)
	add_node_3d_gizmo_plugin(_hide_spot_gizmo)
	_light_source_gizmo = LightSourceGizmo.new()
	add_node_3d_gizmo_plugin(_light_source_gizmo)
	_patrol_path_gizmo = PatrolPathGizmo.new()
	add_node_3d_gizmo_plugin(_patrol_path_gizmo)
	_routine_stop_gizmo = RoutineStopGizmo.new()
	add_node_3d_gizmo_plugin(_routine_stop_gizmo)
	_search_point_gizmo = SearchPointGizmo.new()
	add_node_3d_gizmo_plugin(_search_point_gizmo)


func _exit_tree() -> void:
	if _crawl_entrance_gizmo != null:
		remove_node_3d_gizmo_plugin(_crawl_entrance_gizmo)
	if _hide_spot_gizmo != null:
		remove_node_3d_gizmo_plugin(_hide_spot_gizmo)
	if _beam_path_gizmo != null:
		remove_node_3d_gizmo_plugin(_beam_path_gizmo)
	if _climb_edge_gizmo != null:
		remove_node_3d_gizmo_plugin(_climb_edge_gizmo)
	if _light_source_gizmo != null:
		remove_node_3d_gizmo_plugin(_light_source_gizmo)
	if _patrol_path_gizmo != null:
		remove_node_3d_gizmo_plugin(_patrol_path_gizmo)
	if _routine_stop_gizmo != null:
		remove_node_3d_gizmo_plugin(_routine_stop_gizmo)
	if _search_point_gizmo != null:
		remove_node_3d_gizmo_plugin(_search_point_gizmo)
	_beam_path_gizmo = null
	_climb_edge_gizmo = null
	_crawl_entrance_gizmo = null
	_hide_spot_gizmo = null
	_light_source_gizmo = null
	_patrol_path_gizmo = null
	_routine_stop_gizmo = null
	_search_point_gizmo = null
