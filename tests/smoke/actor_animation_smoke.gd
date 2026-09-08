extends Node3D

## Controlled pose inspection; this is not a first-player timing benchmark.
func _ready() -> void:
	var output := "user://animation-review"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="): output = argument.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(output)
	var camera := Camera3D.new()
	camera.position = Vector3(1.5, 1.6, -2.6)
	add_child(camera)
	camera.look_at(Vector3(0, 0.9, 0))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -30, 0)
	light.light_energy = 2.0
	add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.16, 0.18, 0.22)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.8, 0.85, 1)
	environment.environment.ambient_light_energy = 1.0
	add_child(environment)
	var player = load("res://src/player/player.tscn").instantiate()
	player.position = Vector3(0, 0.9, 0)
	add_child(player)
	player.set_physics_process(false)
	await get_tree().process_frame
	await get_tree().process_frame
	camera.make_current()
	for layer in player.find_children("*", "CanvasLayer", true, false): layer.visible = false
	var visual = player.get_node("Visual/Model")
	visual.set_process(false)
	var results: Array = []
	var failures := 0
	for clip in [&"idle", &"walk", &"crouch_walk", &"crawl", &"climb", &"wall_cling", &"beam", &"swim", &"assassination_back", &"assassination_above", &"assassination_below", &"assassination_corner"]:
		visual.show_clip(clip)
		for frame in range(18):
			visual.advance_visual(1.0 / 30.0)
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output.path_join(str(clip) + ".png"))
		var pose: Transform3D = visual.bone_pose(&"thigh_l")
		if not pose.is_finite(): failures += 1
		var bones: Dictionary = {}
		var skeleton: Skeleton3D = visual.get("_skeleton")
		for bone in [&"Head", &"pelvis", &"foot_l", &"foot_r", &"hand_l", &"hand_r"]:
			bones[str(bone)] = skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin
		results.append({"bones": bones, "clip": str(clip), "active": str(visual.current_clip()), "finite": pose.is_finite()})
	print("ANIMATION_SMOKE ", JSON.stringify({"failures": failures, "poses": results}))
	get_tree().quit(failures)
