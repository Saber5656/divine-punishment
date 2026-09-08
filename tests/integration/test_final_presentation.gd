extends GutTest

func test_detection_effect_is_bounded_and_assassination_contexts_restore_camera() -> void:
	var path := "res://src/ui/gameplay_presentation.gd"
	assert_true(FileAccess.file_exists(path), "Gameplay presentation must be implemented")
	if not FileAccess.file_exists(path): return
	var player = load("res://src/player/player.tscn").instantiate()
	add_child_autofree(player)
	await get_tree().process_frame
	player.set_physics_process(false)
	var rig = player.get_node("CameraRig")
	var camera: Camera3D = rig.get_node("SpringArm3D/Camera3D")
	var fov := camera.fov
	var fx = rig.get_node("GameplayPresentation")
	fx.set_process(false)
	EventBus.player_detected.emit()
	assert_gt(fx.alarm_strength, 0.0)
	assert_true(AudioDirector.get_node("Stinger").playing)
	fx.advance(1.0)
	assert_eq(fx.alarm_strength, 0.0)
	for context in [&"back", &"above", &"below", &"corner"]:
		assert_true(rig.begin_assassination_blend(context, 1.25))
		rig.set_assassination_progress(0.5)
		assert_lt(camera.fov, fov)
		assert_gt(fx.focus_strength, 0.0)
		rig.end_assassination_blend()
		assert_almost_eq(camera.fov, fov, 0.001)
		assert_eq(fx.focus_strength, 0.0)

func test_rank_reveal_completes_while_tree_is_paused_and_cannot_hide_final_text() -> void:
	var path := "res://src/ui/result_reveal.gd"
	assert_true(FileAccess.file_exists(path), "Result reveal must be implemented")
	if not FileAccess.file_exists(path): return
	var label := Label.new()
	label.text = "皆伝"
	add_child_autofree(label)
	var reveal = load(path).new()
	label.add_child(reveal)
	reveal.start(label)
	assert_lt(label.modulate.a, 1.0)
	get_tree().paused = true
	await get_tree().create_timer(1.2, true).timeout
	assert_eq(label.text, "皆伝")
	assert_almost_eq(label.modulate.a, 1.0, 0.001)
	assert_eq(label.scale, Vector2.ONE)
	get_tree().paused = false

func test_results_initial_focus_keeps_rank_visible_before_navigation() -> void:
	var main = load("res://src/ui/main.tscn").instantiate()
	add_child_autofree(main)
	var director = main.get_node("SceneDirector")
	director.start_mission()
	await get_tree().process_frame
	director.show_result()
	for frame in range(4): await get_tree().process_frame
	var rank = director.find_child("Rank", true, false)
	assert_eq(get_viewport().gui_get_focus_owner(), rank, "Rank should be initial focus, so small windows do not scroll past it")
	director._clear_mission()
	get_tree().paused = false
