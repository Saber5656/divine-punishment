extends GutTest

func after_each() -> void:
	MissionDirector.start_mission(null)

func test_escort_follow_wait_and_two_person_hide_contract() -> void:
	var path := "res://src/npcs/escort_companion.gd"
	assert_true(FileAccess.file_exists(path))
	if not FileAccess.file_exists(path): return
	var player = load("res://src/player/player.tscn").instantiate()
	add_child_autofree(player)
	player.set_physics_process(false)
	var companion = load(path).new()
	add_child_autofree(companion)
	assert_true(companion.follow(player))
	assert_eq(player.state_machine.current_state(),&"Escort")
	assert_false(player.state_machine.change_state(&"Sprint"))
	var spot := HideSpot.new()
	add_child_autofree(spot)
	assert_false(spot.can_enter(player))
	spot.set("occupant_capacity",2)
	assert_true(spot.can_enter(player))
	companion.wait_here()
	assert_eq(player.state_machine.current_state(),&"Ground")
	assert_true(player.state_machine.change_state(&"Sprint"))

func test_protected_npc_twelve_minute_hook_is_soft_and_enemy_kill_is_not_player_penalty() -> void:
	var path := "res://src/npcs/protected_npc.gd"
	assert_true(FileAccess.file_exists(path))
	if not FileAccess.file_exists(path): return
	var npc = load(path).new()
	add_child_autofree(npc)
	npc.set_physics_process(false)
	var events: Array = []
	var deaths: Array = []
	var event_listener := func(id,payload): events.append(id)
	var death_listener := func(who): deaths.append(who)
	EventBus.mission_event.connect(event_listener)
	EventBus.civilian_killed.connect(death_listener)
	npc.advance_protection(719.0)
	assert_false(&"protected_target_threatened" in events)
	npc.advance_protection(1.0)
	assert_true(&"protected_target_threatened" in events)
	assert_false(npc.is_defeated(),"Deadline starts a threat, never hard-fails the mission")
	var enemy = load("res://src/enemies/enemy_base.tscn").instantiate()
	add_child_autofree(enemy)
	npc.receive_combat_damage(1,enemy)
	assert_true(&"protected_target_lost" in events)
	assert_eq(deaths.size(),0)
	EventBus.mission_event.disconnect(event_listener)
	EventBus.civilian_killed.disconnect(death_listener)

func test_escort_can_crouch_and_crawl_without_unlocking_sprint_and_hides_both_people() -> void:
	var player = load("res://src/player/player.tscn").instantiate()
	add_child_autofree(player)
	player.set_physics_process(false)
	var companion := EscortCompanion.new()
	add_child_autofree(companion)
	assert_true(companion.follow(player))
	assert_true(player.state_machine.change_state(&"Crouch"))
	assert_false(player.state_machine.change_state(&"Sprint"))
	assert_true(player.state_machine.change_state(&"Crawlspace"))
	companion.advance_follow(0.1)
	var shapes := companion.find_children("*","CollisionShape3D",true,false)
	assert_almost_eq((shapes[0].shape as CapsuleShape3D).height,0.6,0.0001)
	assert_true(player.state_machine.change_state(&"Crouch"))
	assert_true(player.state_machine.change_state(&"Hidden"))
	companion.advance_follow(0.1)
	assert_false(companion.visible)
	assert_true(companion.has_method(&"is_visibility_excluded"))

func test_escort_follows_on_a_physical_floor_and_navigation_mesh() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.position.y = -0.1
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(20,0.2,20)
	floor_body.add_child(shape)
	add_child_autofree(floor_body)
	var region := NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	mesh.vertices = PackedVector3Array([Vector3(-10,0.9,-10),Vector3(10,0.9,-10),Vector3(10,0.9,10),Vector3(-10,0.9,10)])
	mesh.add_polygon(PackedInt32Array([0,1,2,3]))
	region.navigation_mesh = mesh
	add_child_autofree(region)
	var player := load("res://src/player/player.tscn").instantiate() as PlayerController
	player.position.y = 0.9
	add_child_autofree(player)
	player.set_physics_process(false)
	var companion := EscortCompanion.new()
	companion.position = Vector3(0,0,1.4)
	add_child_autofree(companion)
	companion.set_physics_process(false)
	for frame in range(3): await get_tree().physics_frame
	assert_true(companion.follow(player))
	player.position.x = 2.0
	for frame in range(100):
		companion.advance_follow(1.0/60.0)
		await get_tree().physics_frame
	assert_gt(companion.position.x,1.0,"Follower must cross a real floor, not only change state")

func test_unarmored_civilian_is_defeated_by_one_sword_hit() -> void:
	var civilian := CivilianNPC.new()
	add_child_autofree(civilian)
	civilian.receive_combat_damage(1)
	assert_true(civilian.is_defeated())

func test_following_companion_does_not_make_player_invulnerable() -> void:
	var player := load("res://src/player/player.tscn").instantiate() as PlayerController
	add_child_autofree(player)
	player.set_physics_process(false)
	var companion := EscortCompanion.new()
	add_child_autofree(companion)
	assert_true(companion.follow(player))
	var before := player.health()
	assert_eq(player.receive_combat_damage(1),1)
	assert_eq(player.health(),before-1)
	assert_eq(player.state_machine.current_state(),&"Escort")
	assert_false(player.state_machine.change_state(&"Combat"))
