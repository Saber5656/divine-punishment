extends Node3D

## Live AI at 8x time, untouched entry player, inspection cameras only.
var output: String = "user://festival188"
var failures: Array[String] = []
var samples: Array[Dictionary] = []

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(output)
	DisplayServer.window_set_size(Vector2i(1440,900))
	GameState.area_alert_level = 0
	MissionDirector.start_mission(null)
	var started := Time.get_ticks_msec()
	var level: Node3D = load("res://src/levels/festival_night/festival_population.tscn").instantiate()
	add_child(level)
	var population := level.get_node("Population")
	var player := level.get_node("Player") as PlayerController
	player.get_node("CameraRig").process_mode = Node.PROCESS_MODE_DISABLED
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(90,4.8,42)
	camera.look_at(Vector3(84,3,32))
	camera.make_current()
	var origins: Dictionary = {}
	var moved: Dictionary = {}
	for npc: EnemyBase in population.doshin:
		origins[npc.name] = npc.global_position
		moved[npc.name] = 0.0
	var prayer_start: float = -1.0
	var prayer_end: float = -1.0
	var previous_prayer: bool = false
	var maximum_alert: int = 0
	var exposed_prayer_approach: bool = false
	var thresholds: Array[float] = [3.0,179.0,210.0,300.1,340.0,419.0]
	var sample_index: int = 0
	Engine.time_scale = 8.0
	while population.schedule_elapsed() < 420.0:
		await get_tree().physics_frame
		var elapsed: float = population.schedule_elapsed()
		for npc: EnemyBase in population.doshin:
			moved[npc.name] = maxf(moved[npc.name],npc.global_position.distance_to(origins[npc.name]))
		for npc: EnemyBase in population.important_actors()+population.doshin:
			maximum_alert = maxi(maximum_alert,npc.brain().alert_state())
		var praying: bool = population.prayer_active()
		if praying:
			for escort: EnemyBase in population.escorts:
				for point in [Vector3(51,0.02,33),Vector3(51,3.02,24),Vector3(51,3.02,17)]:
					if (escort.get_node("Perception") as EnemyPerception).can_see_position(point+Vector3.UP*0.7): exposed_prayer_approach = true
		if praying and not previous_prayer:
			prayer_start = elapsed
			samples.append(_sample(population,"prayer_start"))
			camera.position = Vector3(56,4.8,28)
			camera.look_at(Vector3(51,3,17))
			await _shot("prayer")
		if previous_prayer and not praying:
			prayer_end = elapsed
			samples.append(_sample(population,"prayer_end"))
		previous_prayer = praying
		if sample_index < thresholds.size() and elapsed >= thresholds[sample_index]:
			samples.append(_sample(population,str(thresholds[sample_index])))
			if sample_index == 0:
				await _shot("dais")
				camera.position = Vector3(40,6,86)
				camera.look_at(Vector3(42,0,65))
				await _shot("crowds")
			sample_index += 1
	Engine.time_scale = 1.0
	if prayer_start < 180.0 or prayer_end > 300.0 or prayer_end-prayer_start < 29.7: failures.append("Thirty seconds of actual isolated prayer did not fit the shrine phase")
	if population.target.global_position.distance_to(Vector3(84,3.02,32)) > 0.5: failures.append("Target did not really return to the dais")
	for name_ in moved:
		if moved[name_] < 1.0: failures.append(str(name_)+" never made real patrol progress")
	if maximum_alert != Enums.AlertState.UNAWARE: failures.append("Untouched safe-entry player provoked hostile AI")
	if population.civilians.size() != 12: failures.append("Festival roster is not twelve civilian actors")
	if exposed_prayer_approach: failures.append("Exterior guards watched the isolated prayer approach")
	var reaction: Array = []
	if not population.target.begin_assassination(&"above"): failures.append("Actual target assassination failed")
	for escort: EnemyBase in population.escorts:
		reaction.append({"name":str(escort.name),"state":escort.brain().alert_state()})
		if escort.brain().alert_state() != Enums.AlertState.COMBAT: failures.append("Escort ignored unseen target death")
	var result := {"scope":"Live AI/physics at8x time, untouched player spawn, inspection cameras; routine and safe-entry evidence; terminal direct assassination fixture tests escort reaction, not a player stealth clear or human baseline","wall_seconds":float(Time.get_ticks_msec()-started)/1000,"prayer_start":prayer_start,"prayer_end":prayer_end,"maximum_alert":maximum_alert,"prayer_approach_exposed":exposed_prayer_approach,"assassination_reaction":reaction,"patrol_max_displacement":moved,"samples":samples,"failures":failures}
	FileAccess.open(output+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("FESTIVAL_POPULATION ",JSON.stringify(result))
	get_tree().quit(0 if failures.is_empty() else 1)

func _sample(population: Node,label: String) -> Dictionary:
	var result := {"label":label,"elapsed":population.schedule_elapsed(),"phase":population.phase(),"prayer_elapsed":population.prayer_elapsed(),"actors":[]}
	for npc: EnemyBase in population.important_actors():
		result.actors.append({"name":str(npc.name),"position":str(npc.global_position),"goal":str(npc.routine_target()),"action":str(npc.current_routine_stop().routine_action),"alert":npc.brain().alert_state()})
	return result

func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output+"/"+label+".png")
