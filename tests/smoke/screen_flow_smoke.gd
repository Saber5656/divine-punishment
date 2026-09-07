extends Node


@onready var _tree: SceneTree = get_tree()
var _failures := 0
var _output := ""
var _minimum_seconds := 0.0
var _started := 0
var _cycles := 0
var _retry_ms: Array[float] = []
var _director: SceneDirector


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="):
			_output = argument.trim_prefix("--output-dir=")
		elif argument.begins_with("--minimum-seconds="):
			_minimum_seconds = float(argument.trim_prefix("--minimum-seconds="))
	_detach.call_deferred()


func _detach() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_parent().remove_child(self)
	_tree.root.add_child(self)
	_run()


func _run() -> void:
	_started = Time.get_ticks_msec()
	if not _output.is_empty():
		_check(DirAccess.make_dir_recursive_absolute(_output) == OK, "screenshot directory available")
	_tree.create_timer(maxf(90.0, _minimum_seconds + 90.0), true).timeout.connect(func() -> void:
		printerr("SCREEN_SMOKE_TIMEOUT")
		_tree.quit(2))
	_check(_tree.change_scene_to_file("res://src/ui/main.tscn") == OK, "Main opens")
	await _frames(8)
	_director = _tree.current_scene.get_node("SceneDirector")
	_check(GameText.get_text(&"app.title") == "天罰", "Japanese text survives export")
	for control in _director._content.get_children():
		_check(control.get_global_rect().position.y >= 28 and control.get_global_rect().end.y <= _tree.root.size.y - 28, "title controls fit minimum window")
	await _shot("title.png")
	_press_button(&"nav.start")
	await _frames(3)
	_check(_director.screen == &"select", "title to selection")
	await _shot("select.png")
	_press_button(&"practice.start")
	await _frames(8)
	await _shot("practice.png")
	await _tap(KEY_ESCAPE)
	_check(_director.screen == &"pause" and _tree.paused, "Esc opens pause")
	await _shot("pause.png")
	_press_button(&"nav.settings")
	await _frames(4)
	_check(_director.screen == &"settings", "settings opens from pause")
	await _shot("settings.png")
	await _tap(KEY_ESCAPE)
	_check(_director.screen == &"pause", "Esc returns to pause")
	var main_id := _tree.current_scene.get_instance_id()
	_press_button(&"nav.retry")
	await _frames(12)
	_check(_tree.current_scene.get_instance_id() == main_id and not _tree.paused, "pause retry preserves Main")
	_retry_ms.append(PlayerRetryFlow.last_retry_elapsed_ms)
	var player := _director.mission.get_node("Player") as PlayerController
	(player.get_node("AssassinationResolver/Combat") as PlayerCombat).receive_damage(20)
	await _tree.create_timer(0.8, true).timeout
	var flow := player.get_node("RetryFlow") as PlayerRetryFlow
	_check(flow.choices_visible(), "death choices available")
	await _shot("death.png")
	flow._retry_button.emit_signal("pressed")
	await _frames(12)
	_retry_ms.append(PlayerRetryFlow.last_retry_elapsed_ms)
	_check(_director.screen == &"playing" and not _tree.paused, "death retry returns to play")
	while true:
		await _play_loop()
		_cycles += 1
		print("SCREEN_SMOKE_CYCLE ", _cycles, " elapsed_sec=", (Time.get_ticks_msec() - _started) / 1000.0)
		if _failures > 0 or (Time.get_ticks_msec() - _started) / 1000.0 >= _minimum_seconds:
			break
		_press_button(&"practice.start")
		await _frames(8)
		await _tap(KEY_ESCAPE)
		_press_button(&"nav.resume")
		await _frames(3)
	_director.show_mission_select()
	_press_button(&"practice.start")
	await _frames(8)
	await _tap(KEY_ESCAPE)
	_press_button(&"nav.abandon")
	await _frames(5)
	_check(_director.screen == &"select" and _director.mission == null, "abandon returns to selection")
	for elapsed in _retry_ms:
		_check(elapsed > 0 and elapsed < 3000, "rendered retry below 3 seconds")
	print("SCREEN_SMOKE_RESULT ", JSON.stringify({"failures": _failures, "cycles": _cycles, "elapsed_sec": (Time.get_ticks_msec() - _started) / 1000.0, "retry_ms": _retry_ms, "renderer": DisplayServer.get_name(), "runtime": Engine.get_version_info()["string"]}))
	_tree.quit(0 if _failures == 0 else 1)


func _play_loop() -> void:
	var player := _director.mission.get_node("Player") as PlayerController
	var target := _director.mission.get_node("Target") as TargetNpc
	# Every approach/escape is physical WASD input; no teleport or direct objective completion.
	await _tap(KEY_C)
	await _move(KEY_W, func() -> bool: return player.global_position.z <= target.global_position.z + 1.1)
	await _frames(4)
	print("SCREEN_SMOKE_BACKSTAB position=", player.global_position, " yaw=", player.rotation.y, " target=", target.global_position, " context=", (player.get_node("AssassinationResolver") as AssassinationResolver).evaluate(target), " state=", player.state_machine.current_state())
	await _tap(KEY_F)
	await _tree.create_timer(2.2, true).timeout
	_check(target.is_target_defeated(), "actual forward-facing F input defeats target")
	if not target.is_target_defeated():
		return
	await _move(KEY_S, func() -> bool: return player.global_position.z >= 6.0)
	await _move(KEY_D, func() -> bool: return player.global_position.x >= 5.5 or _director.screen == &"results")
	await _frames(8)
	_check(_director.screen == &"results", "physical escape reaches result")
	if _director.screen != &"results":
		return
	_check(_director._last_result.flags.get("completed", false), "result is mission-complete")
	if _cycles == 0:
		await _shot("result.png")
	_press_button(&"nav.to_select")
	await _frames(5)


func _move(key: Key, arrived: Callable) -> void:
	var started := Time.get_ticks_msec()
	_key(key, true)
	while not arrived.call() and Time.get_ticks_msec() - started < 12000:
		await _tree.physics_frame
	_key(key, false)
	_check(arrived.call(), "movement reaches destination key=%s" % key)
	await _frames(2)


func _key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)


func _tap(key: Key) -> void:
	_key(key, true)
	await _frames(2)
	_key(key, false)
	await _frames(3)


func _press_button(key: StringName) -> void:
	var expected := GameText.get_text(key)
	for node in _director._content.find_children("*", "Button", true, false):
		if node.text == expected:
			node.emit_signal("pressed")
			return
	_check(false, "button found: " + expected)


func _frames(count: int) -> void:
	for index in count:
		await _tree.physics_frame
		await _tree.process_frame


func _shot(filename: String) -> void:
	if DisplayServer.get_name() == "headless" or _output.is_empty():
		return
	await RenderingServer.frame_post_draw
	var capture := _tree.root.get_texture().get_image()
	if capture != null:
		_check(capture.save_png(_output.path_join(filename)) == OK, "screenshot saved: " + filename)


func _check(passed: bool, message: String) -> void:
	if not passed:
		_failures += 1
		printerr("SCREEN_SMOKE_FAILED ", message)
