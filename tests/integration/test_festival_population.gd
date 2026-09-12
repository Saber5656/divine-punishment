extends GutTest

const SCENE := "res://src/levels/festival_night/festival_population.tscn"

func before_each() -> void:
	GameState.area_alert_level = 0
	MissionDirector.start_mission(null)

func after_each() -> void:
	GameState.area_alert_level = 0
	Input.action_release(&"sprint")

func _level() -> Node3D:
	assert_true(ResourceLoader.exists(SCENE), "M5 needs living patrols and crowds")
	if not ResourceLoader.exists(SCENE): return null
	var level: Node3D = load(SCENE).instantiate()
	add_child_autofree(level)
	return level

func test_roster_preserves_live_brains_and_twelve_grounded_civilians() -> void:
	var level := _level()
	if level == null: return
	var population := level.get_node("Population")
	assert_eq(population.get_node("Doshin").get_child_count(), 8)
	assert_eq(population.get_node("Escorts").get_child_count(), 2)
	assert_true(population.get_node("Kurosawa") is TargetNpc)
	assert_eq(population.civilians.size(), 12)
	for npc: EnemyBase in population.important_actors()+population.doshin:
		assert_true(npc.brain().is_physics_processing())
		assert_true(npc.patrol_path().is_geometry_valid(), "Every live brain needs a usable authored route")
		assert_eq((npc.get_node("Perception") as EnemyPerception).perception_config.view_distance_m, 15.0)
	for civilian: CivilianNPC in population.civilians:
		assert_almost_eq(civilian.global_position.y, -0.9, 0.001, "Civilian origin is at its feet")
		assert_false(civilian.is_defeated())

func test_crowd_loop_conceals_walk_and_emits_scream_on_sprint() -> void:
	var level := _level()
	if level == null: return
	var population := level.get_node("Population")
	var crowd := population.get_node("Crowds/Introduction") as CrowdHideSpot
	crowd.set_physics_process(false)
	assert_eq(crowd.route.get_point_position(0), crowd.route.get_point_position(crowd.route.point_count-1), "No jump on curve wrap")
	var player := level.get_node("Player") as PlayerController
	player.global_position = crowd.global_position+Vector3.UP*0.9
	player.set_physics_process(false)
	for frame in range(3): await get_tree().physics_frame
	assert_true(crowd.conceals(player))
	assert_true(player.is_visibility_excluded())
	var screams: Array = []
	var listener := func(id, _payload):
		if id == &"civilian_scream": screams.append(id)
	EventBus.mission_event.connect(listener)
	player.state_machine.change_state(&"Sprint")
	assert_false(crowd.conceals(player))
	assert_true(crowd.check_disruption(player))
	assert_eq(screams.size(), 1)
	EventBus.mission_event.disconnect(listener)

func test_six_minute_clock_changes_goals_without_teleport_or_cancelled_combat() -> void:
	var level := _level()
	if level == null: return
	var population := level.get_node("Population")
	population.set_physics_process(false)
	var target := population.get_node("Kurosawa") as TargetNpc
	target.brain().set_physics_process(false)
	var initial := target.global_position
	assert_eq(population.phase(), &"dais")
	assert_true(population.advance_schedule(180.01))
	assert_eq(population.phase(), &"shrine")
	assert_eq(target.global_position, initial)
	assert_eq(target.routine_target(), Vector3(51,3.02,17))
	assert_false(population.prayer_active(), "Travel time cannot count as isolated prayer")
	assert_true(population.advance_schedule(120.0))
	assert_eq(population.phase(), &"stalls")
	assert_true(population.advance_schedule(60.0))
	assert_eq(population.phase(), &"dais")
	target.brain().submit_stimulus(PerceptionStimulus.create(Enums.StimulusKind.DAMAGE,4,initial+Vector3.RIGHT,1))
	target.brain().tick(0.01)
	population.advance_schedule(180.0)
	assert_eq(target.brain().alert_state(), Enums.AlertState.COMBAT)
	assert_false(population.advance_schedule(-1.0))
	assert_false(population.advance_schedule(NAN))

func test_actual_navigation_connects_dais_stairs_and_shrine_without_roof_shortcuts() -> void:
	var level := _level()
	if level == null: return
	var population := level.get_node("Population")
	population.set_physics_process(false)
	var target := population.get_node("Kurosawa") as TargetNpc
	target.brain().set_physics_process(false)
	for frame in range(5): await get_tree().physics_frame
	for destination in [Vector3(51,3.02,17), Vector3(48,0.02,56), Vector3(84,3.02,32)]:
		for frame in range(1800):
			if target.advance_navigation(0.1, destination, 3): break
			await get_tree().physics_frame
		assert_lt(target.global_position.distance_to(destination), 0.5, "Real connected route: "+str(target.global_position))
	var map := level.get_world_3d().navigation_map
	var roof := Vector3(28,4.02,60)
	assert_gt(NavigationServer3D.map_get_closest_point(map, roof).distance_to(roof), 2.0, "Roofs are not NPC walking shortcuts")

func test_prayer_counts_thirty_seconds_only_after_real_target_and_escort_arrival() -> void:
	var level := _level()
	if level == null: return
	var population := level.get_node("Population")
	population.set_physics_process(false)
	for actor: EnemyBase in population.important_actors(): actor.brain().set_physics_process(false)
	for frame in range(5): await get_tree().physics_frame
	population.advance_schedule(180.0)
	var observed := 0.0
	var invalid_window := false
	var exposed_approach := false
	for frame in range(600):
		for actor: EnemyBase in population.important_actors(): actor.brain().tick(0.2)
		population.advance_schedule(0.2)
		if population.prayer_active():
			observed += 0.2
			if population.target.global_position.distance_to(Vector3(51,3.02,17)) > 0.5: invalid_window = true
			for escort: EnemyBase in population.escorts:
				if escort.global_position.distance_to(population.target.global_position) < 8.0: invalid_window = true
				for point in [Vector3(51,0.02,33),Vector3(51,3.02,24),Vector3(51,3.02,17)]:
					if (escort.get_node("Perception") as EnemyPerception).can_see_position(point+Vector3.UP*0.7): exposed_approach = true
		if population.prayer_elapsed() >= 30.0: break
		await get_tree().physics_frame
	assert_false(invalid_window, "A prayer window needs the target inside and both escorts outside")
	assert_false(exposed_approach, "Waiting escorts must leave the central stairs and isolated target outside their actual vision")
	if observed < 29.5:
		for actor: EnemyBase in population.important_actors():
			print("PRAYER_DIAGNOSTIC ",actor.name," position=",actor.global_position," destination=",actor.routine_target()," alert=",actor.brain().alert_state()," phase=",population.phase()," stage=",population._prayer_stage)
	assert_gt(observed, 29.5, "Do not spend the thirty-second opportunity on approach travel")
	assert_eq(population.prayer_elapsed(), 30.0)
	assert_eq(population.phase(), &"shrine", "Real travel plus prayer must fit the two-minute shrine phase")


func test_unseen_target_defeat_triggers_escort_combat_without_waking_incapacitated_guard() -> void:
	var level := _level()
	if level == null: return
	var population := level.get_node("Population")
	population.set_physics_process(false)
	for escort: EnemyBase in population.escorts:
		escort.brain().set_physics_process(false)
		assert_eq(escort.brain().alert_state(),Enums.AlertState.UNAWARE)
	assert_true(population.escorts[1].set_incapacitated(&"knockout",10.0))
	assert_true(population.target.begin_assassination(&"above"))
	assert_eq(population.escorts[0].brain().alert_state(),Enums.AlertState.COMBAT,"Actual assassination reaction is independent of line of sight")
	assert_true(population.escorts[1].brain().is_incapacitated())
	assert_eq(population.escorts[1].brain().alert_state(),Enums.AlertState.UNAWARE)
	assert_true(population.escorts[1].set_incapacitated(&""))
	for frame in range(3): await get_tree().physics_frame
	assert_eq(population.escorts[1].brain().alert_state(),Enums.AlertState.COMBAT,"Deferred reaction remains pending until the escort wakes")
