extends Node3D

func _ready() -> void:
	var output := "user://civilian56"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(output)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("33464a")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.8
	add_child(environment)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(4,4,6)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	(floor_mesh.mesh as PlaneMesh).size = Vector2(16,16)
	add_child(floor_mesh)
	var crowd := CrowdHideSpot.new()
	add_child(crowd)
	var player := load("res://src/player/player.tscn").instantiate() as PlayerController
	add_child(player)
	player.set_physics_process(false)
	player.get_node("CameraRig").process_mode = Node.PROCESS_MODE_DISABLED
	camera.current = true
	var noises: Array = []
	EventBus.noise_emitted.connect(func(event):
		if event.kind == Enums.NoiseKind.SCREAM: noises.append(event))
	await get_tree().create_timer(0.6).timeout
	var failures := 0
	var tools: ToolRig = player.get_node("ToolRig")
	var stones := tools.inventory.remaining_count(0)
	print("CIVILIAN_BEFORE ",JSON.stringify({"hidden":player.is_visibility_excluded(),"screams":noises.size(),"state":player.state_machine.current_state()}))
	if not player.is_visibility_excluded() or noises.size() != 0: failures += 1
	var input := InputEventKey.new()
	input.physical_keycode = KEY_R
	input.pressed = true
	get_viewport().push_input(input,true)
	await get_tree().process_frame
	input = InputEventKey.new()
	input.physical_keycode = KEY_R
	get_viewport().push_input(input,true)
	if noises.size() == 0: failures += 1
	print("CIVILIAN_AFTER ",JSON.stringify({"hidden":player.is_visibility_excluded(),"state":player.state_machine.current_state(),"allowed":player.combat._combat_input_allowed()}))
	if player.is_visibility_excluded(): failures += 1
	if tools.inventory.remaining_count(0) != stones: failures += 1
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output+"/crowd-alarm.png")
	print("CIVILIAN_SMOKE ",JSON.stringify({"failures":failures,"screams":noises.size(),"instances":crowd.get_node("CrowdInstances").multimesh.instance_count}))
	get_tree().quit(failures)
