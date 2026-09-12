extends GutTest

func test_archer_is_fixed_and_uses_wide_long_view_with_rear_blind_spot() -> void:
	var path := "res://src/enemies/archer_lookout.tscn"
	assert_true(ResourceLoader.exists(path))
	if not ResourceLoader.exists(path): return
	var archer = load(path).instantiate()
	add_child_autofree(archer)
	var perception: EnemyPerception = archer.get_node("Perception")
	assert_eq(perception.perception_config.fov_degrees,140.0)
	assert_eq(perception.perception_config.view_distance_m,25.0)
	assert_false(perception.can_see_position(Vector3(0,0.7,3)))
	var original: Vector3 = archer.position
	assert_false(archer.advance_navigation(0.25,Vector3(3,0,0),2.0))
	assert_eq(archer.position,original)

func test_arrow_uses_fixed_avoidable_velocity_and_hits_once() -> void:
	var path := "res://src/enemies/arrow_shot.gd"
	assert_true(FileAccess.file_exists(path))
	if not FileAccess.file_exists(path): return
	var arrow = load(path).new()
	add_child_autofree(arrow)
	arrow.set_physics_process(false)
	assert_true(arrow.launch(Vector3.ZERO,Vector3.FORWARD,null))
	arrow.advance(0.1)
	assert_almost_eq(arrow.position.z,-1.2,0.001)
	var player = load("res://src/player/player.tscn").instantiate()
	add_child_autofree(player)
	var health: int = player.combat.health()
	arrow.hit(player)
	arrow.hit(player)
	assert_eq(player.combat.health(),health-1)

func test_invalid_arrow_launch_stays_inert() -> void:
	var arrow := ArrowShot.new()
	add_child_autofree(arrow)
	arrow.set_physics_process(false)
	assert_false(arrow.launch(Vector3.ZERO,Vector3.ZERO,null))
	arrow.advance(0.1)
	assert_eq(arrow.position,Vector3.ZERO)

func test_archer_windup_aim_is_locked_before_avoidable_shot() -> void:
	var archer := load("res://src/enemies/archer_lookout.tscn").instantiate() as ArcherLookout
	add_child_autofree(archer)
	archer.set_physics_process(false)
	archer.brain().set_physics_process(false)
	var player := load("res://src/player/player.tscn").instantiate() as PlayerController
	player.position = Vector3(0,0,-8)
	add_child_autofree(player)
	player.set_physics_process(false)
	archer.brain().force_state(Enums.AlertState.COMBAT,&"test")
	archer.advance_archery(0.1)
	assert_eq(archer.shots_fired,0)
	player.position.x = 2
	archer.advance_archery(0.61)
	assert_eq(archer.shots_fired,1)
	var arrows := get_tree().get_nodes_in_group(&"enemy_arrows")
	assert_eq(arrows.size(),1)
	if arrows.size() == 1:
		assert_almost_eq(arrows[0].get("_direction").x,0.0,0.001)
		arrows[0].queue_free()

func test_archer_has_a_bow_and_an_aiming_pose() -> void:
	var archer := load("res://src/enemies/archer_lookout.tscn").instantiate() as ArcherLookout
	add_child_autofree(archer)
	await get_tree().process_frame
	var visual := archer.get_node("Visual/Model") as ActorAnimation
	visual.update_actor_presentation(0.016)
	assert_eq(visual.current_clip(),&"archer_aim")
	assert_eq(visual.get("_weapon").name,&"Bow")
