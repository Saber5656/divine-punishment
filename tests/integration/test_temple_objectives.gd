extends GutTest

const SCENE := "res://src/levels/rainy_temple/temple_mission.tscn"

func after_each() -> void:
	MissionDirector.start_mission(null)
	GameState.area_alert_level = 0
	GameState.checkpoint_ref.clear()
	PlayerRetryFlow.pending_scene = ""
	get_tree().paused = false

func _world() -> Node3D:
	assert_true(ResourceLoader.exists(SCENE),"Temple mission composes boss, bell and retainers")
	if not ResourceLoader.exists(SCENE): return null
	var level: Node3D = load(SCENE).instantiate()
	add_child_autofree(level)
	for frame in range(5): await get_tree().physics_frame
	level.get_node("Player").set_physics_process(false)
	var population := level.get_node("Population")
	population.set_physics_process(false)
	population.get_node("Duties").set_physics_process(false)
	level.get_node("Mission").set_physics_process(false)
	for actor in population.get_node("Duties").call("actors"):
		actor.brain().set_physics_process(false)
		actor.combat().set_physics_process(false)
		actor.get_node("Perception").set_process(false)
	for npc in level.get_node("Mission/Retainers").get_children(): npc.set_physics_process(false)
	return level

func test_definition_keeps_rescue_separate_from_target_and_escape() -> void:
	var definition := load("res://data/missions/m04.tres") as MissionDefinition
	assert_eq(definition.objectives.size(),2)
	if definition.objectives.size() != 2: return
	assert_eq(definition.objectives[0].kind,&"KILL_TARGET")
	assert_eq(definition.objectives[1].kind,&"ESCAPE")
	assert_not_null(definition.side_objective)
	assert_not_null(definition.level_scene)

func test_bell_and_rescue_require_physical_reach_and_clear_line_of_sight() -> void:
	var level := await _world()
	if level == null: return
	var mission := level.get_node("Mission")
	var player := level.get_node("Player") as PlayerController
	assert_eq((level.get_node("Population/Tetsusenbo") as TargetNpc).health(),8)
	assert_false(mission.call("try_ring_bell"))
	assert_false(mission.call("try_rescue",&"retainer_a"))
	player.global_position = Vector3(26,4.02,54)
	assert_true(mission.call("try_ring_bell"))
	assert_false(mission.call("try_ring_bell"))
	assert_eq(GameState.area_alert_level,1)
	player.global_position = Vector3(76,5.02,36.3)
	var wall := StaticBody3D.new()
	wall.position = Vector3(76,5.3,35.6)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(2,2,0.1)
	wall.add_child(shape)
	level.add_child(wall)
	await get_tree().physics_frame
	assert_false(mission.call("try_rescue",&"retainer_a"),"A nearby captive cannot be freed through a wall")
	wall.queue_free()
	await get_tree().physics_frame
	assert_true(mission.call("try_rescue",&"retainer_a"))
	assert_false(mission.call("try_rescue",&"retainer_a"))

func test_both_retainers_must_really_escape_for_the_five_point_side_bonus() -> void:
	var level := await _world()
	if level == null: return
	var mission := level.get_node("Mission")
	var player := level.get_node("Player") as PlayerController
	var before := MissionDirector.build_result().score
	for spec in [[&"retainer_a",76.0],[&"retainer_b",82.0]]:
		player.global_position = Vector3(spec[1],5.02,36.3)
		assert_true(mission.call("try_rescue",spec[0]))
	assert_false(MissionDirector.stats().side_objective_completed,"Freeing is not the completed evacuation")
	player.global_position = Vector3(12,0.02,88)
	for frame in range(900):
		for npc in mission.get_node("Retainers").get_children(): npc.call("advance_escape",0.1)
		mission.call("advance_mission")
		if MissionDirector.stats().side_objective_completed: break
		await get_tree().physics_frame
	assert_true(MissionDirector.stats().side_objective_completed)
	assert_eq(MissionDirector.build_result().score,before+5)
	mission.call("advance_mission")
	assert_eq(MissionDirector.build_result().score,before+5)
	assert_false(mission.call("try_escape"),"The target remains the main objective")

func test_execution_waits_for_arrival_and_rescue_loss_does_not_fail_main_mission() -> void:
	var level := await _world()
	if level == null: return
	var mission := level.get_node("Mission")
	var population := level.get_node("Population")
	population.call("advance_schedule",720.1)
	mission.call("advance_mission")
	for npc in mission.get_node("Retainers").get_children(): assert_false(npc.is_defeated(),"Deadline starts travel, not instant death")
	for frame in range(600):
		for name_ in ["CourtWest","CourtEast"]:
			(population.get_node("Monks/"+name_) as EnemyBase).brain().tick(0.1)
		mission.call("advance_mission")
		if mission.get("side_failed"): break
		await get_tree().physics_frame
	assert_true(mission.get("side_failed"))
	assert_eq(MissionDirector.current_objective().id,&"m04_target")
	var target := population.get_node("Tetsusenbo") as TargetNpc
	assert_true(target.begin_assassination(&"back"))
	assert_eq(MissionDirector.current_objective().id,&"m04_escape")
	assert_true(mission.call("try_escape"),"Entry escape remains available after failed rescue")
	assert_true(MissionDirector.build_result().flags[&"completed"])
	assert_false(MissionDirector.build_result().flags[&"side_objective"])
