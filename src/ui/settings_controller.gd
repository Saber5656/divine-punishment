class_name SettingsController
extends Node

const SaveScript := preload("res://src/autoload/save_manager.gd")
const PRESETS := {"low": {"scale": 0.7, "msaa": Viewport.MSAA_DISABLED}, "medium": {"scale": 0.85, "msaa": Viewport.MSAA_2X}, "high": {"scale": 1.0, "msaa": Viewport.MSAA_4X}}
var save_manager: Node
var last_conflicts: Array[StringName] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"settings_controller")
	if save_manager == null:
		save_manager = SaveManager
	apply_all()


func values() -> Dictionary:
	return save_manager.settings()


func apply_master_volume(value: float) -> void:
	apply_value("volume_master", value)


func apply_sensitivity(value: float) -> void:
	apply_value("sensitivity", value)


func apply_value(key: String, value: Variant) -> bool:
	if key == "input_overrides" or not SaveScript.default_save().settings.has(key):
		return false
	var candidate := SaveScript.default_save()
	candidate.settings = values().duplicate(true)
	candidate.settings[key] = value
	if SaveScript.migrate(candidate).is_empty():
		return false
	values()[key] = value
	apply_all()
	return true


func save_settings() -> bool:
	if not apply_all():
		return false
	save_manager.commit()
	return save_manager.last_error == OK


func apply_all() -> bool:
	var candidate := SaveScript.default_save()
	candidate.settings = values().duplicate(true)
	var valid := SaveScript.migrate(candidate)
	if valid.is_empty():
		return false
	var config: Dictionary = valid.settings
	for entry in [["Master", "volume_master"], ["BGM", "volume_bgm"], ["SE", "volume_se"]]:
		var index := AudioServer.get_bus_index(entry[0])
		if index < 0:
			AudioServer.add_bus()
			index = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, entry[0])
			AudioServer.set_bus_send(index, &"Master")
		var value := float(config[entry[1]])
		AudioServer.set_bus_mute(index, value == 0.0)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.0001)))
	var viewport := get_viewport()
	var preset: Dictionary = PRESETS[config.quality_preset]
	viewport.scaling_3d_scale = preset.scale
	viewport.msaa_3d = preset.msaa
	# Headless CI has no window; the Viewport/audio/input paths are still real.
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if config.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if config.vsync else DisplayServer.VSYNC_DISABLED)
	return _apply_bindings(config.input_overrides)


static func actions() -> Array[StringName]:
	var result: Array[StringName] = []
	for property in ProjectSettings.get_property_list():
		var name := String(property.name)
		if name.begins_with("input/"):
			result.append(StringName(name.trim_prefix("input/")))
	result.sort()
	return result


func binding_label(action: StringName) -> String:
	var labels: PackedStringArray = []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey or event is InputEventMouseButton:
			labels.append(event.as_text())
	return " / ".join(labels)


func set_binding(action: StringName, event: InputEvent) -> bool:
	if action not in actions():
		return false
	var binding := encode_binding(event)
	if binding.is_empty():
		return false
	var proposed: Dictionary = values().input_overrides.duplicate(true)
	proposed[String(action)] = binding
	last_conflicts = binding_conflicts(action, event, proposed)
	if not last_conflicts.is_empty():
		return false
	if not _apply_bindings(proposed):
		return false
	values().input_overrides = proposed
	return true


func reset_bindings() -> void:
	values().input_overrides = {}
	last_conflicts.clear()
	_apply_bindings({})


static func encode_binding(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if (event.alt_pressed and code != KEY_ALT) or (event.ctrl_pressed and code != KEY_CTRL) or (event.meta_pressed and code != KEY_META) or (event.shift_pressed and code != KEY_SHIFT):
			return {}
		return {"type": "key", "code": code} if code > 0 else {}
	if event is InputEventMouseButton:
		if event.alt_pressed or event.ctrl_pressed or event.meta_pressed or event.shift_pressed:
			return {}
		return {"type": "mouse", "code": event.button_index} if event.button_index > 0 and event.button_index <= 9 else {}
	return {}


static func decode_binding(binding: Dictionary) -> InputEvent:
	if binding.get("type") == "key":
		var event := InputEventKey.new()
		event.physical_keycode = int(binding.get("code", 0))
		return event
	var event := InputEventMouseButton.new()
	event.button_index = int(binding.get("code", 0))
	return event


static func binding_conflicts(action: StringName, event: InputEvent, proposed: Dictionary) -> Array[StringName]:
	var conflicts: Array[StringName] = []
	var encoded := encode_binding(event)
	for other in actions():
		if other == action:
			continue
		for candidate in _events_for(other, proposed):
			if encode_binding(candidate) == encoded:
				# Existing contextual overlap is valid only when both defaults shared it.
				if _default_has(action, encoded) and _default_has(other, encoded):
					continue
				conflicts.append(other)
				break
	return conflicts


func _apply_bindings(overrides: Dictionary) -> bool:
	var known := actions()
	for action in overrides:
		if StringName(action) not in known:
			return false
		var conflicts := binding_conflicts(StringName(action), decode_binding(overrides[action]), overrides)
		if not conflicts.is_empty():
			last_conflicts = conflicts
			return false
	for action in known:
		InputMap.action_erase_events(action)
		for event in _events_for(action, overrides):
			InputMap.action_add_event(action, event)
	return true


static func _events_for(action: StringName, overrides: Dictionary) -> Array[InputEvent]:
	var result: Array[InputEvent] = []
	var defaults: Dictionary = ProjectSettings.get_setting("input/%s" % action, {})
	for event in defaults.get("events", []):
		if overrides.has(String(action)) and (event is InputEventKey or event is InputEventMouseButton):
			continue
		result.append(event)
	if overrides.has(String(action)):
		result.append(decode_binding(overrides[String(action)]))
	return result


static func _default_has(action: StringName, binding: Dictionary) -> bool:
	for event in _events_for(action, {}):
		if encode_binding(event) == binding:
			return true
	return false
