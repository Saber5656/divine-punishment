class_name SceneDirector
extends CanvasLayer


const RESIDENCE: MissionDefinition = preload("res://data/missions/m02.tres")
const PRACTICE: MissionDefinition = preload("res://data/missions/practice.tres")
const TUTORIAL: MissionDefinition = preload("res://data/missions/tutorial.tres")
const BACKGROUND := preload("res://assets/samples/issue-77-pv/issue77-01-exterior.png")
const HIDEOUTS := {&"m02": preload("res://data/narrative/hideout/h1.tres"), &"m03": preload("res://data/narrative/hideout/h2.tres"), &"m04": preload("res://data/narrative/hideout/h3.tres"), &"m05": preload("res://data/narrative/hideout/h4.tres"), &"m06": preload("res://data/narrative/hideout/h5.tres"), &"m07": preload("res://data/narrative/hideout/h6.tres"), &"m08": preload("res://data/narrative/hideout/h7.tres"), &"m09": preload("res://data/narrative/hideout/h8.tres")}
const FLAG_IDS: Array[StringName] = [&"shadow_walker", &"no_traces", &"one_strike", &"swift", &"side_objective"]

var save_manager: Node
var _result_recorded := false
var screen: StringName = &"title"
var mission: Node
var definition: MissionDefinition
var _background: TextureRect
var _menu: Control
var _content: VBoxContainer
var _hud: Control
var _objective: Label
var _hint: Label
var _controls: Label
var _settings_return: StringName = &"title"
var _last_result: MissionResult
var _result_pending := false
var _first_clear_result := false
var _hideout_player: CutscenePlayer


func _ready() -> void:
	if save_manager == null:
		save_manager = SaveManager
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 80
	add_to_group(&"scene_director")
	EventBus.mission_event.connect(_on_mission_event)
	_build_shell()
	get_viewport().size_changed.connect(_update_menu_width)
	show_title()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		if _result_pending and screen == &"playing": return
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
	var board := CampaignSelection.new()
	board.name = "CampaignSelection"
	_content.add_child(board)
	board.configure(save_manager.campaign())
	board.mission_requested.connect(func(next: MissionDefinition) -> void:
		if CampaignCatalog.is_unlocked(next.id, save_manager.campaign()): start_mission(next))
	_update_menu_width()
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
	_first_clear_result = false
	definition = next_definition
	MissionDirector.start_mission(definition)
	mission = definition.level_scene.instantiate()
	mission.name = "Mission"
	get_parent().add_child(mission)
	if definition.weather != MissionDefinition.Weather.CLEAR:
		mission.add_child(WeatherPresentation.new())
	_apply_mission_loadout()
	screen = &"playing"
	_result_pending = false
	_menu.hide()
	_hud.show()
	_controls.text = GameText.with_bindings(&"hud.controls" if MissionDirector.allows_action(&"sword") else &"hud.controls.nonlethal")
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
	_controls.text = GameText.with_bindings(&"hud.controls" if MissionDirector.allows_action(&"sword") else &"hud.controls.nonlethal")
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
		_first_clear_result = first_clear
		save_manager.record_mission_result(definition.id, _last_result, first_clear)
		save_manager.commit()
		_result_recorded = true
	get_tree().paused = true
	_page(&"results", &"result.title", &"result.success" if _last_result.flags.get("completed", false) else &"result.failed")
	if save_manager.last_error != OK:
		_label(&"settings.save_failed", 16)
	var rank_label := _label(StringName("result.rank.%s" % _last_result.rank), 52)
	rank_label.name = "Rank"
	var reveal := ResultReveal.new()
	rank_label.add_child(reveal)
	reveal.start(rank_label)
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
	var non_target_kills := MissionDirector.stats().nontarget_kills
	_raw_label(GameText.get_text(&"result.nontarget") % non_target_kills, 16)
	var report := _raw_label(NarrativeText.oko_report(non_target_kills),20)
	report.name = "OkoReport"
	_label(&"result.next", 16)
	_label(next_goal, 18)
	_button(&"nav.restart", func() -> void: start_mission(definition))
	_button(&"hideout.continue" if _first_clear_result and HIDEOUTS.has(definition.id) else &"nav.to_select", continue_from_result)
	rank_label.focus_mode = Control.FOCUS_ALL
	_focus_if_visible.call_deferred(rank_label)


func _on_mission_event(event: StringName, payload: Dictionary) -> void:
	if not is_instance_valid(mission):
		return
	if event == EventBus.EV_MISSION_FAILED and payload.get("reason") == &"killing_forbidden":
		get_tree().paused = true
		_retry_forbidden_kill.call_deferred()
		return
	if event in [EventBus.EV_OBJECTIVE_CHANGED, EventBus.EV_OBJECTIVE_COMPLETED]:
		_update_objective()
		if MissionDirector.current_objective() == null and not _result_pending:
			_result_pending = true
			_show_result_after_narrative.call_deferred()


func _update_objective() -> void:
	var objective := MissionDirector.current_objective()
	_objective.text = GameText.get_text(objective.text_key) if objective != null else ""


func _clear_mission() -> void:
	WeatherSystem.start(MissionDefinition.Weather.CLEAR)
	_clear_hideout()
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
	_background = art
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
	_controls.text = GameText.with_bindings(&"hud.controls" if MissionDirector.allows_action(&"sword") else &"hud.controls.nonlethal")
	_controls.add_theme_font_size_override("font_size", 14)
	_controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud_stack.add_child(_controls)


func _page(next_screen: StringName, title: StringName, eyebrow: StringName) -> void:
	screen = next_screen
	_content.custom_minimum_size.x = 400
	_background.texture = title_background() if next_screen == &"title" else BACKGROUND
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

func continue_from_result() -> bool:
	if screen != &"results": return false
	if _first_clear_result and _last_result.flags.get("completed",false) and HIDEOUTS.has(definition.id):
		var scene: HideoutScene = HIDEOUTS[definition.id]
		var saved: Dictionary = save_manager.campaign().get("mission_results",{}).get(String(definition.id),{})
		var story_flags: Dictionary = saved.get("first_clear_flags",saved.get("flags",_last_result.flags))
		var data := scene.to_cutscene(int(save_manager.campaign().get("shura",0)),story_flags)
		_hideout_player = CutscenePlayer.new()
		_hideout_player.name = "HideoutPlayer"
		add_child(_hideout_player)
		_hideout_player.finished.connect(_on_hideout_finished)
		if not _hideout_player.play(data, true):
			_clear_hideout()
			return false
		screen = &"hideout"
		_menu.hide()
		_hud.hide()
		return true
	return show_mission_select()

func _on_hideout_finished(id: StringName, _skipped: bool) -> void:
	var campaign: Dictionary = save_manager.campaign()
	var seen: Array = campaign.get("seen_cutscenes",[])
	if not seen.has(String(id)):
		seen.append(String(id))
		campaign["seen_cutscenes"] = seen
		save_manager.commit()
	show_mission_select()

func _clear_hideout() -> void:
	if is_instance_valid(_hideout_player):
		_hideout_player.stop()
		remove_child(_hideout_player)
		_hideout_player.queue_free()
	_hideout_player = null

func title_background() -> Texture2D:
	return preload("res://assets/ui/spring_teahouse.svg") if CampaignCatalog.is_complete(save_manager.campaign()) else BACKGROUND

func _update_menu_width() -> void:
	if is_instance_valid(_content):
		_content.custom_minimum_size.x = minf(1000 if screen == &"select" else 400, maxf(280, get_viewport().get_visible_rect().size.x-104))

func _apply_mission_loadout() -> void:
	if definition.tool_loadout.is_empty(): return
	var rig := mission.get_node_or_null("Player/ToolRig") as ToolRig
	if rig == null: return
	var tools: Array[ToolDefinition] = []
	var counts: Dictionary = {}
	for id in definition.tool_loadout:
		if not MissionDirector.allows_action(StringName(id)): continue
		var path := "res://data/tools/%s.tres" % id
		if not ResourceLoader.exists(path): continue
		var tool := load(path) as ToolDefinition
		if tool == null: continue
		counts[tools.size()] = definition.tool_loadout[id]
		tools.append(tool)
	rig.inventory.slot_limit = clampi(tools.size(),ToolInventory.DEFAULT_SLOT_COUNT,ToolInventory.MAX_SLOT_COUNT)
	rig.inventory.loadout(tools,counts)

func _retry_forbidden_kill() -> void:
	if not is_instance_valid(mission): return
	if not request_checkpoint_retry():
		start_mission(definition)
	set_mission_hint(GameText.get_text(&"nonlethal.failed"))

func _show_result_after_narrative() -> void:
	var completed_mission := mission
	var delay := 0.0
	for overlay in get_tree().get_nodes_in_group(&"narrative_overlays"):
		if is_instance_valid(mission) and mission.is_ancestor_of(overlay):
			delay = maxf(delay,overlay.remaining_time())
			overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	if delay > 0.0:
		# Preserve the existing victory freeze while letting the final words finish.
		get_tree().paused = true
		await get_tree().create_timer(delay,true).timeout
	if is_instance_valid(completed_mission) and mission == completed_mission and _result_pending: show_result()
