extends Node3D

## Native interaction/retry fixture with live AI. Player placement, timed enemy
## attack and final assassination are explicit setup, not a stealth-clear proof.
class VolatileStore extends "res://src/autoload/save_manager.gd":
	func commit() -> void: last_error = OK

var output := "user://temple180"
var failures: Array[String] = []
var samples: Dictionary = {}
var director: SceneDirector

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(output)
	get_tree().create_timer(120.0,true,false,true).timeout.connect(func() -> void:
		FileAccess.open(output+"/timeout.json",FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"samples":samples,"error":"Native fixture exceeded 120 wall seconds"},"  "))
		get_tree().quit(1))
	DisplayServer.window_set_size(Vector2i(1440,900))
	var started := Time.get_ticks_msec()
	var store := VolatileStore.new()
	store.save_path = "user://temple180-smoke-only.json"
	add_child(store)
	var main: Node = load("res://src/ui/main.tscn").instantiate()
	director = main.get_node("SceneDirector")
	director.save_manager = store
	add_child(main)
	_check(director.start_mission(load("res://data/missions/m04.tres")),"Start M4")
	await _frames(8)
	var level := director.mission as Node3D
	var player := level.get_node("Player") as PlayerController
	var boss := level.get_node("Population/Tetsusenbo") as Tetsusenbo
	_check((player.get_node("RetryFlow") as PlayerRetryFlow).capture_checkpoint(&"before_combat"),"Initial checkpoint")
	player.global_position = boss.global_position+Vector3(0,0,1.2)
	player.rotation.y = 0
	await _key(KEY_R)
	await _mouse(MOUSE_BUTTON_LEFT)
	_check(boss.health() == 8,"Frontal sword strike is guarded")
	player.global_position = Vector3(12,0.02,88)
	await get_tree().create_timer(1.1).timeout
	player.global_position = boss.global_position+Vector3(0,0,1.2)
	await _mouse(MOUSE_BUTTON_RIGHT)
	_check(not boss.combat().attack(player),"Mapped parry prevents the timed boss attack")
	_check((player.get_node("AssassinationResolver/Combat") as PlayerCombat).health() == 3,"Parry retains player health")
	await _mouse(MOUSE_BUTTON_LEFT)
	_check(boss.health() == 7,"Mapped counterattack damages Tetsusenbo")
	samples.combat = {"boss_health_after_counter":boss.health(),"player_health":(player.get_node("AssassinationResolver/Combat") as PlayerCombat).health()}
	await _retry("combat")
	level = director.mission as Node3D
	player = level.get_node("Player") as PlayerController
	_check((level.get_node("Population/Tetsusenbo") as Tetsusenbo).health() == 8,"Retry restores guarded boss health")
	player.global_position = Vector3(26,4.02,54)
	await _key(KEY_E)
	_check(GameState.area_alert_level == 1,"Bell increases area alert once")
	await _key(KEY_E)
	_check(GameState.area_alert_level == 1,"Second E cannot ring the bell again")
	player.global_position = Vector3(76,5.02,36.3)
	await _key(KEY_E)
	_check(level.get_node("Mission/Retainers/RetainerA").rescued,"Mapped E frees retainer A")
	player.global_position = Vector3(12,0.02,88)
	_check((player.get_node("RetryFlow") as PlayerRetryFlow).capture_checkpoint(&"partial_rescue"),"Partial-rescue checkpoint")
	await _retry("partial_rescue")
	level = director.mission as Node3D
	player = level.get_node("Player") as PlayerController
	_check(level.get_node("Mission/Retainers/RetainerA").rescued,"Retry retains partial rescue")
	_check(not level.get_node("Mission/Retainers/RetainerB").rescued,"Retry retains captive B")
	_check(not level.get_node("Population/Duties").call("use_bell"),"Retry retains used bell")
	player.global_position = Vector3(82,5.02,36.3)
	await _key(KEY_E)
	_check(level.get_node("Mission/Retainers/RetainerB").rescued,"Mapped E frees retainer B")
	player.global_position = Vector3(12,0.02,88)
	await _shot(Vector3(74,6,28),Vector3(80,5,35),"rescue.png")
	var departure := float(level.get_node("Population").call("schedule_elapsed"))
	Engine.time_scale = 4.0
	while not MissionDirector.stats().side_objective_completed and float(level.get_node("Population").call("schedule_elapsed"))-departure < 100.0:
		await get_tree().physics_frame
	Engine.time_scale = 1.0
	_check(MissionDirector.stats().side_objective_completed,"Both retainers physically reach the ground exit")
	samples.escape_sim_seconds = float(level.get_node("Population").call("schedule_elapsed"))-departure
	boss = level.get_node("Population/Tetsusenbo") as Tetsusenbo
	_check(boss.begin_assassination(&"back"),"Assassination fixture defeats the target")
	await _key(KEY_E)
	var deadline := Time.get_ticks_msec()+6000
	while director.screen != &"results" and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	_check(director.screen == &"results","Escape reaches actual result UI")
	if director.screen == &"results":
		samples.score = director._last_result.score
		samples.flags = director._last_result.flags.duplicate(true)
		await _screen("result.png")
		_check(store.campaign().mission_results.get("m04",{}).get("first_clear_flags",{}).get("side_objective",false),"First-clear rescue outcome reaches save store")
		_check(director.continue_from_result(),"Continue to H3")
		var narrative := director.get_node_or_null("HideoutPlayer") as CutscenePlayer
		if narrative == null:
			failures.append("Missing H3 player")
		else:
			_check(narrative._data.slides[0].lines[-1].text_key == &"hideout.h3.rescued","H3 uses rescued outcome")
			for line in range(6): narrative.advance()
			await _screen("h3.png")
	var result := {"scope":"Native mapped R/E and mouse combat, live retainer navigation at 4x, actual scene replacement and result/H3 UI; player placement, timed boss attack and assassination are fixtures; volatile save; not normal stealth completion", "wall_seconds":float(Time.get_ticks_msec()-started)/1000,"samples":samples,"failures":failures}
	FileAccess.open(output+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("TEMPLE_MECHANICS ",JSON.stringify(result))
	director.show_title()
	await _frames(2)
	get_tree().quit(0 if failures.is_empty() else 1)

func _retry(label: String) -> void:
	var previous := director.mission.get_instance_id()
	var flow := director.mission.get_node("Player/RetryFlow") as PlayerRetryFlow
	_check(flow.request_retry(),label+" retry accepted")
	await _frames(15)
	_check(director.mission.get_instance_id() != previous,label+" scene replaced")
	_check(not get_tree().paused,label+" restore did not pause on error")
	samples[label+"_retry_ms"] = PlayerRetryFlow.last_retry_elapsed_ms

func _check(condition: bool,message: String) -> void:
	if not condition: failures.append(message)

func _frames(count: int) -> void:
	for frame in range(count): await get_tree().physics_frame

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	get_viewport().push_input(event,true)
	var actions: Array[StringName] = []
	for action in InputMap.get_actions():
		if InputMap.event_is_action(event,action): actions.append(action)
	for frame in range(2):
		for action in actions: Input.action_press(action)
		await get_tree().physics_frame
	event = InputEventKey.new()
	event.physical_keycode = code
	get_viewport().push_input(event,true)
	for action in actions: Input.action_release(action)
	await _frames(2)

func _mouse(button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	get_viewport().push_input(event,true)
	await _frames(2)
	event = InputEventMouseButton.new()
	event.button_index = button
	get_viewport().push_input(event,true)
	await _frames(2)

func _screen(filename: String) -> void:
	await get_tree().create_timer(0.8,true,false,true).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output+"/"+filename)

func _shot(point: Vector3,toward: Vector3,filename: String) -> void:
	var previous := get_viewport().get_camera_3d()
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = point
	camera.look_at(toward)
	camera.make_current()
	await _screen(filename)
	if is_instance_valid(previous): previous.make_current()
	camera.queue_free()
