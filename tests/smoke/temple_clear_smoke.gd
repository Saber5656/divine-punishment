extends "res://tests/smoke/temple_routes_smoke.gd"

## Normal-time campaign replay. Movement/traversal/combat use mapped controls;
## steering changes player heading, never actor position or AI state.
class VolatileStore extends "res://src/autoload/save_manager.gd":
	func commit() -> void: last_error = OK

var director: SceneDirector
var level: RainyTemple
var player: PlayerController
var mission: Node
var store: VolatileStore
var ending := false
var stages: Array[Dictionary] = []
var min_breath := INF
var max_visibility := 0.0
var narrative := {}
var main: Node
var roof_retry_ms := 0.0
var roof_checkpoint := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	output = "user://temple181"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
		if arg.begins_with("--route="): route_id = arg.trim_prefix("--route=")
	DirAccess.make_dir_recursive_absolute(output)
	DisplayServer.window_set_size(Vector2i(1440,900))
	store = VolatileStore.new()
	store.save_path = "user://temple181-smoke-only.json"
	add_child(store)
	store.campaign().unlocked_mission = 4
	main = load("res://src/ui/main.tscn").instantiate()
	director = main.get_node("SceneDirector")
	director.save_manager = store
	add_child(main)
	director.show_mission_select()
	var board := director.find_children("*","CampaignSelection",true,false)[0] as CampaignSelection
	board.select_mission(3)
	if board.start_button.disabled:
		failures.append("Unlocked M4 campaign slot is unavailable")
		get_tree().quit(1)
		return
	board.start_button.pressed.emit()
	level = director.mission as RainyTemple
	player = level.get_node("Player")
	mission = level.get_node("Mission")
	player.state_machine.state_changed.connect(func(_from,to): states.append(to))
	for frame in range(8): await get_tree().physics_frame
	started = Time.get_ticks_msec()
	_record("start")
	if route_id == "C":
		if not await _approach_cell(): return
		await _rescue()
		if ending: return
		for point in [Vector3(72,5.02,36.3),Vector3(72,5.02,30),Vector3(70,5.02,30),Vector3(64,4.02,38),Vector3(48,4.02,40),Vector3(48,8.02,32),Vector3(51,8.02,23.2)]:
			if not await _walk_to(player,point): return
	elif route_id == "B":
		if not await _approach_roof(): return
	else:
		await _key(KEY_C)
		for point in level.route_waypoints(&"A_steps").slice(1,-1):
			if not await _walk_to(player,point): return
		if not await _walk_to(player,Vector3(51,8.02,23.2)): return
	_record("approach")
	await _debug_shot()
	var resolver := player.get_node("AssassinationResolver") as AssassinationResolver
	print("TEMPLE_PROMPT ",resolver.prompt_context()," enemy=",resolver.prompt_enemy()," target=",mission.target.global_position)
	await _key(KEY_F)
	for frame in range(4): await get_tree().physics_frame
	var overlay := player.get_node("NarrativeOverlay") as NarrativeOverlay
	narrative = {"inner":overlay.monologue_text(),"last_words":overlay.last_words_text()}
	for frame in range(100): await get_tree().physics_frame
	_record("assassination")
	await _shot("assassination")
	if not mission.target.is_target_defeated():
		failures.append("Mapped F did not assassinate Tetsusenbo")
		await _finish()
		return
	if route_id == "B" and not await _retry_roof(): return
	if player.state_machine.current_state() == &"Beam": await _key(KEY_SHIFT)
	if player.state_machine.current_state() == &"Ground": await _key(KEY_C)
	for point in [Vector3(51,8.02,29),Vector3(48,8.02,32),Vector3(48,4.02,40),Vector3(48,4.02,58),Vector3(40,4.02,66),Vector3(40,0.02,84),Vector3(40,0.02,88),Vector3(12,0.02,88)]:
		if not await _walk_to(player,point): return
	if route_id == "C":
		var deadline := Time.get_ticks_msec()+100000
		while not MissionDirector.stats().side_objective_completed and not mission.side_failed and Time.get_ticks_msec() < deadline:
			await get_tree().physics_frame
		if not MissionDirector.stats().side_objective_completed: failures.append("Both freed retainers did not reach the exit")
	await _key(KEY_E)
	var deadline := Time.get_ticks_msec()+6000
	while director.screen != &"results" and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	await _finish()

func _approach_roof() -> bool:
	await _key(KEY_C)
	for point in [Vector3(18,0.02,76),Vector3(18,0.02,72.4)]:
		if not await _walk_to(player,point): return false
	await _climb_to(player,Vector3(24,4.02,66))
	if player.state_machine.current_state() == &"Ground": await _key(KEY_C)
	for point in [Vector3(24,4.02,58),Vector3(28,4.02,54)]:
		if not await _walk_to(player,point): return false
	await _climb_to(player,Vector3(28,8.02,48))
	if player.state_machine.current_state() == &"Ground": await _key(KEY_C)
	for point in [Vector3(28,8.12,44),Vector3(44,11.72,32),Vector3(44,11.62,30),Vector3(51,11.62,24)]:
		if not await _walk_to(player,point): return false
	await _climb_to(player,Vector3(51,11.9,22),false)
	return not ending

func _retry_roof() -> bool:
	var previous := level.get_instance_id()
	var checkpoint := GameState.checkpoint_ref.duplicate(true)
	roof_checkpoint = {"id":checkpoint.get("id"),"posture":checkpoint.get("posture"),"position":checkpoint.get("position")}
	if checkpoint.get("id") != "assassination_complete" or int(checkpoint.get("mission_world",{}).get("mission",{}).get("objective",-1)) != 1:
		failures.append("Roof assassination did not create its world checkpoint")
		await _finish()
		return false
	await _key(KEY_ESCAPE)
	var retry_button: Button
	for child in director._content.get_children():
		if child is Button and child.text == GameText.get_text(&"nav.retry"): retry_button = child
	if retry_button == null:
		failures.append("Pause menu has no checkpoint retry button")
		await _finish()
		return false
	retry_button.pressed.emit()
	for frame in range(15): await get_tree().physics_frame
	level = director.mission as RainyTemple
	player = level.get_node("Player")
	mission = level.get_node("Mission")
	player.state_machine.state_changed.connect(func(_from,to): states.append(to))
	roof_retry_ms = PlayerRetryFlow.last_retry_elapsed_ms
	var saved_position: Array = checkpoint["position"]
	var destination := Vector3(saved_position[0],saved_position[1],saved_position[2])
	roof_checkpoint.restored_posture = String(player.state_machine.current_state())
	roof_checkpoint.restored_position = str(player.global_position)
	# Assassination releases traversal into a stable standing posture on the board.
	if level.get_instance_id() == previous or get_tree().paused or not mission.target.is_target_defeated() or String(player.state_machine.current_state()) != checkpoint["posture"] or player.global_position.distance_to(destination) > 0.05:
		failures.append("Roof assassination checkpoint did not restore its saved scene, target, posture and position")
		await _finish()
		return false
	_record("roof_retry")
	return true

func _approach_cell() -> bool:
	for point in [Vector3(80,0.02,92),Vector3(84,0.02,92),Vector3(94,-1.65,92),Vector3(94,-1.65,44),Vector3(84,0.02,44),Vector3(86.75,0.02,44),Vector3(86.75,3.72,33),Vector3(86.75,3.72,32)]:
		if not await _walk_to(player,point): return false
	await _key(KEY_E)
	if player.state_machine.current_state() != &"Crawlspace": failures.append("Mill crawl entry failed")
	if not await _walk_to(player,Vector3(76,3.72,32)): return false
	await _key(KEY_E)
	if player.state_machine.current_state() != &"Crouch": failures.append("Cell hatch exit failed")
	return await _walk_to(player,Vector3(72,5.02,32))

func _rescue() -> void:
	for point in [Vector3(72,5.02,36.3),Vector3(76,5.02,36.3)]:
		if not await _walk_to(player,point): return
	await _key(KEY_E)
	if not mission.get_node("Retainers/RetainerA").rescued: failures.append("Mapped E did not rescue A")
	if not await _walk_to(player,Vector3(82,5.02,36.3)): return
	await _key(KEY_E)
	if not mission.get_node("Retainers/RetainerB").rescued: failures.append("Mapped E did not rescue B")
	_record("rescue")
	await _shot("rescue")

func _walk_to(actor: PlayerController,destination: Vector3) -> bool:
	var remaining := maxf(15.0,actor.global_position.distance_to(destination)/0.8+10.0)
	while remaining > 0 and not ending and director.screen == &"playing" and not actor.state_machine.is_dead():
		var difference := destination-actor.global_position
		difference.y = 0
		if difference.length() < 0.15: break
		Input.action_press(&"move_forward")
		actor.rotation.y = atan2(-difference.x,-difference.z)
		await get_tree().physics_frame
		remaining -= get_physics_process_delta_time()
	Input.action_release(&"move_forward")
	for frame in range(2): await get_tree().physics_frame
	if ending: return false
	if remaining <= 0:
		failures.append("Movement blocked at "+str(actor.global_position)+" approaching "+str(destination))
		await _finish()
		return false
	print("TEMPLE_WAYPOINT ",destination," actual=",actor.global_position," state=",actor.state_machine.current_state())
	return true

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player) or ending or started == 0: return
	min_breath = minf(min_breath,player.breath_remaining())
	max_visibility = maxf(max_visibility,(player.get_node("Visibility") as PlayerVisibility).visibility())
	if player.state_machine.is_dead() or Time.get_ticks_msec()-started > 600000:
		ending = true
		failures.append("Player died or replay exceeded ten minutes")
		_finish.call_deferred()

func _record(stage: String) -> void:
	stages.append({"stage":stage,"seconds":float(Time.get_ticks_msec()-started)/1000,"position":str(player.global_position),"detections":MissionDirector.stats().detections,"alert":GameState.area_alert_level})
	print("TEMPLE_STAGE ",JSON.stringify(stages[-1]))

func _debug_shot() -> void:
	var debug := main.get_node("StealthDebugOverlay") as StealthDebugOverlay
	debug.set_debug_visible(true)
	for frame in range(3): await get_tree().process_frame
	FileAccess.open(output+"/perception.json",FileAccess.WRITE).store_string(JSON.stringify({"geometry":debug.debug_geometry_snapshot(),"lights":debug.light_radius_snapshot(),"enemies":debug.enemy_debug_snapshot(),"visibility":debug.player_visibility_value(),"noise":debug.active_noise_radii()},"  "))
	await _shot("debug-approach")
	debug.set_debug_visible(false)

func _shot(filename: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output+"/"+filename+".png")

func _finish() -> void:
	ending = true
	if director.screen != &"results": failures.append("Mission did not reach results")
	if MissionDirector.stats().detections != 0: failures.append("Player was detected")
	if MissionDirector.stats().civilian_kills != 0: failures.append("A civilian was killed")
	if MissionDirector.stats().nontarget_kills != 0: failures.append("A non-target was killed")
	_record("finish")
	await get_tree().create_timer(0.8,true,false,true).timeout
	await _shot("result")
	var result := {"route":route_id,"scope":"Unlocked campaign board; mapped normal-time movement/traversal/F assassination/E rescue and escape; heading steering, no actor placement, AI changes or direct kill; volatile save; not human timing","seconds":float(Time.get_ticks_msec()-started)/1000,"screen":director.screen,"failures":failures,"stages":stages,"states":states,"min_breath":min_breath,"max_visibility":max_visibility,"narrative":narrative,"score":MissionDirector.build_result().score,"flags":MissionDirector.build_result().flags,"campaign":store.campaign().duplicate(true),"detections":MissionDirector.stats().detections,"nontarget_kills":MissionDirector.stats().nontarget_kills,"civilian_kills":MissionDirector.stats().civilian_kills}
	result.roof_retry_ms = roof_retry_ms
	result.roof_checkpoint = roof_checkpoint
	FileAccess.open(output+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("TEMPLE_CLEAR ",JSON.stringify(result))
	director.show_title()
	for frame in range(2): await get_tree().physics_frame
	get_tree().quit(0 if failures.is_empty() else 1)
