extends Node3D

## Controlled presentation inspection, not a human gameplay acceptance test.
var output := "user://presentation-review"
var failures := 0
var rows: Array = []
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="): output = argument.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(output)
	var main = load("res://src/ui/main.tscn").instantiate()
	add_child(main)
	var director = main.get_node("SceneDirector")
	director.start_mission()
	for frame in range(8): await get_tree().process_frame
	var player = director.mission.get_node("Player")
	player.set_physics_process(false)
	var enemy = load("res://src/enemies/enemy_base.tscn").instantiate()
	add_child(enemy)
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	enemy.global_position = player.global_position + Vector3(0,0,-1)
	var rig = player.get_node("CameraRig")
	var camera = rig.get_node("SpringArm3D/Camera3D")
	camera.make_current()
	var original_fov: float = camera.fov
	var presentation = player.get_node("AssassinationResolver/AssassinationPresentation")
	for context in [&"back", &"above", &"below", &"corner"]:
		player.state_machine.change_state(&"Assassinate")
		presentation.begin(enemy, context)
		var start := Time.get_ticks_msec()
		await get_tree().create_timer(.63).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(output.path_join(str(context)+".png"))
		var clip: String = str(player.get_node("Visual/Model").current_clip())
		while presentation.is_active(): await get_tree().process_frame
		var elapsed := (Time.get_ticks_msec()-start)/1000.0
		if elapsed<1.0 or elapsed>2.0 or abs(camera.fov-original_fov)>.001: failures+=1
		rows.append({"context":str(context),"seconds":elapsed,"clip":clip,"restored_fov":camera.fov})
	EventBus.player_detected.emit()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join("detection.png"))
	await get_tree().create_timer(1.0).timeout
	if rig.get_node("GameplayPresentation").alarm_strength!=0.0: failures+=1
	# Failed/unfinished result avoids changing a real campaign save.
	director.show_result()
	await get_tree().create_timer(1.1,true).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join("result.png"))
	var rank = director.find_child("Rank",true,false)
	if rank==null or rank.modulate.a!=1.0: failures+=1
	print("PRESENTATION_SMOKE ",JSON.stringify({"failures":failures,"contexts":rows,"rank":rank.text if rank!=null else "missing"}))
	get_tree().paused=false
	get_tree().quit(failures)
