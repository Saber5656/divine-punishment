extends Node3D

## Explicit roof/ground placements and clock offset isolate rendering, V and pause.
var output := "user://festival189-fireworks"
var failures: Array[String] = []
var sounds: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(output)
	DisplayServer.window_set_size(Vector2i(1440,900))
	GameState.area_alert_level = 0
	MissionDirector.start_mission(null)
	var level: Node3D = load("res://src/levels/festival_night/festival_population.tscn").instantiate()
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	var population := level.get_node("Population")
	var player := level.get_node("Player") as PlayerController
	player.set_physics_process(false)
	player.get_node("CameraRig").process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = Vector3(28,4.02,60)
	var visibility := player.get_node("Visibility") as PlayerVisibility
	var fireworks := FestivalFireworks.new()
	fireworks.name = "Fireworks"
	level.add_child(fireworks)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(30,9,68)
	camera.look_at(Vector3(55,17,18))
	camera.make_current()
	population.advance_schedule(40.0)
	for frame in range(3): await get_tree().physics_frame
	var baseline := visibility.recompute()
	await _shot("countdown")
	while fireworks.elapsed() < 42.4: await get_tree().physics_frame
	var roof_burst := visibility.recompute()
	_check(is_equal_approx(roof_burst,baseline*2.0),"Roof visibility must double")
	_check(fireworks.masks_gameplay_noise(),"Burst should mask noise")
	var boom_playing := (fireworks.get_node("Boom") as AudioStreamPlayer3D).playing
	_check(boom_playing,"Original boom stream must be playing during burst")
	await _shot("burst")
	var listener := func(event): sounds.append(event)
	EventBus.noise_emitted.connect(listener)
	NoiseEventSystem.emit(NoiseEvent.create(player.global_position,5,Enums.NoiseKind.FOOTSTEP,player),get_tree())
	_check(sounds.is_empty(),"Burst footstep leaked to telemetry")
	get_tree().paused = true
	var pause_elapsed := fireworks.elapsed()
	for frame in range(30): await get_tree().process_frame
	_check(is_equal_approx(fireworks.elapsed(),pause_elapsed),"Paused mission advanced firework phase")
	get_tree().paused = false
	player.global_position = Vector3(48,0.02,60)
	var ground_burst := visibility.recompute()
	_check(is_equal_approx(ground_burst,baseline),"Ground visibility must stay neutral")
	while fireworks.elapsed() < 45.2: await get_tree().physics_frame
	_check(not fireworks.masks_gameplay_noise(),"Burst did not end at cycle boundary")
	NoiseEventSystem.emit(NoiseEvent.create(player.global_position,5,Enums.NoiseKind.FOOTSTEP,player),get_tree())
	_check(sounds.size() == 1,"Noise did not return after burst")
	EventBus.noise_emitted.disconnect(listener)
	player.global_position = Vector3(28,4.02,60)
	var restored_roof := visibility.recompute()
	_check(is_equal_approx(restored_roof,baseline),"Roof visibility failed to return to baseline")
	await _shot("after")
	var result := {"scope":"Native fireworks fixture: explicit roof and ground player placements, disabled player movement/camera rig, live population with40second clock offset, normal-time burst and30render-frame pause; not a mission clear or human baseline","roof_baseline":baseline,"roof_burst":roof_burst,"ground_burst":ground_burst,"roof_after":restored_roof,"boom_playing":boom_playing,"paused_elapsed":pause_elapsed,"final_elapsed":fireworks.elapsed(),"unmasked_sounds":sounds.size(),"failures":failures}
	FileAccess.open(output+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("FESTIVAL_FIREWORKS ",JSON.stringify(result))
	get_tree().quit(0 if failures.is_empty() else 1)

func _check(condition: bool,message: String) -> void:
	if not condition: failures.append(message)

func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output+"/"+label+".png")
