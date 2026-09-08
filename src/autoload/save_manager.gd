extends Node

const CURRENT_VERSION := 2
const RANKS := ["shoden", "chuden", "okuden", "kaiden"]
const LEGACY_RANKS := {"初伝": "shoden", "中伝": "chuden", "奥伝": "okuden", "皆伝": "kaiden"}

var save_path: String = "user://save.json"
var last_error: Error = OK
var last_status: StringName = &"not_loaded"
var load_notice: StringName = &""
var _write_blocked := false
var _data: Dictionary = default_save()


func _ready() -> void:
	load_save()
	if last_error == OK and not FileAccess.file_exists(save_path):
		commit()


func load_save() -> void:
	load_notice = &""
	_write_blocked = false
	last_error = OK
	if not FileAccess.file_exists(save_path):
		if _recover_interrupted_save():
			return
		if _write_blocked:
			return
		_data = default_save()
		last_status = &"new_save"
		return
	var loaded := _read_file(save_path)
	if loaded.error != OK:
		if loaded.error == ERR_PARSE_ERROR:
			var backup := _unique_backup("%s.corrupt" % save_path)
			var moved := _rename(save_path, backup)
			if moved == OK:
				load_notice = &"corrupt_backed_up"
				if _recover_interrupted_save() or _write_blocked:
					return
				_data = default_save()
				last_status = &"corrupt_backed_up"
				return
		_fail(loaded.error, &"load_failed", true)
		return
	var migrated := migrate(loaded.data)
	if migrated.is_empty():
		_fail(ERR_INVALID_DATA, &"unsupported_or_invalid_save", true)
		return
	_data = migrated
	last_status = &"loaded"


func commit() -> void:
	if _write_blocked:
		_fail(ERR_UNAUTHORIZED, &"write_blocked", true)
		return
	var checked := migrate(_data)
	if checked.is_empty():
		_fail(ERR_INVALID_DATA, &"invalid_memory_data")
		return
	var tmp_path := "%s.tmp" % save_path
	# Keep an earlier interrupted write until the current transaction succeeds.
	if FileAccess.file_exists(tmp_path):
		var preserve_error := _rename(tmp_path, _unique_backup("%s.interrupted" % save_path))
		if preserve_error != OK:
			_fail(preserve_error, &"temporary_preservation_failed")
			return
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		_fail(FileAccess.get_open_error(), &"temporary_open_failed")
		return
	var serialized := JSON.stringify(checked, "\t")
	file.store_string(serialized)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		_fail(write_error, &"temporary_write_failed")
		return
	var readback := _read_file(tmp_path)
	if readback.error != OK or readback.get("contents", "") != serialized or migrate(readback.data).is_empty():
		_fail(ERR_FILE_CORRUPT, &"temporary_verification_failed")
		return
	var backup_path := "%s.bak" % save_path
	var has_existing := FileAccess.file_exists(save_path)
	if has_existing:
		if FileAccess.file_exists(backup_path):
			var preserve_error := _rename(backup_path, _unique_backup("%s.previous" % save_path))
			if preserve_error != OK:
				_fail(preserve_error, &"backup_preservation_failed")
				return
		var backup_error := _rename(save_path, backup_path)
		if backup_error != OK:
			_fail(backup_error, &"backup_failed")
			return
	var rename_error := _rename(tmp_path, save_path)
	if rename_error != OK:
		if has_existing and _rename(backup_path, save_path) != OK:
			_fail(rename_error, &"rollback_failed_backup_retained", true)
		else:
			_fail(rename_error, &"commit_failed_original_restored")
		return
	_data = checked
	last_error = OK
	last_status = &"saved"


func campaign() -> Dictionary:
	return _data["campaign"]


func settings() -> Dictionary:
	return _data["settings"]


func record_mission_result(mission_id: StringName, result: RefCounted, first_clear: bool) -> void:
	if result == null or String(mission_id).is_empty():
		return
	var rank := String(result.get("rank"))
	if rank not in RANKS:
		return
	var counts: Dictionary = result.narrative_counts if result is MissionResult else {}
	for key in ["nontarget_kills", "civilian_kills", "detections"]:
		var value: Variant = counts.get(key, 0)
		if not _integer(value) or value < 0: return
	for key in ["nontarget_kills", "civilian_kills", "detections"]:
		campaign()["total_"+key] = int(campaign()["total_"+key]) + int(counts.get(key,0))
	campaign()["shura"] = NarrativeTotals.shura(campaign().total_nontarget_kills, campaign().total_civilian_kills, campaign().total_detections)
	var results: Dictionary = campaign()["mission_results"]
	var previous: Dictionary = results.get(String(mission_id), {})
	var score := int(result.get("score"))
	var previous_rank := RANKS.find(String(previous.get("rank", "")))
	if previous.is_empty() or RANKS.find(rank) > previous_rank or (RANKS.find(rank) == previous_rank and score > int(previous.get("score", 0))):
		results[String(mission_id)] = {"score": score, "rank": rank, "flags": result.get("flags").duplicate(true)}
	if first_clear:
		campaign()["unlocked_mission"] = mini(11, maxi(int(campaign()["unlocked_mission"]), _mission_number(mission_id) + 1))


func write_checkpoint(snapshot: Dictionary) -> void:
	_data["checkpoint"] = snapshot.duplicate(true)


func clear_checkpoint() -> void:
	_data["checkpoint"] = null


static func migrate(data: Dictionary) -> Dictionary:
	if not _integer(data.get("version")) or int(data.version) < 1 or int(data.version) > CURRENT_VERSION:
		return {}
	if not _json_value(data):
		return {}
	var migrated := data.duplicate(true)
	var defaults := default_save()
	for section in ["campaign", "settings"]:
		if migrated.has(section) and not migrated[section] is Dictionary:
			return {}
		if not migrated.has(section):
			migrated[section] = {}
		for key in defaults[section]:
			if not migrated[section].has(key):
				migrated[section][key] = defaults[section][key]
	if not migrated.has("checkpoint"):
		migrated.checkpoint = null
	if migrated.checkpoint != null and not migrated.checkpoint is Dictionary:
		return {}
	var progress: Dictionary = migrated.campaign
	for key in ["unlocked_mission", "shura", "total_nontarget_kills", "total_civilian_kills", "total_detections"]:
		if not _integer(progress[key]) or progress[key] < 0:
			return {}
	for key in ["unlocked_mission", "shura", "total_nontarget_kills", "total_civilian_kills", "total_detections"]:
		progress[key] = int(progress[key])
	if progress.unlocked_mission < 1 or progress.unlocked_mission > 11:
		return {}
	if not progress.mission_results is Dictionary or not progress.seen_cutscenes is Array:
		return {}
	for cutscene in progress.seen_cutscenes:
		if not cutscene is String:
			return {}
	for id in progress.mission_results:
		var result = progress.mission_results[id]
		if not result is Dictionary or not _integer(result.get("score")) or not result.get("rank") is String or not result.get("flags") is Dictionary:
			return {}
		result.score = int(result.score)
		result.rank = LEGACY_RANKS.get(result.rank, result.rank)
		if result.rank not in RANKS:
			return {}
	var config: Dictionary = migrated.settings
	for key in ["volume_master", "volume_bgm", "volume_se", "sensitivity"]:
		if not _number(config[key]) or config[key] < 0.0 or config[key] > 1.0:
			return {}
	for key in ["sensitivity_x", "sensitivity_y"]:
		if not _number(config[key]) or config[key] < 0.1 or config[key] > 3.0:
			return {}
	for key in ["invert_y", "fullscreen", "vsync"]:
		if not config[key] is bool:
			return {}
	if config.quality_preset not in ["low", "medium", "high"] or not config.locale is String or not config.input_overrides is Dictionary:
		return {}
	for action in config.input_overrides:
		var binding = config.input_overrides[action]
		if not binding is Dictionary or binding.get("type") not in ["key", "mouse"] or not _integer(binding.get("code")) or binding.code <= 0:
			return {}
		if binding.type == "mouse" and binding.code > 9:
			return {}
	migrated.version = CURRENT_VERSION
	return migrated


static func default_save() -> Dictionary:
	return {
		"version": CURRENT_VERSION,
		"campaign": {"unlocked_mission": 1, "shura": 0, "total_nontarget_kills": 0, "total_civilian_kills": 0, "total_detections": 0, "mission_results": {}, "seen_cutscenes": []},
		"settings": {"volume_master": 1.0, "volume_bgm": 0.8, "volume_se": 1.0, "sensitivity": 0.5, "sensitivity_x": 1.0, "sensitivity_y": 1.0, "invert_y": false, "quality_preset": "high", "fullscreen": false, "vsync": true, "input_overrides": {}, "locale": "ja"},
		"checkpoint": null,
	}


static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _integer(value: Variant) -> bool:
	return _number(value) and float(value) == floor(float(value))


static func _json_value(value: Variant) -> bool:
	if value == null or value is bool or value is String or value is StringName:
		return true
	if value is int or value is float:
		return _number(value)
	if value is Array:
		for item in value:
			if not _json_value(item):
				return false
		return true
	if value is Dictionary:
		for key in value:
			if not (key is String or key is StringName) or not _json_value(value[key]):
				return false
		return true
	return false


static func _mission_number(mission_id: StringName) -> int:
	var text := String(mission_id)
	if text.length() == 3 and text.begins_with("m") and text.substr(1).is_valid_int():
		return clampi(int(text.substr(1)), 0, 10)
	return 0


func _read_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": FileAccess.get_open_error(), "data": {}}
	var contents := file.get_as_text()
	var read_error := file.get_error()
	file.close()
	if read_error not in [OK, ERR_FILE_EOF]:
		return {"error": read_error, "data": {}}
	var json := JSON.new()
	if json.parse(contents) != OK or not json.data is Dictionary:
		return {"error": ERR_PARSE_ERROR, "data": {}}
	return {"error": OK, "data": json.data, "contents": contents}


func _recover_interrupted_save() -> bool:
	var found := false
	for candidate in ["%s.tmp" % save_path, "%s.bak" % save_path]:
		if not FileAccess.file_exists(candidate):
			continue
		found = true
		var loaded := _read_file(candidate)
		if loaded.error != OK:
			continue
		var migrated := migrate(loaded.data)
		if migrated.is_empty():
			continue
		if _rename(candidate, save_path) != OK:
			continue
		_data = migrated
		last_error = OK
		last_status = &"recovered"
		load_notice = &"recovered"
		return true
	if found:
		_fail(ERR_FILE_CORRUPT, &"recovery_failed_sources_retained", true)
	return false


func _rename(from: String, to: String) -> Error:
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(from), ProjectSettings.globalize_path(to))


func _unique_backup(prefix: String) -> String:
	var suffix := int(Time.get_unix_time_from_system() * 1000000.0)
	while FileAccess.file_exists("%s.%d" % [prefix, suffix]):
		suffix += 1
	return "%s.%d" % [prefix, suffix]


func _fail(error: Error, status: StringName, block: bool = false) -> void:
	last_error = error
	last_status = status
	_write_blocked = _write_blocked or block
