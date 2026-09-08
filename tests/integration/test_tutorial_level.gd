extends GutTest

const LevelScene := preload("res://src/levels/tutorial/tutorial.tscn")
const Definition := preload("res://data/missions/tutorial.tres")
var _level: TutorialLevel


func before_each() -> void:
	MissionDirector.start_mission(Definition)
	_level = LevelScene.instantiate()
	add_child_autofree(_level)
	await get_tree().physics_frame
	await get_tree().physics_frame


func after_each() -> void:
	for action in [&"stance_toggle", &"move_forward", &"move_backward", &"move_left", &"move_right", &"interact", &"sprint", &"aim", &"tool_use"]:
		Input.action_release(action)
	MissionDirector.start_mission(null)


func test_tutorial_has_four_roles_and_real_climb_hide_navigation_geometry() -> void:
	var enemies := get_tree().get_nodes_in_group(&"enemies")
	assert_eq(enemies.size(), 4)
	var patrols := 0
	var sentries := 0
	for enemy in enemies:
		patrols += 1 if enemy.brain().is_patrol() else 0
		sentries += 1 if enemy.brain().is_guard() else 0
	assert_eq(patrols, 2)
	assert_eq(sentries, 2)
	assert_true(_level.actors.roof_climb.is_geometry_valid())
	assert_true(_level.actors.brush.is_geometry_valid())
	assert_true(_level.actors.body_hide.is_geometry_valid())
	assert_eq(Definition.objectives.size(), 8)
	assert_eq(Definition.objectives[4].kind, &"KILL_TARGET")


func test_actual_crouch_input_and_movement_observe_visibility_without_completing_in_place() -> void:
	Input.action_press(&"stance_toggle")
	await get_tree().physics_frame
	Input.action_release(&"stance_toggle")
	await get_tree().physics_frame
	assert_eq(_level.actors.player.state_machine.current_state(), PlayerStateMachine.STATE_CROUCH)
	assert_eq(MissionDirector.current_objective().id, &"tutorial_sneak")
	Input.action_press(&"move_forward")
	for frame in range(140):
		await get_tree().physics_frame
	Input.action_release(&"move_forward")
	assert_gt(_level._sneak_distance, 0.1)
	assert_gt(_level._max_visibility, 0.0)
	assert_eq(MissionDirector.current_objective().id, &"tutorial_sneak", "distance alone does not prove the shade lesson")


func test_gate_collision_blocks_skipping_first_lesson() -> void:
	var query := PhysicsRayQueryParameters3D.create(Vector3(0, 1, -17), Vector3(0, 1, -19), 1)
	var hit := _level.get_world_3d().direct_space_state.intersect_ray(query)
	assert_eq(hit.get("collider"), _level.actors.SneakGate)
	assert_eq(_level.learned, {})


func test_foreign_noise_does_not_mark_lure_or_gravel() -> void:
	var unrelated := Node3D.new()
	add_child_autofree(unrelated)
	EventBus.noise_emitted.emit(NoiseEvent.create(_level.actors.guard_c.global_position, 6.0, Enums.NoiseKind.TOOL, unrelated))
	assert_true(_level._pending_lure.is_empty())
	assert_false(_level._gravel_heard)


func test_premature_required_enemy_death_is_an_explicit_retry_failure() -> void:
	assert_true(_level.actors.patrol_d.begin_assassination(&"back"))
	assert_true(_level._failed)
	assert_false(MissionDirector.build_result().flags.failed_reason.is_empty())
	assert_false(MissionDirector.build_result().flags.completed)


func test_patrol_eyes_follow_authored_enemy_and_patrol_moves_on_real_navigation() -> void:
	var patrol: EnemyBase = _level.actors.patrol_b
	var eye: Node3D = patrol.get_node("Perception/EyePoint")
	assert_lt(eye.global_position.distance_to(patrol.global_position + Vector3(0, 0.7, 0)), 0.01, "eye must follow the enemy world transform")
	var start := patrol.global_position
	for frame in range(420):
		await get_tree().physics_frame
	assert_gt(patrol.global_position.distance_to(start), 1.0, "authored patrol must actually travel")
	print("PATROL_DEBUG ", patrol.global_position, " eye=", eye.global_position, " state=", patrol.brain().current_state(), " target=", patrol.routine_target())


func test_tutorial_checkpoint_roundtrip_and_invalid_world_rejection() -> void:
	assert_true(_level.has_method("capture_checkpoint_world"), "tutorial must persist learning and world state")
	if not _level.has_method("capture_checkpoint_world"): return
	var snapshot: Dictionary = _level.call("capture_checkpoint_world")
	var before: Vector3 = _level.actors.guard_c.global_position
	var corrupt := snapshot.duplicate(true)
	corrupt["npcs"].erase("patrol_b")
	assert_false(_level.call("restore_checkpoint_world", {"tutorial_world": corrupt}))
	assert_eq(_level.actors.guard_c.global_position, before)
	_level.actors.lamp_a.set_extinguished(true)
	assert_true(_level.call("restore_checkpoint_world", {"tutorial_world": snapshot}))
	assert_true(_level.actors.lamp_a.is_on())
	assert_eq(MissionDirector.current_objective().id, &"tutorial_sneak")


func test_world_checkpoint_restores_learned_body_storage_without_new_kill_credit() -> void:
	# This fixture isolates restore semantics; the input driver proves acquisition.
	for id in [&"tutorial_sneak", &"tutorial_hide", &"tutorial_lure", &"tutorial_lights"]:
		_level._complete(id, {"fixture": true})
	assert_true(_level.actors.patrol_d.begin_assassination(&"back"))
	assert_true(_level.actors.body_hide.restore_stored_body(_level.actors.patrol_d))
	_level._carried_target = true
	_level._complete(&"tutorial_body", {"fixture": true})
	var snapshot := _level.capture_checkpoint_world()
	var first_level := _level
	remove_child(first_level)
	first_level.queue_free()
	_level = LevelScene.instantiate()
	add_child_autofree(_level)
	await get_tree().physics_frame
	assert_eq(MissionDirector.current_objective().id, &"tutorial_sneak")
	assert_true(_level.restore_checkpoint_world({"tutorial_world": snapshot}))
	assert_eq(MissionDirector.current_objective().id, &"tutorial_document")
	assert_eq(_level.actors.body_hide.stored_body(), _level.actors.patrol_d)
	assert_eq(MissionDirector.capture_checkpoint_state(_level._entities()).target_kills, 1)
