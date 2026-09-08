extends Node


var current_mission_id: StringName = &""
var area_alert_level: int = 0
var checkpoint_ref: Dictionary = {}


func reset_for_mission(mission_id: StringName) -> void:
	current_mission_id = mission_id
	area_alert_level = 0
	checkpoint_ref.clear()

# SaveManager owns campaign persistence; these views cannot drift independently.
var total_nontarget_kills: int:
	get: return int(SaveManager.campaign().total_nontarget_kills)
var total_civilian_kills: int:
	get: return int(SaveManager.campaign().total_civilian_kills)
var total_detections: int:
	get: return int(SaveManager.campaign().total_detections)
var shura: int:
	get: return int(SaveManager.campaign().shura)
