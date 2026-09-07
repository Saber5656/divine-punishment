extends GutTest

const SaveScript := preload("res://src/autoload/save_manager.gd")
const SettingsScript := preload("res://src/ui/settings_controller.gd")
const CameraScene := preload("res://src/player/player_camera_rig.gd")
const TEST_PATH := "user://issue37_settings_test.json"
var _manager: Node
var _controller: SettingsController
var _original_settings: Dictionary
var _bus_count: int


func before_each() -> void:
	_original_settings = SaveManager.settings().duplicate(true)
	_bus_count = AudioServer.bus_count
	_manager = SaveScript.new()
	_manager.save_path = TEST_PATH
	_controller = SettingsScript.new()
	_controller.save_manager = _manager
	add_child_autofree(_controller)


func after_each() -> void:
	_controller.reset_bindings()
	SaveManager.settings().clear()
	SaveManager.settings().merge(_original_settings, true)
	_controller.save_manager = SaveManager
	_controller.apply_all()
	while AudioServer.bus_count > _bus_count:
		AudioServer.remove_bus(AudioServer.bus_count - 1)
	_manager.free()
	var dir := DirAccess.open("user://")
	for file in dir.get_files():
		if file.begins_with("issue37_settings_test.json"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + file))


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event


func test_all_project_actions_are_remappable_and_joypad_is_preserved() -> void:
	var expected := 0
	for property in ProjectSettings.get_property_list():
		if String(property.name).begins_with("input/"):
			expected += 1
	assert_eq(SettingsController.actions().size(), expected)
	var joy_count := 0
	for event in InputMap.action_get_events(&"move_forward"):
		if event is InputEventJoypadMotion:
			joy_count += 1
	assert_true(_controller.set_binding(&"move_forward", _key(KEY_P)))
	assert_true(InputMap.action_has_event(&"move_forward", _key(KEY_P)))
	assert_false(InputMap.action_has_event(&"move_forward", _key(KEY_W)))
	var after_joy := 0
	for event in InputMap.action_get_events(&"move_forward"):
		if event is InputEventJoypadMotion:
			after_joy += 1
	assert_eq(after_joy, joy_count)
	assert_false(_controller.set_binding(&"ui_accept", _key(KEY_P)))


func test_conflict_is_rejected_without_mutation_and_defaults_can_reset() -> void:
	assert_false(_controller.set_binding(&"move_forward", _key(KEY_S)))
	assert_has(_controller.last_conflicts, &"move_backward")
	assert_true(InputMap.action_has_event(&"move_forward", _key(KEY_W)))
	assert_eq(_controller.values().input_overrides, {})
	assert_true(_controller.set_binding(&"move_forward", _key(KEY_P)))
	_controller.reset_bindings()
	assert_true(InputMap.action_has_event(&"move_forward", _key(KEY_W)))
	assert_false(InputMap.action_has_event(&"move_forward", _key(KEY_P)))


func test_audio_buses_and_graphics_change_real_runtime_values() -> void:
	assert_true(_controller.apply_value("volume_master", 0.4))
	assert_true(_controller.apply_value("volume_bgm", 0.25))
	assert_true(_controller.apply_value("volume_se", 0.0))
	assert_almost_eq(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))), 0.4, 0.001)
	assert_almost_eq(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("BGM"))), 0.25, 0.001)
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index("SE")))
	assert_true(_controller.apply_value("quality_preset", "low"))
	assert_almost_eq(get_viewport().scaling_3d_scale, 0.7, 0.001)
	assert_eq(get_viewport().msaa_3d, Viewport.MSAA_DISABLED)
	assert_true(_controller.apply_value("quality_preset", "high"))
	assert_eq(get_viewport().msaa_3d, Viewport.MSAA_4X)
	assert_false(_controller.apply_value("volume_master", NAN))
	assert_false(_controller.apply_value("quality_preset", "ultra"))


func test_camera_consumes_live_settings_without_mutating_shared_tuning() -> void:
	SaveManager.settings().sensitivity = 0.5
	SaveManager.settings().sensitivity_x = 1.0
	SaveManager.settings().sensitivity_y = 1.0
	SaveManager.settings().invert_y = false
	var rig := CameraScene.new()
	add_child_autofree(rig)
	var baseline := Tuning.camera().mouse_look_sensitivity
	assert_almost_eq(rig.apply_mouse_look(Vector2(10, 0)), -10.0 * baseline, 0.00001)
	SaveManager.settings().sensitivity = 1.0
	SaveManager.settings().sensitivity_x = 1.5
	SaveManager.settings().invert_y = true
	assert_almost_eq(rig.apply_mouse_look(Vector2(10, 1)), -30.0 * baseline, 0.00001)
	assert_gt(rig.rotation.x, 0.0)
	assert_eq(Tuning.camera().mouse_look_sensitivity, baseline)


func test_settings_panel_constructs_and_keeps_open_after_failed_save() -> void:
	var panel := preload("res://src/ui/settings_panel.gd").new()
	panel.configure(_controller)
	add_child_autofree(panel)
	watch_signals(panel)
	_manager.save_path = "user://issue37_missing_directory/save.json"
	panel._save_and_close()
	assert_signal_not_emitted(panel, "closed")
	assert_false(panel._status.text.is_empty())
	assert_eq(panel._binding_buttons.size(), SettingsController.actions().size())


func test_standalone_modifier_keys_are_bindable_but_chords_are_rejected() -> void:
	var shift := _key(KEY_SHIFT)
	shift.shift_pressed = true
	assert_eq(SettingsController.encode_binding(shift), {"type": "key", "code": KEY_SHIFT})
	assert_false(_controller.set_binding(&"interact", shift), "existing sprint Shift binding conflicts")
	var chord := _key(KEY_K)
	chord.ctrl_pressed = true
	assert_eq(SettingsController.encode_binding(chord), {})
	assert_eq(_controller.values().input_overrides, {})
