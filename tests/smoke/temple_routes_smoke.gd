extends "res://tests/smoke/port_routes_smoke.gd"

## Layout-only replay: actual mapped movement/traversal, no NPC clear claims.
func _ready() -> void:
	output = "user://temple178"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
		if arg.begins_with("--route="): route_id = arg.trim_prefix("--route=")
	DirAccess.make_dir_recursive_absolute(output)
	var level := load("res://src/levels/rainy_temple/rainy_temple.tscn").instantiate() as RainyTemple
	add_child(level)
	var player := level.get_node("Player") as PlayerController
	player.state_machine.state_changed.connect(func(_from: StringName,to: StringName): states.append(to))
	player.get_node("CameraRig").process_mode = Node.PROCESS_MODE_DISABLED
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(115,92,132)
	camera.look_at(Vector3(48,2,50))
	camera.current = true
	for frame in range(8): await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output+"/overview.png")
	started = Time.get_ticks_msec()
	if route_id == "A":
		for destination in level.route_waypoints(&"A_steps").slice(1):
			if not await _walk_to(player,destination): return
	elif route_id == "B":
		for destination in [Vector3(18,0.02,76),Vector3(18,0.02,72.4)]:
			if not await _walk_to(player,destination): return
		await _climb_to(player,Vector3(24,4.02,66))
		for destination in [Vector3(24,4.02,58),Vector3(28,4.02,54)]:
			if not await _walk_to(player,destination): return
		await _climb_to(player,Vector3(28,8.02,48))
		for destination in [Vector3(28,8.12,44),Vector3(44,11.72,32),Vector3(44,11.62,30),Vector3(51,11.62,24)]:
			if not await _walk_to(player,destination): return
		await _climb_to(player,Vector3(51,11.9,22),false)
	elif route_id == "C":
		for destination in [Vector3(80,0.02,92),Vector3(84,0.02,92),Vector3(94,-1.65,92),Vector3(94,-1.65,44),Vector3(84,0.02,44),Vector3(86.75,0.02,44),Vector3(86.75,3.72,33),Vector3(86.75,3.72,32)]:
			if not await _walk_to(player,destination): return
		await _key(KEY_E)
		if player.state_machine.current_state() != &"Crawlspace": failures.append("Mill crawl entry did not enter Crawlspace")
		await _walk_to(player,Vector3(76,3.72,32))
		await _key(KEY_E)
		if player.state_machine.current_state() != &"Crouch": failures.append("Cell hatch did not permit the normal crouched exit")
		await _key(KEY_C)
		await _walk_to(player,Vector3(72,5.02,32))
		if player.state_machine.current_state() != &"Ground": failures.append("Cell exit must leave crawl posture")
		for destination in level.rescue_return_waypoints().slice(1):
			if not await _walk_to(player,destination): return
	_write_result(player)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output+"/route-"+route_id+".png")
	get_tree().quit(0 if failures.is_empty() else 1)

func _climb_to(player: PlayerController,destination: Vector3,leave_beam: bool = true) -> void:
	await _key(KEY_E)
	var remaining := 20.0
	while remaining > 0.0 and player.position.distance_to(destination) > 0.15:
		Input.action_press(&"move_forward")
		await get_tree().physics_frame
		remaining -= get_physics_process_delta_time()
	Input.action_release(&"move_forward")
	if remaining <= 0.0: failures.append("Climb/beam passage failed at "+str(player.position)+" state="+str(player.state_machine.current_state()))
	if leave_beam: await _key(KEY_SHIFT)
