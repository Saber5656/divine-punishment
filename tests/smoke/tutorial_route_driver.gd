extends Node

class RuntimeResultStore extends Node:
	var last_error: Error = OK
	var results := {}
	func campaign() -> Dictionary: return {"mission_results": results}
	func record_mission_result(id: StringName, result: RefCounted, _first_clear: bool) -> void:
		results[String(id)] = {"rank": result.rank, "score": result.score}
	func commit() -> void: pass

var director: SceneDirector
const DEFINITION := preload("res://data/missions/tutorial.tres")
var level: TutorialLevel
var player: PlayerController
var records: Array[Dictionary] = []
var started_usec: int
var failed := false
var waypoint := ""
var _mouse_buttons := 0


func _ready() -> void:
	started_usec = Time.get_ticks_usec()
	process_mode = Node.PROCESS_MODE_ALWAYS
	var main := preload("res://src/ui/main.tscn").instantiate()
	var result_store := RuntimeResultStore.new()
	add_child(result_store)
	director = main.get_node("SceneDirector")
	director.save_manager = result_store
	add_child(main)
	director.start_mission(DEFINITION)
	level = director.mission
	player = level.actors.player
	level.learning_observed.connect(func(id: StringName, evidence: Dictionary):
		records.append({"objective": String(id), "evidence": evidence, "elapsed_sec": _elapsed()})
		print("TUTORIAL_LEARNING ", JSON.stringify(records[-1]))
	)
	EventBus.noise_emitted.connect(func(event: NoiseEvent):
		if event.kind == Enums.NoiseKind.TOOL:
			print("TUTORIAL_IMPACT ", event.position, " radius=", event.radius))
	_run.call_deferred()


func _run() -> void:
	await _frames(4)
	var resume_file := OS.get_environment("TUTORIAL_DEBUG_CHECKPOINT")
	if not resume_file.is_empty():
		var snapshot: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(resume_file))
		if not CheckpointSnapshot.restore(snapshot, player, DEFINITION.level_scene.resource_path) or not level.restore_checkpoint_world(snapshot):
			_finish(false, "debug checkpoint restore failed")
			return
		await _frames(4)
		await _run_exit()
		return
	await _tap(&"stance_toggle")
	if not await _walk(Vector3(0, 0.9, -5), "moonlit_path"): return
	if not await _walk(Vector3(-3, 0.9, -12), "tree_shadow"): return
	if not _expect(&"tutorial_hide", "crouch and shadow"): return
	if not await _walk(Vector3(0, 0.9, -20), "cliff_entry"): return
	if not await _walk(Vector3(-5.7, 0.9, -28), "brush"): return
	await _tap(&"interact")
	if not player.is_hidden():
		_finish(false, "hide input did not enter Hidden")
		return
	await _frames(600)
	await _tap(&"interact")
	if not await _walk(Vector3(-6, 0.9, -33), "peek_corner"): return
	await _tap(&"interact")
	_press(&"peek", true)
	_press(&"move_left", true)
	await _frames(8)
	print("PEEK_DEBUG ", player.camera_peek_offset(), " axis=", Input.get_axis(&"move_left", &"move_right"), " flags=", [level._hidden_passed, level._exited_hide, level._peeked], " pressed=", Input.is_action_pressed(&"peek"))
	_press(&"peek", false)
	_press(&"move_left", false)
	if not _expect(&"tutorial_lure", "hide patrol and peek"): return
	await _tap(&"sprint")
	if player.state_machine.current_state() == PlayerStateMachine.STATE_GROUND:
		await _tap(&"stance_toggle")
	if not await _walk(Vector3(0, 0.9, -40), "gravel_entry"): return
	if not await _walk(Vector3(0, 0.9, -50), "stone_throw"): return
	await _throw_at(Vector3(1, 0.05, -55))
	for frame in range(600):
		if level._objective_id() == &"tutorial_lights": break
		await _frames(1)
	if not _expect(&"tutorial_lights", "gravel and stone lure"): return
	if OS.get_environment("TUTORIAL_UNTIL") == "lure":
		_finish(true, "first three production-input lessons")
		return
	if not await _walk(Vector3(8, 0.9, -51), "hut_door_west"): return
	if not await _walk(Vector3(12, 0.9, -51), "hut_door_east"): return
	if not await _walk(Vector3(13, 0.9, -52), "first_lantern"): return
	await _tap(&"interact")
	if not await _walk(Vector3(20, 0.9, -51), "hut_north_cover"): return
	if not await _walk(Vector3(22, 0.9, -54.8), "second_lantern"): return
	await _tap(&"interact")
	await _frames(3)
	if not _expect(&"tutorial_assassinate", "two actual lights extinguished"): return
	if not await _backstab_target(): return
	for frame in range(180):
		if player.state_machine.current_state() != PlayerStateMachine.STATE_ASSASSINATE: break
		await _frames(1)
	if not _expect(&"tutorial_body", "back assassination"): return
	if not await _walk(level.actors.patrol_d.global_position, "body_pickup", 0.8): return
	await _tap(&"interact")
	if not player.is_carrying_body():
		_finish(false, "actual body pickup failed")
		return
	if not await _walk(Vector3(14, 0.9, -62), "body_storage"): return
	await _tap(&"interact")
	if not _expect(&"tutorial_document", "body stored"): return
	if not await _walk(Vector3(16, 0.9, -63.5), "document"): return
	await _tap(&"interact")
	if not _expect(&"tutorial_escape", "document interact"): return
	if not await _walk(Vector3(12, 0.9, -67), "route_choice"): return
	var checkpoint_path := OS.get_environment("TUTORIAL_RESULT") + ".checkpoint.json"
	if OS.get_environment("TUTORIAL_RESULT").is_empty(): checkpoint_path = "user://tutorial-checkpoint.json"
	var checkpoint_file := FileAccess.open(checkpoint_path, FileAccess.WRITE)
	checkpoint_file.store_string(JSON.stringify(GameState.checkpoint_ref, "\t"))
	checkpoint_file.close()
	await _run_exit()


func _run_exit() -> void:
	if not await _walk(Vector3(12, 0.9, -67), "exit_approach"): return
	if OS.get_environment("TUTORIAL_ROUTE") == "roof":
		if not await _walk(Vector3(20, 0.9, -67), "roof_edge"): return
		await _tap(&"interact")
		print("CLIMB_DEBUG ", player.state_machine.current_state(), " nearest=", player._nearest_climb_edge(), " clearance=", player._has_standing_clearance(), " carry=", player.is_carrying_body())
		_press(&"move_forward", true)
		for frame in range(300):
			await _frames(1)
			if player.state_machine.current_state() != PlayerStateMachine.STATE_CLIMB: break
		_press(&"move_forward", false)
		await _frames(2)
		if not level._roof_climbed:
			_finish(false, "production climb did not reach roof")
			return
		if not await _walk(Vector3(3, 3.9, -71), "roof_walk"): return
		if not await _walk(Vector3(3, 0.9, -81), "roof_drop_exit"): return
	else:
		if not await _walk(Vector3(8, 0.9, -67), "gate_lure_position"): return
		await _throw_at(Vector3(4, 0.05, -59))
		await _frames(300)
		if not await _walk(Vector3(8, 0.9, -67), "gate_lantern"): return
		await _tap(&"interact")
		if not await _walk(Vector3(8, 0.9, -81), "ground_exit"): return
	await _frames(3)
	_finish(MissionDirector.build_result().flags.completed, "all lessons and " + String(level.chosen_route) + " escape")


func _backstab_target() -> bool:
	var target: EnemyBase = level.actors.patrol_d
	var resolver: AssassinationResolver = player.get_node("AssassinationResolver")
	for attempt in range(1200):
		if player.is_defeated():
			_finish(false, "defeated during back approach")
			return false
		var context: StringName = resolver.prompt_context()
		if context == &"back":
			_press(&"move_forward", false)
			await _tap(&"assassinate")
			await _frames(3)
			return target.is_assassinated()
		var destination := target.global_position + target.global_basis.z * 1.0
		var offset := destination - player.global_position
		offset.y = 0
		_look(atan2(-offset.x, -offset.z), 0)
		_press(&"move_forward", offset.length() > 0.15)
		await _frames(1)
	_finish(false, "no eligible backstab during physical approach")
	return false


func _walk(target: Vector3, label: String, tolerance: float = 0.3) -> bool:
	waypoint = label
	var previous := player.global_position
	var stalled := 0
	for frame in range(1800):
		if level._failed or player.is_defeated():
			_finish(false, "mission failed at " + label)
			return false
		var difference := target - player.global_position
		difference.y = 0
		if difference.length() < tolerance:
			_press(&"move_forward", false)
			await _frames(2)
			print("TUTORIAL_WAYPOINT ", label, " ", player.global_position)
			await _capture(label)
			return true
		_look(atan2(-difference.x, -difference.z), 0.0)
		_press(&"move_forward", true)
		await _frames(1)
		if player.global_position.distance_to(previous) < 0.001:
			stalled += 1
		else:
			stalled = 0
		previous = player.global_position
		if stalled > 180:
			_finish(false, "blocked waypoint " + label)
			return false
	_finish(false, "timeout waypoint " + label)
	return false


func _look(yaw: float, pitch: float) -> void:
	var sensitivity := Tuning.camera().mouse_look_sensitivity
	var yaw_change := clampf(wrapf(yaw - player.rotation.y, -PI, PI), -0.2, 0.2)
	var pitch_change := clampf(pitch - player.camera_rig.rotation.x, -0.2, 0.2)
	var motion := InputEventMouseMotion.new()
	motion.screen_relative = Vector2(-yaw_change / sensitivity, -pitch_change / sensitivity)
	motion.relative = motion.screen_relative
	motion.button_mask = _mouse_buttons
	Input.parse_input_event(motion)


func _throw_at(target: Vector3) -> void:
	_press(&"aim", true)
	var rig: ToolRig = player.get_node("ToolRig")
	for frame in range(90):
		var origin: Vector3 = rig.camera().global_position
		var offset := target - origin
		var distance := Vector2(offset.x, offset.z).length()
		var speed := rig.selected_definition().projectile_speed
		var gravity := rig.selected_definition().trajectory_gravity
		var discriminant := pow(speed, 4) - gravity * (gravity * distance * distance + 2 * offset.y * speed * speed)
		var pitch := atan((speed * speed - sqrt(maxf(0, discriminant))) / (gravity * maxf(distance, 0.1)))
		_look(atan2(-offset.x, -offset.z), pitch)
		await _frames(1)
	print("TOOL_DEBUG aiming=", rig.is_aiming(), " carry=", player.is_carrying_body(), " selected=", rig.selected_definition().id, " can_use=", rig.inventory.can_use())
	await _tap(&"tool_use")
	_press(&"aim", false)
	print("TUTORIAL_STONE ", rig.current_aim(), " remaining=", rig.remaining_count())


func _tap(action: StringName) -> void:
	_press(action, true)
	await _frames(2)
	_press(action, false)
	await _frames(2)


func _press(action: StringName, pressed: bool) -> void:
	for binding in InputMap.action_get_events(action):
		if binding is InputEventKey or binding is InputEventMouseButton:
			var event: InputEvent = binding.duplicate()
			event.pressed = pressed
			if event is InputEventMouseButton:
				var bit: int = 1 << (event.button_index - 1)
				_mouse_buttons = (_mouse_buttons | bit) if pressed else (_mouse_buttons & ~bit)
				event.button_mask = _mouse_buttons
			Input.parse_input_event(event)
			return
	_finish(false, "missing physical input binding " + String(action))


func _frames(count: int) -> void:
	for frame in range(count):
		await get_tree().physics_frame


func _expect(objective: StringName, description: String) -> bool:
	if level._objective_id() == objective:
		return true
	_finish(false, "unmet " + description)
	return false


func _elapsed() -> float:
	return float(Time.get_ticks_usec() - started_usec) / 1000000.0


func _finish(passed: bool, reason: String) -> void:
	if failed:
		return
	failed = not passed
	for action in [&"move_forward", &"move_left", &"peek", &"aim", &"tool_use", &"interact", &"stance_toggle", &"sprint"]:
		_press(action, false)
	var result := {"passed": passed, "debug_checkpoint": not OS.get_environment("TUTORIAL_DEBUG_CHECKPOINT").is_empty(), "reason": reason, "waypoint": waypoint, "elapsed_sec": _elapsed(), "time_scale": Engine.time_scale, "screen": String(director.screen), "objective": String(level._objective_id()), "player_position": [player.position.x, player.position.y, player.position.z], "player_state": String(player.state_machine.current_state()), "learned": records, "visibility": [level._min_visibility, level._max_visibility], "hidden": [level._hidden_seconds, level._hidden_patrol_distance], "gravel": level._gravel_heard, "sentry_position": str(level.actors.guard_c.position), "sentry_state": level.actors.guard_c.brain().current_state(), "sentry_focus": str(level.actors.guard_c.brain().investigation_position())}
	var output := OS.get_environment("TUTORIAL_RESULT")
	if output.is_empty(): output = "user://tutorial-runtime-result.json"
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("TUTORIAL_RUNTIME_RESULT ", JSON.stringify(result))
	await _capture("result")
	get_tree().quit(0 if passed else 1)


func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless" or OS.get_environment("TUTORIAL_RESULT").is_empty(): return
	await RenderingServer.frame_post_draw
	var shot := get_viewport().get_texture().get_image()
	shot.save_png(OS.get_environment("TUTORIAL_RESULT") + "." + label + ".png")
