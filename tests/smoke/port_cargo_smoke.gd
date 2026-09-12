extends "res://tests/smoke/port_routes_smoke.gd"

var mission: Node
var actor: PlayerController

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(output)
	SaveManager.save_path = "user://port172-smoke-only.json"
	var level := load("res://src/levels/port_storehouse/port_mission.tscn").instantiate() as PortStorehouse
	add_child(level)
	mission = level.get_node("Mission")
	actor = level.get_node("Player") as PlayerController
	actor.get_node("CameraRig").process_mode = Node.PROCESS_MODE_DISABLED
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(88,12,54)
	camera.look_at(Vector3(76,0,42))
	camera.current = true
	for frame in range(5): await get_tree().physics_frame
	# Start beside the cargo to isolate carrying/disposal. NPCs and physics stay live.
	actor.global_position = Vector3(68,0.02,37.2)
	actor.rotation.y = 0
	for frame in range(4): await get_tree().physics_frame
	started = Time.get_ticks_msec()
	await _key(KEY_E)
	if not mission.cargo.is_carried(): failures.append("Mapped E did not pick up the crate")
	await _walk_to(actor,Vector3(68,0.02,43.5))
	await _walk_to(actor,Vector3(79,0.02,43.5))
	await _walk_to(actor,Vector3(79,0.02,41))
	await _walk_to(actor,Vector3(81,0.02,41))
	await _key(KEY_E)
	if mission.cargo.is_carried(): failures.append("Mapped E did not release the crate")
	for frame in range(180):
		await get_tree().physics_frame
		if mission.cargo.is_disposed(): break
	if not mission.cargo.is_disposed(): failures.append("Thrown cargo did not sink into the water")
	if not MissionDirector.stats().side_objective_completed: failures.append("Submerged cargo did not complete the side objective")
	if actor.state_machine.is_dead(): failures.append("Player died during the carry fixture")
	_write_result(actor)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output+"/cargo.png")
	get_tree().quit(failures.size())

func _write_result(player: PlayerController) -> void:
	var result := {"failures":failures,"fixture":"start beside warehouse cargo; normal E input and walk to shore; live NPCs and collision","seconds":float(Time.get_ticks_msec()-started)/1000,"player":str(player.global_position),"cargo":str(mission.cargo.global_position),"disposed":mission.cargo.is_disposed(),"side_objective":MissionDirector.stats().side_objective_completed}
	var file := FileAccess.open(output+"/result.json",FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(result,"  "))
	print("PORT_CARGO ",JSON.stringify(result))
