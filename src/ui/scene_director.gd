class_name SceneDirector
extends CanvasLayer


const RESIDENCE: MissionDefinition = preload("res://data/missions/m02.tres")
const PRACTICE: MissionDefinition = preload("res://data/missions/practice.tres")
const TUTORIAL: MissionDefinition = preload("res://data/missions/tutorial.tres")
const BACKGROUND := preload("res://assets/samples/issue-77-pv/issue77-01-exterior.png")
const FLAG_IDS: Array[StringName] = [&"shadow_walker", &"no_traces", &"one_strike", &"swift", &"side_objective"]

var save_manager: Node
var _result_recorded := false
var screen: StringName = &"title"
var mission: Node
var definition: MissionDefinition
var _menu: Control
var _content: VBoxContainer
var _hud: Control
var _objective: Label
var _hint: Label
var _controls: Label
var _settings_return: StringName = &"title"
var _last_result: MissionResult
var _result_pending := false


func _ready() -> void:
	if save_manager == null:
		save_manager = SaveManager
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 80
	add_to_group(&"scene_director")
	EventBus.mission_event.connect(_on_mission_event)
	_build_shell()
	show_title()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		if screen == &"playing":
			var player := mission.get_node_or_null("Player") if is_instance_valid(mission) else null
			if player != null and not (player.get_node("StateMachine") as PlayerStateMachine).is_dead():
				show_pause()
		elif screen == &"pause":
			resume_mission()
		elif screen == &"settings":
			_close_settings()
		get_viewport().set_input_as_handled()


func show_title() -> void:
	_clear_mission()
	_page(&"title", &"app.title", &"app.eyebrow")
	_label(&"app.subtitle", 18)
	_label(&"app.build", 14)
	if SaveManager.load_notice == &"recovered":
		_label(&"settings.recovery_notice", 16)
	elif SaveManager.load_notice == &"corrupt_backed_up":
		_label(&"settings.corrupt_notice", 16)
	if SaveManager.last_error != OK:
		_label(&"settings.save_failed", 16)
	_button(&"nav.start", show_mission_select)
	_button(&"nav.settings", show_settings)
	_button(&"nav.quit", func() -> void: get_tree().quit())
	_focus_first()


func show_mission_select() -> bool:
	_clear_mission()
	_page(&"select", &"select.title", &"select.eyebrow")
	_label(&"practice.title", 28)
	_label(&"practice.summary", 18)
	_label(&"practice.tools", 15)
	var best: Dictionary = save_manager.campaign().get("mission_results", {}).get("practice", {})
	if not best.is_empty():
		var rank := GameText.get_text(StringName("result.rank." + String(best.get("rank", "shoden"))))
		_raw_label(GameText.get_text(&"select.best") % rank, 18)
	_button(&"practice.start", func() -> void: start_mission(PRACTICE))
	_content.add_child(HSeparator.new())
	_label(&"mission.tutorial", 28)
	_label(&"tutorial.summary", 18)
	var tutorial_best: Dictionary = save_manager.campaign().get("mission_results", {}).get("m01", {})
	if not tutorial_best.is_empty():
		var rank := GameText.get_text(StringName("result.rank." + String(tutorial_best.get("rank", "shoden"))))
		_raw_label(GameText.get_text(&"select.best") % rank, 18)
	_button(&"tutorial.start", func() -> void: start_mission(TUTORIAL))
	_content.add_child(HSeparator.new())
	_label(&"m02.title", 28)
	_label(&"m02.summary", 18)
	_button(&"m02.start", func() -> void: start_mission(RESIDENCE))
	_content.add_child(HSeparator.new())
	_label(&"campaign.pending", 22)
	_label(&"campaign.detail", 15)
	_button(&"nav.back", show_title)
	_focus_first()
	return true


func start_mission(next_definition: MissionDefinition = PRACTICE) -> bool:
	if next_definition == null or next_definition.level_scene == null:
		show_mission_select()
		_label(&"error.load", 16)
		return false
	_clear_mission()
	_result_recorded = false
	definition = next_definition
	MissionDirector.start_mission(definition)
	mission = definition.level_scene.instantiate()
	mission.name = "Mission"
	get_parent().add_child(mission)
	screen = &"playing"
	_result_pending = false
	_menu.hide()
	_hud.show()
	_controls.text = GameText.with_bindings(&"hud.controls")
	_update_objective()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	return true


func show_pause() -> void:
	if not is_instance_valid(mission):
		return
	get_tree().paused = true
	_page(&"pause", &"pause.title", &"pause.eyebrow")
	_button(&"nav.resume", resume_mission)
	_button(&"nav.retry", request_checkpoint_retry)
	_button(&"nav.settings", show_settings)
	_button(&"nav.abandon", show_mission_select)
	_focus_first()


func resume_mission() -> void:
	if not is_instance_valid(mission):
		return
	screen = &"playing"
	_menu.hide()
	_hud.show()
	_controls.text = GameText.with_bindings(&"hud.controls")
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func request_checkpoint_retry() -> bool:
	if not is_instance_valid(mission):
		return false
	var flow := mission.get_node_or_null("Player/RetryFlow") as PlayerRetryFlow
	return flow.request_retry() if flow != null else false


func retry_from_checkpoint(snapshot: Dictionary) -> bool:
	if definition == null or not is_instance_valid(mission) or not CheckpointSnapshot.is_valid(snapshot, mission.scene_file_path):
		return false
	var retained_definition := definition
	var retained := snapshot.duplicate(true)
	# start_mission clears old mission-local state; the new player's deferred ready restores it.
	var pending := PlayerRetryFlow.pending_scene
	var requested_usec := PlayerRetryFlow.retry_started_usec
	if not start_mission(retained_definition):
		return false
	PlayerRetryFlow.pending_scene = pending
	PlayerRetryFlow.retry_started_usec = requested_usec
	GameState.checkpoint_ref = retained
	get_tree().paused = true
	return true


func show_settings() -> void:
	_settings_return = screen
	_page(&"settings", &"settings.title", &"app.subtitle")
	var controller := get_tree().get_first_node_in_group(&"settings_controller") as SettingsController
	if controller == null:
		_label(&"settings.unavailable", 18)
		_button(&"nav.back", _close_settings)
	else:
		var host := Control.new()
		host.custom_minimum_size.y = 430
		_content.add_child(host)
		var panel := SettingsPanel.new()
		panel.configure(controller)
		host.add_child(panel)
		panel.closed.connect(_close_settings)
	_focus_first()


func _close_settings() -> void:
	match _settings_return:
		&"pause": show_pause()
		&"select": show_mission_select()
		_: show_title()


func show_result() -> void:
	if not is_instance_valid(mission):
		return
	_last_result = MissionDirector.build_result()
	if not _result_recorded and _last_result.flags.get("completed", false):
		var first_clear: bool = not save_manager.campaign().get("mission_results", {}).has(String(definition.id))
		save_manager.record_mission_result(definition.id, _last_result, first_clear)
		save_manager.commit()
		_result_recorded = true
	get_tree().paused = true
	_page(&"results", &"result.title", &"result.success" if _last_result.flags.get("completed", false) else &"result.failed")
	if save_manager.last_error != OK:
		_label(&"settings.save_failed", 16)
	_label(StringName("result.rank.%s" % _last_result.rank), 52)
	_raw_label(GameText.get_text(&"result.score") % _last_result.score, 22)
	var cfg := Tuning.scoring()
	var points := [cfg.shadow_walker_points, cfg.no_traces_points, cfg.one_strike_points, cfg.swift_points, cfg.side_objective_bonus]
	var next_goal: StringName = &"result.all_done"
	for index in FLAG_IDS.size():
		var flag := FLAG_IDS[index]
		var label := GameText.get_text(StringName("result.flag.%s" % flag))
		var achieved := bool(_last_result.flags.get(flag, false))
		if flag == &"side_objective" and definition.side_objective == null:
			_raw_label(GameText.get_text(&"result.flag_na") % label, 18)
		else:
			_raw_label(GameText.get_text(&"result.flag_pass") % [label, points[index]] if achieved else GameText.get_text(&"result.flag_fail") % label, 18)
			if not achieved and next_goal == &"result.all_done":
				next_goal = StringName("result.next.%s" % flag)
	_raw_label(GameText.get_text(&"result.nontarget") % MissionDirector.stats().nontarget_kills, 16)
	_label(&"result.next", 16)
	_label(next_goal, 18)
	_button(&"nav.restart", func() -> void: start_mission(definition))
	_button(&"nav.to_select", show_mission_select)
	_focus_first()


func _on_mission_event(event: StringName, _payload: Dictionary) -> void:
	if not is_instance_valid(mission):
		return
	if event in [EventBus.EV_OBJECTIVE_CHANGED, EventBus.EV_OBJECTIVE_COMPLETED]:
		_update_objective()
		if MissionDirector.current_objective() == null and not _result_pending:
			_result_pending = true
			show_result.call_deferred()


func _update_objective() -> void:
	var objective := MissionDirector.current_objective()
	_objective.text = GameText.get_text(objective.text_key) if objective != null else ""


func _clear_mission() -> void:
	AudioDirector.play_bgm_set(&"silence")
	AudioDirector.set_ambience(&"")
	if is_instance_valid(mission):
		MissionDirector.fail_mission(&"abandoned")
		mission.get_parent().remove_child(mission)
		mission.queue_free()
	mission = null
	set_mission_hint("")
	GameState.checkpoint_ref.clear()
	PlayerRetryFlow.pending_scene = ""
	_result_pending = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _build_shell() -> void:
	_menu = Control.new()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.theme = GameUi.theme()
	add_child(_menu)
	var art := TextureRect.new()
	art.texture = BACKGROUND
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(art)
	var shade := ColorRect.new()
	shade.color = Color(0.035, 0.04, 0.045, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	_menu.add_child(margin)
	get_tree().root.min_size = Vector2i(640, 360)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	margin.add_child(scroll)
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(row)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_content = VBoxContainer.new()
	_content.custom_minimum_size = Vector2(400, 0)
	_content.add_theme_constant_override("separation", 8)
	var panel := PanelContainer.new()
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color(0.065, 0.075, 0.07, 0.94)
	paper.border_color = Color("756d5b")
	paper.set_border_width_all(1)
	paper.content_margin_left = 24
	paper.content_margin_right = 24
	paper.content_margin_top = 16
	paper.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", paper)
	row.add_child(panel)
	panel.add_child(_content)
	_hud = Control.new()
	_hud.theme = _menu.theme
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud)
	var hud_margin := MarginContainer.new()
	hud_margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hud_margin.add_theme_constant_override("margin_left", 24)
	hud_margin.add_theme_constant_override("margin_top", 20)
	hud_margin.add_theme_constant_override("margin_right", 24)
	_hud.add_child(hud_margin)
	var hud_stack := VBoxContainer.new()
	hud_margin.add_child(hud_stack)
	_objective = Label.new()
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud_stack.add_child(_objective)
	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_color_override("font_color", Color("e6c289"))
	hud_stack.add_child(_hint)
	_controls = Label.new()
	_controls.text = GameText.with_bindings(&"hud.controls")
	_controls.add_theme_font_size_override("font_size", 14)
	_controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud_stack.add_child(_controls)


func _page(next_screen: StringName, title: StringName, eyebrow: StringName) -> void:
	screen = next_screen
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_menu.show()
	_hud.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_label(eyebrow, 15)
	_label(title, 36)


func _label(key: StringName, font_size: int) -> Label:
	return _raw_label(GameText.get_text(key), font_size)


func _raw_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", roundi(font_size * 0.8) if get_tree().root.size.y < 500 else font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(label)
	return label


func _button(key: StringName, action: Callable) -> Button:
	var button := Button.new()
	button.text = GameText.get_text(key)
	if get_tree().root.size.y < 500:
		button.add_theme_font_size_override("font_size", 14)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	_content.add_child(button)
	return button


func _focus_first() -> void:
	for child in _content.get_children():
		if child is Button:
			_focus_if_visible.call_deferred(child)
			return


func _focus_if_visible(control: Control) -> void:
	if is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree():
		control.grab_focus()


func set_mission_hint(text: String) -> void:
	if _hint != null:
		_hint.text = text
		_hint.visible = not text.is_empty()
