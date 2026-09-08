extends GutTest

func test_civilian_scans_at_two_hz_and_screams_with_fifteen_meter_radius() -> void:
	var path := "res://src/npcs/civilian_npc.gd"
	assert_true(FileAccess.file_exists(path))
	if not FileAccess.file_exists(path): return
	var civilian = load(path).new()
	add_child_autofree(civilian)
	civilian.set_physics_process(false)
	var player = load("res://src/player/player.tscn").instantiate()
	player.position = Vector3(0,0,-3)
	add_child_autofree(player)
	player.set_physics_process(false)
	var heard: Array = []
	var listener := func(event): heard.append(event)
	EventBus.noise_emitted.connect(listener)
	civilian.advance_perception(0.49,player)
	assert_eq(heard.size(),0)
	civilian.advance_perception(0.01,player)
	assert_eq(heard.size(),1)
	if heard.size() == 1:
		assert_eq(heard[0].kind,Enums.NoiseKind.SCREAM)
		assert_eq(heard[0].radius,15.0)
	civilian.advance_perception(0.5,player)
	assert_eq(heard.size(),1,"Screams are rate limited")
	EventBus.noise_emitted.disconnect(listener)

func test_civilian_death_emits_once_with_existing_heavy_penalty() -> void:
	var path := "res://src/npcs/civilian_npc.gd"
	assert_true(FileAccess.file_exists(path))
	if not FileAccess.file_exists(path): return
	var civilian = load(path).new()
	add_child_autofree(civilian)
	var deaths: Array = []
	var listener := func(who): deaths.append(who)
	EventBus.civilian_killed.connect(listener)
	civilian.receive_combat_damage(999)
	civilian.receive_combat_damage(999)
	assert_eq(deaths.size(),1)
	assert_true(civilian.is_defeated())
	assert_eq(Tuning.scoring().civilian_kill_penalty,-10)
	assert_eq(NarrativeTotals.shura(0,1,0),3)
	EventBus.civilian_killed.disconnect(listener)

func test_crowd_uses_five_instances_and_breaks_cover_on_sprint_or_sword() -> void:
	var path := "res://src/npcs/crowd_hide_spot.gd"
	assert_true(FileAccess.file_exists(path))
	if not FileAccess.file_exists(path): return
	var crowd = load(path).new()
	add_child_autofree(crowd)
	crowd.set_physics_process(false)
	var player = load("res://src/player/player.tscn").instantiate()
	add_child_autofree(player)
	player.set_physics_process(false)
	assert_eq(crowd.get_node("CrowdInstances").multimesh.instance_count,5)
	assert_true(crowd.conceals(player))
	player.state_machine.change_state(&"Sprint")
	assert_false(crowd.conceals(player))
	assert_true(crowd.check_disruption(player))
	player.state_machine.change_state(&"Ground")
	player.state_machine.change_state(&"Combat")
	assert_false(crowd.conceals(player))

func test_crowd_cover_reaches_player_visibility_contract_and_sword_can_target_civilian() -> void:
	var crowd := CrowdHideSpot.new()
	add_child_autofree(crowd)
	var player = load("res://src/player/player.tscn").instantiate()
	add_child_autofree(player)
	player.set_physics_process(false)
	assert_true(player.is_visibility_excluded())
	var civilian := CivilianNPC.new()
	civilian.position = Vector3(0,0,-0.5)
	add_child_autofree(civilian)
	assert_true(player.combat._nearest_enemy() is CivilianNPC)

func test_scream_reaches_guard_search_and_audio_cue_is_available() -> void:
	var civilian := CivilianNPC.new()
	add_child_autofree(civilian)
	var enemy = load("res://src/enemies/enemy_base.tscn").instantiate()
	enemy.position = Vector3(5,0,0)
	add_child_autofree(enemy)
	enemy.set_physics_process(false)
	enemy.brain().set_physics_process(false)
	assert_true(civilian.scream())
	enemy.brain()._physics_process(0.016)
	assert_eq(enemy.brain().alert_state(),Enums.AlertState.SEARCHING)
	assert_true(&"civilian_scream" in AudioPlayback.CUES)
	assert_true(ResourceLoader.exists("res://assets/audio/civilian_scream.wav"))

func test_civilian_does_not_see_behind_it_or_through_a_wall() -> void:
	var civilian := CivilianNPC.new()
	add_child_autofree(civilian)
	civilian.set_physics_process(false)
	var player = load("res://src/player/player.tscn").instantiate()
	player.position = Vector3(0,0,3)
	add_child_autofree(player)
	player.set_physics_process(false)
	assert_false(civilian.can_see_player(player))
	player.position.z = -3
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(3,3,0.3)
	wall.position = Vector3(0,1,-1.5)
	wall.add_child(shape)
	add_child_autofree(wall)
	await get_tree().physics_frame
	assert_false(civilian.can_see_player(player))

func test_crowd_route_moves_five_members_and_leaves_dead_member_behind() -> void:
	var crowd := CrowdHideSpot.new()
	crowd.route = Curve3D.new()
	crowd.route.add_point(Vector3.ZERO)
	crowd.route.add_point(Vector3(5,0,0))
	add_child_autofree(crowd)
	crowd.set_physics_process(false)
	crowd.advance_route(0.25)
	assert_gt(crowd.position.x,0.0)
	assert_eq(crowd.members.size(),5)
	var member: CivilianNPC = crowd.members[0]
	member.receive_combat_damage(999)
	crowd._sync_instances()
	var corpse_position := member.global_position
	crowd.advance_route(0.25)
	assert_eq(member.global_position,corpse_position)
	member.queue_free()

func test_crowd_cannot_conceal_player_through_partition() -> void:
	var crowd := CrowdHideSpot.new()
	add_child_autofree(crowd)
	var player = load("res://src/player/player.tscn").instantiate()
	player.position = Vector3(0,0,1.6)
	add_child_autofree(player)
	player.set_physics_process(false)
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(3,3,0.1)
	wall.position = Vector3(0,1,0.8)
	wall.add_child(shape)
	add_child_autofree(wall)
	await get_tree().physics_frame
	assert_false(crowd.conceals(player))

func test_drawing_sword_from_crowd_walk_breaks_concealment() -> void:
	MissionDirector.start_mission(null)
	var crowd := CrowdHideSpot.new()
	add_child_autofree(crowd)
	var player = load("res://src/player/player.tscn").instantiate()
	add_child_autofree(player)
	player.set_physics_process(false)
	var event := InputEventAction.new()
	event.action = &"sword"
	event.pressed = true
	player.combat._unhandled_input(event)
	assert_eq(player.state_machine.current_state(),&"Combat")
	assert_false(player.is_visibility_excluded())

func test_walking_attack_keeps_tool_input_separate_from_drawing() -> void:
	MissionDirector.start_mission(null)
	var player = load("res://src/player/player.tscn").instantiate()
	add_child_autofree(player)
	player.set_physics_process(false)
	var event := InputEventAction.new()
	event.action = &"attack"
	event.pressed = true
	player.combat._unhandled_input(event)
	assert_eq(player.state_machine.current_state(),&"Ground")
