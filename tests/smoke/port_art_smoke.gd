extends Node3D

func _ready() -> void:
	var output := "user://port61-art"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(output)
	SaveManager.save_path = "user://port61-art-only.json"
	DisplayServer.window_set_size(Vector2i(1440,900))
	var level: PortStorehouse = load("res://src/levels/port_storehouse/port_mission.tscn").instantiate()
	add_child(level)
	var player := level.get_node("Player") as PlayerController
	player.get_node("CameraRig").process_mode = Node.PROCESS_MODE_DISABLED
	player.get_node("Visibility/SwimHud").hide()
	var camera := Camera3D.new()
	add_child(camera)
	camera.current = true
	var frames: Array[float] = []
	for view in [
		["overview",Vector3(105,62,102),Vector3(46,2,33)],
		["quay",Vector3(22,7,57),Vector3(49,2,36)],
		["ship",Vector3(74,10,32),Vector3(88,3,50)],
		["house",Vector3(72,4.7,25),Vector3(66,3.1,13)],
	]:
		camera.position = view[1]
		camera.look_at(view[2])
		for frame in range(30): await RenderingServer.frame_post_draw
		var previous := Time.get_ticks_usec()
		for frame in range(60):
			await RenderingServer.frame_post_draw
			var now := Time.get_ticks_usec()
			frames.append(float(now-previous)/1000)
			previous = now
		get_viewport().get_texture().get_image().save_png(output+"/"+view[0]+".png")
	frames.sort()
	var art := level.get_node("PortArt")
	var result := {"scope":"Art inspection cameras, default player spawn, live NPCs; not a route clear", "coverage":art.coverage,"physical_contract_unchanged":art.before_contract == art.capture_contract(level),"samples":frames.size(),"median_frame_ms":frames[frames.size()/2],"p95_frame_ms":frames[int(frames.size()*0.95)],"rendered_primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
	var file := FileAccess.open(output+"/result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	print("PORT_ART ",JSON.stringify(result))
	get_tree().quit(0 if result.physical_contract_unchanged else 1)
