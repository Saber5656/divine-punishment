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
	await shot("a-camera-selection")
	for node in director._content.find_children("*","Button",true,false):
		if node.text=="屋敷へ潜入": node.pressed.emit()
	mission=director.mission.get_node("Mission")
	player=director.mission.get_node("Player")
	for f in 12: await frame()
	note("started_via_mission_button")
	await shot("a-camera-start")
	await pulse(&"stance_toggle")
	var okay=true
	for point in [Vector3(12,0,20),Vector3(28,0,17),Vector3(33,0,17.6),Vector3(35,0,18),Vector3(46,0,18),Vector3(46,0,23),Vector3(64,0,23)]:
		if not await move(point):
			okay=false
			break
	await shot("a-camera-approach")
	if okay:
		while mission.target.brain().routine_clock()<134.0 and Time.get_ticks_msec()<deadline: await frame()
		okay=await move(Vector3(65.9,0,19.7))
		if okay:
			await pulse(&"assassinate")
			for f in 125: await frame()
			note("kill_attempt")
			await shot("a-camera-kill")
			if not mission.target.is_target_defeated(): failures.append("F did not kill target")
			else:
				for point in [Vector3(66,0,24),Vector3(46,0,24),Vector3(46,0,18),Vector3(35,0,18),Vector3(28,0,17),Vector3(12,0,20),Vector3(8,0,8)]:
					if not await move(point):break
	stop()
	note("finished")
	await shot("a-camera-final")
	print("ROUTE_A_RESULT ",JSON.stringify({"failures":failures,"screen":director.screen,"detections":root.get_node("MissionDirector").stats().detections,"wall_seconds":(Time.get_ticks_msec()-started)/1000.0,"time_scale":Engine.time_scale,"method":"Production Main/SceneDirector mission button, Input events/actions, no actor placement or AI state/time writes"}))
	quit(0 if failures.is_empty() and director.screen==&"results" and root.get_node("MissionDirector").stats().detections==0 else 1)
