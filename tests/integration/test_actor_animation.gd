extends GutTest

const ADAPTER := "res://src/visuals/actor_animation.gd"

func test_adapter_covers_every_player_stance_and_assassination_context() -> void:
	assert_true(FileAccess.file_exists(ADAPTER), "Production animation adapter must exist")
	if not FileAccess.file_exists(ADAPTER): return
	var script = load(ADAPTER)
	for state in PlayerStateMachine.TRANSITIONS.keys():
		assert_ne(script.player_clip(state, false), &"", "A visible or hidden presentation exists for %s" % state)
	var contexts: Array = []
	for context in [&"back", &"above", &"below", &"corner"]:
		contexts.append(script.assassination_clip(context))
	assert_eq(contexts.size(), 4)
	for index in range(4):
		assert_eq(contexts.count(contexts[index]), 1, "Each assassination has its own motion")
	assert_eq(script.player_clip(&"unknown", false), &"idle")

func test_production_player_animates_bones_without_moving_gameplay_body() -> void:
	assert_true(FileAccess.file_exists(ADAPTER))
	if not FileAccess.file_exists(ADAPTER): return
	var player = load("res://src/player/player.tscn").instantiate()
	add_child_autofree(player)
	player.set_physics_process(false)
	await get_tree().process_frame
	var adapter = player.get_node("Visual/Model")
	assert_true(adapter.has_method("show_clip"))
	if not adapter.has_method("show_clip"): return
	var before: Vector3 = player.position
	var collision = player.get_node("CollisionShape3D").shape
	adapter.show_clip(&"walk")
	adapter.advance_visual(0.1)
	var first: Transform3D = adapter.bone_pose(&"thigh_l")
	adapter.advance_visual(0.3)
	var second: Transform3D = adapter.bone_pose(&"thigh_l")
	assert_ne(first, second, "A real skeletal walk must move")
	assert_eq(player.position, before)
	assert_same(player.get_node("CollisionShape3D").shape, collision)
	assert_true(adapter.has_node("AnimationTree"))

func test_enemy_alert_mapping_includes_search_return_and_death() -> void:
	assert_true(FileAccess.file_exists(ADAPTER))
	if not FileAccess.file_exists(ADAPTER): return
	var script = load(ADAPTER)
	assert_eq(script.enemy_clip(Enums.AlertState.UNAWARE, true, false), &"walk")
	assert_eq(script.enemy_clip(Enums.AlertState.SUSPICIOUS, false, false), &"investigate")
	assert_eq(script.enemy_clip(Enums.AlertState.SEARCHING, true, false), &"search")
	assert_eq(script.enemy_clip(Enums.AlertState.RETURN, true, false), &"walk")
	assert_eq(script.enemy_clip(Enums.AlertState.COMBAT, false, false), &"combat")
	assert_eq(script.enemy_clip(Enums.AlertState.UNAWARE, false, true), &"death")

func test_crawl_stays_inside_low_clearance_and_climb_reaches_above_head() -> void:
	var player = load("res://src/player/player.tscn").instantiate()
	add_child_autofree(player)
	player.set_physics_process(false)
	await get_tree().process_frame
	var adapter = player.get_node("Visual/Model")
	adapter.set_process(false)
	player.state_machine.change_state(&"Crawlspace")
	adapter.show_clip(&"crawl")
	for step in range(8): adapter.advance_visual(0.1)
	var skeleton: Skeleton3D = adapter.get("_skeleton")
	var half_height: float = player.get_node("CollisionShape3D").shape.height * 0.5
	for bone in [&"Head", &"hand_l", &"hand_r"]:
		var world: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin)
		assert_lt(absf(world.y - player.global_position.y), half_height + 0.05, "Prone limbs stay in the crawl clearance")
	adapter.show_clip(&"climb")
	for step in range(8): adapter.advance_visual(0.1)
	var head: Vector3 = skeleton.get_bone_global_pose(skeleton.find_bone(&"Head")).origin
	for bone in [&"hand_l", &"hand_r"]:
		var hand: Vector3 = skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin
		assert_gt(hand.y, head.y + 0.1, "Climbing hands reach the ledge above the head")

func test_assassination_hook_retains_context_until_gameplay_state_finishes() -> void:
	var player = load("res://src/player/player.tscn").instantiate()
	add_child_autofree(player)
	player.set_physics_process(false)
	await get_tree().process_frame
	var adapter = player.get_node("Visual/Model")
	adapter.set_process(false)
	player.state_machine.change_state(&"Assassinate")
	for context in [&"back", &"above", &"below", &"corner"]:
		var clip := StringName("assassination_" + str(context))
		player.get_node("AssassinationResolver/AssassinationPresentation").animation_requested.emit(context, clip)
		adapter.update_actor_presentation(1.3)
		assert_eq(adapter.current_clip(), clip, "Presentation must retain the requested context until state completion")

func test_corpse_presentation_can_finish_while_actor_logic_is_disabled() -> void:
	var enemy = load("res://src/enemies/enemy_base.tscn").instantiate()
	add_child_autofree(enemy)
	await get_tree().process_frame
	var adapter = enemy.get_node("Visual/Model")
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	assert_true(adapter.can_process(), "Carrying disables AI but must not freeze a death pose halfway")
	get_tree().paused = true
	assert_false(adapter.can_process(), "Mission pause also pauses visual animation")
	get_tree().paused = false

func test_practice_uses_rigs_without_legacy_capsules_or_double_death_rotation() -> void:
	var gym = load("res://src/levels/gym/mission_flow_gym.tscn").instantiate()
	add_child_autofree(gym)
	await get_tree().process_frame
	for actor in [gym.get_node("Player"), gym.get_node("Target")]:
		var model = actor.get_node("Visual/Model")
		for child in model.get_children():
			assert_false(child is MeshInstance3D, "Placeholder meshes must not cover the animated model")
	gym.get_node("Target").target_defeated_event.emit(&"test")
	assert_eq(gym.get_node("Target/Visual/Model").rotation.z, 0.0, "Death animation owns the fall, so the whole rig is not rotated again")

func test_combat_motion_has_a_hand_bound_blade_and_stationary_search_does_not_walk() -> void:
	assert_eq(ActorAnimation.enemy_clip(Enums.AlertState.COMBAT, true, false), &"sprint")
	assert_eq(ActorAnimation.enemy_clip(Enums.AlertState.SEARCHING, false, false), &"investigate")
	var player = load("res://src/player/player.tscn").instantiate()
	add_child_autofree(player)
	player.set_physics_process(false)
	await get_tree().process_frame
	var adapter = player.get_node("Visual/Model")
	var weapons = adapter.find_children("Weapon", "BoneAttachment3D", true, false)
	assert_eq(weapons.size(), 1, "Sword motions need a blade attached to the grip")
	if weapons.is_empty(): return
	assert_eq(weapons[0].bone_name, "hand_r")
	adapter.show_clip(&"walk")
	assert_false(weapons[0].visible)
	adapter.show_clip(&"attack")
	assert_true(weapons[0].visible)

func test_below_assassination_keeps_the_body_prone() -> void:
	var player = load("res://src/player/player.tscn").instantiate()
	add_child_autofree(player)
	player.set_physics_process(false)
	await get_tree().process_frame
	var adapter = player.get_node("Visual/Model")
	adapter.set_process(false)
	adapter.show_clip(&"assassination_below")
	for step in range(8): adapter.advance_visual(0.1)
	var skeleton: Skeleton3D = adapter.get("_skeleton")
	var head := skeleton.get_bone_global_pose(skeleton.find_bone(&"Head")).origin
	var foot := skeleton.get_bone_global_pose(skeleton.find_bone(&"foot_l")).origin
	assert_lt(absf(head.y - foot.y), 0.4, "The below-floor assassination keeps the torso under the floor")

func test_close_player_camera_does_not_look_through_the_players_own_body() -> void:
	var player = load("res://src/player/player.tscn").instantiate()
	add_child_autofree(player)
	player.set_physics_process(false)
	await get_tree().process_frame
	var adapter = player.get_node("Visual/Model")
	adapter.set_process(false)
	var camera: Camera3D = player.find_children("*", "Camera3D", true, false)[0]
	camera.make_current()
	camera.global_position = player.global_position + Vector3(0,-0.7,1.0)
	adapter.update_actor_presentation(0.0)
	assert_false(adapter.visible, "A camera pushed under a crawl ceiling must not be covered by the player's rig")
	camera.global_position = player.global_position + Vector3(0,1,4)
	adapter.update_actor_presentation(0.0)
	assert_true(adapter.visible, "Third-person distance restores the animated body")
