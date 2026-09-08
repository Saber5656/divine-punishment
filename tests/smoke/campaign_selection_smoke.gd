extends Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var output := "user://campaign53"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(output)
	SaveManager.save_path = "user://campaign53-smoke-only.json"
	SaveManager.campaign().unlocked_mission = 2
	SaveManager.campaign().mission_results = {"m01":{"rank":"kaiden","score":100,"flags":{"shadow_walker":true,"no_traces":true,"one_strike":true,"swift":true,"side_objective":true}}}
	var main = load("res://src/ui/main.tscn").instantiate()
	add_child(main)
	var director: SceneDirector = main.get_node("SceneDirector")
	var failures := 0
	director.show_mission_select()
	for dimensions in [Vector2i(1280,720),Vector2i(640,360)]:
		DisplayServer.window_set_size(dimensions)
		for frame in range(8): await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var board: CampaignSelection = director.get_node("Menu").find_child("CampaignSelection",true,false) if director.has_node("Menu") else director.find_child("CampaignSelection",true,false)
		if board == null or board.slots.size() != 10: failures += 1
		else:
			if board.global_position.x+board.size.x > get_viewport().get_visible_rect().size.x: failures += 1
		get_viewport().get_texture().get_image().save_png(output+"/select-%d.png" % dimensions.x)
	SaveManager.campaign().mission_results.m10 = {"rank":"shoden","score":0,"flags":{}}
	DisplayServer.window_set_size(Vector2i(1280,720))
	director.show_title()
	for frame in range(8): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output+"/spring-title.png")
	print("CAMPAIGN_SELECTION_SMOKE ",JSON.stringify({"failures":failures}))
	get_tree().quit(failures)
