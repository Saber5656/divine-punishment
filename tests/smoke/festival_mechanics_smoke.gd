extends "res://tests/smoke/temple_mechanics_smoke.gd"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	output = "user://festival189-mechanics"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(output)
	get_tree().create_timer(60.0,true,false,true).timeout.connect(func() -> void:
		FileAccess.open(output+"/timeout.json",FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"samples":samples,"error":"Native fixture exceeded60wall seconds"},"  "))
		get_tree().quit(1))
	DisplayServer.window_set_size(Vector2i(1440,900))
	var started := Time.get_ticks_msec()
	var store := VolatileStore.new()
	store.save_path = "user://festival189-smoke-only.json"
	add_child(store)
	var main: Node = load("res://src/ui/main.tscn").instantiate()
	director = main.get_node("SceneDirector")
	director.save_manager = store
	add_child(main)
	_check(director.start_mission(load("res://data/missions/m05.tres")),"Start actual M5 campaign scene")
	await _frames(8)
	var level := director.mission as Node3D
	var player := level.get_node("Player") as PlayerController
	var rig := player.get_node("ToolRig") as ToolRig
	_check(rig.inventory.slot_count() == 4,"Mission loadout exposes four tool slots")
	for index in range(3): await _key(KEY_Q)
	_check(rig.selected_definition().id == &"naruko","Mapped Q cycling reaches naruko")
	_check(rig.inventory.remaining_count(3) == 3,"Three naruko charges")
	await _mouse(MOUSE_BUTTON_LEFT)
	_check(rig.inventory.remaining_count(3) == 2,"Mapped mouse actually throws one naruko")
	await get_tree().create_timer(1.2).timeout
	samples.naruko_remaining = rig.inventory.remaining_count(3)
	await _shot(Vector3(39,7,80),Vector3(50,1,52),"lanterns.png")
	await _key(KEY_C)
	_check(player.state_machine.current_state() == &"Crouch","Mapped crouch before checkpoint")
	var population := level.get_node("Population")
	population.advance_schedule(43.0-population.schedule_elapsed())
	await _frames(2)
	_check((player.get_node("RetryFlow") as PlayerRetryFlow).capture_checkpoint(&"burst"),"Capture active-burst world")
	samples.checkpoint_elapsed = population.schedule_elapsed()
	population.advance_schedule(10.0)
	population.civilians[0].scream()
	population.target.begin_assassination(&"above")
	rig.inventory.set_remaining_count(3,0)
	# Preserve the explicit earlier snapshot; target death normally updates it deferred.
	var saved := GameState.checkpoint_ref.duplicate(true)
	await _frames(2)
	GameState.checkpoint_ref = saved
	await _retry("burst")
	level = director.mission as Node3D
	player = level.get_node("Player") as PlayerController
	population = level.get_node("Population")
	rig = player.get_node("ToolRig") as ToolRig
	_check(player.state_machine.current_state() == &"Crouch","Retry retains crouch posture")
	_check(rig.inventory.remaining_count(3) == 2,"Retry restores naruko stock")
	_check(not population.target.is_target_defeated(),"Retry restores living target")
	_check(level.get_node("Mission").scream_count == 0,"Retry clears post-checkpoint scream")
	_check(level.get_node("Fireworks").masks_gameplay_noise(),"Retry retains active firework phase")
	_check(MissionDirector.current_objective().id == &"m05_target","Retry restores target objective")
	samples.restored_elapsed = population.schedule_elapsed()
	await _screen("retry.png")
	_check(population.target.begin_assassination(&"above"),"Explicit final assassination fixture")
	await _frames(3)
	_check(GameState.checkpoint_ref.get("id","") == "assassination_complete","Actual target death updates checkpoint")
	await _retry("target")
	level = director.mission as Node3D
	population = level.get_node("Population")
	_check(population.target.is_target_defeated(),"Target death survives actual replacement")
	_check(MissionDirector.current_objective().id == &"m05_escape","Retry retains escape objective")
	_check(MissionDirector.capture_checkpoint_state({}).target_kills == 1,"Target kill is not recounted")
	await _key(KEY_E)
	var deadline := Time.get_ticks_msec()+6000
	while director.screen != &"results" and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	_check(director.screen == &"results","Mapped E reaches real result UI")
	if director.screen == &"results":
		samples.score = director._last_result.score
		samples.flags = director._last_result.flags.duplicate(true)
		_check(director._last_result.flags.get(&"side_objective",false),"Zero-scream sidebonus survives retry")
		_check(CampaignCatalog.is_unlocked(&"m06",store.campaign()),"M5 clear unlocks M6 in volatile save")
		await _screen("result.png")
	var result := {"scope":"Native campaign mechanics fixture: mapped Q/tool mouse/C/E, untouched entry player, live AI, actual scene replacements and result UI; explicit43second clock offset, civilian scream, remote target assassination and stock mutations test rewind; volatile save; not a stealth route or human baseline","wall_seconds":float(Time.get_ticks_msec()-started)/1000,"samples":samples,"failures":failures}
	FileAccess.open(output+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("FESTIVAL_MECHANICS ",JSON.stringify(result))
	director.show_title()
	await _frames(2)
	get_tree().quit(0 if failures.is_empty() else 1)
