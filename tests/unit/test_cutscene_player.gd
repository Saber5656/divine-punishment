extends GutTest

var _player: Control

func _start() -> bool:
	var path := "res://src/ui/cutscene_player.gd"
	assert_true(ResourceLoader.exists(path), "CutscenePlayer is available")
	if not ResourceLoader.exists(path):
		return false
	_player = load(path).new()
	add_child_autofree(_player)
	return true

func _sample() -> Resource:
	return load("res://data/narrative/cutscenes/sample.tres")

func after_each() -> void:
	if is_instance_valid(_player):
		_player.stop()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func test_sample_schema_and_manual_completion() -> void:
	if not _start(): return
	var data := _sample()
	assert_eq(data.id, &"sample")
	assert_true(_player.play(data))
	assert_true(get_tree().paused)
	assert_eq(_player.current_line, 0)
	watch_signals(_player)
	for count in range(3): _player.advance()
	assert_false(_player.active)
	assert_signal_emit_count(_player, "finished", 1)
	assert_false(get_tree().paused)
	_player.advance()
	assert_signal_emit_count(_player, "finished", 1)

func test_invalid_resource_does_not_claim_pause() -> void:
	if not _start(): return
	var data: Resource = load("res://src/core/narrative/cutscene_data.gd").new()
	assert_false(_player.play(data))
	assert_false(get_tree().paused)
	assert_false(_player.play(null))
	data = _sample().duplicate(true)
	data.slides[0].lines[0].text_key = &""
	assert_false(_player.play(data))

func test_auto_hold_and_skip_confirmation_do_not_race() -> void:
	if not _start(): return
	assert_true(_player.play(_sample()))
	_player.set_auto(true)
	_player.request_skip()
	_player.advance_time(30.0, true)
	assert_eq(_player.current_line, 0)
	_player.confirm_skip(false)
	_player.advance_time(4.1, false)
	assert_eq(_player.current_line, 1)
	_player.set_auto(false)
	_player.advance_time(0.3, true)
	assert_eq(_player.current_line, 1)
	_player.advance_time(0.3, true)
	assert_eq(_player.current_line, 2)
	_player.request_skip()
	watch_signals(_player)
	_player.confirm_skip(true)
	assert_signal_emitted_with_parameters(_player, "finished", [&"sample", true])

func test_reduced_mode_and_prior_pause_restore() -> void:
	if not _start(): return
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var prior_mouse := Input.mouse_mode # Headless display may reject capture.
	assert_true(_player.play(_sample(), true))
	_player.advance_time(4.0, false)
	assert_eq(_player.image_view.scale, Vector2.ONE)
	_player.stop()
	assert_true(get_tree().paused)
	assert_eq(Input.mouse_mode, prior_mouse)

func test_slide_transition_updates_ambience_and_unskippable_guard() -> void:
	if not _start(): return
	var data := _sample().duplicate(true)
	data.skippable = false
	data.slides.append(data.slides[0].duplicate(true))
	data.slides[0].ambience = AudioStreamWAV.new()
	assert_true(_player.play(data))
	assert_not_null(_player.ambience.stream)
	_player.request_skip()
	assert_false(_player.skip_pending)
	for count in range(3): _player.advance()
	assert_eq(_player.current_slide, 1)
	assert_null(_player.ambience.stream)
	assert_true(_player.active)

func test_styles_motion_and_repeated_play_preserve_ownership() -> void:
	if not _start(): return
	assert_true(_player.play(_sample()))
	assert_false(_player.play(_sample()))
	assert_false(_player.speaker.visible)
	_player.advance_time(2.0, false)
	assert_gt(_player.image_view.scale.x, 1.0)
	_player.advance()
	assert_true(_player.speaker.visible)
	assert_eq(_player.speaker.text, "使いの者")
	_player.advance()
	assert_false(_player.speaker.visible)
	assert_true(_player.subtitle.has_theme_font_override("font"))
	_player.stop()
	assert_false(_player.ambience.playing)
	assert_false(get_tree().paused)
	assert_true(_player.play(_sample()))
	assert_false(_player.subtitle.has_theme_font_override("font"))
	_player.get_parent().remove_child(_player)
	assert_false(get_tree().paused)
	_player.free()

func test_invalid_duration_and_unnamed_dialogue_fail_before_playback() -> void:
	if not _start(): return
	var data := _sample().duplicate(true)
	data.slides[0].duration_auto = NAN
	assert_false(_player.play(data))
	data.slides[0].duration_auto = 12.0
	data.slides[0].lines[1].speaker_key = &""
	assert_false(_player.play(data))

func test_reduced_mode_rejects_background_changes() -> void:
	if not _start(): return
	var data := _sample().duplicate(true)
	data.slides.append(data.slides[0].duplicate(true))
	assert_false(_player.play(data, true), "hideout mode accepts one fixed background")
