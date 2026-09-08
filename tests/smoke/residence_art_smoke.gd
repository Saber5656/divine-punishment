extends Node3D

## Diagnostic fixed-camera views under neutral fill, not final lighting QA.
func _ready() -> void:
	var output := "user://residence-art"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="): output = argument.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(output)
	var level = load("res://src/levels/samurai_residence/samurai_residence.tscn").instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame
	for layer in level.find_children("*", "CanvasLayer", true, false): layer.visible = false
	var camera := Camera3D.new()
	add_child(camera)
	camera.make_current()
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45,-30,0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(.16,.20,.24)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(.7,.75,.85)
	env.environment.ambient_light_energy = .6
	add_child(env)
	for row in [
		["overview",Vector3(104,65,98),Vector3(50,0,30)],
		["garden",Vector3(28,2,36),Vector3(53,2,20)],
		["tatami",Vector3(66,2.2,25),Vector3(57,1.5,19)],
		["roof",Vector3(46,7,6),Vector3(58,3,20)]]:
		camera.position = row[1]
		camera.look_at(row[2])
		for frame in range(8): await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output.path_join(row[0]+".png"))
	print("RESIDENCE_ART_SMOKE ",JSON.stringify({"coverage":level.get_node("ResidenceArt").coverage,"contract":level.is_contract_valid()}))
	get_tree().quit()
