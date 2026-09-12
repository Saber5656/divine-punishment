class_name SettingsPanel
extends Control

signal closed

var controller: SettingsController
var _status: Label
var _list: VBoxContainer
var _capture_action: StringName = &""
var _binding_buttons: Dictionary = {}


func configure(value: SettingsController) -> void:
	controller = value


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 20)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	margin.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 14)
	scroll.add_child(_list)
	_label(&"settings.title")
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(_status)
	if controller == null:
		_status.text = _text(&"settings.unavailable")
		return
	for key in ["volume_master", "volume_bgm", "volume_se", "sensitivity"]:
		_slider(key, 0.0, 1.0, 0.05)
	for key in ["sensitivity_x", "sensitivity_y"]:
		_slider(key, 0.1, 3.0, 0.1)
	for key in ["invert_y", "fullscreen", "vsync", "inner_monologue"]:
		var toggle := CheckButton.new()
		toggle.text = _text(StringName("settings." + key))
		toggle.button_pressed = controller.values()[key]
		toggle.toggled.connect(func(value: bool): controller.apply_value(key, value))
		_list.add_child(toggle)
	_label(&"settings.quality_preset")
	var quality := OptionButton.new()
	for preset in ["low", "medium", "high"]:
		quality.add_item(_text(StringName("settings.quality." + preset)))
	quality.select(["low", "medium", "high"].find(controller.values().quality_preset))
	quality.item_selected.connect(func(index: int): controller.apply_value("quality_preset", ["low", "medium", "high"][index]))
	_list.add_child(quality)
	_label(&"settings.bindings")
	_label(&"settings.binding_help")
	for action in SettingsController.actions():
		var row := VBoxContainer.new()
		var label := Label.new()
		label.text = _text(StringName("input." + String(action)))
		row.add_child(label)
		var button := Button.new()
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.text = controller.binding_label(action)
		button.tooltip_text = button.text
		if button.text.is_empty():
			button.text = _text(&"settings.unassigned")
		button.pressed.connect(func(): _begin_capture(action))
		row.add_child(button)
		_binding_buttons[action] = button
		_list.add_child(row)
	var reset := Button.new()
	reset.text = _text(&"settings.reset_bindings")
	reset.pressed.connect(func(): controller.reset_bindings(); _refresh_bindings())
	_list.add_child(reset)
	var save := Button.new()
	save.text = _text(&"settings.save_back")
	save.pressed.connect(_save_and_close)
	_list.add_child(save)
	var back := Button.new()
	back.text = _text(&"settings.back_without_save")
	back.pressed.connect(func(): closed.emit())
	_list.add_child(back)
	if controller.save_manager.last_error != OK:
		_status.text = _text(&"settings.save_failed")
	elif not controller.save_manager.load_notice.is_empty():
		_status.text = _text(&"settings.corrupt_notice" if controller.save_manager.load_notice == &"corrupt_backed_up" else &"settings.recovery_notice")


func _slider(key: String, minimum: float, maximum: float, step: float) -> void:
	var label := _label(StringName("settings." + key))
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = controller.values()[key]
	slider.custom_minimum_size.y = 28
	slider.value_changed.connect(func(value: float):
		controller.apply_value(key, value)
		label.text = "%s  %.2f" % [_text(StringName("settings." + key)), value]
	)
	_list.add_child(slider)


func _label(key: StringName) -> Label:
	var label := Label.new()
	label.text = _text(key)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(label)
	return label


func _begin_capture(action: StringName) -> void:
	_capture_action = action
	_status.text = _text(&"settings.press_binding")


func _input(event: InputEvent) -> void:
	if _capture_action.is_empty() or not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE):
		_capture_action = &""
		_status.text = ""
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey or event is InputEventMouseButton):
		return
	if controller.set_binding(_capture_action, event):
		_capture_action = &""
		_status.text = ""
		_refresh_bindings()
	else:
		_status.text = _text(&"settings.binding_conflict")
	get_viewport().set_input_as_handled()


func _refresh_bindings() -> void:
	for action in _binding_buttons:
		var text := controller.binding_label(action)
		_binding_buttons[action].text = text if not text.is_empty() else _text(&"settings.unassigned")
		_binding_buttons[action].tooltip_text = text


func _save_and_close() -> void:
	if controller.save_settings():
		closed.emit()
	else:
		_status.text = _text(&"settings.save_failed")


static func _text(key: StringName) -> String:
	# #36 owns the shared catalog. Dynamic load keeps this module independently testable.
	if ResourceLoader.exists("res://src/ui/game_text.gd"):
		var catalog = load("res://src/ui/game_text.gd")
		return catalog.get_text(key)
	return String(key)
