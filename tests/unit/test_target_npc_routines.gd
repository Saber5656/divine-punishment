extends GutTest


const TargetScene := preload("res://src/enemies/target_npc.tscn")
const EscortScene := preload("res://src/enemies/escort_guard.tscn")

var _mission_event_names: Array[StringName] = []
var _mission_event_payloads: Array[Dictionary] = []


func test_target_role_cycles_authored_stops_and_exposes_bounded_timing() -> void:
	var target := TargetScene.instantiate() as TargetNpc
	add_child_autofree(target)
	var path := _make_path([
		{ "position": Vector3.ZERO, "action": &"study", "dwell": 120.0 },
		{ "position": Vector3(2.0, 0.0, 0.0), "action": &"toilet", "dwell": 60.0 },
	])
	assert_true(target.set_target_routine_path(path))
	assert_eq(target.routine_role(), &"target")
	assert_true(target.brain().is_target())
	assert_true(target.is_target_routine_enabled())
	assert_eq(target.target_routine_stop().routine_action, &"study")
	assert_eq(target.target_routine_stop().dwell_duration(), 120.0)
	assert_true(target.set_routine_cycle_seconds(360.0))
	assert_eq(target.target_routine_cycle_seconds(), 360.0)
	assert_eq(target.brain().routine_cycle_seconds(), 360.0)
	assert_false(target.set_routine_cycle_seconds(NAN))
	assert_false(target.set_routine_cycle_seconds(-1.0))
	assert_eq(target.target_routine_cycle_seconds(), 360.0)

	assert_true(target.brain().advance_routine_stop())
	target._physics_process(0.016)
	assert_eq(target.target_routine_stop_index(), 1)
	assert_eq(target.routine_action(), &"toilet")
	assert_true(target.is_escort_separated())
	assert_eq(target.escort_anchor_position(), Vector3.ZERO)
	assert_eq(target.target_routine_stop_elapsed(), 0.0)

	assert_true(target.brain().advance_routine_stop())
	target._physics_process(0.016)
	assert_eq(target.target_routine_stop_index(), 0)
	assert_false(target.is_escort_separated())


func test_target_routine_cycle_wraps_brain_schedule_clock() -> void:
	var target := TargetScene.instantiate() as TargetNpc
	add_child_autofree(target)
	var path := _make_path([
		{ "position": Vector3.ZERO, "action": &"study", "dwell": 600.0 },
		{ "position": Vector3(1.0, 0.0, 0.0), "action": &"stand", "dwell": 600.0 },
	])
	assert_true(target.set_target_routine_path(path))
	assert_true(target.set_routine_cycle_seconds(2.0))
	assert_eq(target.brain().routine_cycle_seconds(), 2.0)

	for _index in 6:
		target.brain().tick(0.25)
	assert_almost_eq(target.target_routine_cycle_elapsed(), 1.5, 0.0001)
	for _index in 4:
		target.brain().tick(0.25)
	assert_almost_eq(target.target_routine_cycle_elapsed(), 0.5, 0.0001)
	assert_false(target.set_routine_cycle_seconds(0.5))
	assert_false(target.set_routine_cycle_seconds(INF))


func test_target_routine_rejects_invalid_route_without_movement() -> void:
	var target := TargetScene.instantiate() as TargetNpc
	add_child_autofree(target)
	var invalid_path := PatrolPath.new()
	add_child_autofree(invalid_path)
	var invalid_stop := RoutineStop.new()
	invalid_stop.position = Vector3(NAN, 0.0, 0.0)
	invalid_path.add_child(invalid_stop)
	assert_true(target.set_target_routine_path(invalid_path))
	assert_false(target.brain().advance_routine_stop())
	assert_eq(target.global_position, Vector3.ZERO)


func test_escort_follows_target_and_holds_separation_anchor() -> void:
	var target := TargetScene.instantiate() as TargetNpc
	add_child_autofree(target)
	target.global_position = Vector3(4.0, 0.0, 2.0)
	var path := _make_path([
		{ "position": target.global_position, "action": &"study", "dwell": 1.0 },
		{ "position": Vector3(7.0, 0.0, 2.0), "action": &"separate_escort", "dwell": 1.0 },
	])
	assert_true(target.set_target_routine_path(path))
	var escort := EscortScene.instantiate() as EscortGuard
	add_child_autofree(escort)
	assert_true(escort.set_escort_target(target))
	escort.follow_offset = Vector3(-1.0, 0.0, 0.0)
	escort.separation_offset = Vector3(0.0, 0.0, 2.0)
	assert_eq(escort.routine_role(), &"escort")
	assert_eq(escort.desired_escort_position(), target.global_position + escort.follow_offset)

	assert_true(target.brain().advance_routine_stop())
	target._physics_process(0.016)
	assert_true(target.is_escort_separated())
	assert_eq(escort.desired_escort_position(), Vector3(4.0, 0.0, 4.0))
	assert_eq(escort.escort_target(), target)

	escort.follow_offset = Vector3(INF, 0.0, 0.0)
	assert_eq(escort.follow_offset, Vector3(-1.5, 0.0, 0.0))
	escort.separation_offset = Vector3(NAN, 0.0, 0.0)
	assert_eq(escort.separation_offset, Vector3(0.0, 0.0, 2.0))
	var detached_target := TargetNpc.new()
	assert_false(escort.set_escort_target(detached_target))
	detached_target.free()


func test_target_defeat_emits_one_shot_mission_event_and_escort_enters_combat() -> void:
	var target := TargetScene.instantiate() as TargetNpc
	add_child_autofree(target)
	var escort := EscortScene.instantiate() as EscortGuard
	add_child_autofree(escort)
	assert_true(escort.set_escort_target(target))
	_mission_event_names.clear()
	_mission_event_payloads.clear()
	var callback := Callable(self, &"_capture_mission_event")
	EventBus.mission_event.connect(callback)

	assert_true(target.notify_target_defeated(&"assassination"))
	assert_false(target.notify_target_defeated(&"combat"))
	assert_true(target.target_defeat_event_emitted())
	assert_true(target.is_target_defeated())
	assert_eq(_mission_event_names, [&"target_killed"])
	assert_eq(_mission_event_payloads.size(), 1)
	assert_eq(_mission_event_payloads[0].get("target"), target)
	assert_eq(_mission_event_payloads[0].get("method"), &"assassination")
	assert_true(escort.target_defeated())
	assert_eq(escort.brain().alert_state(), Enums.AlertState.COMBAT)

	EventBus.mission_event.disconnect(callback)


func test_target_dead_api_emits_event_once_through_combat_compatibility() -> void:
	var target := TargetScene.instantiate() as TargetNpc
	add_child_autofree(target)
	_mission_event_names.clear()
	_mission_event_payloads.clear()
	var callback := Callable(self, &"_capture_mission_event")
	EventBus.mission_event.connect(callback)
	assert_true(target.set_incapacitated(&"dead", 0.0))
	assert_true(target.set_incapacitated(&"dead", 0.0))
	assert_eq(_mission_event_names, [&"target_killed"])
	assert_eq(_mission_event_payloads[0].get("method"), &"combat")
	EventBus.mission_event.disconnect(callback)


func test_target_assassination_preserves_assassination_method() -> void:
	var target := TargetScene.instantiate() as TargetNpc
	add_child_autofree(target)
	_mission_event_names.clear()
	_mission_event_payloads.clear()
	var callback := Callable(self, &"_capture_mission_event")
	EventBus.mission_event.connect(callback)

	assert_true(target.begin_assassination(&"back"))
	assert_eq(_mission_event_names, [&"target_killed"])
	assert_eq(_mission_event_payloads.size(), 1)
	assert_eq(_mission_event_payloads[0].get("method"), &"assassination")

	EventBus.mission_event.disconnect(callback)


func test_incapacitated_escort_defers_target_combat_until_wake() -> void:
	var target := TargetScene.instantiate() as TargetNpc
	add_child_autofree(target)
	var escort := EscortScene.instantiate() as EscortGuard
	add_child_autofree(escort)
	assert_true(escort.set_escort_target(target))
	assert_true(escort.set_incapacitated(&"knockout", 10.0))

	assert_true(target.notify_target_defeated(&"combat"))
	assert_true(escort.brain().is_incapacitated())
	assert_eq(escort.brain().alert_state(), Enums.AlertState.UNAWARE)
	assert_false(escort.brain().alert_state() == Enums.AlertState.COMBAT)

	assert_true(escort.set_incapacitated(&""))
	escort._physics_process(0.016)
	assert_eq(escort.brain().alert_state(), Enums.AlertState.COMBAT)


func _capture_mission_event(event_name: StringName, payload: Dictionary) -> void:
	_mission_event_names.append(event_name)
	_mission_event_payloads.append(payload)


func _make_path(definitions: Array) -> PatrolPath:
	var path := PatrolPath.new()
	path.looped = true
	add_child_autofree(path)
	for index in definitions.size():
		var definition: Dictionary = definitions[index]
		var stop := RoutineStop.new()
		stop.route_index = index
		stop.position = definition["position"]
		stop.routine_action = definition["action"]
		stop.dwell_seconds = definition["dwell"]
		path.add_child(stop)
	return path


func test_unseen_target_death_alerts_escort_without_counting_player_until_contact() -> void:
	var target := TargetScene.instantiate() as TargetNpc
	add_child_autofree(target)
	var escort := EscortScene.instantiate() as EscortGuard
	add_child_autofree(escort)
	escort.set_physics_process(false)
	escort.brain().set_physics_process(false)
	escort.brain().set_target_visible(false)
	assert_true(escort.set_escort_target(target))
	watch_signals(EventBus)
	assert_true(target.notify_target_defeated(&"assassination"))
	assert_signal_not_emitted(EventBus,&"player_detected")
	assert_eq(escort.brain().alert_state(),Enums.AlertState.COMBAT)
	escort.brain().set_target_visible(true)
	escort.brain().tick(0.1)
	assert_signal_emit_count(EventBus,&"player_detected",1)
	escort.brain().tick(0.1)
	assert_signal_emit_count(EventBus,&"player_detected",1)
	escort.brain().set_target_visible(false)
	for step in 14:
		escort.brain().tick(0.25)
		escort._physics_process(0.25)
	assert_eq(escort.brain().alert_state(),Enums.AlertState.SEARCHING)
	assert_signal_emit_count(EventBus,&"player_detected",1)


func test_escort_checkpoint_keeps_consumed_death_reaction_and_pending_contact() -> void:
	var target := TargetScene.instantiate() as TargetNpc
	add_child_autofree(target)
	var escort := EscortScene.instantiate() as EscortGuard
	add_child_autofree(escort)
	escort.set_physics_process(false)
	escort.brain().set_physics_process(false)
	escort.brain().set_target_visible(false)
	escort.set_escort_target(target)
	target.notify_target_defeated(&"assassination")
	for step in 14:
		escort.brain().tick(0.25)
		escort._physics_process(0.25)
	var saved := MissionNpcSnapshot.capture(escort)
	var restored := EscortScene.instantiate() as EscortGuard
	add_child_autofree(restored)
	restored.set_physics_process(false)
	restored.brain().set_physics_process(false)
	restored.set_escort_target(target)
	assert_true(MissionNpcSnapshot.restore(saved,restored))
	restored._physics_process(0.1)
	assert_eq(restored.brain().alert_state(),Enums.AlertState.SEARCHING,"Reload must not replay the already consumed target-death reaction")
	watch_signals(EventBus)
	restored.brain().set_target_visible(false)
	for step in 14:
		restored.brain().tick(0.25)
		restored._physics_process(0.25)
	assert_eq(restored.brain().alert_state(),Enums.AlertState.SEARCHING)
	assert_signal_not_emitted(EventBus,&"player_detected")


func test_escort_alarm_cannot_auto_target_or_attack_an_unseen_player() -> void:
	var target := TargetScene.instantiate() as TargetNpc
	add_child_autofree(target)
	var escort := EscortScene.instantiate() as EscortGuard
	add_child_autofree(escort)
	var player := load("res://src/player/player.tscn").instantiate() as PlayerController
	add_child_autofree(player)
	player.position = Vector3(0,0,1)
	player.set_physics_process(false)
	escort.brain().set_target_visible(false)
	escort.set_escort_target(target)
	var defense := player.get_node("AssassinationResolver/Combat") as PlayerCombat
	var health := defense.health()
	target.notify_target_defeated(&"assassination")
	var combat := escort.get_node("Combat") as EnemyCombat
	combat.tick(0.1)
	assert_null(combat.target(),"A death alarm provides no omniscient player target")
	assert_eq(defense.health(),health,"An unseen player behind the escort must not be hit")
	combat.receive_damage(1,player)
	combat.tick(0.1)
	assert_lt(defense.health(),health,"Direct contact must restore normal defense and attacks")
