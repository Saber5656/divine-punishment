extends Node3D

## Controlled, fixed-position V / image comparison. Not a route or AI playtest.
var output := "user://port61-lighting"
var rows: Array = []
var player: PlayerController
var camera: Camera3D
var failures: Array[String] = []

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(output)
	DisplayServer.window_set_size(Vector2i(1440,900))
	SaveManager.save_path = "user://port61-lighting-only.json"
	var level: PortStorehouse = load("res://src/levels/port_storehouse/port_mission.tscn").instantiate()
	add_child(level)
	for frame in range(6): await get_tree().physics_frame
	level.get_node("Population").process_mode = Node.PROCESS_MODE_DISABLED
	player = level.get_node("Player")
	player.set_physics_process(false)
	player.get_node("CameraRig").process_mode = Node.PROCESS_MODE_DISABLED
	player.get_node("Visibility/SwimHud").hide()
	camera = Camera3D.new()
	add_child(camera)
	camera.make_current()
	for light: LightSource in level.get_node("PortEnvironment/Lights").get_children(): light.set_extinguished(true)
	var source := level.get_node("PortEnvironment/Lights/PierWestLamp") as LightSource
	player.position = Vector3(27,0.02,49)
	camera.position = Vector3(27,2.8,53)
	camera.look_at(Vector3(27,0.2,49))
	source.set_extinguished(false)
	await _sample("near_on")
	source.set_extinguished(true)
	await _sample("near_off")
	source.set_extinguished(false)
	player.position = Vector3(20,0.02,49)
	camera.position = Vector3(20,2.8,53)
	camera.look_at(Vector3(20,0.2,49))
	await _sample("far")
	source.set_extinguished(true)
	level.get_node("PortEnvironment/Lights/CountingLamp").set_extinguished(false)
	player.state_machine.change_state(&"Crawlspace")
	player.position = Vector3(65,1.72,14)
	camera.position = Vector3(69,1.3,14)
	camera.look_at(Vector3(65,1.3,14))
	await _sample("under_floor")
	if not rows[0].visibility > rows[1].visibility: failures.append("Switching off the nearby lamp must reduce V")
	if not rows[0].visibility > rows[2].visibility: failures.append("Outside light range must reduce V")
	if not rows[0].luminance > rows[1].luminance*1.1: failures.append("The same image must visibly darken when the lamp is extinguished")
	if rows[3].visibility > 0.05: failures.append("The solid counting floor must shield the crawlspace from its overhead lamp")
	var result := {"scope":"Fixed player/camera positions, frozen NPCs, same-frame V and center image luminance; not route clear evidence","failures":failures,"samples":rows}
	var file := FileAccess.open(output.path_join("result.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	print("PORT_LIGHTING ",JSON.stringify(result))
	get_tree().quit(0 if failures.is_empty() else 1)

func _sample(label: String) -> void:
	for frame in range(12): await RenderingServer.frame_post_draw
	var value := (player.get_node("Visibility") as PlayerVisibility).recompute()
	await RenderingServer.frame_post_draw
	var rendered := get_viewport().get_texture().get_image()
	var luminance := 0.0
	var samples := 0
	for x in range(rendered.get_width()/3,rendered.get_width()*2/3,8):
		for y in range(rendered.get_height()/3,rendered.get_height()*2/3,8):
			var color := rendered.get_pixel(x,y)
			luminance += color.r*0.2126+color.g*0.7152+color.b*0.0722
			samples += 1
	rendered.save_png(output.path_join(label+".png"))
	rows.append({"case":label,"visibility":value,"luminance":luminance/samples,"position":str(player.position)})
