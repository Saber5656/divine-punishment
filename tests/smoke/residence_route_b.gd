extends "res://tests/smoke/residence_route_replay.gd"

func run() -> void:
	isolate_save()
	started=Time.get_ticks_msec()
	deadline=started+220000
	last_note=started
	root.size=Vector2i(1280,720)
	var main=load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	current_scene=main
	director=main.get_node("SceneDirector")
	director.show_mission_select()
	await shot("b-camera-selection")
	for node in director._content.find_children("*","Button",true,false):
		if node.text=="屋敷へ潜入": node.pressed.emit()
	mission=director.mission.get_node("Mission")
	player=director.mission.get_node("Player")
	for f in 12: await frame()
	note("started_via_mission_button")
	await shot("b-camera-start")
	await pulse(&"stance_toggle")
	var okay=await move(Vector3(12,0,2.8))
	if okay:
		await pulse(&"interact")
		okay=await follow_beam(Vector3(40,5,8),32.0)
	if okay:
		await pulse(&"sprint")
		for f in 20: await frame()
		okay=await move(Vector3(41,0,8))
	if okay:
		await pulse(&"interact")
		okay=await follow_beam(Vector3(58,5,20.3),24.0)
	await shot("b-camera-approach")
	if okay:
		await pulse(&"assassinate")
		for f in 125: await frame()
		note("kill_attempt")
		await shot("b-camera-kill")
		if not mission.target.is_target_defeated(): failures.append("F did not kill target")
		else:
			for point in [Vector3(62,0,21),Vector3(62,0,11),Vector3(44,0,10),Vector3(40,0,8),Vector3(40,0,5),Vector3(12,0,5),Vector3(8,0,5),Vector3(8,0,8)]:
				if not await move(point):break

	stop()
	note("finished")
	await shot("b-camera-final")
	print("ROUTE_B_RESULT ",JSON.stringify({"failures":failures,"screen":director.screen,"detections":root.get_node("MissionDirector").stats().detections,"wall_seconds":(Time.get_ticks_msec()-started)/1000.0,"time_scale":Engine.time_scale,"method":"Production Main/SceneDirector mission button, Input events/actions, no actor placement or AI state/time writes"}))
	quit(0 if failures.is_empty() and director.screen==&"results" and root.get_node("MissionDirector").stats().detections==0 else 1)

func follow_beam(point: Vector3,seconds: float) -> bool:
	var until=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<until:
		if player.global_position.distance_to(point)<0.08:
			stop()
			note("beam_endpoint")
			return true
		Input.action_press(&"move_forward")
		await frame()
	stop()
	failures.append("beam traversal timeout "+str(point))
	note("beam_failed")
	return false
