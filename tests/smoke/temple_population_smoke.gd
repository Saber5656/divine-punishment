extends Node3D

## Accelerated live AI replay, with normal physics/perception and no actor placement.
## This checks routines and presentation, not stealth completion or human pacing.
var output := "user://temple179"
var failures: Array[String] = []
var samples: Array[Dictionary] = []
var weather_only := false

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
		if arg == "--weather-only": weather_only = true
	DirAccess.make_dir_recursive_absolute(output)
	DisplayServer.window_set_size(Vector2i(1440,900))
	var started := Time.get_ticks_msec()
	var level: Node3D = load("res://src/levels/rainy_temple/temple_population.tscn").instantiate()
	add_child(level)
	var population := level.get_node("Population")
	var player := level.get_node("Player") as PlayerController
	player.get_node("CameraRig").process_mode = Node.PROCESS_MODE_DISABLED
	var camera := Camera3D.new()
	add_child(camera)
	camera.current = true
	if weather_only:
		camera.position = player.global_position+Vector3(0,2,3)
		camera.look_at(player.global_position+Vector3(0,1,-8))
		await get_tree().create_timer(2.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output+"/rain.png")
		get_tree().quit()
		return
	var initial := {}
	for monk in population.get_node("Monks").get_children(): initial[monk.name] = monk.global_position
	Engine.time_scale = 8.0
	for timestamp in [3.0,18.0,39.0,719.0,760.0]:
		while float(population.call("schedule_elapsed")) < timestamp:
			await get_tree().physics_frame
		await get_tree().process_frame
		var entry := {"time":population.call("schedule_elapsed"),"monks":[]}
		var ringing := (population.get_node("SutraBell") as AudioStreamPlayer3D).playing
		entry.sutra_bell_playing = ringing
		if timestamp in [3.0,39.0] and not ringing: failures.append("Sutra window was silent")
		if timestamp == 18.0 and ringing: failures.append("Sutra cue continued outside its window")
		for monk in population.get_node("Monks").get_children():
			var toward: Vector3 = Vector3(51,8.02,22)-monk.global_position
			toward.y = 0
			var facing: Vector3 = -monk.global_basis.z
			var alignment := facing.normalized().dot(toward.normalized())
			var walked: float = monk.global_position.distance_to(initial[monk.name])
			entry.monks.append({"name":str(monk.name),"position":str(monk.global_position),"action":str(monk.current_routine_stop().routine_action),"alert":monk.brain().alert_state(),"hall_alignment":alignment,"displacement":walked})
			if timestamp in [3.0,39.0] and alignment < 0.99: failures.append(str(monk.name)+" failed shared chant facing at "+str(timestamp))
			if timestamp == 18.0 and walked < 2.0: failures.append(str(monk.name)+" failed real patrol movement")
		var target := population.get_node("Tetsusenbo") as TargetNpc
		entry.target = {"position":str(target.global_position),"action":str(target.routine_action())}
		if timestamp == 719.0 and target.global_position.distance_to(Vector3(51,8.02,22)) > 0.5: failures.append("Target left training too early")
		if timestamp == 760.0 and target.global_position.distance_to(Vector3(78,5.02,28)) > 0.5: failures.append("Target failed live cell inspection")
		samples.append(entry)
		if timestamp == 3.0:
			camera.position = Vector3(18,4,96)
			camera.look_at(Vector3(34,3,66))
		elif timestamp == 18.0:
			camera.position = Vector3(74,32,78)
			camera.look_at(Vector3(41,4,50))
		elif timestamp == 39.0:
			camera.position = Vector3(48,9,69)
			camera.look_at(Vector3(48,4,55))
		elif timestamp == 760.0:
			camera.position = Vector3(71,6.4,28)
			camera.look_at(Vector3(79,5,29))
		if timestamp != 719.0:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(output+"/phase-"+str(int(timestamp))+".png")
	Engine.time_scale = 1.0
	var weather := population.get_node("Weather")
	if not (weather.get_node("Precipitation") as GPUParticles3D).emitting: failures.append("Rain particles inactive")
	if not (weather.get_node("RainAudio") as AudioStreamPlayer).playing: failures.append("Rain ambience inactive")
	var result := {"scope":"Live AI/physics at 8x simulation time; untouched player spawn; inspection cameras; no stealth clear claim", "wall_seconds":float(Time.get_ticks_msec()-started)/1000,"samples":samples,"failures":failures}
	FileAccess.open(output+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("TEMPLE_POPULATION ",JSON.stringify(result))
	get_tree().quit(0 if failures.is_empty() else 1)
