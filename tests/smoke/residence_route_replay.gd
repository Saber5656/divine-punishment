extends SceneTree
var OUT := "user://route-review/"
const MOVES = [&"move_left",&"move_right",&"move_forward",&"move_backward"]
var player
var director
var mission
var started = 0
var deadline = 0
var last_note = 0
var failures = []
var min_breath = 100.0
var exhausted = false
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="): OUT=argument.trim_prefix("--output-dir=").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(OUT)
	run.call_deferred()
func run() -> void:
	pass
func isolate_save() -> void:
	var save = root.get_node("SaveManager")
	save.save_path = OUT+"save.json"
	save.load_save()

func note(label: String) -> void:
	print(JSON.stringify({"event":label,"wall_seconds":(Time.get_ticks_msec()-started)/1000.0,"player":str(player.global_position) if is_instance_valid(player) else "","state":player.state_machine.current_state() if is_instance_valid(player) else "","detections":root.get_node("MissionDirector").stats().detections,"target":str(mission.target.global_position) if is_instance_valid(mission) else ""}))
func frame() -> void:
	await physics_frame
	if is_instance_valid(player):
		min_breath=minf(min_breath,player.breath_remaining())
		exhausted=exhausted or player.is_forced_surfacing()
	if Time.get_ticks_msec()-last_note>15000:
		last_note=Time.get_ticks_msec()
		note("heartbeat")
func stop() -> void:
	for action in MOVES: Input.action_release(action)
	Input.action_release(&"sprint")
func pulse(action: StringName) -> void:
	var event = InputEventAction.new()
	event.action=action
	event.pressed=true
	Input.parse_input_event(event)
	await frame()
	await frame()
	event=InputEventAction.new()
	event.action=action
	event.pressed=false
	Input.parse_input_event(event)
	await frame()
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")
func move(point: Vector3,seconds = 30.0) -> bool:
	var until = mini(deadline,Time.get_ticks_msec()+int(seconds*1000))
	while Time.get_ticks_msec()<until:
		if director.screen == &"results":
			stop()
			return true
		var delta=point-player.global_position
		delta.y=0
		if delta.length()<0.2:
			stop()
			note("arrived "+str(point))
			return true
		var local=player.global_basis.inverse()*delta.normalized()
		stop()
		Input.action_press(&"move_right" if local.x>0 else &"move_left",absf(local.x))
		Input.action_press(&"move_backward" if local.z>0 else &"move_forward",absf(local.z))
		await frame()
	stop()
	failures.append("move timeout "+str(point))
	note("move_failed")
	return false
