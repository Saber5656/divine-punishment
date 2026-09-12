extends GutTest

const SCENE := "res://src/levels/rainy_temple/temple_population.tscn"

func before_each() -> void:
	GameState.area_alert_level = 0

func after_each() -> void:
	WeatherSystem.start(MissionDefinition.Weather.CLEAR)
	GameState.area_alert_level = 0

func _level() -> Node3D:
	assert_true(ResourceLoader.exists(SCENE),"Temple population scene exists")
	if not ResourceLoader.exists(SCENE): return null
	var level: Node3D = load(SCENE).instantiate()
	add_child_autofree(level)
	return level

func test_ten_enemies_have_private_umbrella_profiles_and_actual_rain() -> void:
	var level := _level()
	if level == null: return
	var population := level.get_node("Population")
	assert_eq(population.get_node("Monks").get_child_count(),8)
	assert_true(population.get_node("Tetsusenbo") is TargetNpc)
	assert_true(population.get_node("CellGuard") is EnemyBase)
	assert_eq(WeatherSystem.current,&"rain")
	assert_eq(WeatherSystem.noise_multiplier(),0.5)
	var shared: PerceptionConfig = load("res://data/tuning/perception_ashigaru.tres")
	for monk in population.get_node("Monks").get_children():
		var vision := monk.get_node("Perception") as EnemyPerception
		assert_ne(vision.perception_config,shared)
		assert_almost_eq(vision.effective_view_distance(),9.6,0.001)
		assert_true(monk.brain().is_physics_processing())
	assert_eq(shared.view_distance_m,15.0)
	assert_almost_eq((population.get_node("CellGuard/Perception") as EnemyPerception).effective_view_distance(),12.0,0.001)

func test_sutra_window_aligns_live_monks_without_interrupting_combat() -> void:
	var level := _level()
	if level == null: return
	var population := level.get_node("Population")
	population.set_physics_process(false)
	for frame in range(4): await get_tree().physics_frame
	for monk in population.get_node("Monks").get_children():
		monk.brain().set_physics_process(false)
	population.call("advance_schedule",36.0)
	for monk in population.get_node("Monks").get_children():
		assert_eq(monk.current_routine_stop().routine_action,&"chant")
		var toward: Vector3 = Vector3(51,8.02,22)-monk.global_position
		toward.y = 0
		assert_gt(monk.current_routine_stop().facing_direction.normalized().dot(toward.normalized()),0.99)
	var fighter: EnemyBase = population.get_node("Monks/GateWest")
	fighter.brain().submit_stimulus(PerceptionStimulus.create(Enums.StimulusKind.DAMAGE,4,Vector3(42,4,60),1))
	fighter.brain().tick(0.01)
	population.call("advance_schedule",1.0)
	assert_eq(fighter.brain().alert_state(),Enums.AlertState.COMBAT)
	population.call("advance_schedule",5.0)
	assert_eq(population.get_node("Monks/GateEast").current_routine_stop().routine_action,&"walk")

func test_target_waits_twelve_minutes_then_really_walks_to_the_cell() -> void:
	var level := _level()
	if level == null: return
	var population := level.get_node("Population")
	population.set_physics_process(false)
	var target := population.get_node("Tetsusenbo") as TargetNpc
	target.brain().set_physics_process(false)
	for frame in range(4): await get_tree().physics_frame
	var initial := target.global_position
	population.call("advance_schedule",719.0)
	assert_eq(target.routine_action(),&"train")
	# RoutineStop includes its authored end instant; inspect on the next tick.
	population.call("advance_schedule",1.01)
	assert_eq(target.routine_action(),&"inspect")
	assert_eq(target.global_position,initial,"A clock jump must not teleport the target")
	var destination := Vector3(78,5.02,28)
	for frame in range(1000):
		target.brain().tick(0.1)
		if target.global_position.distance_to(destination) < 0.5: break
		await get_tree().physics_frame
	assert_lt(target.global_position.distance_to(destination),0.5,"Real target arrival: "+str(target.global_position))

func test_navigation_crosses_graveyard_courtyard_and_ground_without_cliff_shortcuts() -> void:
	var level := _level()
	if level == null: return
	var population := level.get_node("Population")
	population.set_physics_process(false)
	var monk := population.get_node("Monks/Graveyard") as EnemyBase
	monk.brain().set_physics_process(false)
	for frame in range(4): await get_tree().physics_frame
	for destination in [Vector3(48,4.02,56),Vector3(40,0.02,88)]:
		for frame in range(1000):
			if monk.advance_navigation(0.1,destination,3): break
			await get_tree().physics_frame
		assert_lt(monk.global_position.distance_to(destination),0.5,"Connected walking surfaces: "+str(monk.global_position))

func test_reload_restores_initial_time_positions_and_weather() -> void:
	var level := _level()
	if level == null: return
	var population := level.get_node("Population")
	population.call("advance_schedule",721.0)
	level.free()
	level = _level()
	population = level.get_node("Population")
	assert_eq(population.call("schedule_elapsed"),0.0)
	assert_eq(population.get_node("Tetsusenbo").global_position,Vector3(51,8.02,22))
	assert_eq(population.get_node("Tetsusenbo").routine_action(),&"train")
	assert_eq(WeatherSystem.current,&"rain")
