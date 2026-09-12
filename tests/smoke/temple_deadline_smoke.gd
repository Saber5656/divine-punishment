extends Node3D

## Accelerated deadline observation. Player remains at the real entry, and AI
## walks normally; this is separate from normal-time route completion evidence.
var output := "user://temple181-deadline"
var failures: Array[String] = []
var samples: Array[Dictionary] = []

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(output)
	get_tree().create_timer(150.0,true,false,true).timeout.connect(func() -> void:
		FileAccess.open(output+"/timeout.json",FileAccess.WRITE).store_string(JSON.stringify({"samples":samples,"failures":failures}))
		get_tree().quit(1))
	var started := Time.get_ticks_msec()
	var level: Node3D = load("res://src/levels/rainy_temple/temple_mission.tscn").instantiate()
	add_child(level)
	var weather := WeatherPresentation.new()
	level.add_child(weather)
	var population := level.get_node("Population")
	var mission := level.get_node("Mission")
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(72,6.5,28)
	camera.look_at(Vector3(80,5,35))
	camera.make_current()
	Engine.time_scale = 8.0
	for timestamp in [719.0,720.5,820.0]:
		while float(population.call("schedule_elapsed")) < timestamp: await get_tree().physics_frame
		var living := 0
		for npc: TempleRetainer in mission.get_node("Retainers").get_children():
			if not npc.is_defeated(): living += 1
		var party := {}
		for name_ in ["CourtWest","CourtEast"]:
			var actor := population.get_node("Monks/"+name_) as EnemyBase
			party[name_] = {"position":str(actor.global_position),"action":String(actor.current_routine_stop().routine_action)}
		samples.append({"time":population.call("schedule_elapsed"),"living_retainers":living,"side_failed":mission.side_failed,"party":party})
		if timestamp <= 720.5 and living != 2: failures.append("Deadline killed a captive before actual travel")
		if timestamp == 720.5:
			for row: Dictionary in party.values():
				if row.action != "execute": failures.append("Execution party did not begin its journey")
		if timestamp == 820.0 and (living != 0 or not mission.side_failed): failures.append("Arriving execution party did not complete captive loss")
		if MissionDirector.current_objective() == null or MissionDirector.current_objective().id != &"m04_target": failures.append("Rescue deadline interrupted the main objective")
		if MissionDirector.build_result().flags.get("failed_reason","") != "": failures.append("Rescue deadline failed the main mission")
	Engine.time_scale = 1.0
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output+"/cell.png")
	var result := {"scope":"8x live clock and AI, untouched entry player, inspection camera; soft-deadline failure fixture, not route or human timing","wall_seconds":float(Time.get_ticks_msec()-started)/1000,"samples":samples,"failures":failures}
	FileAccess.open(output+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("TEMPLE_DEADLINE ",JSON.stringify(result))
	level.queue_free()
	for frame in range(2): await get_tree().physics_frame
	get_tree().quit(0 if failures.is_empty() else 1)
