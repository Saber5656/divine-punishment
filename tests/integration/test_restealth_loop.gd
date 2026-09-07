extends GutTest


const GymScene := preload("res://src/levels/gym/restealth_gym.tscn")

var gym: Node3D
var player: PlayerController
var guard: EnemyBase
var brain: EnemyBrain
var perception: EnemyPerception
var visibility: PlayerVisibility
var _original_area_alert := 0


func before_each() -> void:
	_original_area_alert = GameState.area_alert_level
	gym = GymScene.instantiate() as Node3D
	add_child_autofree(gym)
	player = gym.get_node("Player") as PlayerController
	guard = gym.get_node("Guard") as EnemyBase
	brain = guard.brain()
	perception = guard.get_node("Perception") as EnemyPerception
	visibility = player.get_node("Visibility") as PlayerVisibility
	# Advance AI through its real public tick API on a deterministic clock.
	# Geometry, navigation, player grounding, overlaps and presentation stay live.
	brain.set_physics_process(false)
	(guard.get_node("Combat") as EnemyCombat).set_physics_process(false)
	for _frame in 10:
		await get_tree().physics_frame


func after_each() -> void:
	Input.action_release(&"stance_toggle")
	Input.action_release(&"sprint")
	GameState.area_alert_level = _original_area_alert


func test_production_gym_detection_hide_search_return_and_back_assassination() -> void:
	watch_signals(brain)
	watch_signals(EventBus)
	assert_true(EnemyBase._navigation_map_ready(guard.get_node("NavigationAgent3D")))
	for _step in 120:
		await _tick(0.1)
		if brain.alert_state() == Enums.AlertState.COMBAT:
			break
	assert_eq(brain.alert_state(), Enums.AlertState.COMBAT, "Production rays/meter must detect the player")
	assert_signal_emit_count(EventBus, "player_detected", 1)
	assert_true(perception.target_visible())
	assert_eq(player.receive_combat_damage(1, guard), 1)
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_COMBAT)
	# Exercise the production escape input after damage, including sprint release.
	Input.action_press(&"sprint")
	player._update_state_from_input()
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_SPRINT)
	Input.action_release(&"sprint")
	player._update_state_from_input()
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_GROUND)

	var hide_spot := gym.get_node("HideSpot") as HideSpot
	await _place_player(hide_spot.global_position)
	visibility.recompute()
	perception.tick(0.1)
	assert_false(perception.target_visible(), "Actual wall blocks rays before Hidden exclusion")
	assert_true(player.try_enter_hide_spot(hide_spot))
	assert_true(player.is_visibility_excluded())
	await _tick_for(3.2)
	assert_eq(brain.alert_state(), Enums.AlertState.SEARCHING)
	await _tick_for(4.0)
	assert_gt(guard.global_position.distance_to(Vector3.ZERO), 0.5, "Search must physically leave its post")
	for _step in 600:
		if brain.alert_state() == Enums.AlertState.RETURN:
			break
		await _tick(0.1)
	assert_eq(brain.alert_state(), Enums.AlertState.RETURN)
	assert_almost_eq(brain.vigilance_multiplier(), 1.5, 0.0001)
	var return_start := guard.global_position
	for _step in 100:
		await _tick(0.1)
		if brain.alert_state() == Enums.AlertState.UNAWARE:
			break
	assert_eq(brain.alert_state(), Enums.AlertState.UNAWARE, "Return must walk back, not just set a target")
	assert_gt(guard.global_position.distance_to(return_start), 0.5)
	assert_lt(guard.global_position.distance_to(Vector3.ZERO), 0.51)
	assert_true(brain.residual_alert_active(), "Arrival must not clear the residual window")
	assert_almost_eq(perception.vigilance_multiplier(), 1.5, 0.0001)

	assert_true(player.try_exit_hide_spot())
	await _place_player(guard.global_position + guard.global_basis.z * 1.0)
	var resolver := player.get_node("AssassinationResolver") as AssassinationResolver
	for _frame in 8:
		await get_tree().physics_frame
		if resolver.evaluate(guard) == &"back":
			break
	assert_eq(resolver.evaluate(guard), &"back")
	assert_true(resolver.confirm())
	assert_true(guard.is_assassinated())
	for _frame in 120:
		await get_tree().physics_frame
		if player.state_machine.current_state() != PlayerStateMachine.STATE_ASSASSINATE:
			break
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_GROUND)
	assert_null(resolver.active_enemy(), "Presentation releases the player lock; the enemy remains dead")
	assert_signal_emit_count(EventBus, "player_detected", 1, "Recovery must not erase or double count detection")


func test_residual_window_scales_real_meter_and_expires() -> void:
	# Timer boundary is isolated here; the end-to-end test reaches Return naturally.
	visibility.recompute()
	perception.tick(0.1)
	var normal_gain := perception.meter()
	assert_gt(normal_gain, 0.0)
	brain.force_state(Enums.AlertState.RETURN, &"timer_boundary")
	brain.tick(0.1)
	var vigilant_gain := perception.meter() - normal_gain
	assert_almost_eq(vigilant_gain, normal_gain * 1.5, 0.0001)
	await _place_player((gym.get_node("HideSpot") as HideSpot).global_position)
	assert_true(player.try_enter_hide_spot())
	brain.tick(brain.return_vigilance_remaining() - 0.1)
	assert_true(brain.residual_alert_active())
	brain.tick(0.11)
	assert_false(brain.residual_alert_active())
	assert_eq(perception.vigilance_multiplier(), 1.0)


func test_return_without_navigation_stays_put_and_does_not_claim_arrival() -> void:
	var agent := guard.get_node("NavigationAgent3D") as NavigationAgent3D
	var empty_map := NavigationServer3D.map_create()
	agent.set_navigation_map(empty_map)
	brain.force_state(Enums.AlertState.RETURN, &"empty_map")
	var start := guard.global_position
	await _place_player((gym.get_node("HideSpot") as HideSpot).global_position)
	assert_true(player.try_enter_hide_spot())
	brain.tick(1.0)
	assert_eq(guard.global_position, start)
	assert_eq(brain.alert_state(), Enums.AlertState.RETURN)
	NavigationServer3D.free_rid(empty_map)


func test_combat_stance_escape_waits_for_attack_recovery() -> void:
	var combat := player.combat
	assert_true(combat.start_attack())
	Input.action_press(&"stance_toggle")
	player._update_state_from_input()
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_COMBAT)
	Input.action_release(&"stance_toggle")
	player._update_state_from_input()
	combat.tick(1.0)
	assert_false(combat.can_disengage(), "Attack recovery cannot be cancelled by crouching")
	Input.action_press(&"stance_toggle")
	player._update_state_from_input()
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_COMBAT)
	Input.action_release(&"stance_toggle")
	player._update_state_from_input()
	combat.tick(1.0)
	assert_true(combat.can_disengage())
	Input.action_press(&"stance_toggle")
	player._update_state_from_input()
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_CROUCH)


func test_gym_navigation_rounds_wall_corners_before_returning() -> void:
	await _place_player((gym.get_node("HideSpot") as HideSpot).global_position)
	assert_true(player.try_enter_hide_spot())
	# Reproduce the actual escape route seen during real-time input QA. The
	# enemy must reach the corner waypoint before turning toward the next one.
	guard.global_position = Vector3(0, 0, -5)
	var escaped_position := Vector3(-5, 0, -4)
	for _step in 120:
		if guard.advance_navigation(0.25, escaped_position, 3.0):
			break
		await get_tree().physics_frame
	assert_lt(guard.global_position.distance_to(escaped_position), 0.51)
	brain.force_state(Enums.AlertState.RETURN, &"corner_recovery")
	for _step in 150:
		brain.tick(0.1)
		await get_tree().physics_frame
		if brain.alert_state() == Enums.AlertState.UNAWARE:
			break
	assert_eq(brain.alert_state(), Enums.AlertState.UNAWARE)
	assert_lt(guard.global_position.distance_to(Vector3.ZERO), 0.51)


func test_retained_combat_target_cannot_chase_or_hit_hidden_player() -> void:
	var combat := guard.combat()
	assert_true(combat.set_target(player))
	await _place_player((gym.get_node("HideSpot") as HideSpot).global_position)
	assert_true(player.try_enter_hide_spot())
	var old_position := guard.global_position
	assert_false(combat.attack_target(), "A retained target does not reveal a Hidden player's position")
	assert_eq(guard.global_position, old_position)
	guard.global_position = player.global_position + Vector3(0.0, 0.0, 0.7)
	var health := player.health()
	assert_false(combat.attack_target(), "Hidden exclusion is rechecked immediately before applying damage")
	assert_eq(player.health(), health)
	assert_true(player.is_hidden())
	assert_false(combat.set_target(player))
	assert_true(player.try_exit_hide_spot())
	assert_true(combat.set_target(player))
	assert_true(combat.attack_target(), "Leaving cover restores the normal damage contract")
	assert_eq(player.health(), health - 1)


func _place_player(position: Vector3) -> void:
	# Test navigation between named stations, never forcing gameplay/AI states.
	player.global_position = position
	player.velocity = Vector3.ZERO
	for _frame in 8:
		await get_tree().physics_frame
		if player.is_on_floor():
			break
	assert_true(player.is_on_floor())


func _tick(delta: float) -> void:
	visibility.recompute()
	brain.tick(delta)
	(guard.get_node("Combat") as EnemyCombat).tick(delta)
	await get_tree().physics_frame


func _tick_for(seconds: float) -> void:
	for _step in ceili(seconds / 0.1):
		await _tick(0.1)
