extends GutTest

const SCENE := "res://src/levels/festival_night/festival_mission.tscn"

func after_each() -> void:
	MissionDirector.start_mission(null)
	GameState.area_alert_level = 0
	GameState.checkpoint_ref.clear()
	PlayerRetryFlow.pending_scene = ""
	get_tree().paused = false

func _world() -> Node3D:
	assert_true(ResourceLoader.exists(SCENE),"M5 must compose population, fireworks, lanterns and real objectives")
	if not ResourceLoader.exists(SCENE): return null
	var level: Node3D = load(SCENE).instantiate()
	add_child_autofree(level)
	for frame in range(5): await get_tree().physics_frame
	level.get_node("Player").set_physics_process(false)
	var population := level.get_node("Population")
	population.set_physics_process(false)
	for actor: EnemyBase in population.important_actors()+population.doshin:
		actor.brain().set_physics_process(false)
		actor.combat().set_physics_process(false)
		actor.get_node("Perception").set_process(false)
	for npc: CivilianNPC in population.civilians: npc.set_physics_process(false)
	for crowd in population.get_node("Crowds").get_children(): crowd.set_physics_process(false)
	return level

func test_definition_has_real_target_escape_side_bonus_and_three_naruko() -> void:
	var definition := load("res://data/missions/m05.tres") as MissionDefinition
	assert_not_null(definition.level_scene)
	assert_eq(definition.objectives.size(),2)
	if definition.objectives.size() != 2: return
	assert_eq(definition.objectives[0].kind,&"KILL_TARGET")
	assert_eq(definition.objectives[1].kind,&"ESCAPE")
	assert_eq(definition.side_objective.id,&"m05_no_screams")
	assert_eq(definition.tool_loadout.get(&"naruko"),3)
	assert_eq(definition.par_time_minutes,20.0)
	assert_eq(definition.kill_policy,1)

func test_real_target_death_then_nearby_escape_awards_zero_scream_bonus_once() -> void:
	var level := await _world()
	if level == null: return
	var mission := level.get_node("Mission")
	var target := level.get_node("Population/Kurosawa") as TargetNpc
	var player := level.get_node("Player") as PlayerController
	assert_false(mission.try_escape())
	assert_false(MissionDirector.stats().side_objective_completed)
	assert_true(target.begin_assassination(&"above"))
	assert_eq(MissionDirector.current_objective().id,&"m05_escape")
	player.global_position = Vector3(20,0.02,88)
	assert_false(mission.try_escape())
	player.global_position = Vector3(12,0.02,88)
	var before := MissionDirector.build_result().score
	assert_true(mission.try_escape())
	assert_eq(MissionDirector.build_result().score,before+5)
	assert_true(MissionDirector.build_result().flags[&"completed"])
	assert_false(mission.try_escape())
	assert_eq(MissionDirector.build_result().score,before+5)

func test_masked_civilian_scream_loses_only_side_bonus() -> void:
	var level := await _world()
	if level == null: return
	var population := level.get_node("Population")
	population.advance_schedule(42.0)
	level.get_node("Fireworks").synchronize_elapsed(population.schedule_elapsed(),false)
	assert_true(population.civilians[0].scream())
	assert_eq(level.get_node("Mission").scream_count,1)
	assert_eq(MissionDirector.current_objective().id,&"m05_target")
	assert_true((population.target as TargetNpc).begin_assassination(&"back"))
	assert_true(level.get_node("Mission").try_escape())
	assert_true(MissionDirector.build_result().flags[&"completed"])
	assert_false(MissionDirector.build_result().flags[&"side_objective"])

func test_lanterns_are_persistent_and_crowd_lights_follow_real_groups() -> void:
	var level := await _world()
	if level == null: return
	var environment := level.get_node("FestivalEnvironment")
	var player := level.get_node("Player") as PlayerController
	assert_eq(environment.get_node("Lights").get_child_count(),16)
	for light: LightSource in environment.get_node("Lights").get_children():
		assert_true(light.is_on())
		assert_false(light.extinguishable)
		assert_false(light.try_extinguish_from_projectile())
		assert_true(light.is_geometry_valid())
	var crowd := level.get_node("Population/Crowds/Introduction") as CrowdHideSpot
	crowd.advance_route(0.2)
	environment.sync_crowd_lights()
	assert_eq((environment.get_node("Lights/IntroductionLantern") as Node3D).global_position,crowd.global_position+Vector3.UP*2.2)
	var visibility := player.get_node("Visibility") as PlayerVisibility
	var dark := visibility.recompute()
	player.global_position = Vector3(44,0.02,72)
	assert_gt(visibility.recompute(),dark,"Street lighting must affect gameplay V")
	assert_eq(environment.get_node("Search").get_child_count(),14)
