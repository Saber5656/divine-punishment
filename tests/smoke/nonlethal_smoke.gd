extends Node3D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var output := "user://nonlethal54"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(output)
	SaveManager.save_path = "user://nonlethal54-smoke-only.json"
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("354a53")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.7
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45,-25,0)
	add_child(sun)
	var main = load("res://src/ui/main.tscn").instantiate()
	add_child(main)
	var director: SceneDirector = main.get_node("SceneDirector")
	var definition := load("res://data/missions/m09.tres").duplicate() as MissionDefinition
	definition.level_scene = load("res://tests/fixtures/nonlethal_mission.tscn")
	var objective := ObjectiveData.new()
	objective.id = &"rescue"
	objective.kind = &"RESCUE"
	objective.text_key = &"objective.practice_escape"
	definition.objectives = [objective]
	director.start_mission(definition)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	(floor_mesh.mesh as PlaneMesh).size = Vector2(20,20)
	add_child(floor_mesh)
	for frame in range(20): await get_tree().physics_frame
	var player: PlayerController = director.mission.get_node("Player")
	var enemy: EnemyBase = director.mission.get_node("Enemy")
	player.set_physics_process(false)
	enemy.set_physics_process(false)
	enemy.brain().set_physics_process(false)
	enemy.get_node("Perception").set_physics_process(false)
	enemy.rotation = Vector3.ZERO
	player.rotation = Vector3.ZERO
	player.global_position = enemy.global_position+Vector3(0,0,1)
	for frame in range(3): await get_tree().physics_frame
	print("NONLETHAL_SETUP ",JSON.stringify({"state":player.state_machine.current_state(),"can":player.get_node("NonlethalActions").can_knockout(enemy),"target":player.get_node("NonlethalActions").find_target(false)==enemy}))
	var health := enemy.health()
	var input := InputEventKey.new()
	input.physical_keycode = KEY_G
	input.pressed = true
	print("NONLETHAL_INPUT ",JSON.stringify({"match":input.is_action_pressed(&"knockout"),"events":str(InputMap.action_get_events(&"knockout")),"processing":player.get_node("NonlethalActions").is_processing_unhandled_input()}))
	get_viewport().push_input(input,true)
	await get_tree().process_frame
	input = InputEventKey.new()
	input.physical_keycode = KEY_G
	get_viewport().push_input(input,true)
	print("NONLETHAL_AFTER_INPUT ",enemy.brain().incapacitated_kind())
	var failures := 0
	if enemy.brain().incapacitated_kind() != &"knockout" or enemy.health() != health: failures += 1
	var tools: ToolRig = player.get_node("ToolRig")
	tools.inventory.select_slot(2)
	if not tools.use_selected(): failures += 1
	await get_tree().create_timer(2.2).timeout
	if enemy.brain().incapacitated_kind() != &"restrained" or enemy.is_defeated(): failures += 1
	if tools.inventory.remaining_count(2) != 3: failures += 1
	var carried := player.try_pick_up_body(enemy)
	if not carried: failures += 1
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output+"/restrained-carry.png")
	var old_id := director.mission.get_instance_id()
	EventBus.enemy_killed.emit(enemy,"fixture_external_kill")
	for frame in range(20): await get_tree().process_frame
	if director.mission.get_instance_id() == old_id or get_tree().paused: failures += 1
	print("NONLETHAL_SMOKE ",JSON.stringify({"failures":failures,"knockout_key":"G","restraint_seconds":2.0,"carried_without_killing":carried}))
	get_tree().quit(failures)
