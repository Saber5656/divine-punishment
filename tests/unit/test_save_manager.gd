extends GutTest


const SaveManagerScript := preload("res://src/autoload/save_manager.gd")
const TEST_SAVE_PATH := "user://save_manager_test.json"


func after_each() -> void:
	_remove_user_file(TEST_SAVE_PATH)
	_remove_user_file("%s.tmp" % TEST_SAVE_PATH)
	_remove_user_file("%s.bak" % TEST_SAVE_PATH)


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


func _remove_user_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
