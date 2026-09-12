extends GutTest

const SCENE := "res://src/levels/festival_night/festival_mission.tscn"

func after_each() -> void:
	MissionDirector.start_mission(null)
	GameState.area_alert_level = 0
	GameState.checkpoint_ref.clear()
	PlayerRetryFlow.pending_scene = ""
	get_tree().paused = false

func _world() -> Node3D:
	var level: Node3D = load(SCENE).instantiate()
	add_child_autofree(level)
	for frame in range(5): await get_tree().physics_frame
	level.get_node("Player").set_physics_process(false)
	var population := level.get_node("Population")
	population.set_physics_process(false)
	level.get_node("Fireworks").set_physics_process(false)
	level.get_node("FestivalEnvironment").set_physics_process(false)
	for actor: EnemyBase in population.important_actors()+population.doshin:
		actor.set_physics_process(false)
		actor.brain().set_physics_process(false)
		actor.combat().set_physics_process(false)
		actor.get_node("Perception").set_process(false)
	for npc: CivilianNPC in population.civilians: npc.set_physics_process(false)
	for crowd in population.get_node("Crowds").get_children(): crowd.set_physics_process(false)
	return level

func _capture(level: Node3D) -> Dictionary:
	assert_true((level.get_node("Player/RetryFlow") as PlayerRetryFlow).capture_checkpoint(&"test"))
	assert_true(GameState.checkpoint_ref.has("mission_world"),"Player checkpoints must include the complete festival world")
	return GameState.checkpoint_ref.duplicate(true)

func test_restore_rewinds_target_escort_reactions_civilians_and_firework_clock() -> void:
	var level := await _world()
	assert_true(GameState.checkpoint_ref.has("mission_world"),"Initial retry baseline includes world")
	var population := level.get_node("Population")
	population.advance_schedule(43.0)
	var baseline := _capture(level)
	if not baseline.has("mission_world"): return
	assert_true(population.civilians[0].scream())
	population.civilians[0].receive_combat_damage(1,level.get_node("Player"))
	assert_true(population.target.begin_assassination(&"above"))
	population.advance_schedule(60.0)
	assert_true(level.get_node("Mission").restore_checkpoint_world(baseline))
	assert_false(population.target.is_target_defeated())
	assert_eq(level.get_node("Mission").scream_count,0)
	assert_eq(population.civilians[0].health(),1)
	for escort: EscortGuard in population.escorts: assert_false(escort.has_reacted_to_target_defeat())
	assert_true(level.get_node("Fireworks").masks_gameplay_noise())
	assert_almost_eq(population.schedule_elapsed(),baseline.mission_world.schedule.elapsed,0.0001)
	assert_eq(MissionDirector.current_objective().id,&"m05_target")
	assert_eq(MissionDirector.stats().civilian_kills,0)

func test_prayer_stage_goals_and_crowd_distance_survive_restore() -> void:
	var level := await _world()
	var population := level.get_node("Population")
	population.advance_schedule(220.0)
	population.target.global_position = Vector3(51,3.02,17)
	population.escorts[0].global_position = Vector3(48,3.02,19)
	population.escorts[1].global_position = Vector3(54,3.02,19)
	population.advance_schedule(0.0)
	population.escorts[0].global_position = Vector3(47,0.02,31)
	population.escorts[1].global_position = Vector3(55,0.02,31)
	population.advance_schedule(0.0)
	population.advance_schedule(7.0)
	var crowd := population.get_node("Crowds/Introduction") as CrowdHideSpot
	crowd.advance_route(0.2)
	var baseline := _capture(level)
	if not baseline.has("mission_world"): return
	var crowd_position := crowd.global_position
	population.advance_schedule(80.0)
	crowd.advance_route(0.25)
	assert_true(level.get_node("Mission").restore_checkpoint_world(baseline))
	assert_true(population.prayer_active())
	assert_almost_eq(population.prayer_elapsed(),7.0,0.0001)
	assert_eq(population.target.current_routine_stop().routine_action,&"pray")
	assert_eq(population.escorts[0].current_routine_stop().facing_direction,Vector3.LEFT)
	assert_eq(population.escorts[1].current_routine_stop().facing_direction,Vector3.RIGHT)
	assert_eq(crowd.global_position,crowd_position)

func test_dead_crowd_member_stays_at_corpse_position_and_scream_cooldown_is_retained() -> void:
	var level := await _world()
	var alive := _capture(level)
	if not alive.has("mission_world"): return
	var population := level.get_node("Population")
	var crowd := population.get_node("Crowds/Introduction") as CrowdHideSpot
	var dead := crowd.members[0]
	var speaker := crowd.members[1]
	assert_true(speaker.scream())
	dead.receive_combat_damage(1,level.get_node("Player"))
	crowd._sync_instances()
	var corpse_position := dead.global_position
	var retained := _capture(level)
	assert_true(level.get_node("Mission").restore_checkpoint_world(alive))
	assert_eq(dead.get_parent(),crowd)
	assert_true(level.get_node("Mission").restore_checkpoint_world(retained))
	assert_true(dead.is_defeated())
	assert_ne(dead.get_parent(),crowd)
	assert_false(speaker.scream(),"Retry cannot instantly replay a scream still on cooldown")
	crowd.advance_route(0.25)
	crowd._sync_instances()
	assert_eq(dead.global_position,corpse_position)
	assert_eq(MissionDirector.stats().civilian_kills,1)
	assert_eq(level.get_node("Mission").scream_count,1)

func test_corrupt_world_rejected_before_any_actor_clock_or_counter_mutates() -> void:
	var level := await _world()
	var original := _capture(level)
	if not original.has("mission_world"): return
	var corruptions: Array[Dictionary] = []
	var bad := original.duplicate(true)
	bad.mission_world.npcs.erase("Escort1")
	corruptions.append(bad)
	bad = original.duplicate(true)
	bad.mission_world.schedule.elapsed = NAN
	corruptions.append(bad)
	bad = original.duplicate(true)
	bad.mission_world.schedule.prayer_stage = 2
	corruptions.append(bad)
	bad = original.duplicate(true)
	bad.mission_world.civilians.Introduction0.cooldown = 6.0
	corruptions.append(bad)
	bad = original.duplicate(true)
	bad.mission_world.crowds.Introduction.distance = INF
	corruptions.append(bad)
	bad = original.duplicate(true)
	bad.mission_world.mission.objective = 1
	corruptions.append(bad)
	bad = original.duplicate(true)
	bad.mission_world.mission.stats.side_objective_completed = true
	corruptions.append(bad)
	bad = original.duplicate(true)
	bad.mission_world.lights.erase("WestRoof")
	corruptions.append(bad)
	var population := level.get_node("Population")
	population.advance_schedule(190.0)
	population.civilians[0].scream()
	var current := _capture(level)
	for corrupt in corruptions:
		assert_false(level.get_node("Mission").restore_checkpoint_world(corrupt))
		assert_eq(_capture(level).mission_world,current.mission_world)

func test_actual_scene_replacement_retains_target_death_without_recounting() -> void:
	var level := await _world()
	var baseline := _capture(level)
	if not baseline.has("mission_world"): return
	var population := level.get_node("Population")
	population.advance_schedule(43.0)
	assert_true(population.target.begin_assassination(&"above"))
	population.civilians[0].scream()
	for frame in range(2): await get_tree().physics_frame
	var retained := _capture(level)
	level.queue_free()
	await get_tree().process_frame
	PlayerRetryFlow.pending_scene = SCENE
	GameState.checkpoint_ref = retained
	var replacement := await _world()
	assert_eq(PlayerRetryFlow.pending_scene,"")
	assert_false(get_tree().paused)
	assert_true(replacement.get_node("Population/Kurosawa").is_target_defeated())
	assert_eq(replacement.get_node("Mission").scream_count,1)
	assert_true(replacement.get_node("Fireworks").masks_gameplay_noise())
	assert_eq(MissionDirector.current_objective().id,&"m05_escape")
	assert_eq(MissionDirector.capture_checkpoint_state({}).target_kills,1)
