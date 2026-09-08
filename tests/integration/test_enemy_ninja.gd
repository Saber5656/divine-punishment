extends GutTest

func test_ninja_archetype_loads_perception_navigation_immunity_and_fast_relight() -> void:
	var path := "res://src/enemies/enemy_ninja.tscn"
	assert_true(ResourceLoader.exists(path))
	if not ResourceLoader.exists(path): return
	var ninja = load(path).instantiate()
	add_child_autofree(ninja)
	var config: PerceptionConfig = ninja.get_node("Perception").perception_config
	assert_eq(config.fov_degrees,130.0)
	assert_eq(config.hearing_multiplier,1.5)
	assert_true(config.dart_immune)
	assert_eq(ninja.get_node("NavigationAgent3D").navigation_layers,3)
	assert_false(ninja.set_incapacitated(&"knockout",60.0))
	assert_false(ninja.brain().set_incapacitated(&"sleep",60.0))
	assert_eq(ninja.brain().get("relight_delay_seconds"),0.0)
	assert_eq(ninja.max_health(),4)

func test_ninja_places_bounded_caltrops_while_searching() -> void:
	var path := "res://src/enemies/enemy_ninja.tscn"
	assert_true(ResourceLoader.exists(path))
	if not ResourceLoader.exists(path): return
	var ninja = load(path).instantiate()
	add_child_autofree(ninja)
	ninja.set_physics_process(false)
	ninja.brain().submit_stimulus(PerceptionStimulus.create(Enums.StimulusKind.NOISE,3,Vector3(0,0,-3),1.0))
	ninja.brain()._physics_process(0.016)
	ninja.advance_tactics(1.0)
	assert_eq(ninja.active_caltrops().size(),1)
	for i in range(10): ninja.advance_tactics(10.0)
	assert_lte(ninja.active_caltrops().size(),3)
	for trap in ninja.active_caltrops(): trap.queue_free()

func test_caltrop_damage_is_single_use_and_expires() -> void:
	var player = load("res://src/player/player.tscn").instantiate()
	add_child_autofree(player)
	var trap := CaltropTrap.new()
	add_child_autofree(trap)
	var before: int = player.combat.health()
	trap.trigger(player)
	trap.trigger(player)
	assert_eq(player.combat.health(),before-1)
	var expired := CaltropTrap.new()
	add_child_autofree(expired)
	expired._process(30.0)
	assert_true(expired.is_queued_for_deletion())

func test_ninja_traverses_dedicated_vertical_link_ordinary_guard_cannot() -> void:
	var world := Node3D.new()
	add_child_autofree(world)
	var floor_body := StaticBody3D.new()
	floor_body.position.y = -0.1
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = BoxShape3D.new()
	(floor_shape.shape as BoxShape3D).size = Vector3(10,0.2,10)
	floor_body.add_child(floor_shape)
	world.add_child(floor_body)
	var roof := StaticBody3D.new()
	roof.position = Vector3(2.75,2.9,0)
	var roof_shape := CollisionShape3D.new()
	roof_shape.shape = BoxShape3D.new()
	(roof_shape.shape as BoxShape3D).size = Vector3(4.5,0.2,4)
	roof.add_child(roof_shape)
	world.add_child(roof)
	for height in [0.9,3.9]:
		var region := NavigationRegion3D.new()
		region.navigation_layers = 1 if height < 1 else 2
		var mesh := NavigationMesh.new()
		mesh.vertices = PackedVector3Array([Vector3(-2,height,-2),Vector3(4,height,-2),Vector3(4,height,2),Vector3(-2,height,2)])
		mesh.add_polygon(PackedInt32Array([0,1,2,3]))
		region.navigation_mesh = mesh
		world.add_child(region)
	var link := NavigationLink3D.new()
	link.navigation_layers = 2
	link.start_position = Vector3(0,0.9,0)
	link.end_position = Vector3(0,3.9,0)
	world.add_child(link)
	var ninja = load("res://src/enemies/enemy_ninja.tscn").instantiate()
	ninja.position = Vector3(0,0.9,1)
	world.add_child(ninja)
	ninja.brain().set_physics_process(false)
	var guard = load("res://src/enemies/enemy_base.tscn").instantiate()
	guard.position = Vector3(1,0.9,1)
	world.add_child(guard)
	guard.brain().set_physics_process(false)
	for frame in range(5): await get_tree().physics_frame
	var target := Vector3(2,3.9,-1)
	for frame in range(300):
		ninja.brain()._set_navigation_target(target)
		ninja.advance_navigation(1.0/60.0,target,2.4)
		guard.advance_navigation(1.0/60.0,target,2.4)
		await get_tree().physics_frame
	print("NINJA_PATH ",ninja.position," ",ninja.get_node("NavigationAgent3D").get_current_navigation_path())
	assert_lt(ninja.position.distance_to(target),0.6,"Ninja must get onto the roof, not stop at its lip")
	assert_gt(ninja.position.y,3.4,"Ninja must follow the authored roof link")
	assert_lt(guard.position.y,1.0,"Ordinary guards cannot use ninja-only links")

func test_first_navigation_target_at_origin_still_initializes_path() -> void:
	var world := Node3D.new()
	add_child_autofree(world)
	var region := NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	mesh.vertices = PackedVector3Array([Vector3(-2,0,-2),Vector3(2,0,-2),Vector3(2,0,2),Vector3(-2,0,2)])
	mesh.add_polygon(PackedInt32Array([0,1,2,3]))
	region.navigation_mesh = mesh
	world.add_child(region)
	var enemy = load("res://src/enemies/enemy_base.tscn").instantiate()
	enemy.position = Vector3(1,0,1)
	world.add_child(enemy)
	enemy.brain().set_physics_process(false)
	for frame in range(4): await get_tree().physics_frame
	for frame in range(10):
		enemy.advance_navigation(0.05,Vector3.ZERO,2.0)
		await get_tree().physics_frame
	assert_lt(enemy.position.length(),1.0)

func test_ninja_relights_nearby_discovered_light_without_sixty_second_delay() -> void:
	var ninja = load("res://src/enemies/enemy_ninja.tscn").instantiate()
	add_child_autofree(ninja)
	ninja.brain().set_physics_process(false)
	var light := LightSource.new()
	light.position = Vector3(0,0.5,-0.5)
	add_child_autofree(light)
	light.set_extinguished(true)
	ninja.brain().submit_stimulus(PerceptionStimulus.create(Enums.StimulusKind.ANOMALY,1,light.position,1.0,light.current_anomaly()))
	ninja.brain()._physics_process(0.016)
	ninja.brain()._physics_process(0.016)
	assert_true(light.is_on())

func test_ninja_visibility_gain_is_lower_in_actual_darkness() -> void:
	var ninja = load("res://src/enemies/enemy_ninja.tscn").instantiate()
	add_child_autofree(ninja)
	ninja.brain().set_physics_process(false)
	var player = load("res://src/player/player.tscn").instantiate()
	player.position = Vector3(0,0,-4)
	add_child_autofree(player)
	player.set_physics_process(false)
	var light := LightSource.new()
	light.position = player.position+Vector3.UP
	add_child_autofree(light)
	var visibility: PlayerVisibility = player.get_node("Visibility")
	var perception: EnemyPerception = ninja.get_node("Perception")
	visibility.recompute()
	perception._evaluate_visual(0.1,player)
	var bright := perception.meter()
	perception.restore_checkpoint_meter(0.0)
	light.set_extinguished(true)
	visibility.recompute()
	perception._evaluate_visual(0.1,player)
	assert_gt(bright,0.0)
	assert_lt(perception.meter(),bright)

func test_ninja_presentation_uses_actual_climbing_displacement() -> void:
	var ninja = load("res://src/enemies/enemy_ninja.tscn").instantiate()
	add_child_autofree(ninja)
	ninja.brain().set_physics_process(false)
	await get_tree().process_frame
	var visual: ActorAnimation = ninja.get_node("Visual/Model")
	visual.set_process(false)
	visual.update_actor_presentation(0.016)
	ninja.position.y += 0.1
	visual.update_actor_presentation(0.016)
	assert_eq(visual.get("_clip"),&"climb")
