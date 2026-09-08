extends Node3D

func _ready() -> void:
	var output := "user://weather55"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(output)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("374553")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.7
	add_child(environment)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(4,4,7)
	camera.look_at(Vector3(0,0,-2))
	camera.current = true
	var floor_body := StaticBody3D.new()
	floor_body.set_meta(&"floor_material",&"snow")
	add_child(floor_body)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(30,0.2,30)
	shape.position.y = -0.1
	floor_body.add_child(shape)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	(floor_mesh.mesh as PlaneMesh).size = Vector2(30,30)
	floor_body.add_child(floor_mesh)
	var player := Node3D.new()
	player.add_to_group(&"player")
	add_child(player)
	WeatherSystem.start(MissionDefinition.Weather.RAIN)
	var presentation := WeatherPresentation.new()
	add_child(presentation)
	await get_tree().create_timer(2.0).timeout
	var failures := 0
	if not presentation.get_node("RainAudio").playing: failures += 1
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output+"/rain.png")
	WeatherSystem.start(MissionDefinition.Weather.SNOW)
	for index in range(40):
		player.position.z = -index*0.1
		await get_tree().create_timer(0.11).timeout
	if presentation.markers.size() < 4: failures += 1
	if presentation.get_node("RainAudio").playing: failures += 1
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output+"/snow.png")
	var count := presentation.markers.size()
	WeatherSystem.advance(90.0)
	presentation.sync_footprints()
	if presentation.markers.size() != 0: failures += 1
	WeatherSystem.set_weather(&"clear")
	await get_tree().process_frame
	await get_tree().process_frame
	if presentation.get_node("Precipitation").emitting: failures += 1
	print("WEATHER_SMOKE ",JSON.stringify({"failures":failures,"footprints":count,"rain_to_snow_to_clear":true}))
	get_tree().quit(failures)
