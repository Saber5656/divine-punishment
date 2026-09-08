extends "res://tests/smoke/residence_route_replay.gd"

func run() -> void:
	isolate_save()
	started=Time.get_ticks_msec()
	deadline=started+360000
	last_note=started
	root.size=Vector2i(1280,720)
	var main=load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	current_scene=main
	director=main.get_node("SceneDirector")
	director.show_mission_select()
	await shot("c-camera-selection")
	for node in director._content.find_children("*","Button",true,false):
		if node.text=="屋敷へ潜入": node.pressed.emit()
	mission=director.mission.get_node("Mission")
	player=director.mission.get_node("Player")
	for f in 12: await frame()
	note("started_via_mission_button")
	await shot("c-camera-start")
	await pulse(&"stance_toggle")
	# Return to walking for the safe outside approach; both stances use input.
	await pulse(&"stance_toggle")
	var okay=true
	for point in [Vector3(8,0,44),Vector3(76,0,44),Vector3(84,0,52)]:
		if not await move(point,40.0):
			okay=false
			break
	if okay:
		await pulse(&"stance_toggle")
		okay=await move(Vector3(78,0,47))
	if okay: okay=await move(Vector3(78,0,44))
	for f in 90: await frame()
	if okay:
		await pulse(&"interact")
		note("crawl_entry")
		if player.state_machine.current_state()!=&"Crawlspace":
			failures.append("crawl entry input failed")
			okay=false
	if okay:
		for point in [Vector3(70,0,37),Vector3(58,0,19.5)]:
			if not await move(point,60.0):
				okay=false
				break
	var look = InputEventMouseMotion.new()
	look.screen_relative = Vector2(0,-180)
	look.relative = look.screen_relative
	Input.parse_input_event(look)
	for f in 10: await frame()
	print("CRAWL_CAMERA ",player.get_node("CameraRig/SpringArm3D/Camera3D").global_position, " pitch ",player.get_node("CameraRig").rotation.x)
	await shot("c-camera-approach")
	if okay:
		await pulse(&"assassinate")
		for f in 125: await frame()
		note("kill_attempt")
		await shot("c-camera-kill")
		if not mission.target.is_target_defeated(): failures.append("F did not kill target")
		else:
			await pulse(&"pause")
			for node in director._content.find_children("*","Button",true,false):
				if node.text=="チェックポイントから再開": node.pressed.emit()
			for f in 12: await frame()
			mission=director.mission.get_node("Mission")
			player=director.mission.get_node("Player")
			note("checkpoint_restored")
			await shot("c-camera-restored")
			if not mission.target.is_target_defeated() or player.state_machine.current_state()!=&"Crawlspace": failures.append("crawl kill checkpoint mismatch")
			for point in [Vector3(70,0,37),Vector3(78,0,41)]:
				if not await move(point,60.0):break
			await pulse(&"interact")
			note("crawl_exit")
			for point in [Vector3(84,0,52),Vector3(84,0,56)]:
				if not await move(point):break

	stop()
	note("finished")
	await shot("c-camera-final")
	print("ROUTE_C_RESULT ",JSON.stringify({"failures":failures,"screen":director.screen,"detections":root.get_node("MissionDirector").stats().detections,"wall_seconds":(Time.get_ticks_msec()-started)/1000.0,"time_scale":Engine.time_scale,"min_breath":min_breath,"forced_surface":exhausted,"method":"Production input traversal and checkpoint capture/restore roundtrip; no placement outside checkpoint restore or direct AI/time edits"}))
	quit(0 if not exhausted and failures.is_empty() and director.screen==&"results" and root.get_node("MissionDirector").stats().detections==0 else 1)
