extends GutTest

const TARGET := preload("res://src/enemies/target_npc.tscn")
var definition: MissionDefinition
var target: TargetNpc
var entities: Dictionary

func before_each() -> void:
	definition = MissionDefinition.new()
	definition.id = &"world_checkpoint_test"
	var kill := ObjectiveData.new()
	kill.id = &"kill"
	kill.kind = &"KILL_TARGET"
	kill.target_group = &"checkpoint_test_target"
	var escape := ObjectiveData.new()
	escape.id = &"escape"
	escape.kind = &"ESCAPE"
	definition.objectives = [kill,escape]
	MissionDirector.start_mission(definition)
	target = TARGET.instantiate() as TargetNpc
	add_child_autofree(target)
	target.add_to_group(&"checkpoint_test_target")
	target.position = Vector3(7,0,5)
	entities = {"target":target}

func test_new_scene_claim_resets_previous_run_but_preserves_director_started_run() -> void:
	assert_true(MissionDirector.has_method(&"attach_mission_scene"))
	if not MissionDirector.has_method(&"attach_mission_scene"): return
	var first := Node.new()
	var second := Node.new()
	add_child_autofree(first)
	add_child_autofree(second)
	MissionDirector.stats().detections = 2
	MissionDirector.call(&"attach_mission_scene",first,definition)
	assert_eq(MissionDirector.stats().detections,2,"SceneDirector already started this run")
	MissionDirector.complete_objective(&"kill")
	MissionDirector.call(&"attach_mission_scene",second,definition)
	assert_eq(MissionDirector.current_objective().id,&"kill","A new scene owns a fresh run")
	assert_eq(MissionDirector.stats().detections,0)

func test_world_checkpoint_restores_dead_target_and_score_without_reemitting_kill() -> void:
	assert_true(target.begin_assassination(&"back"))
	var npc := MissionNpcSnapshot.capture(target)
	var mission := MissionDirector.capture_checkpoint_state(entities)
	var replacement := TARGET.instantiate() as TargetNpc
	add_child_autofree(replacement)
	replacement.add_to_group(&"checkpoint_test_target")
	var restored_entities := {"target":replacement}
	assert_true(MissionNpcSnapshot.restore(npc,replacement))
	assert_true(MissionDirector.restore_checkpoint_state(mission,restored_entities))
	assert_true(replacement.is_target_defeated())
	assert_true(replacement.target_defeat_event_emitted())
	assert_eq(MissionDirector.current_objective().id,&"escape")
	EventBus.mission_event.emit(EventBus.EV_TARGET_KILLED,{"target":replacement,"method":&"assassination"})
	assert_eq(MissionDirector.capture_checkpoint_state(restored_entities)["target_kills"],1)
	assert_true(MissionDirector.stats().one_strike)

func test_invalid_snapshot_is_rejected_before_npc_position_or_score_changes() -> void:
	var npc := MissionNpcSnapshot.capture(target)
	npc["meter"] = NAN
	npc["position"] = [100,100,100]
	assert_false(MissionNpcSnapshot.restore(npc,target))
	assert_eq(target.position,Vector3(7,0,5))
	var mission := MissionDirector.capture_checkpoint_state(entities)
	mission["objective"] = 2
	mission["completed"] = true
	mission["running"] = true
	assert_false(MissionDirector.restore_checkpoint_state(mission,entities),"Completed cannot still run")
	assert_not_null(MissionDirector.current_objective())
	if MissionDirector.current_objective() != null: assert_eq(MissionDirector.current_objective().id,&"kill")

func test_partial_damage_and_perception_are_preserved() -> void:
	var combat := target.get_node("Combat") as EnemyCombat
	assert_eq(combat.receive_damage(1,null),1)
	var perception := target.get_node("Perception") as EnemyPerception
	assert_true(perception.restore_checkpoint_meter(1.4))
	var snapshot := MissionNpcSnapshot.capture(target)
	var replacement := TARGET.instantiate() as TargetNpc
	add_child_autofree(replacement)
	assert_true(MissionNpcSnapshot.restore(snapshot,replacement))
	assert_eq((replacement.get_node("Combat") as EnemyCombat).health(),combat.health())
	assert_almost_eq((replacement.get_node("Perception") as EnemyPerception).meter(),1.4,0.0001)

func test_invalid_brain_stop_and_combat_health_flags_fail_atomically() -> void:
	var snapshot := MissionNpcSnapshot.capture(target)
	snapshot["brain"]["stop_index"] = 63
	assert_false(MissionNpcSnapshot.restore(snapshot,target),"No authored route can restore stop 63")
	snapshot = MissionNpcSnapshot.capture(target)
	snapshot["combat"]["health"] = 0
	snapshot["combat"]["defeated"] = false
	assert_false(MissionNpcSnapshot.restore(snapshot,target),"Zero health cannot restore as undefeated")
	assert_eq((target.get_node("Combat") as EnemyCombat).health(),3)
