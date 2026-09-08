extends Node

var _tree: SceneTree
var _player: CutscenePlayer
var _failures := 0
var _output := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_tree = get_tree()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="):
			_output = argument.trim_prefix("--output-dir=")
	_run.call_deferred()

func _run() -> void:
	_tree.create_timer(40.0, true).timeout.connect(func():
		printerr("CUTSCENE_SMOKE_TIMEOUT")
		_tree.quit(2))
	_tree.root.gui_embed_subwindows = true
	if not _output.is_empty():
		_check(DirAccess.make_dir_recursive_absolute(_output) == OK, "output directory")
	_player = CutscenePlayer.new()
	add_child(_player)
	var data: CutsceneData = load("res://data/narrative/cutscenes/sample.tres")
	_check(_player.play(data), "sample starts")
	await _frames(6)
	_check(_player.subtitle.text == "雪の夜。遠い灯りだけが、城下の眠りを守っていた。", "Japanese narration")
	await _shot("narration.png")
	for button: Control in _player.get_node("Toolbar").get_children():
		_check(button.get_global_rect().end.x <= _tree.root.size.x - 16, "toolbar fits viewport")
	await _tap(KEY_SPACE)
	_check(_player.current_line == 1 and _player.speaker.visible, "accept advances to named dialogue")
	await _shot("dialogue.png")
	await _tap(KEY_SPACE)
	_check(_player.current_line == 2 and _player.subtitle.has_theme_font_override("font"), "accept advances to pale slanted inner speech")
	await _shot("inner.png")
	await _tap(KEY_ESCAPE)
	_check(_player.skip_pending, "Esc requests confirmation")
	await _shot("skip-confirmation.png")
	await _tap(KEY_ESCAPE)
	_check(not _player.skip_pending and _player.active and _player.current_line == 2, "Esc cancels without changing line")
	await _tap(KEY_SPACE)
	_check(not _player.active and not _tree.paused, "manual completion restores world")
	_check(_player.play(data), "replay starts")
	await _tap(KEY_ESCAPE)
	await _tap(KEY_ENTER)
	_check(not _player.active and not _tree.paused, "confirmation accepts through keyboard")
	_check(_player.play(data), "hold replay starts")
	_key(KEY_SPACE, true)
	await _tree.create_timer(0.85, true).timeout
	_key(KEY_SPACE, false)
	_check(not _player.active, "held accept fast forwards to completion")
	_check(_player.play(data, true), "reduced scene starts")
	await _click(_player._auto_button)
	_check(_player.auto_enabled, "mouse toggles auto")
	await _tree.create_timer(12.4, true).timeout
	_check(not _player.active and not _tree.paused, "auto completes on actual elapsed time")
	print("CUTSCENE_SMOKE_RESULT failures=", _failures)
	_tree.quit(0 if _failures == 0 else 1)

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func _tap(code: Key) -> void:
	_key(code, true)
	await _frames(2)
	_key(code, false)
	await _frames(3)

func _frames(count: int) -> void:
	for index in range(count):
		await _tree.process_frame

func _shot(filename: String) -> void:
	if _output.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var capture := _tree.root.get_texture().get_image()
	_check(capture != null and capture.save_png(_output.path_join(filename)) == OK, "capture " + filename)

func _check(passed: bool, message: String) -> void:
	if not passed:
		_failures += 1
		printerr("CUTSCENE_SMOKE_FAILED ", message)

func _click(button: Button) -> void:
	var position := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	Input.parse_input_event(motion)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		Input.parse_input_event(event)
		await _frames(2)
