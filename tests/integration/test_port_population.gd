extends GutTest

var _prior_alert := 0
func before_each() -> void:
	_prior_alert = GameState.area_alert_level
	GameState.area_alert_level = 0
func after_each() -> void:
	GameState.area_alert_level = _prior_alert

const POPULATION := "res://src/levels/port_storehouse/port_population.gd"

func test_port_population_has_authored_roles_and_target_schedule() -> void:
	assert_true(ResourceLoader.exists(POPULATION),"Port population implementation exists")
	if not ResourceLoader.exists(POPULATION): return
	var level := load("res://src/levels/port_storehouse/port_storehouse.tscn").instantiate() as PortStorehouse
	add_child_autofree(level)
	var population: Node3D = load(POPULATION).new()
	level.add_child(population)
	assert_eq(population.get_node("Civilians").get_child_count(),6)
	assert_eq(population.get_node("Guards").get_child_count(),8)
	var target := population.get_node("Target") as TargetNpc
	assert_eq(target.target_routine_cycle_seconds(),300.0)
	assert_eq(target.target_routine_path().stops().size(),3)
	assert_eq(population.call("active_escort_count"),1)
	population.call("apply_alarm",1)
	assert_eq(population.call("active_escort_count"),2)
	assert_true(level.get_node("Markers/Traversal/RearCrawl").is_geometry_valid())

func test_port_target_navigates_between_all_three_real_locations() -> void:
	var level := load("res://src/levels/port_storehouse/port_storehouse.tscn").instantiate() as PortStorehouse
	add_child_autofree(level)
	var population: Node3D = load(POPULATION).new()
	level.add_child(population)
	var target := population.get_node("Target") as TargetNpc
	target.brain().set_physics_process(false)
	for frame in range(5): await get_tree().physics_frame
	for destination in [Vector3(48,0.02,36),Vector3(68,0.02,52),Vector3(66,3.02,14)]:
		for frame in range(1200):
			if target.advance_navigation(1.0/30.0,destination,2.0): break
			await get_tree().physics_frame
		assert_lt(target.global_position.distance_to(destination),0.6,"Navigated to "+str(destination)+" from "+str(target.global_position))

func test_port_abacus_is_local_to_counting_and_stops_on_alarm() -> void:
	var level := load("res://src/levels/port_storehouse/port_storehouse.tscn").instantiate() as PortStorehouse
	add_child_autofree(level)
	var population: Node3D = load(POPULATION).new()
	level.add_child(population)
	for frame in range(3): await get_tree().physics_frame
	var sound := population.get_node("CountingAbacus") as AudioStreamPlayer3D
	assert_true(sound.playing)
	assert_gt((sound.stream as AudioStreamWAV).data.size(),22050)
	assert_eq(sound.max_distance,22.0)
	population.call("apply_alarm",1)
	assert_false(sound.playing)

func test_port_archer_fields_overlap_above_the_middle_storehouse() -> void:
	var level := load("res://src/levels/port_storehouse/port_mission.tscn").instantiate() as PortStorehouse
	add_child_autofree(level)
	for frame in range(3): await get_tree().physics_frame
	var guards := level.get_node("Population/Guards")
	for name_ in ["WestArcher","EastArcher"]:
		var vision := guards.get_node(name_+"/Perception") as EnemyPerception
		assert_true(vision.can_see_position(Vector3(46,5.72,36)),name_+" covers the roof crossing")
