extends "res://tests/smoke/temple_routes_smoke.gd"

## Graybox route replay with actual mapped traversal and ordinary ground return.
## No NPCs yet; this does not claim undetected campaign completion.
var hatch_only := false

func _ready() -> void:
	output = "user://festival187"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
		if arg.begins_with("--route="): route_id = arg.trim_prefix("--route=")
		if arg == "--leg=hatch": hatch_only = true
	if route_id not in ["A","B","C"] or (hatch_only and route_id != "C"):
		push_error("Choose route A/B/C; the isolated hatch leg requires route C")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	DisplayServer.window_set_size(Vector2i(1440,900))
	var level := load("res://src/levels/festival_night/festival_night.tscn").instantiate() as FestivalNight
	add_child(level)
	var player := level.get_node("Player") as PlayerController
	player.state_machine.state_changed.connect(func(_from,to): states.append(to))
	player.get_node("CameraRig").process_mode = Node.PROCESS_MODE_DISABLED
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(126,105,126)
	camera.look_at(Vector3(54,0,45))
	camera.make_current()
	for frame in range(8): await get_tree().physics_frame
	await _shot("overview")
	started = Time.get_ticks_msec()
	if route_id == "A":
		for point in level.route_waypoints(&"A_crowd").slice(1):
			if not await _walk_to(player,point): return
	elif route_id == "B":
		for point in [Vector3(18,0.02,78),Vector3(18,0.02,76.4)]:
			if not await _walk_to(player,point): return
		await _climb_to(player,Vector3(22,4.02,70))
		for point in [Vector3(28,4.02,50),Vector3(28,4.02,48),Vector3(68,4.02,48),Vector3(70,4.02,44),Vector3(84,6.62,40),Vector3(84,6.62,34)]:
			if not await _walk_to(player,point): return
		await _climb_to(player,Vector3(84,6.9,32),false)
	elif route_id == "C":
		if hatch_only:
			player.global_position = Vector3(84,-3,22.5)
			for frame in range(5): await get_tree().physics_frame
		else:
			for point in [Vector3(72,0.02,84),Vector3(72,0.02,38),Vector3(66,0.02,38),Vector3(66,0.02,26),Vector3(72,0.02,18),Vector3(69,0.02,16),Vector3(69,-3,13)]:
				if not await _walk_to(player,point): return
			for frame in range(60): await get_tree().physics_frame
			if absf(player.global_position.y+3) > 0.2: failures.append("Well did not land on the canal floor")
			for point in [Vector3(84,-3,13),Vector3(84,-3,22.5)]:
				if not await _walk_to(player,point): return
		await _key(KEY_E)
		if player.state_machine.current_state() != &"Crawlspace": failures.append("Canal entry did not enter Crawlspace")
		if not await _walk_to(player,Vector3(84,1.72,34.4)): return
		for frame in range(10): await get_tree().physics_frame
		var exit_marker := level.get_node("Markers/Traversal/DaisCrawl") as CrawlEntrance
		print("HATCH_DIAGNOSTIC ",JSON.stringify({"position":str(player.global_position),"near":exit_marker.is_near_inside(player.global_position),"candidate":str(player._nearest_crawl_entrance(false)),"source_clear":player._has_capsule_clearance_at(player.crawl_capsule_height,player.global_position),"crawl_destination":player._has_capsule_clearance_at(player.crawl_capsule_height,exit_marker.outside_world_position()),"crouch_destination":player._has_capsule_clearance_at(player.crouch_capsule_height,exit_marker.outside_world_position()),"path_clear":player._has_capsule_path_clear(player.crawl_capsule_height,player.global_position,exit_marker.outside_world_position()),"contract":player._crawl_contract_valid,"invalidated":player._crawl_contract_invalidated}))
		await _key(KEY_E)
		if player.state_machine.current_state() != &"Crouch":
			failures.append("Dais hatch did not exit into Crouch")
			_write_result(player)
			get_tree().quit(1)
			return
		for point in [Vector3(84,3.02,38),Vector3(84,3.02,39),Vector3(87,3.02,39),Vector3(87,3.02,33.2),Vector3(84,3.02,33.2)]:
			if not await _walk_to(player,point): return
		await _key(KEY_C)
	if hatch_only:
		camera.position = Vector3(90,4.8,42)
		camera.look_at(player.global_position)
		await _shot("hatch")
		_write_result(player)
		get_tree().quit(0 if failures.is_empty() else 1)
		return
	var arrival := {"position":str(player.global_position),"state":player.state_machine.current_state(),"seconds":float(Time.get_ticks_msec()-started)/1000}
	camera.position = Vector3(56,4.8,28) if route_id == "A" else (Vector3(90,4.8,42) if route_id == "C" else player.global_position+Vector3(6,5,7))
	camera.look_at(player.global_position)
	await _shot("arrival")
	if route_id == "A":
		for point in [Vector3(51,3.02,25),Vector3(51,0.02,33),Vector3(48,0.02,40),Vector3(48,0.02,76),Vector3(40,0.02,84),Vector3(12,0.02,88)]:
			if not await _walk_to(player,point): return
	else:
		if route_id == "B":
			await _key(KEY_SHIFT)
			if not await _walk_to(player,Vector3(83.4,3.02,32)): return
			for frame in range(90): await get_tree().physics_frame
		for point in level.escape_waypoints():
			if not await _walk_to(player,point): return
	if player.state_machine.is_dead(): failures.append("Ground return killed the player")
	var result := {"route":route_id,"failures":failures,"arrival":arrival,"position":str(player.global_position),"state":player.state_machine.current_state(),"states":states,"seconds":float(Time.get_ticks_msec()-started)/1000,"scope":"Normal-time mapped movement/E climb/crawl/Shift beam release, heading steering, no actor placement; NPC-free graybox route and ground return only"}
	FileAccess.open(output+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	level.queue_free()
	for frame in range(3): await get_tree().physics_frame
	get_tree().quit(0 if failures.is_empty() else 1)

func _shot(name_: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output+"/"+name_+".png")

func _write_result(player: PlayerController) -> void:
	var result := {"route":route_id,"failures":failures,"position":str(player.global_position),"state":player.state_machine.current_state(),"states":states,"seconds":float(Time.get_ticks_msec()-started)/1000,"fixture": "Explicit canal-entry placement; mapped hatch leg only" if hatch_only else "Mapped full route; no actor placement","complete_ground_return":false}
	FileAccess.open(output+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))

func _walk_to(player: PlayerController,destination: Vector3) -> bool:
	var remaining := maxf(15.0,player.global_position.distance_to(destination)/0.8+10.0)
	var stuck := 0.0
	Input.action_press(&"move_forward")
	while remaining > 0.0:
		var difference := destination-player.global_position
		difference.y = 0.0
		if difference.length() < 0.15: break
		# Window focus changes can release injected actions; emulate the held key each tick.
		Input.action_press(&"move_forward")
		player.rotation.y = atan2(-difference.x,-difference.z)
		var before := player.global_position
		await get_tree().physics_frame
		stuck = stuck+get_physics_process_delta_time() if player.global_position.distance_to(before) < 0.0001 else 0.0
		if stuck >= 3.0:
			remaining = 0
			break
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
