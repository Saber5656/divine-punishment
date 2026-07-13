extends Node


const CURRENT_VERSION := 2

var save_path: String = "user://save.json"
var _data: Dictionary = default_save()


func _ready() -> void:
	load_save()
	if not FileAccess.file_exists(save_path):
		commit()


func load_save() -> void:
	if not FileAccess.file_exists(save_path):
		_data = default_save()
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_warning("Could not open save file; using defaults")
		_data = default_save()
		return
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	if parse_error != OK:
		_backup_corrupt_save()
		_data = default_save()
		return
	var parsed = json.data
	if typeof(parsed) != TYPE_DICTIONARY:
		_backup_corrupt_save()
		_data = default_save()
		return
	_data = migrate(parsed as Dictionary)


func commit() -> void:
	var tmp_path := "%s.tmp" % save_path
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not open temporary save file for writing")
		return
	file.store_string(JSON.stringify(_data, "\t"))
	file.close()

	var final_abs := ProjectSettings.globalize_path(save_path)
	var tmp_abs := ProjectSettings.globalize_path(tmp_path)
	var backup_abs := "%s.bak" % final_abs
	var has_existing := FileAccess.file_exists(save_path)
	if has_existing:
		if FileAccess.file_exists("%s.bak" % save_path):
			DirAccess.remove_absolute(backup_abs)
		var backup_error := DirAccess.rename_absolute(final_abs, backup_abs)
		if backup_error != OK:
			push_error("Could not back up existing save file: %s" % error_string(backup_error))
			return

	var rename_error := DirAccess.rename_absolute(tmp_abs, final_abs)
	if rename_error != OK:
		if has_existing:
			DirAccess.rename_absolute(backup_abs, final_abs)
		push_error("Could not commit save file: %s" % error_string(rename_error))
		return

	if has_existing and FileAccess.file_exists("%s.bak" % save_path):
		DirAccess.remove_absolute(backup_abs)


func campaign() -> Dictionary:
	return _data["campaign"]


func settings() -> Dictionary:
	return _data["settings"]


func record_mission_result(mission_id: StringName, result: RefCounted, first_clear: bool) -> void:
	var campaign_data := campaign()
	campaign_data["mission_results"][String(mission_id)] = {
		"score": result.get("score"),
		"rank": String(result.get("rank")),
		"flags": result.get("flags"),
	}
	if first_clear:
		campaign_data["unlocked_mission"] = maxi(int(campaign_data["unlocked_mission"]), _mission_number(mission_id) + 1)


func write_checkpoint(snapshot: Dictionary) -> void:
	_data["checkpoint"] = snapshot.duplicate(true)


func clear_checkpoint() -> void:
	_data["checkpoint"] = null


static func migrate(data: Dictionary) -> Dictionary:
	var version := int(data.get("version", 0))
	if version <= 0 or version > CURRENT_VERSION:
		return default_save()

	var migrated := default_save()
	if data.has("campaign") and typeof(data["campaign"]) == TYPE_DICTIONARY:
		_merge_known_keys(migrated["campaign"], data["campaign"])
	if data.has("settings") and typeof(data["settings"]) == TYPE_DICTIONARY:
		_merge_known_keys(migrated["settings"], data["settings"])
	if data.has("checkpoint"):
		migrated["checkpoint"] = data["checkpoint"]
	migrated["version"] = CURRENT_VERSION
	return migrated


static func default_save() -> Dictionary:
	return {
		"version": CURRENT_VERSION,
		"campaign": {
			"unlocked_mission": 1,
			"shura": 0,
			"total_nontarget_kills": 0,
			"total_civilian_kills": 0,
			"total_detections": 0,
			"mission_results": {},
			"seen_cutscenes": [],
		},
		"settings": {
			"volume_master": 1.0,
			"volume_bgm": 0.8,
			"volume_se": 1.0,
			"sensitivity": 0.5,
			"quality_preset": "high",
			"input_overrides": {},
			"locale": "ja",
		},
		"checkpoint": null,
	}


static func _merge_known_keys(target: Dictionary, source: Dictionary) -> void:
	for key in target.keys():
		if source.has(key):
			target[key] = source[key]


static func _mission_number(mission_id: StringName) -> int:
	var digits := ""
	for character: String in String(mission_id):
		if character.is_valid_int():
			digits += character
	return int(digits)


func _backup_corrupt_save() -> void:
	var source_abs := ProjectSettings.globalize_path(save_path)
	var backup_abs := "%s.corrupt.%d" % [source_abs, Time.get_unix_time_from_system()]
	var error := DirAccess.rename_absolute(source_abs, backup_abs)
	if error != OK:
		push_warning("Could not back up corrupt save file: %s" % error_string(error))
