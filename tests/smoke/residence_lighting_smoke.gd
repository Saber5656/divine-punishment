extends Node3D

## Fixed-position lighting comparison; not an input route or human playtest.
var output := "user://lighting-review"
var rows: Array = []
var level
var camera: Camera3D
var player
var failures := 0
func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="): output=argument.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(output)
	level=load("res://src/levels/samurai_residence/samurai_residence.tscn").instantiate()
	add_child(level)
	for frame in range(6): await get_tree().process_frame
	player=level.get_node("Player")
	player.set_physics_process(false)
	for npc in level.get_node("Mission").npcs.values(): npc.process_mode=Node.PROCESS_MODE_DISABLED
	for source in level.get_node("Markers/Lights").get_children(): source.set_extinguished(true)
	camera=Camera3D.new();add_child(camera);camera.make_current()
	var source=level.get_node("Markers/Lights/L2_LanternGarden")
	player.global_position=Vector3(36,.02,22)
	camera.position=Vector3(36,2.8,26);camera.look_at(Vector3(36,.2,22))
	source.set_extinguished(false)
	await _sample("near_on")
	source.set_extinguished(true)
	await _sample("near_off")
	source.set_extinguished(false)
	player.global_position=Vector3(29,.02,28)
	camera.position=Vector3(29,2.8,32);camera.look_at(Vector3(29,.2,28))
	await _sample("far")
	source.set_extinguished(true)
	level.get_node("Markers/Lights/L10_LatrineLantern").set_extinguished(false)
	player.state_machine.change_state(&"Crawlspace")
	player.global_position=Vector3(66,.02,18)
	camera.position=Vector3(66,-.3,21);camera.look_at(Vector3(66,0,18))
	await _sample("under_floor")
	if not (rows[0].visibility>rows[1].visibility and rows[0].visibility>rows[2].visibility): failures+=1
	if not rows[0].luminance>rows[1].luminance*1.1: failures+=1
	if rows[3].visibility>0.05: failures+=1
	print("LIGHTING_SMOKE ",JSON.stringify({"failures":failures,"samples":rows}))
	get_tree().quit(failures)
func _sample(label: String) -> void:
	for frame in range(12): await get_tree().process_frame
	var value: float=player.get_node("Visibility").recompute()
	await RenderingServer.frame_post_draw
	var image=get_viewport().get_texture().get_image()
	var luminance:=0.0
	var samples:=0
	for x in range(image.get_width()/3,image.get_width()*2/3,8):
		for y in range(image.get_height()/3,image.get_height()*2/3,8):
			var color=image.get_pixel(x,y)
			luminance+=color.r*.2126+color.g*.7152+color.b*.0722
			samples+=1
	var overlay=level.get_node("ResidenceLighting/StealthDebugOverlay")
	overlay.set_debug_visible(true)
	for frame in range(2): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join(label+".png"))
	overlay.set_debug_visible(false)
	rows.append({"case":label,"visibility":value,"luminance":luminance/samples,"debug_visibility":overlay.player_visibility_value()})
