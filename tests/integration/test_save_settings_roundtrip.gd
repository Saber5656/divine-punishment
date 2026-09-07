extends GutTest

const SaveScript := preload("res://src/autoload/save_manager.gd")
const ControllerScript := preload("res://src/ui/settings_controller.gd")
const TEST_PATH := "user://issue37_integration_test.json"


func test_completed_result_and_applied_settings_survive_disk_roundtrip() -> void:
	var manager := SaveScript.new()
	manager.save_path = TEST_PATH
	var controller := ControllerScript.new()
	controller.save_manager = manager
	add_child_autofree(controller)
	manager.campaign().unlocked_mission = 6
	manager.write_checkpoint({"mission_id": "m06", "position": [1.0, 2.0, 3.0], "objective_index": 1})
	manager.record_mission_result(&"m01", MissionResult.create(99, &"kaiden", {&"swift": true}), false)
	controller.apply_value("volume_bgm", 0.3)
	controller.apply_value("sensitivity", 0.75)
	controller.apply_value("sensitivity_x", 1.5)
	controller.apply_value("invert_y", true)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_K
	assert_true(controller.set_binding(&"interact", key))
	assert_true(controller.save_settings())
	controller.reset_bindings()
	manager.load_save()
	assert_true(controller.apply_all())
	assert_eq(manager.campaign().unlocked_mission, 6)
	assert_eq(manager.campaign().mission_results.m01.rank, "kaiden")
	assert_eq(manager.campaign().mission_results.m01.score, 99)
	assert_true(manager.campaign().mission_results.m01.flags.swift)
	assert_eq(controller.values().sensitivity, 0.75)
	assert_eq(controller.values().sensitivity_x, 1.5)
	assert_true(controller.values().invert_y)
	assert_true(InputMap.action_has_event(&"interact", key))
	assert_almost_eq(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("BGM"))), 0.3, 0.001)
	manager.record_mission_result(&"m01", MissionResult.create(50, &"chuden", {}), false)
	assert_true(controller.save_settings())
	manager.load_save()
	assert_eq(manager.campaign().mission_results.m01.rank, "kaiden")
	var disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	assert_eq(disk.checkpoint.mission_id, "m06")
	assert_eq(disk.checkpoint.position, [1.0, 2.0, 3.0])
	controller.reset_bindings()
	controller.save_manager = SaveManager
	controller.apply_all()
	manager.free()
	for filename in DirAccess.open("user://").get_files():
		if filename.begins_with("issue37_integration_test.json"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + filename))
