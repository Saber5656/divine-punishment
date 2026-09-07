extends GutTest


const SaveManagerScript := preload("res://src/autoload/save_manager.gd")
const TEST_SAVE_PATH := "user://save_manager_test.json"


func after_each() -> void:
	_remove_user_file(TEST_SAVE_PATH)
	_remove_user_file("%s.tmp" % TEST_SAVE_PATH)
	_remove_user_file("%s.bak" % TEST_SAVE_PATH)
	_remove_corrupt_backups()


func test_migrate_v1_like_data_to_v2_defaults_missing_keys() -> void:
	var migrated := SaveManagerScript.migrate({
		"version": 1,
		"campaign": {
			"unlocked_mission": 3,
			"shura": 2,
		},
		"settings": {
			"locale": "ja",
			"volume_master": 0.7,
		},
	})
	assert_eq(migrated["version"], 2)
	assert_eq(migrated["campaign"]["unlocked_mission"], 3)
	assert_eq(migrated["campaign"]["total_detections"], 0)
	assert_eq(migrated["settings"]["volume_master"], 0.7)
	assert_eq(migrated["settings"]["quality_preset"], "high")


func test_commit_and_load_round_trip() -> void:
	var writer := SaveManagerScript.new()
	writer.save_path = TEST_SAVE_PATH
	writer.load_save()
	writer.campaign()["unlocked_mission"] = 2
	writer.settings()["sensitivity"] = 0.75
	writer.commit()

	var reader := SaveManagerScript.new()
	reader.save_path = TEST_SAVE_PATH
	reader.load_save()
	assert_eq(int(reader.campaign()["unlocked_mission"]), 2)
	assert_eq(reader.settings()["sensitivity"], 0.75)
	writer.free()
	reader.free()
	assert_false(FileAccess.file_exists("%s.bak" % TEST_SAVE_PATH))


func test_load_recovers_interrupted_temporary_save_before_defaults() -> void:
	var file := FileAccess.open("%s.tmp" % TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"version": 2,
		"campaign": {"unlocked_mission": 4},
		"settings": {"locale": "en"},
	}))
	file.close()

	var manager := SaveManagerScript.new()
	manager.save_path = TEST_SAVE_PATH
	manager.load_save()
	assert_eq(manager.campaign()["unlocked_mission"], 4)
	assert_eq(manager.settings()["locale"], "en")
	assert_true(FileAccess.file_exists(TEST_SAVE_PATH))
	assert_false(FileAccess.file_exists("%s.tmp" % TEST_SAVE_PATH))
	manager.free()


func test_corrupt_json_initializes_default_save() -> void:
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string("{not json")
	file.close()

	var manager := SaveManagerScript.new()
	manager.save_path = TEST_SAVE_PATH
	manager.load_save()
	assert_eq(manager.campaign()["unlocked_mission"], 1)
	assert_eq(manager.settings()["locale"], "ja")
	manager.free()
	assert_false(FileAccess.file_exists(TEST_SAVE_PATH))
	assert_eq(_corrupt_backup_count(), 1)


func _remove_user_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _corrupt_backup_count() -> int:
	var count := 0
	var directory := DirAccess.open(ProjectSettings.globalize_path("user://"))
	if directory == null:
		return count
	for filename in directory.get_files():
		if filename.begins_with("save_manager_test.json.corrupt."):
			count += 1
	return count


func _remove_corrupt_backups() -> void:
	var directory := DirAccess.open(ProjectSettings.globalize_path("user://"))
	if directory == null:
		return
	for filename in directory.get_files():
		if filename.begins_with("save_manager_test.json."):
			_remove_user_file("user://%s" % filename)


class FailingRenameSave extends "res://src/autoload/save_manager.gd":
	var fail_backup := false
	var fail_commit := false
	var fail_rollback := false
	var fail_corrupt := false
	var corrupt_readback := false

	func _read_file(path: String) -> Dictionary:
		var result := super._read_file(path)
		if corrupt_readback and path.ends_with(".tmp"):
			result["contents"] = "{}"
		return result

	func _rename(from: String, to: String) -> Error:
		if fail_backup and from == save_path and to.ends_with(".bak"):
			return ERR_CANT_CREATE
		if fail_commit and from.ends_with(".tmp") and to == save_path:
			return ERR_CANT_CREATE
		if fail_rollback and from.ends_with(".bak") and to == save_path:
			return ERR_CANT_CREATE
		if fail_corrupt and to.contains(".corrupt."):
			return ERR_CANT_CREATE
		return super._rename(from, to)


func _write_fixture(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
	file.close()


func test_future_version_and_invalid_typed_values_remain_unchanged_on_disk() -> void:
	for value in [{"version": 99}, {"version": 2, "campaign": {"mission_results": []}}, {"version": 2, "settings": {"volume_master": "loud"}}, {"version": 2, "checkpoint": []}]:
		_write_fixture(TEST_SAVE_PATH, value)
		var original := FileAccess.get_file_as_string(TEST_SAVE_PATH)
		var manager := SaveManagerScript.new()
		manager.save_path = TEST_SAVE_PATH
		manager.load_save()
		assert_eq(manager.last_status, &"unsupported_or_invalid_save")
		manager.commit()
		assert_eq(manager.last_status, &"write_blocked")
		assert_eq(FileAccess.get_file_as_string(TEST_SAVE_PATH), original)
		assert_false(FileAccess.file_exists("%s.tmp" % TEST_SAVE_PATH))
		manager.free()


func test_failed_corrupt_backup_does_not_allow_default_overwrite() -> void:
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	var manager := FailingRenameSave.new()
	manager.save_path = TEST_SAVE_PATH
	manager.fail_corrupt = true
	manager.load_save()
	manager.commit()
	assert_eq(manager.last_status, &"write_blocked")
	assert_eq(FileAccess.get_file_as_string(TEST_SAVE_PATH), "{broken")
	manager.free()


func test_backup_failure_keeps_original_and_reports_failure() -> void:
	var original := SaveManagerScript.default_save()
	original.campaign.unlocked_mission = 7
	_write_fixture(TEST_SAVE_PATH, original)
	var bytes := FileAccess.get_file_as_string(TEST_SAVE_PATH)
	var manager := FailingRenameSave.new()
	manager.save_path = TEST_SAVE_PATH
	manager.load_save()
	manager.settings().sensitivity = 0.7
	manager.fail_backup = true
	manager.commit()
	assert_eq(manager.last_status, &"backup_failed")
	assert_ne(manager.last_error, OK)
	assert_eq(FileAccess.get_file_as_string(TEST_SAVE_PATH), bytes)
	manager.free()


func test_commit_failure_rolls_original_back_and_keeps_temporary_candidate() -> void:
	_write_fixture(TEST_SAVE_PATH, SaveManagerScript.default_save())
	var bytes := FileAccess.get_file_as_string(TEST_SAVE_PATH)
	var manager := FailingRenameSave.new()
	manager.save_path = TEST_SAVE_PATH
	manager.load_save()
	manager.settings().sensitivity = 0.7
	manager.fail_commit = true
	manager.commit()
	assert_eq(manager.last_status, &"commit_failed_original_restored")
	assert_eq(FileAccess.get_file_as_string(TEST_SAVE_PATH), bytes)
	assert_true(FileAccess.file_exists("%s.tmp" % TEST_SAVE_PATH))
	manager.free()


func test_rollback_failure_retains_backup_and_blocks_further_writes() -> void:
	_write_fixture(TEST_SAVE_PATH, SaveManagerScript.default_save())
	var bytes := FileAccess.get_file_as_string(TEST_SAVE_PATH)
	var manager := FailingRenameSave.new()
	manager.save_path = TEST_SAVE_PATH
	manager.load_save()
	manager.fail_commit = true
	manager.fail_rollback = true
	manager.commit()
	assert_eq(manager.last_status, &"rollback_failed_backup_retained")
	assert_eq(FileAccess.get_file_as_string("%s.bak" % TEST_SAVE_PATH), bytes)
	manager.commit()
	assert_eq(manager.last_status, &"write_blocked")
	assert_eq(FileAccess.get_file_as_string("%s.bak" % TEST_SAVE_PATH), bytes)
	manager.free()


func test_recovery_ignores_invalid_tmp_and_restores_valid_backup() -> void:
	_write_fixture("%s.tmp" % TEST_SAVE_PATH, {"version": 999})
	var backup := SaveManagerScript.default_save()
	backup.campaign.unlocked_mission = 5
	_write_fixture("%s.bak" % TEST_SAVE_PATH, backup)
	var manager := SaveManagerScript.new()
	manager.save_path = TEST_SAVE_PATH
	manager.load_save()
	assert_eq(manager.last_status, &"recovered")
	assert_eq(manager.campaign().unlocked_mission, 5)
	assert_true(FileAccess.file_exists("%s.tmp" % TEST_SAVE_PATH))
	manager.free()


func test_invalid_recovery_candidates_are_not_replaced_by_defaults() -> void:
	_write_fixture("%s.tmp" % TEST_SAVE_PATH, {"version": 999})
	var bytes := FileAccess.get_file_as_string("%s.tmp" % TEST_SAVE_PATH)
	var manager := SaveManagerScript.new()
	manager.save_path = TEST_SAVE_PATH
	manager.load_save()
	assert_eq(manager.last_status, &"recovery_failed_sources_retained")
	manager.commit()
	assert_false(FileAccess.file_exists(TEST_SAVE_PATH))
	assert_eq(FileAccess.get_file_as_string("%s.tmp" % TEST_SAVE_PATH), bytes)
	manager.free()


func test_mission_replay_preserves_best_rank_and_score_flags() -> void:
	var manager := SaveManagerScript.new()
	var best := MissionResult.create(110, &"kaiden", {&"swift": true})
	manager.record_mission_result(&"m01", best, true)
	manager.record_mission_result(&"m01", MissionResult.create(60, &"chuden", {}), false)
	assert_eq(manager.campaign().mission_results.m01.rank, "kaiden")
	assert_eq(manager.campaign().mission_results.m01.score, 110)
	assert_true(manager.campaign().mission_results.m01.flags.swift)
	assert_eq(manager.campaign().unlocked_mission, 2)
	manager.record_mission_result(&"m01", MissionResult.create(115, &"kaiden", {}), false)
	assert_eq(manager.campaign().mission_results.m01.score, 115)
	manager.record_mission_result(&"m10", best, true)
	assert_eq(manager.campaign().unlocked_mission, 11)
	manager.free()


func test_v1_migration_preserves_unknown_data_and_normalizes_legacy_rank() -> void:
	var input := {"version": 1, "campaign": {"mission_results": {"m01": {"score": 93, "rank": "皆伝", "flags": {"swift": false}}}}, "extension": {"safe": 7}}
	var migrated := SaveManagerScript.migrate(input)
	assert_eq(migrated.campaign.mission_results.m01.rank, "kaiden")
	assert_eq(migrated.settings.sensitivity_x, 1.0)
	assert_eq(migrated.extension.safe, 7)
	assert_eq(input.campaign.mission_results.m01.rank, "皆伝", "pure migration does not edit input")


func test_temporary_readback_mismatch_cannot_replace_existing_save() -> void:
	_write_fixture(TEST_SAVE_PATH, SaveManagerScript.default_save())
	var bytes := FileAccess.get_file_as_string(TEST_SAVE_PATH)
	var manager := FailingRenameSave.new()
	manager.save_path = TEST_SAVE_PATH
	manager.load_save()
	manager.corrupt_readback = true
	manager.commit()
	assert_eq(manager.last_status, &"temporary_verification_failed")
	assert_eq(FileAccess.get_file_as_string(TEST_SAVE_PATH), bytes)
	manager.free()


func test_corrupt_final_recovers_existing_backup_and_retains_notice_after_commit() -> void:
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	var progress := SaveManagerScript.default_save()
	progress.campaign.unlocked_mission = 8
	_write_fixture("%s.bak" % TEST_SAVE_PATH, progress)
	var manager := SaveManagerScript.new()
	manager.save_path = TEST_SAVE_PATH
	manager.load_save()
	assert_eq(manager.campaign().unlocked_mission, 8)
	assert_eq(manager.load_notice, &"recovered")
	assert_eq(_corrupt_backup_count(), 1)
	manager.commit()
	assert_eq(manager.last_error, OK)
	assert_eq(manager.load_notice, &"recovered", "saving must not hide the startup recovery notice")
	manager.free()
