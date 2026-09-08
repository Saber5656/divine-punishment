extends Node3D

## Real rendered production load. Vsync off; timings include frame scheduling.
var frames: Array[float] = []
func _ready() -> void:
	get_tree().root.content_scale_size = Vector2i(1920,1080)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	get_tree().root.size = Vector2i(1920,1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var level = load("res://src/levels/samurai_residence/samurai_residence.tscn").instantiate()
	add_child(level)
	for frame in range(8): await get_tree().process_frame
	var player = level.get_node("Player")
	player.set_physics_process(false)
	# Keep the target alive without disabling enemy brains or perception.
	player.get_node("AssassinationResolver/Combat").set("_hit_invulnerability_remaining",3600.0)
	player.global_position = Vector3(36,.1,22)
	var enemies := get_tree().get_nodes_in_group("enemies")
	while enemies.size()<12:
		var enemy = load("res://src/enemies/enemy_base.tscn").instantiate()
		enemy.position = Vector3(35+enemies.size()%4,.9,23)
		level.add_child(enemy)
		enemies.append(enemy)
	var lights := get_tree().get_nodes_in_group("lights")
	while lights.size()<20:
		var source := LightSource.new()
		source.position = Vector3(28+(lights.size()%5)*3,2,19+(lights.size()/5)*3)
		var omni := OmniLight3D.new()
		omni.omni_range = 6.0
		omni.light_energy = 2.2
		omni.light_color = Color(1,.65,.32)
		omni.shadow_enabled = true
		source.add_child(omni)
		level.add_child(source)
		ResidenceLighting.configure_gameplay_light(source)
		lights.append(source)
	var camera := Camera3D.new()
	add_child(camera)
	camera.make_current()
	var views := [[Vector3(43,15,43),Vector3(44,1,26)], [Vector3(37,2.5,27),Vector3(37,1,21)], [Vector3(60,2.4,27),Vector3(64,1,24)]]
	var reports: Array = []
	for view in views:
		camera.position = view[0]
		camera.look_at(view[1])
		# Warm each view before measurement, including shadow/material pipelines.
		for frame in range(120): await get_tree().process_frame
		frames.clear()
		PerceptionProfile.reset()
		PerceptionProfile.enabled = true
		var previous := Time.get_ticks_usec()
		for frame in range(300):
			await RenderingServer.frame_post_draw
			var now := Time.get_ticks_usec()
			frames.append((now-previous)/1000.0)
			previous = now
		PerceptionProfile.enabled = false
		frames.sort()
		var perception: Array = PerceptionProfile.frame_totals.values()
		perception.sort()
		var total := 0.0
		for value in frames: total += value
		reports.append({"camera":camera.position,"frames":frames.size(),"mean_ms":total/frames.size(),"p95_ms":frames[int(frames.size()*.95)],"max_ms":frames[-1],"perception_max_ms":float(perception[-1])/1000 if not perception.is_empty() else -1,"perception_p95_ms":float(perception[int(perception.size()*.95)])/1000 if not perception.is_empty() else -1,"player_alive":not player.state_machine.is_dead(),"perception_calls":PerceptionProfile.calls,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	print("PERFORMANCE_SMOKE ",JSON.stringify({"resolution":get_viewport().get_texture().get_size(),"renderer":RenderingServer.get_video_adapter_name(),"enemies":enemies.size(),"lights":lights.size(),"views":reports}))
	PerceptionProfile.reset()
	get_tree().quit()
