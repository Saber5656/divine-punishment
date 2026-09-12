extends GutTest

const SCENE := "res://src/levels/rainy_temple/temple_mission.tscn"

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
	_freeze(level)
	return level

func _freeze(level: Node3D) -> void:
	level.get_node("Player").set_physics_process(false)
	level.get_node("Population").set_physics_process(false)
	level.get_node("Mission").set_physics_process(false)
	for actor in level.get_node("Population/Duties").call("actors"):
		actor.set_physics_process(false)
		actor.brain().set_physics_process(false)
		actor.combat().set_physics_process(false)
		actor.get_node("Perception").set_process(false)
	for npc in level.get_node("Mission/Retainers").get_children(): npc.set_physics_process(false)

func _baseline(level: Node3D) -> Dictionary:
	assert_true((level.get_node("Player/RetryFlow") as PlayerRetryFlow).capture_checkpoint(&"test"))
	assert_true(GameState.checkpoint_ref.has("mission_world"),"Every player checkpoint includes the temple world")
	return GameState.checkpoint_ref.duplicate(true)

func test_checkpoint_rewinds_execution_bell_health_and_main_objective() -> void:
	var level := await _world()
	assert_true(GameState.checkpoint_ref.has("mission_world"),"The automatic entry snapshot contains the world")
	var snapshot := _baseline(level)
	if not snapshot.has("mission_world"): return
	var mission := level.get_node("Mission")
	var population := level.get_node("Population")
	var target := population.get_node("Tetsusenbo") as TargetNpc
	population.call("advance_schedule",740.0)
	population.get_node("Duties").call("use_bell")
	mission.get_node("Retainers/RetainerA").receive_combat_damage(1,target)
	assert_true(target.begin_assassination(&"back"))
	assert_true(mission.get("side_failed"))
	assert_true(CheckpointSnapshot.restore(snapshot,level.get_node("Player"),SCENE))
	assert_true(mission.call("restore_checkpoint_world",snapshot))
	assert_eq(target.health(),8)
	assert_false(target.is_target_defeated())
	assert_false(mission.get("side_failed"))
	assert_false(mission.get_node("Retainers/RetainerA").is_defeated())
	assert_eq(MissionDirector.current_objective().id,&"m04_target")
	assert_almost_eq(population.call("schedule_elapsed"),snapshot.mission_world.elapsed,0.001)
	assert_eq(GameState.area_alert_level,0)
	assert_true(population.get_node("Duties").call("use_bell"),"Rewound bell is usable exactly once")
	assert_false(population.get_node("Duties").call("use_bell"))

func test_partial_rescue_and_active_counter_window_survive_restore() -> void:
	var level := await _world()
	var mission := level.get_node("Mission")
	var target := level.get_node("Population/Tetsusenbo") as TargetNpc
	var retainer := mission.get_node("Retainers/RetainerA") as TempleRetainer
	assert_true(retainer.rescue())
	retainer.global_position = Vector3(64,3.1,40)
	level.get_node("Population/Duties").call("use_bell")
	EventBus.combat_parried.emit(level.get_node("Player"),target.combat())
	var snapshot := _baseline(level)
	if not snapshot.has("mission_world"): return
	retainer.receive_combat_damage(1,target)
	target.set("_counter_remaining",0.0)
	assert_true(mission.call("restore_checkpoint_world",snapshot))
	assert_true(retainer.rescued)
	assert_false(retainer.escaped)
	assert_eq(retainer.health(),1)
	assert_eq(retainer.global_position,Vector3(64,3.1,40))
	assert_false(MissionDirector.stats().side_objective_completed)
	assert_gt(float(target.get("_counter_remaining")),1.0)
	assert_false(level.get_node("Population/Duties").call("use_bell"))
	assert_eq(target.receive_combat_damage(1,level.get_node("Player")),1)

func test_invalid_world_is_rejected_before_any_mutation() -> void:
	var level := await _world()
	var snapshot := _baseline(level)
	if not snapshot.has("mission_world"): return
	var corruptions: Array[Dictionary] = []
	var bad := snapshot.duplicate(true)
	bad.mission_world.npcs.erase("CellGuard")
	corruptions.append(bad)
	bad = snapshot.duplicate(true)
	bad.mission_world.npcs.CellGuard.brain.route_stop_count = 63
	corruptions.append(bad)
	bad = snapshot.duplicate(true)
	bad.mission_world.elapsed = NAN
	corruptions.append(bad)
	bad = snapshot.duplicate(true)
	bad.mission_world.retainers.retainer_a.escaped = true
	corruptions.append(bad)
	bad = snapshot.duplicate(true)
	bad.mission_world.mission.objective = 1
	corruptions.append(bad)
	var target := level.get_node("Population/Tetsusenbo") as TargetNpc
	level.get_node("Population").call("advance_schedule",725.0)
	level.get_node("Population/Duties").call("use_bell")
	for value in corruptions:
		assert_false(level.get_node("Mission").call("restore_checkpoint_world",value))
		assert_gt(float(level.get_node("Population").call("schedule_elapsed")),725.0)
		assert_eq(target.health(),8)
		assert_eq(MissionDirector.current_objective().id,&"m04_target")
		assert_false(level.get_node("Population/Duties").call("use_bell"))

func test_scene_reload_preserves_pending_world_and_does_not_recount_deaths() -> void:
	var level := await _world()
	level.get_node("Population").call("advance_schedule",725.0)
	level.get_node("Population/Duties").call("use_bell")
	level.get_node("Mission/Retainers/RetainerA").rescue()
	assert_true((level.get_node("Population/Tetsusenbo") as TargetNpc).begin_assassination(&"back"))
	for frame in range(2): await get_tree().physics_frame
	var retained := _baseline(level)
	if not retained.has("mission_world"): return
	level.queue_free()
	await get_tree().process_frame
	PlayerRetryFlow.pending_scene = SCENE
	GameState.checkpoint_ref = retained
	var replacement := await _world()
	assert_eq(PlayerRetryFlow.pending_scene,"")
	assert_false(get_tree().paused,"World restore does not show an error menu")
	assert_true((replacement.get_node("Population/Tetsusenbo") as TargetNpc).is_target_defeated())
	assert_true(replacement.get_node("Mission/Retainers/RetainerA").rescued)
	assert_false(replacement.get_node("Population/Duties").call("use_bell"))
	assert_gt(float(replacement.get_node("Population").call("schedule_elapsed")),725.0)
	assert_eq(MissionDirector.current_objective().id,&"m04_escape")
	assert_eq(MissionDirector.capture_checkpoint_state({}).target_kills,1)

func test_evacuated_retainers_and_departed_party_restore_without_replaying_bonus() -> void:
	var level := await _world()
	var baseline := _baseline(level)
	if not baseline.has("mission_world"): return
	var mission := level.get_node("Mission")
	var population := level.get_node("Population")
	population.call("advance_schedule",790.0)
	for npc: TempleRetainer in mission.get_node("Retainers").get_children():
		assert_true(npc.rescue())
		npc.global_position = TempleRetainer.ESCAPE-Vector3.UP*0.9
		npc.advance_escape(0.1)
	(population.get_node("CellGuard") as EnemyBase).receive_combat_damage(99,level.get_node("Player"))
	mission.call("advance_mission")
	var retained := _baseline(level)
	var score := MissionDirector.build_result().score
	assert_true(mission.call("restore_checkpoint_world",baseline))
	assert_true(mission.get_node("Retainers/RetainerA").visible)
	assert_true(mission.call("restore_checkpoint_world",retained))
	assert_true(MissionDirector.stats().side_objective_completed)
	assert_true((population.get_node("CellGuard") as EnemyBase).is_defeated())
	assert_eq((population.get_node("Monks/CourtWest") as EnemyBase).current_routine_stop().routine_action,&"execute")
	for npc: TempleRetainer in mission.get_node("Retainers").get_children():
		assert_true(npc.escaped)
		assert_false(npc.visible)
		assert_eq(npc.collision_layer,0)
	mission.call("advance_mission")
	assert_eq(MissionDirector.build_result().score,score,"Restoring evacuation does not award the bonus twice")
