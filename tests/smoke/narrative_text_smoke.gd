extends Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var output := "user://narrative59"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(output)
	SaveManager.save_path = "user://narrative59-smoke-only.json"
	SaveManager.settings()["inner_monologue"] = true
	var main := load("res://src/ui/main.tscn").instantiate() as Node
	add_child(main)
	var director := main.get_node("SceneDirector") as SceneDirector
	var failures := 0
	director.start_mission(load("res://data/missions/m02.tres"))
	for frame in range(8): await get_tree().physics_frame
	var player := director.mission.get_node("Player") as PlayerController
	var target := get_tree().get_first_node_in_group(&"m02_target") as TargetNpc
	for enemy in get_tree().get_nodes_in_group(&"enemies"):
		if enemy is EnemyBase:
			enemy.brain().set_physics_process(false)
			if enemy != target: enemy.global_position += Vector3(80,0,80)
	target.brain().force_state(Enums.AlertState.UNAWARE,&"fixture")
	target.set_target_routine_enabled(false)
	player.set_physics_process(false)
	player.global_position = target.global_position+target.global_basis.z*1.1
	player.global_rotation = target.global_rotation
	for frame in range(3): await get_tree().physics_frame
	for frame in range(3): await get_tree().process_frame
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F
	event.pressed = true
	get_viewport().push_input(event,true)
	await get_tree().process_frame
	event = InputEventKey.new()
	event.physical_keycode = KEY_F
	get_viewport().push_input(event,true)
	var overlay := player.get_node("NarrativeOverlay") as NarrativeOverlay
	if overlay.monologue_text().is_empty() or overlay.last_words_text().is_empty() or not target.is_target_defeated(): failures += 1
	overlay.set_process(false)
	for dimensions in [Vector2i(1280,720),Vector2i(640,360)]:
		DisplayServer.window_set_size(dimensions)
		for frame in range(8): await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output+"/dialogue-%d.png"%dimensions.x)
	var settings := get_tree().get_first_node_in_group(&"settings_controller") as SettingsController
	if not settings.apply_value("inner_monologue",false): failures += 1
	overlay.advance(0.0)
	if not overlay.monologue_text().is_empty() or overlay.last_words_text().is_empty(): failures += 1
	settings.apply_value("inner_monologue",true)
	overlay.advance(4.0)
	if not overlay.last_words_text().is_empty(): failures += 1
	MissionDirector.stats().nontarget_kills = 5
	director.show_result()
	DisplayServer.window_set_size(Vector2i(1280,720))
	for frame in range(8): await get_tree().process_frame
	var report := director.find_child("OkoReport",true,false) as Label
	if report == null or report.text != "……ずいぶん、殺したね": failures += 1
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output+"/result.png")
	print("NARRATIVE_TEXT_SMOKE ",JSON.stringify({"failures":failures,"target_defeated":target.is_target_defeated(),"report":report.text if report != null else "missing"}))
	get_tree().paused = false
	get_tree().quit(failures)
