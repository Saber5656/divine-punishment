extends GutTest

func after_each() -> void:
	MissionDirector.start_mission(null)
	GameState.area_alert_level = 0
	GameState.checkpoint_ref.clear()
	PlayerRetryFlow.pending_scene = ""
	get_tree().paused = false

func test_port_mission_defines_target_ledger_escape_and_opium_side_goal() -> void:
	var definition := load("res://data/missions/m03.tres") as MissionDefinition
	assert_eq(definition.objectives.size(),3)
	if definition.objectives.size() != 3: return
	assert_eq(definition.objectives[0].kind,&"KILL_TARGET")
	assert_eq(definition.objectives[1].kind,&"COLLECT")
	assert_eq(definition.objectives[2].kind,&"ESCAPE")
	assert_not_null(definition.side_objective)
	assert_true(ResourceLoader.exists("res://src/levels/port_storehouse/port_objectives.gd"))

func test_port_cargo_pickup_requires_clear_reach_and_disposal_requires_water() -> void:
	const CARGO := "res://src/levels/port_storehouse/port_cargo.gd"
	assert_true(ResourceLoader.exists(CARGO))
	if not ResourceLoader.exists(CARGO): return
	var level := load("res://src/levels/port_storehouse/port_storehouse.tscn").instantiate() as PortStorehouse
	add_child_autofree(level)
	var player := level.get_node("Player") as PlayerController
	var cargo: RigidBody3D = load(CARGO).new()
	cargo.position = Vector3(68,-0.45,36)
	level.add_child(cargo)
	for frame in range(3): await get_tree().physics_frame
	assert_false(cargo.call("try_interact",player),"Cannot collect cargo remotely")
	player.global_position = Vector3(68,0.02,37.2)
	assert_true(cargo.call("try_interact",player))
	assert_true(cargo.call("is_carried"))
	assert_false(cargo.call("is_disposed"))
	assert_true(cargo.call("try_interact",player))
	assert_false(cargo.call("is_carried"))
	assert_false(cargo.call("is_disposed"),"Dropping on land earns no side objective")

func test_port_requires_target_then_reachable_ledger_then_actual_exit() -> void:
	var level := load("res://src/levels/port_storehouse/port_mission.tscn").instantiate() as PortStorehouse
	add_child_autofree(level)
	var mission := level.get_node("Mission")
	var player := level.get_node("Player") as PlayerController
	for frame in range(5): await get_tree().physics_frame
	assert_eq(MissionDirector.current_objective().id,&"m03_target")
	assert_false(mission.call("try_escape",&"Entry"))
	assert_false(mission.call("try_collect_ledger"))
	assert_true((level.get_node("Population/Target") as TargetNpc).begin_assassination(&"below"))
	assert_eq(MissionDirector.current_objective().id,&"m03_ledger")
	assert_false(mission.call("try_collect_ledger"),"Ledger cannot be collected from the spawn")
	assert_false(mission.call("try_escape",&"Entry"))
	player.global_position = Vector3(68,3.02,13.2)
	assert_true(mission.call("try_collect_ledger"),"Reachable ledger after target death can be picked up")
	assert_eq(MissionDirector.current_objective().id,&"m03_escape")
	assert_false(mission.call("try_collect_ledger"),"Ledger is one-shot")
	assert_false(mission.call("try_escape",&"Entry"),"An exit ID does not bypass physical proximity")
	player.global_position = Vector3(8,0.02,60)
	assert_true(mission.call("try_escape",&"Entry"))
	assert_null(MissionDirector.current_objective())
	assert_false(mission.call("try_escape",&"Entry"))

func test_port_cargo_submerges_once_and_awards_the_side_goal_once() -> void:
	var level := load("res://src/levels/port_storehouse/port_mission.tscn").instantiate() as PortStorehouse
	add_child_autofree(level)
	for frame in range(5): await get_tree().physics_frame
	var cargo := level.get_node("Mission/OpiumCargo") as RigidBody3D
	var before := MissionDirector.build_result().score
	var emissions: Array = []
	cargo.connect("disposed",func(): emissions.append(true))
	cargo.global_position = Vector3(88,0,32)
	for frame in range(180):
		await get_tree().physics_frame
		if cargo.call("is_disposed"): break
	assert_true(cargo.call("is_disposed"),"Gravity drops the cargo fully below the real water surface")
	assert_true(MissionDirector.stats().side_objective_completed)
	assert_eq(MissionDirector.build_result().score,before+5)
	for frame in range(30): await get_tree().physics_frame
	assert_eq(emissions.size(),1)
	assert_eq(MissionDirector.build_result().score,before+5)

func test_port_checkpoint_restores_ledger_cargo_civilians_and_target_together() -> void:
	var level := load("res://src/levels/port_storehouse/port_mission.tscn").instantiate() as PortStorehouse
	add_child_autofree(level)
	for frame in range(5): await get_tree().physics_frame
	var mission := level.get_node("Mission")
	var player := level.get_node("Player") as PlayerController
	var flow := player.get_node("RetryFlow") as PlayerRetryFlow
	assert_true(flow.capture_checkpoint(&"port_test"))
	assert_true(GameState.checkpoint_ref.has("mission_world"))
	if not GameState.checkpoint_ref.has("mission_world"): return
	var before := GameState.checkpoint_ref.duplicate(true)
	var target := level.get_node("Population/Target") as TargetNpc
	target.begin_assassination(&"back")
	player.global_position = Vector3(68,3.02,13.2)
	assert_true(mission.call("try_collect_ledger"),"Reachable ledger after target death can be picked up")
	var civilian := level.get_node("Population/Civilians/Worker0") as CivilianNPC
	civilian.receive_combat_damage(1,player)
	assert_true(civilian.is_defeated())
	assert_true(mission.call("restore_checkpoint_world",before),"Restore validates and applies the captured world")
	assert_false(target.is_target_defeated(),"Restored target is alive")
	assert_eq(target.collision_layer,4,"Restored living target regains the enemy layer")
	assert_true(target.can_be_assassinated(),"An undone kill must not leave its assassination lock")
	assert_false(civilian.is_defeated(),"Restored civilian is alive")
	assert_false(mission.get("ledger_collected"))
	assert_eq(MissionDirector.current_objective().id,&"m03_target")
	assert_eq(MissionDirector.stats().civilian_kills,0)
	var corrupt := before.duplicate(true)
	corrupt["mission_world"]["ledger"] = true
	assert_false(mission.call("restore_checkpoint_world",corrupt))
	assert_false(mission.get("ledger_collected"))

func test_port_checkpoint_undoes_opium_disposal_without_retaining_its_bonus() -> void:
	var level := load("res://src/levels/port_storehouse/port_mission.tscn").instantiate() as PortStorehouse
	add_child_autofree(level)
	for frame in range(5): await get_tree().physics_frame
	var mission := level.get_node("Mission")
	var flow := level.get_node("Player/RetryFlow") as PlayerRetryFlow
	assert_true(flow.capture_checkpoint(&"before_cargo"))
	var snapshot := GameState.checkpoint_ref.duplicate(true)
	var cargo := level.get_node("Mission/OpiumCargo") as RigidBody3D
	cargo.global_position = Vector3(88,0,32)
	for frame in range(180):
		await get_tree().physics_frame
		if cargo.call("is_disposed"): break
	assert_true(MissionDirector.stats().side_objective_completed)
	assert_true(mission.call("restore_checkpoint_world",snapshot))
	assert_false(cargo.call("is_disposed"))
	assert_false(MissionDirector.stats().side_objective_completed)
	assert_lt(cargo.global_position.distance_to(Vector3(68,-0.45,36)),0.3)
	var corrupt := snapshot.duplicate(true)
	corrupt["mission_world"]["cargo"]["velocity"] = [NAN,0,0]
	assert_false(mission.call("restore_checkpoint_world",corrupt))

func test_port_scene_reload_preserves_the_pending_world_before_initialization() -> void:
	const SCENE := "res://src/levels/port_storehouse/port_mission.tscn"
	var level := load(SCENE).instantiate() as PortStorehouse
	add_child_autofree(level)
	for frame in range(5): await get_tree().physics_frame
	var player := level.get_node("Player") as PlayerController
	(level.get_node("Population/Target") as TargetNpc).begin_assassination(&"back")
	player.global_position = Vector3(68,3.02,13.2)
	assert_true(level.get_node("Mission").try_collect_ledger())
	assert_true((player.get_node("RetryFlow") as PlayerRetryFlow).capture_checkpoint(&"after_ledger"))
	var retained := GameState.checkpoint_ref.duplicate(true)
	level.queue_free()
	await get_tree().process_frame
	PlayerRetryFlow.pending_scene = SCENE
	GameState.checkpoint_ref = retained
	var replacement := load(SCENE).instantiate() as PortStorehouse
	add_child_autofree(replacement)
	for frame in range(8): await get_tree().physics_frame
	assert_eq(MissionDirector.current_objective().id,&"m03_escape","Reload keeps the restored objective")
	assert_true(replacement.get_node("Mission").ledger_collected)
	assert_true((replacement.get_node("Population/Target") as TargetNpc).is_target_defeated())
	assert_false((replacement.get_node("Player/RetryFlow") as PlayerRetryFlow).choices_visible(),"No restore error menu")
	get_tree().paused = false
	PlayerRetryFlow.pending_scene = ""

func test_port_carried_crate_cannot_be_pushed_through_a_storehouse_wall() -> void:
	var level := load("res://src/levels/port_storehouse/port_storehouse.tscn").instantiate() as PortStorehouse
	add_child_autofree(level)
	var player := level.get_node("Player") as PlayerController
	var cargo: RigidBody3D = load("res://src/levels/port_storehouse/port_cargo.gd").new()
	cargo.position = Vector3(74.3,-0.45,36)
	level.add_child(cargo)
	for frame in range(3): await get_tree().physics_frame
	player.global_position = Vector3(75.3,0.02,36)
	player.rotation.y = -PI/2
	assert_true(cargo.call("try_interact",player))
	for frame in range(3): await get_tree().physics_frame
	assert_lt(cargo.global_position.x,75.55,"The held box stops before the physical wall, even while its collision layer is disabled")
