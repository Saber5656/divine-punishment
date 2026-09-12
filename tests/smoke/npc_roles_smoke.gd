extends Node3D

func _ready() -> void:
	var output := "user://npc58"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(output)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("35434b")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.7
	add_child(environment)
	var floor_body := StaticBody3D.new()
	floor_body.position.y = -0.1
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(40,0.2,40)
	floor_body.add_child(shape)
	var ground := MeshInstance3D.new()
	ground.mesh = BoxMesh.new()
	(ground.mesh as BoxMesh).size = Vector3(40,0.2,40)
	floor_body.add_child(ground)
	add_child(floor_body)
	var region := NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	mesh.vertices = PackedVector3Array([Vector3(-20,0.9,-20),Vector3(20,0.9,-20),Vector3(20,0.9,20),Vector3(-20,0.9,20)])
	mesh.add_polygon(PackedInt32Array([0,1,2,3]))
	region.navigation_mesh = mesh
	add_child(region)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(10,9,12)
	camera.look_at(Vector3.ZERO)
	var player := load("res://src/player/player.tscn").instantiate() as PlayerController
	add_child(player)
	player.get_node("CameraRig").process_mode = Node.PROCESS_MODE_DISABLED
	camera.current = true
	var companion := EscortCompanion.new()
	companion.position = Vector3(0,0,1.4)
	add_child(companion)
	for frame in range(30): await get_tree().physics_frame
	player.set_physics_process(false)
	var failures := 0
	var input := InputEventKey.new()
	input.physical_keycode = KEY_T
	input.pressed = true
	get_viewport().push_input(input,true)
	await get_tree().process_frame
	input = InputEventKey.new()
	input.physical_keycode = KEY_T
	get_viewport().push_input(input,true)
	if player.state_machine.current_state() != &"Escort": failures += 1
	if player.state_machine.change_state(&"Sprint"): failures += 1
	player.position.x = 2.0
	await get_tree().create_timer(1.6).timeout
	var follow_position := companion.position
	var follow_state := player.state_machine.current_state()
	var followed := companion.position.x > 1.0
	if not followed: failures += 1
	var hide_spot := HideSpot.new()
	hide_spot.position = player.position
	add_child(hide_spot)
	if player.try_enter_hide_spot(hide_spot): failures += 1
	hide_spot.occupant_capacity = 2
	if not player.try_enter_hide_spot(hide_spot): failures += 1
	for frame in range(3): await get_tree().physics_frame
	var hid_both := player.is_hidden() and not companion.visible
	if not hid_both: failures += 1
	player.try_exit_hide_spot()
	companion.wait_here()
	var protected := ProtectedNPC.new()
	protected.position = Vector3(6,0,-2)
	add_child(protected)
	protected.advance_protection(720.0)
	if not protected.threatened or protected.is_defeated(): failures += 1
	var archer := load("res://src/enemies/archer_lookout.tscn").instantiate() as ArcherLookout
	archer.position = Vector3(-3,0.9,-5)
	archer.rotation.y = PI
	add_child(archer)
	archer.set_physics_process(false)
	archer.brain().set_physics_process(false)
	archer.brain().force_state(Enums.AlertState.COMBAT,&"fixture")
	archer.advance_archery(0.1)
	archer.advance_archery(0.61)
	var hp := player.health()
	player.position.x += 3.0
	await get_tree().create_timer(1.0).timeout
	if archer.shots_fired != 1 or player.health() != hp: failures += 1
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output+"/archer-escort.png")
	player.position = Vector3(30,0,30)
	var target := load("res://src/enemies/target_npc.tscn").instantiate() as TargetNpc
	target.position = Vector3(-6,0.9,5)
	add_child(target)
	var guards: Array[EscortGuard] = []
	for index in range(12):
		var guard := load("res://src/enemies/escort_guard.tscn").instantiate() as EscortGuard
		guard.position = target.position+Vector3(-1 if index%2==0 else 1,0,float(index/2)+1.5)
		add_child(guard)
		guards.append(guard)
	var route := Curve3D.new()
	route.add_point(Vector3(-6,0.9,5))
	route.add_point(Vector3(6,0.9,5))
	var procession := ProcessionController.new()
	add_child(procession)
	procession.rest_seconds = 1.2
	procession.configure(target,guards,route)
	var rests: Array = []
	EventBus.mission_event.connect(func(id,payload):
		if id == &"procession_rest": rests.append(payload.index))
	var exited := false
	var elapsed := 0.0
	while procession.phase != &"finished" and elapsed < 24.0:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if procession.phase == &"resting" and target.global_position.distance_to(procession.get_node("Palanquin").global_position) > 0.7:
			if not exited:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(output+"/procession-rest.png")
			exited = true
	if rests != [0,1,2] or not exited or procession.phase != &"finished": failures += 1
	print("NPC_ROLES_SMOKE ",JSON.stringify({"failures":failures,"followed":followed,"follow_position":str(follow_position),"follow_state":follow_state,"hid_both":hid_both,"arrow_avoided":player.health()==hp,"rests":rests,"target_exited":exited,"guards":guards.size(),"phase":procession.phase}))
	get_tree().quit(failures)
