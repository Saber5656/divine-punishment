extends Node3D

func _ready() -> void:
	var output := "user://elite57"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): output = arg.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(output)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("2c3945")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.65
	add_child(environment)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(-7,6,7)
	camera.look_at(Vector3(1,2,0))
	camera.current = true
	_add_floor(Vector3(0,-0.1,0),Vector3(12,0.2,12))
	_add_floor(Vector3(2.75,2.9,0),Vector3(4.5,0.2,4))
	for height in [0.9,3.9]:
		var region := NavigationRegion3D.new()
		region.navigation_layers = 1 if height < 1 else 2
		var mesh := NavigationMesh.new()
		var left := -5.0 if height < 1 else 0.0
		mesh.vertices = PackedVector3Array([Vector3(left,height,-2),Vector3(5,height,-2),Vector3(5,height,2),Vector3(left,height,2)])
		mesh.add_polygon(PackedInt32Array([0,1,2,3]))
		region.navigation_mesh = mesh
		add_child(region)
	var link := NavigationLink3D.new()
	link.navigation_layers = 2
	link.start_position = Vector3(0,0.9,0)
	link.end_position = Vector3(0,3.9,0)
	add_child(link)
	var ninja := load("res://src/enemies/enemy_ninja.tscn").instantiate() as EnemyNinja
	ninja.position = Vector3(-1,0.9,0)
	add_child(ninja)
	var guard := load("res://src/enemies/enemy_base.tscn").instantiate() as EnemyBase
	guard.position = Vector3(-1,0.9,1.5)
	add_child(guard)
	for frame in range(5): await get_tree().physics_frame
	var target := Vector3(2,3.9,0)
	for actor in [ninja,guard]:
		actor.brain().submit_stimulus(PerceptionStimulus.create(Enums.StimulusKind.NOISE,1,target,1.0))
	await get_tree().create_timer(3.5).timeout
	var failures := 0
	if ninja.position.distance_to(target) > 0.6 or guard.position.y > 1.0: failures += 1
	var climbed := ninja.position
	print("ELITE_PATH ",ninja.get_node("NavigationAgent3D").get_current_navigation_path()," target ",ninja.brain()._investigation_navigation_target()," state ",ninja.brain().alert_state())
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output+"/roof-pursuit.png")
	ninja.brain().set_physics_process(false)
	ninja.brain().submit_stimulus(PerceptionStimulus.create(Enums.StimulusKind.NOISE,3,target,1.0))
	ninja.brain()._physics_process(0.016)
	ninja.advance_tactics(1.0)
	if ninja.active_caltrops().size() != 1: failures += 1
	var player := load("res://src/player/player.tscn").instantiate() as PlayerController
	player.position = Vector3(-3,0,-4)
	add_child(player)
	player.set_physics_process(false)
	ninja.position = Vector3(-3,0,0)
	ninja.rotation = Vector3.ZERO
	var light := LightSource.new()
	light.position = player.position+Vector3.UP
	add_child(light)
	var visibility := player.get_node("Visibility") as PlayerVisibility
	var perception := ninja.get_node("Perception") as EnemyPerception
	visibility.recompute()
	perception.restore_checkpoint_meter(0.0)
	perception._evaluate_visual(0.1,player)
	var bright := perception.meter()
	light.set_extinguished(true)
	visibility.recompute()
	perception.restore_checkpoint_meter(0.0)
	perception._evaluate_visual(0.1,player)
	var dark := perception.meter()
	if bright <= 0.0 or dark >= bright: failures += 1
	print("ELITE_SMOKE ",JSON.stringify({"failures":failures,"ninja_position":str(climbed),"guard_height":guard.position.y,"bright_gain":bright,"dark_gain":dark,"caltrops":ninja.active_caltrops().size()}))
	get_tree().quit(failures)

func _add_floor(point: Vector3,size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = point
	add_child(body)
	var collision := CollisionShape3D.new()
	collision.shape = BoxShape3D.new()
	(collision.shape as BoxShape3D).size = size
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	visual.mesh = BoxMesh.new()
	(visual.mesh as BoxMesh).size = size
	body.add_child(visual)
