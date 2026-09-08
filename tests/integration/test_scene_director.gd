extends GutTest




class ResultStore extends Node:
	var last_error: Error = OK
	var rows := {"mission_results": {}}
	var commits := 0
	func campaign() -> Dictionary:
		return rows
	func record_mission_result(id: StringName, result: RefCounted, _first_clear: bool) -> void:
		rows.mission_results[String(id)] = {"rank": result.rank, "score": result.score}
	func commit() -> void:
		commits += 1


var _main: Node
var _director: SceneDirector
var _store: ResultStore


func before_each() -> void:
	_main = load("res://src/ui/main.tscn").instantiate()
	_director = _main.get_node("SceneDirector") as SceneDirector
	_store = ResultStore.new()
	add_child_autofree(_store)
	_director.set("save_manager", _store)
	add_child_autofree(_main)
	await get_tree().process_frame


func after_each() -> void:
	_director._clear_mission()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_title_selection_and_failed_load_have_actionable_routes() -> void:
	assert_eq(_director.screen, &"title")
	assert_eq(GameText.get_text(&"app.title"), "天罰")
	assert_true(_director.show_mission_select())
	assert_eq(_director.screen, &"select")
	assert_false(_director.start_mission(MissionDefinition.new()))
	assert_eq(_director.screen, &"select")
	assert_null(_director.mission)


func test_pause_freezes_world_then_retry_recreates_only_mission_child() -> void:
	assert_true(_director.start_mission())
	await get_tree().process_frame
	await get_tree().physics_frame
	var main_id := _main.get_instance_id()
	var mission_id := _director.mission.get_instance_id()
	_director.show_pause()
	var elapsed := MissionDirector.stats().elapsed_sec
	await get_tree().create_timer(0.05, true).timeout
	assert_eq(MissionDirector.stats().elapsed_sec, elapsed)
	assert_eq(_director.screen, &"pause")
	assert_true(_director.request_checkpoint_retry())
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	assert_eq(_main.get_instance_id(), main_id)
	assert_ne(_director.mission.get_instance_id(), mission_id)
	assert_eq(_director.screen, &"playing")
	assert_false(get_tree().paused)
	assert_eq(GameState.checkpoint_ref["scene"], SceneDirector.PRACTICE.level_scene.resource_path)
	_director.show_pause()
	_director.resume_mission()
	assert_false(get_tree().paused)
	_director.show_mission_select()
	assert_null(_director.mission)
	assert_true(GameState.checkpoint_ref.is_empty())


func test_production_assassination_escape_and_results_complete_a_real_loop() -> void:
	assert_true(_director.start_mission())
	await get_tree().physics_frame
	await get_tree().process_frame
	var mission := _director.mission
	var player := mission.get_node("Player") as PlayerController
	var target := mission.get_node("Target") as TargetNpc
	mission._on_escape_entered(player)
	assert_eq(MissionDirector.current_objective().id, &"practice_target")
	player.set_physics_process(false)
	player.global_position = target.global_position + Vector3(0, 0, 1.1)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var resolver := player.get_node("AssassinationResolver") as AssassinationResolver
	assert_eq(resolver.evaluate(target), &"back", "Player faces -Z into the enemy's back")
	var action := InputEventKey.new()
	action.physical_keycode = KEY_F
	action.pressed = true
	Input.parse_input_event(action)
	await get_tree().process_frame
	action = InputEventKey.new()
	action.physical_keycode = KEY_F
	action.pressed = false
	Input.parse_input_event(action)
	await get_tree().create_timer(2.2).timeout
	assert_true(target.is_target_defeated())
	assert_eq(MissionDirector.current_objective().id, &"practice_escape")
	player.global_position = mission.get_node("Escape").global_position
	for index in 8:
		await get_tree().physics_frame
		await get_tree().process_frame
		if _director.screen == &"results":
			break
	assert_eq(_director.screen, &"results")
	assert_null(MissionDirector.current_objective())
	assert_true(_director._last_result.flags[&"completed"])
	assert_true(_director._last_result.flags[&"one_strike"])
	_director.show_mission_select()
	assert_eq(_director.screen, &"select")


func test_externalized_retry_text_exists_and_csv_is_shipped_in_all_exports() -> void:
	for key: StringName in [&"death.title", &"nav.retry", &"error.restore", &"death.abandoned"]:
		assert_ne(GameText.get_text(key), String(key))
	var config := ConfigFile.new()
	assert_eq(config.load("res://export_presets.cfg"), OK)
	for index in 3:
		assert_true("data/text/*.csv" in config.get_value("preset.%d" % index, "include_filter"))


func test_settings_actions_are_localized_and_panel_fits_its_host() -> void:
	assert_false(SettingsController.actions().has(&"ui_text_backspace_all_to_left"))
	for action in SettingsController.actions():
		assert_ne(GameText.get_text(StringName("input." + String(action))), "input." + String(action))
	_director.show_settings()
	for frame in 4:
		await get_tree().process_frame
	var panels := _director._content.find_children("*", "Control", true, false)
	for candidate in panels:
		if candidate is SettingsPanel:
			var panel := candidate as SettingsPanel
			for slider in panel.find_children("*", "HSlider", true, false):
				assert_lte(slider.get_global_rect().end.x, panel.get_global_rect().end.x)


func test_completed_result_records_once_and_selection_shows_best_rank() -> void:
	assert_true(_director.start_mission())
	await get_tree().process_frame
	MissionDirector.complete_objective(&"practice_target")
	MissionDirector.complete_objective(&"practice_escape")
	await get_tree().process_frame
	assert_eq(_store.commits, 1)
	assert_true(_store.rows.mission_results.has("practice"))
	_director.show_result()
	assert_eq(_store.commits, 1, "reopening the result is not another save")
	_director.show_mission_select()
	var expected_rank := GameText.get_text(StringName("result.rank." + String(_store.rows.mission_results.practice.rank)))
	var found := false
	for child in _director._content.get_children():
		if child is Label and expected_rank in child.text:
			found = true
	assert_true(found, "selection shows the recorded rank")


func test_mission_selection_can_start_tutorial_from_its_button() -> void:
	_director.show_mission_select()
	var found: Button
	for node in _director.find_children("*", "Button", true, false):
		if node.text == GameText.get_text(&"tutorial.start"): found = node
	assert_not_null(found)
	if found == null: return
	found.pressed.emit()
	await get_tree().physics_frame
	assert_eq(_director.screen, &"playing")
	assert_eq(MissionDirector.active_mission_id(), &"m01")
	assert_eq(MissionDirector.current_objective().id, &"tutorial_sneak")


func test_settings_remap_is_reflected_when_playing_hud_is_shown_again() -> void:
	assert_true(_director.start_mission())
	await get_tree().process_frame
	await get_tree().physics_frame
	_director.show_pause()
	var controller: SettingsController = _main.get_node("SettingsController")
	var previous: Dictionary = controller.values().input_overrides.duplicate(true)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_J
	assert_true(controller.set_binding(&"stance_toggle", key))
	_director.resume_mission()
	var explanation := ""
	for node in _director.find_children("*", "Label", true, false):
		if node.text.contains("しゃがむ"): explanation = node.text
	assert_true(explanation.contains("J"), "the newly applied crouch key must be shown on return from settings")
	assert_false(explanation.contains("Physical"))
	controller.values().input_overrides = previous
	assert_true(controller.apply_all())
