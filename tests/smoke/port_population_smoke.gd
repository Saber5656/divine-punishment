extends Node3D

var failures: Array[String] = []
var output := "user://port171"
var arrivals := {}
var full_cycle := false

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
		if arg == "--full-cycle": full_cycle = true
	DirAccess.make_dir_recursive_absolute(output)
	SaveManager.save_path = "user://port171-smoke-only.json"
	GameState.area_alert_level = 0
	Engine.time_scale = 4.0
	var level := load("res://src/levels/port_storehouse/port_mission.tscn").instantiate() as PortStorehouse
	add_child(level)
	var population := level.get_node("Population")
	var target := population.get_node("Target") as TargetNpc
	var player := level.get_node("Player") as PlayerController
	player.get_node("CameraRig").process_mode = Node.PROCESS_MODE_DISABLED
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(95,50,64)
	camera.look_at(Vector3(50,0,32))
	camera.current = true
	var points := [Vector3(66,3.02,14),Vector3(48,0.02,36),Vector3(68,0.02,52)]
	var elapsed := 0.0
	var previous := target.global_position
	var maximum_step := 0.0
	var previous_clock := 0.0
	var wrapped := false
	while elapsed < (342.0 if full_cycle else 278.0):
		await get_tree().physics_frame
		var delta := get_physics_process_delta_time()
		elapsed += delta
		var current_clock := target.target_routine_clock()
		if current_clock < previous_clock-1.0: wrapped = true
		previous_clock = current_clock
		maximum_step = maxf(maximum_step,target.global_position.distance_to(previous))
		previous = target.global_position
		for index in points.size():
			if target.global_position.distance_to(points[index]) < 0.6 and not arrivals.has(str(index)):
				arrivals[str(index)] = {"elapsed":elapsed,"clock":target.target_routine_clock(),"position":str(target.global_position)}
	if full_cycle and not wrapped: failures.append("300-second schedule did not wrap")
	if arrivals.size() != 3: failures.append("Target did not visit all three scheduled locations")
	var alarm_start := target.global_position
	population.call("apply_alarm",1)
	var retreat := 0.0
	while retreat < 80.0 and target.global_position.distance_to(points[0]) >= 0.6:
		await get_tree().physics_frame
		retreat += get_physics_process_delta_time()
		maximum_step = maxf(maximum_step,target.global_position.distance_to(previous))
		previous = target.global_position
	if target.global_position.distance_to(points[0]) >= 0.6: failures.append("Merchant did not retreat to the counting room")
	for frame in range(180): await get_tree().physics_frame
	var reserve := population.get_node("Guards/HouseReserve") as EscortGuard
	if reserve.global_position.distance_to(target.global_position) > 4.0: failures.append("Second escort did not join the target")
	if maximum_step > 0.4: failures.append("Navigation step exceeded the bounded physical step")
	var result := {"failures":failures,"time_scale":Engine.time_scale,"schedule_wrapped":wrapped,"arrivals":arrivals,"alarm_start":str(alarm_start),"retreat_seconds":retreat,"target_end":str(target.global_position),"reserve_end":str(reserve.global_position),"maximum_step":maximum_step}
	var file := FileAccess.open(output+"/result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	print("PORT_POPULATION ",JSON.stringify(result))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output+"/population.png")
	Engine.time_scale = 1.0
	get_tree().quit(failures.size())
