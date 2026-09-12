extends Node3D

var failures: Array[String] = []
var output := "user://port170"
var route_id := "A"
var states: Array[StringName] = []
var started := 0

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
		if arg.begins_with("--route="): route_id = arg.trim_prefix("--route=")
	DirAccess.make_dir_recursive_absolute(output)
	var level := load("res://src/levels/port_storehouse/port_storehouse.tscn").instantiate() as PortStorehouse
	add_child(level)
	var player := level.get_node("Player") as PlayerController
	player.state_machine.state_changed.connect(func(_from: StringName,to: StringName): states.append(to))
	player.get_node("CameraRig").process_mode = Node.PROCESS_MODE_DISABLED
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(110,78,104)
	camera.look_at(Vector3(46,0,34))
	camera.current = true
	for frame in range(8): await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output+"/overview.png")
	started = Time.get_ticks_msec()
	if route_id == "A":
		for destination in level.route_waypoints(&"A_pier").slice(1):
			if not await _walk_to(player,destination): break
	elif route_id == "B":
		var route := level.route_waypoints(&"B_roofs")
		for destination in route.slice(1,4):
			if not await _walk_to(player,destination): break
		await _key(KEY_E)
		var remaining := 20.0
		while remaining > 0.0 and player.global_position.distance_to(route[5]) > 0.15:
			Input.action_press(&"move_forward")
			await get_tree().physics_frame
			remaining -= get_physics_process_delta_time()
		Input.action_release(&"move_forward")
		if remaining <= 0.0: failures.append("Ladder/beam passage failed at "+str(player.global_position)+" state="+str(player.state_machine.current_state()))
		await _key(KEY_SHIFT)
		for destination in route.slice(6):
			if not await _walk_to(player,destination): break
	elif route_id == "C":
		for destination in [Vector3(12,0,60),Vector3(12,0,64),Vector3(20,-1.65,64),Vector3(88,-1.65,64),Vector3(88,-1.65,60)]:
			if not await _walk_to(player,destination): break
		if player.state_machine.current_state() != &"SwimSurface": failures.append("Water entry did not reach SwimSurface")
		await _key(KEY_C)
		if player.state_machine.current_state() != &"SwimUnderwater": failures.append("Dive did not reach SwimUnderwater")
		await _walk_to(player,Vector3(88,-3.7,40))
		await _key(KEY_C)
		for destination in [Vector3(88,-1.65,18),Vector3(80,0,18),Vector3(80,0,16),Vector3(85,0,16),Vector3(85,0,14),Vector3(78.5,1.72,14)]:
			if not await _walk_to(player,destination): break
		await _key(KEY_E)
		if player.state_machine.current_state() != &"Crawlspace": failures.append("Rear passage did not enter Crawlspace: "+str(player.state_machine.current_state()))
		await _walk_to(player,Vector3(66,1.72,14))

	_write_result(player)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output+"/route-"+route_id+".png")
	get_tree().quit(failures.size())

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
	event.pressed = false
	get_viewport().push_input(event,true)
	for action in actions: Input.action_release(action)
	for frame in range(2): await get_tree().physics_frame

func _walk_to(player: PlayerController,destination: Vector3) -> bool:
	var remaining := maxf(15.0,player.global_position.distance_to(destination)/0.8+10.0)
	Input.action_press(&"move_forward")
	while remaining > 0.0:
		var difference := destination-player.global_position
		difference.y = 0.0
		if difference.length() < 0.15: break
		# Window focus changes can release injected actions; emulate the held key each tick.
		Input.action_press(&"move_forward")
		player.rotation.y = atan2(-difference.x,-difference.z)
		await get_tree().physics_frame
		remaining -= get_physics_process_delta_time()
	Input.action_release(&"move_forward")
	for frame in range(2): await get_tree().physics_frame
	if remaining <= 0.0:
		var hits: Array = []
		for index in player.get_slide_collision_count():
			var hit := player.get_slide_collision(index)
			hits.append(str(hit.get_collider().name)+" "+str(hit.get_normal()))
		failures.append("Movement blocked approaching "+str(destination)+" at "+str(player.global_position)+" collisions="+str(hits))
		print("PORT_FAILURE ",failures)
		_write_result(player)
		get_tree().quit(1)
		return false
	print("PORT_WAYPOINT ",destination," position=",player.global_position," state=",player.state_machine.current_state())
	return true

func _write_result(player: PlayerController) -> void:
	var result := {"route":route_id,"failures":failures,"position":str(player.global_position),"seconds":float(Time.get_ticks_msec()-started)/1000.0,"state":player.state_machine.current_state(),"states":states}
	print("PORT_ROUTE_"+route_id+" ",JSON.stringify(result))
	var file := FileAccess.open(output+"/result.json",FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(result,"  "))
