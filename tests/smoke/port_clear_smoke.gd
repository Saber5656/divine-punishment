extends "res://tests/smoke/port_routes_smoke.gd"

class VolatileStore extends Node:
	var last_error := OK
	var rows := {"unlocked_mission":3,"mission_results":{}}
	func campaign() -> Dictionary: return rows
	func record_mission_result(id,result,_first) -> void:
		rows.mission_results[String(id)] = {"score":result.score,"flags":result.flags}
	func commit() -> void: pass

var director: SceneDirector
var level: PortStorehouse
var player: PlayerController
var mission: Node
var screams := 0
var min_breath := INF
var max_visibility := 0.0
var stages: Array = []
var ending := false
var narrative := {}
var store: VolatileStore
var inspect_approach := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
		if arg.begins_with("--route="): route_id = arg.trim_prefix("--route=")
		if arg == "--inspect-approach": inspect_approach = true
	DirAccess.make_dir_recursive_absolute(output)
	SaveManager.save_path = "user://port173-clear-smoke-only.json"
	var main: Node = load("res://src/ui/main.tscn").instantiate()
	add_child(main)
	director = main.get_node("SceneDirector") as SceneDirector
	store = VolatileStore.new()
	add_child(store)
	director.save_manager = store
	director.show_mission_select()
	var board := director.find_children("*","CampaignSelection",true,false)[0] as CampaignSelection
	board.select_mission(2)
	if board.start_button.disabled:
		push_error("Unlocked M3 campaign slot is not playable")
		get_tree().quit(1)
		return
	board.start_button.pressed.emit()
	level = director.mission as PortStorehouse
	player = level.get_node("Player") as PlayerController
	mission = level.get_node("Mission")
	player.state_machine.state_changed.connect(func(_from,to): states.append(to))
	EventBus.mission_event.connect(func(event,_payload):
		if event == &"civilian_scream": screams += 1)
	for frame in range(8): await get_tree().physics_frame
	started = Time.get_ticks_msec()
	_record("start")
	if route_id == "C": await _approach_c()
	elif route_id == "B": await _approach_b()
	else:
		await _key(KEY_C)
		for destination in level.route_waypoints(&"A_pier").slice(1,6): await _walk_to(player,destination)
		await _walk_to(player,Vector3(66,3.02,15.2))
	_record("approach")
	if inspect_approach:
		var debug := main.get_node("StealthDebugOverlay") as StealthDebugOverlay
		debug.set_debug_visible(true)
		for frame in range(3): await get_tree().process_frame
		var file := FileAccess.open(output+"/perception.json",FileAccess.WRITE)
		file.store_string(JSON.stringify({"scope":"read-only developer approach visualization; not a complete clear","geometry":debug.debug_geometry_snapshot(),"lights":debug.light_radius_snapshot(),"enemies":debug.enemy_debug_snapshot(),"visibility":debug.player_visibility_value(),"noise":debug.active_noise_radii(),"stages":stages},"  "))
		await _shot("debug-approach")
		get_tree().quit()
		return
	await _shot("approach")
	if route_id == "B": await _throw_smoke(Vector3(66,6.1,14))
	var resolver := player.get_node("AssassinationResolver") as AssassinationResolver
	for frame in range(8): await get_tree().physics_frame
	print("PORT_CLEAR_PROMPT ",resolver.prompt_context()," target=",resolver.prompt_enemy()," actual=",mission.target.global_position)
	await _key(KEY_F)
	for frame in range(4): await get_tree().physics_frame
	var overlay := player.get_node_or_null("NarrativeOverlay") as NarrativeOverlay
	if overlay != null: narrative = {"inner":overlay.monologue_text(),"last_words":overlay.last_words_text()}
	for frame in range(100): await get_tree().physics_frame
	_record("assassination")
	await _shot("assassination")
	if not mission.target.is_target_defeated():
		failures.append("Mapped F did not assassinate the target")
		await _finish()
		return
	if route_id == "C":
		await _walk_to(player,Vector3(77,1.72,14))
		await _key(KEY_E)
		for point in [Vector3(84,0,14),Vector3(81,0,14),Vector3(81,0,3),Vector3(52,0,3),Vector3(48,0,27),Vector3(48,0,43.5),Vector3(58,0,43.5),Vector3(58,0,30),Vector3(58,3,22)]: await _walk_to(player,point)
	elif route_id == "B":
		await _walk_to(player,Vector3(66.6,3.02,14))
		for frame in range(45): await get_tree().physics_frame
	await _walk_to(player,Vector3(68,3.02,13.2))
	await _key(KEY_E)
	_record("ledger")
	if not mission.ledger_collected: failures.append("Mapped E did not collect the ledger")
	if route_id == "B": await _throw_smoke(Vector3(68,2.15,17))
	for point in [Vector3(68,3,21),Vector3(58,3,22),Vector3(58,1.5,26),Vector3(55,0,26),Vector3(52,0,26),Vector3(52,0,3),Vector3(81,0,3),Vector3(88,-1.65,3),Vector3(88,-1.65,18)]: await _walk_to(player,point)
	for frame in range(12): await get_tree().physics_frame
	await _finish()

func _approach_b() -> void:
	var route := level.route_waypoints(&"B_roofs")
	for destination in route.slice(1,4): await _walk_to(player,destination)
	await _key(KEY_E)
	var remaining := 20.0
	while remaining > 0 and player.global_position.distance_to(route[5]) > 0.15:
		Input.action_press(&"move_forward")
		await get_tree().physics_frame
		remaining -= get_physics_process_delta_time()
	Input.action_release(&"move_forward")
	await _key(KEY_SHIFT)
	for destination in route.slice(6,-1): await _walk_to(player,destination)
	await _key(KEY_E)
	remaining = 10.0
	while remaining > 0 and player.global_position.distance_to(Vector3(66,7,14)) > 0.08:
		Input.action_press(&"move_forward")
		await get_tree().physics_frame
		remaining -= get_physics_process_delta_time()
	Input.action_release(&"move_forward")

func _approach_c() -> void:
	for point in [Vector3(12,0,60),Vector3(12,0,64),Vector3(20,-1.65,64),Vector3(88,-1.65,64),Vector3(88,-1.65,60)]: await _walk_to(player,point)
	await _key(KEY_C)
	await _walk_to(player,Vector3(88,-3.7,40))
	await _key(KEY_C)
	for point in [Vector3(88,-1.65,18),Vector3(80,0,18),Vector3(80,0,16),Vector3(85,0,16),Vector3(85,0,14),Vector3(78.5,1.72,14)]: await _walk_to(player,point)
	await _key(KEY_E)
	await _walk_to(player,Vector3(66,1.72,14))

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player) or ending or started == 0: return
	min_breath = minf(min_breath,player.breath_remaining())
	max_visibility = maxf(max_visibility,(player.get_node("Visibility") as PlayerVisibility).visibility())
	if player.state_machine.is_dead() or Time.get_ticks_msec()-started > 600000:
		ending = true
		failures.append("Player died or the 10-minute automated replay deadline expired")
		_finish.call_deferred()

func _walk_to(actor: PlayerController,destination: Vector3) -> bool:
	var remaining := maxf(15.0,actor.global_position.distance_to(destination)/0.8+10.0)
	while remaining > 0.0 and director.screen == &"playing" and not actor.state_machine.is_dead():
		var difference := destination-actor.global_position
		difference.y = 0
		if difference.length() < 0.15: break
		Input.action_press(&"move_forward")
		actor.rotation.y = atan2(-difference.x,-difference.z)
		await get_tree().physics_frame
		remaining -= get_physics_process_delta_time()
	Input.action_release(&"move_forward")
	for frame in range(2): await get_tree().physics_frame
	if remaining <= 0:
		failures.append("Movement blocked approaching "+str(destination)+" at "+str(actor.global_position))
		_write_result(actor)
		get_tree().quit(1)
		return false
	print("PORT_WAYPOINT ",destination," position=",actor.global_position," state=",actor.state_machine.current_state())
	return true

func _record(stage: String) -> void:
	stages.append({"stage":stage,"seconds":float(Time.get_ticks_msec()-started)/1000,"position":str(player.global_position),"detections":MissionDirector.stats().detections,"screams":screams})
	print("PORT_CLEAR_STAGE ",JSON.stringify(stages[-1]))

func _throw_smoke(point: Vector3) -> void:
	var rig := player.get_node("ToolRig") as ToolRig
	for attempt in range(3):
		if rig.selected_definition().id == &"smoke": break
		await _key(KEY_Q)
	var before := rig.remaining_count()
	_mouse(MOUSE_BUTTON_RIGHT,true)
	for frame in range(45):
		Input.action_press(&"aim")
		var offset := point-rig.camera().global_position
		var distance := Vector2(offset.x,offset.z).length()
		var speed := rig.selected_definition().projectile_speed
		var gravity := rig.selected_definition().trajectory_gravity
		var discriminant := pow(speed,4)-gravity*(gravity*distance*distance+2*offset.y*speed*speed)
		var pitch := atan((speed*speed-sqrt(maxf(0,discriminant)))/(gravity*maxf(distance,0.1)))
		var yaw_change := clampf(wrapf(atan2(-offset.x,-offset.z)-player.rotation.y,-PI,PI),-0.2,0.2)
		var pitch_change := clampf(pitch-player.camera_rig.rotation.x,-0.2,0.2)
		var motion := InputEventMouseMotion.new()
		motion.screen_relative = Vector2(-yaw_change,-pitch_change)/Tuning.camera().mouse_look_sensitivity
		motion.relative = motion.screen_relative
		motion.button_mask = MOUSE_BUTTON_MASK_RIGHT
		get_viewport().push_input(motion,true)
		await get_tree().physics_frame
	_mouse(MOUSE_BUTTON_LEFT,true)
	for frame in range(2): await get_tree().physics_frame
	_mouse(MOUSE_BUTTON_LEFT,false)
	_mouse(MOUSE_BUTTON_RIGHT,false)
	Input.action_release(&"aim")
	if rig.remaining_count() != before-1: failures.append("Mapped smoke throw did not consume exactly one smoke bomb")
	print("PORT_SMOKE ",point," remaining=",rig.remaining_count()," volumes=",get_tree().get_nodes_in_group(&"smoke_volumes").size())

func _mouse(button: MouseButton,pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	get_viewport().push_input(event,true)

func _shot(name_: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output+"/"+name_+".png")

func _finish() -> void:
	ending = true
	if director.screen != &"results": failures.append("Mission did not reach results")
	if MissionDirector.stats().detections != 0: failures.append("Enemies detected the player")
	if MissionDirector.stats().civilian_kills != 0: failures.append("A civilian died")
	_write_result(player)
	await _shot("final")
	get_tree().paused = false
	get_tree().quit(failures.size())

func _write_result(actor: PlayerController) -> void:
	var stats := MissionDirector.stats()
	var result := {"route":route_id,"failures":failures,"screen":director.screen,"seconds":float(Time.get_ticks_msec()-started)/1000,"position":str(actor.global_position),"state":actor.state_machine.current_state(),"detections":stats.detections,"civilian_kills":stats.civilian_kills,"nontarget_kills":stats.nontarget_kills,"screams":screams,"min_breath":min_breath,"max_visibility":max_visibility,"states":states,"stages":stages,"method":"Unlocked campaign board via Main/SceneDirector; normal mapped input, physical movement and turning, live AI/time/perception; no actor placement or direct kill"}
	var file := FileAccess.open(output+"/result.json",FileAccess.WRITE)
	result["narrative"] = narrative
	result["save"] = store.rows
	if file != null: file.store_string(JSON.stringify(result,"  "))
	print("PORT_CLEAR_RESULT ",JSON.stringify(result))
