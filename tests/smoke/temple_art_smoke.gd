extends Node

class VolatileStore extends "res://src/autoload/save_manager.gd":
	func commit() -> void: last_error = OK

var output := "user://temple63"

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(output)
	DisplayServer.window_set_size(Vector2i(1440,900))
	get_tree().create_timer(90.0,true,false,true).timeout.connect(func(): get_tree().quit(1))
	var store := VolatileStore.new()
	store.save_path = "user://temple63-smoke-only.json"
	add_child(store)
	store.campaign().unlocked_mission = 4
	var main: Node = load("res://src/ui/main.tscn").instantiate()
	var director := main.get_node("SceneDirector") as SceneDirector
	director.save_manager = store
	add_child(main)
	director.show_mission_select()
	var board := director.find_children("*","CampaignSelection",true,false)[0] as CampaignSelection
	board.select_mission(3)
	board.start_button.pressed.emit()
	var level := director.mission as RainyTemple
	var art := level.get_node("TempleArt")
	var camera := Camera3D.new()
	camera.fov = 65
	level.add_child(camera)
	camera.make_current()
	for frame in range(60): await get_tree().process_frame
	for spec in [["gate",Vector3(41,6,70),Vector3(48,5,56)],["hall",Vector3(45,10,36),Vector3(51,9,22)],["bell",Vector3(21,6,60),Vector3(26,6,54)],["graves",Vector3(9,5.8,59),Vector3(19,4.2,49)],["lodging",Vector3(29,5.6,57),Vector3(27,6,46)],["roof",Vector3(44,13.5,30),Vector3(52,11.4,22)],["cell",Vector3(72,6.4,28),Vector3(80,5.6,35)],["mill",Vector3(94,2.5,54),Vector3(86,2,44)]]:
		camera.position = spec[1]
		camera.look_at(spec[2])
		for frame in range(40): await get_tree().process_frame
		await _shot(spec[0])
	var lamp := level.get_node("TempleEnvironment/Lights/CellLamp") as LightSource
	camera.position = Vector3(79,6.2,30)
	camera.look_at(Vector3(84,5.7,35))
	await _shot("lamp-on")
	lamp.set_extinguished(true)
	for frame in range(4): await get_tree().process_frame
	await _shot("lamp-off")
	lamp.set_extinguished(false)
	var player := level.get_node("Player") as PlayerController
	for spec in [["rain-covered",Vector3(46,8.02,26),Vector3(46,9.2,29),Vector3(51,9.5,21)],["rain-outdoor",Vector3(48,4.02,45),Vector3(48,5.8,49),Vector3(48,7,38)]]:
		player.global_position = spec[1]
		camera.position = spec[2]
		camera.look_at(spec[3])
		await get_tree().create_timer(2.0).timeout
		await _shot(spec[0])
	var result := {"scope":"Visual camera plus two explicit player placements for covered/outdoor rain inspection; active AI and normal clock; not route proof","coverage":art.coverage,"physical_contract_unchanged":art.capture_contract(level)==art.before_contract,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)}
	FileAccess.open(output+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	director.show_title()
	for frame in range(3): await get_tree().physics_frame
	get_tree().quit(0 if result.physical_contract_unchanged else 1)

func _shot(name_: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output+"/"+name_+".png")
