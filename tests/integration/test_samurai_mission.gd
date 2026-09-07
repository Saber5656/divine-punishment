extends GutTest

const LEVEL := preload("res://src/levels/samurai_residence/samurai_residence.tscn")
var level: SamuraiResidence
var mission: SamuraiMission

func before_each() -> void:
	PlayerRetryFlow.pending_scene = ""
	level = LEVEL.instantiate() as SamuraiResidence
	add_child_autofree(level)
	mission = level.get_node("Mission") as SamuraiMission
	for frame in 5: await get_tree().physics_frame

func after_each() -> void:
	PlayerRetryFlow.pending_scene = ""

func test_all_eleven_production_npcs_have_clear_standing_capsules_and_real_routines() -> void:
	assert_eq(mission.npcs.size(),11)
	assert_true(mission.target is TargetNpc)
	assert_eq(MissionDirector.active_mission_id(),&"m02")
	assert_eq(MissionDirector.current_objective().kind,&"KILL_TARGET")
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	for identity: String in mission.npcs:
		var npc := mission.npcs[identity] as EnemyBase
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.transform = Transform3D(Basis.IDENTITY,npc.global_position)
		query.collision_mask = 1
		assert_true(level.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),identity)
		assert_eq(npc.get_meta(&"mission_entity_id"),identity)
		if not npc is EscortGuard:
			assert_not_null(npc.brain().routine_path())
			assert_true(npc.brain().routine_path().is_geometry_valid(),identity + " must have an executable standing or walking schedule")
	assert_eq(mission.target.target_routine_cycle_seconds(),360.0)
	assert_eq(mission.npcs["E3_GardenPatrol"].brain().routine_cycle_seconds(),90.0)
	assert_eq(mission.npcs["E5_LanternBearer"].brain().routine_cycle_seconds(),120.0)
	assert_eq(mission.npcs["E7_CorridorPatrol"].brain().routine_cycle_seconds(),45.0)

func test_physical_gate_and_escape_reject_unfinished_mission_and_preserve_alternate_exit() -> void:
	assert_false(mission.try_escape(&"EscapeEntry"))
	assert_false(mission.try_escape(&"EscapeWaterway"))
	GameState.area_alert_level = 1
	EventBus.area_alert_changed.emit(1)
	assert_ne(mission.gate.collision_layer & 1,0)
	assert_true(mission.gate.visible)
	assert_true(mission.target.begin_assassination(&"back"))
	assert_eq(MissionDirector.current_objective().kind,&"ESCAPE")
	assert_false(mission.try_escape(&"EscapeGate"))
	assert_true(mission.try_escape(&"EscapeWaterway"))
	assert_null(MissionDirector.current_objective())
	assert_false(mission.try_escape(&"EscapeWaterway"))

func test_target_checkpoint_cannot_fire_on_approach_and_snapshot_restores_dead_world_without_extra_score() -> void:
	var target_checkpoint := level.get_node("Markers/Checkpoints/CheckpointTarget") as CheckpointArea
	assert_false(target_checkpoint.monitoring)
	var flow := level.get_node("Player/RetryFlow") as PlayerRetryFlow
	assert_true(flow.capture_checkpoint(&"perimeter_reached"))
	assert_true(GameState.checkpoint_ref.has("mission_world"))
	assert_eq(GameState.checkpoint_ref["mission_world"]["mission"]["objective"],0)
	assert_true(flow.capture_checkpoint(&"house_reached"))
	assert_true(mission.target.begin_assassination(&"below"))
	for frame in 3: await get_tree().physics_frame
	assert_eq(GameState.checkpoint_ref.get("id"),"assassination_complete")
	var snapshot := GameState.checkpoint_ref.duplicate(true)
	assert_eq(snapshot["mission_world"]["npcs"]["TGT_Toyama"]["brain"]["kind"],"dead")
	var expected_stats: Dictionary = snapshot["mission_world"]["mission"]["stats"].duplicate(true)
	assert_true(mission.restore_checkpoint_world(snapshot))
	assert_true(mission.target.is_target_defeated())
	assert_true(mission.target.target_defeat_event_emitted())
	assert_eq(MissionDirector.current_objective().kind,&"ESCAPE")
	assert_eq(MissionDirector.stats().one_strike,expected_stats["one_strike"])
	assert_eq(MissionDirector.stats().detections,expected_stats["detections"])
	EventBus.mission_event.emit(EventBus.EV_TARGET_KILLED,{"target":mission.target,"method":&"assassination"})
	assert_eq(MissionDirector.capture_checkpoint_state(mission.npcs)["target_kills"],1)

func test_world_restore_rejects_mismatched_objective_or_bad_npc_before_any_mutation() -> void:
	var flow := level.get_node("Player/RetryFlow") as PlayerRetryFlow
	assert_true(flow.capture_checkpoint(&"house_reached"))
	var original := GameState.checkpoint_ref.duplicate(true)
	var invalid := original.duplicate(true)
	invalid["mission_world"]["mission"]["objective"] = 1
	assert_false(mission.restore_checkpoint_world(invalid))
	assert_false(mission.target.is_target_defeated())
	assert_eq(MissionDirector.current_objective().kind,&"KILL_TARGET")
	invalid = original.duplicate(true)
	invalid["mission_world"]["npcs"]["E1_GateGuard"]["position"] = [NAN,0,0]
	var before := (mission.npcs["E1_GateGuard"] as EnemyBase).global_position
	assert_false(mission.restore_checkpoint_world(invalid))
	assert_eq((mission.npcs["E1_GateGuard"] as EnemyBase).global_position,before)
	assert_true(mission.restore_checkpoint_world(original))

func test_target_schedule_uses_phase_windows_not_dwell_plus_travel_and_separates_escorts() -> void:
	for npc: EnemyBase in mission.npcs.values():
		npc.brain().set_physics_process(false)
		npc.set_physics_process(false)
	var brain := mission.target.brain()
	var initial := brain.capture_checkpoint_state()
	# Bounded clock restore supplies boundary fixtures; this is not 360 seconds
	# of runtime evidence. Movement is still production navigation/physics.
	initial["routine_clock"] = 119.9
	assert_true(brain.restore_checkpoint_state(initial))
	for step in 12:
		brain.tick(0.25)
		mission.target._physics_process(0.25)
		await get_tree().physics_frame
	assert_true(mission.target.is_escort_separated())
	assert_eq(mission.target.routine_action(),&"toilet")
	var separated := (mission.npcs["G1_TargetGuard"] as EscortGuard).desired_escort_position()
	assert_lt(separated.z,19.0)
	initial["routine_clock"] = 359.9
	initial["stop_index"] = 5
	assert_true(brain.restore_checkpoint_state(initial))
	for step in 8:
		brain.tick(0.25)
		await get_tree().physics_frame
	assert_lt(brain.routine_clock(),3.0)
	assert_eq(brain.current_routine_stop().routine_action,&"study")

func test_roof_handoff_can_select_second_climb_after_landing() -> void:
	var player := level.get_node("Player") as PlayerController
	player.set_physics_process(false)
	player.global_position = Vector3(41,5,8)
	var selected := player._nearest_climb_edge()
	assert_not_null(selected)
	if selected != null:
		assert_eq(selected.name,&"C2_VerandaRoofEntry","Roof handoff must not select the first route's descent again")

func test_ground_approach_does_not_force_swimming_at_veranda_ramp() -> void:
	var pond := level.get_node("Markers/Water/W1_Pond") as WaterVolume
	var points := level.route_waypoints(&"A_ground")
	for index in range(1,points.size()):
		for sample in range(21):
			var point := points[index - 1].lerp(points[index],sample / 20.0)
			assert_false(pond.can_enter_from_position(point),"Route A must reach the ramp on dry ground: %s" % point)


func test_authored_routine_points_do_not_move_or_turn_with_their_actor() -> void:
	var npc := mission.npcs["E6_VerandaSentry"] as EnemyBase
	npc.brain().set_physics_process(false)
	npc.set_physics_process(false)
	var stop := npc.brain().current_routine_stop()
	var point := stop.target_position()
	var facing := stop.world_facing_direction()
	npc.global_position += Vector3(2,0,3)
	npc.rotation.y += 0.5
	assert_eq(stop.target_position(),point,"World route points must stay fixed when their NPC walks")
	assert_eq(stop.world_facing_direction(),facing,"Sentry must face an authored world direction without spinning")
