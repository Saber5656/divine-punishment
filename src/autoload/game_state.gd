extends Node


var current_mission_id: StringName = &""
var area_alert_level: int = 0
var checkpoint_ref: Dictionary = {}


func reset_for_mission(mission_id: StringName) -> void:
	current_mission_id = mission_id
	area_alert_level = 0
	checkpoint_ref.clear()
