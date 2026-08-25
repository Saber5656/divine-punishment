extends GutTest


const ResolverScript := preload("res://src/player/assassination_resolver.gd")
const ConfigScript := preload("res://src/core/tuning/assassination_config.gd")
const PlayerScene := preload("res://src/player/player.tscn")
const EnemyScene := preload("res://src/enemies/enemy_base.tscn")
const CONFIG_PATH := "res://data/tuning/assassination.tres"


func test_static_resolve_accepts_all_four_tuned_contexts() -> void:
	var config := load(CONFIG_PATH) as Resource
	if config == null or config.get("back_max_distance_m") == null:
		# Godot 4.3 may finish the clean-import script cache after this test
		# starts.  Exercise the same bounded defaults used by the resolver when
		# the optional tuning resource is not available yet.
		config = ConfigScript.new() as Resource
	assert_not_null(config)
	assert_eq(config.get("back_max_distance_m"), 1.5)
	assert_eq(config.get("above_max_distance_m"), 4.0)
	assert_eq(config.get("below_max_angle_degrees"), 45.0)
	assert_eq(config.get("corner_max_angle_degrees"), 60.0)
	assert_eq(
		ResolverScript.resolve(&"Ground", Vector3(0.0, 0.0, 1.0), Enums.AlertState.UNAWARE, false, config),
		&"back",
	)
	assert_eq(
		ResolverScript.resolve(&"Beam", Vector3(0.0, -3.0, 0.0), Enums.AlertState.SUSPICIOUS, false, config),
		&"above",
	)
	assert_eq(
		ResolverScript.resolve(&"Crawlspace", Vector3(0.0, 1.0, 0.0), Enums.AlertState.SEARCHING, false, config),
		&"below",
	)
	assert_eq(
		ResolverScript.resolve(&"WallCling", Vector3(1.0, 0.0, 0.0), Enums.AlertState.RETURN, false, config),
		&"corner",
	)


func test_resolver_provides_a_fallback_config_when_resource_load_is_unavailable() -> void:
	var player := PlayerScene.instantiate() as PlayerController
	add_child_autofree(player)
	await get_tree().process_frame

	var resolver := player.get_node("AssassinationResolver") as AssassinationResolver
	assert_not_null(resolver.config)
	assert_true(resolver.config is Resource)
	assert_eq(resolver.config.get("back_max_distance_m"), 1.5)
	assert_eq(resolver.config.get("above_max_distance_m"), 4.0)


func test_static_resolve_enforces_distance_and_angle_boundaries() -> void:
	var config := ConfigScript.new() as AssassinationConfig
	assert_eq(
		ResolverScript.resolve(&"Ground", Vector3(0.0, 0.0, 1.5), Enums.AlertState.UNAWARE, false, config),
		&"back",
	)
	assert_eq(
		ResolverScript.resolve(&"Ground", Vector3(0.0, 0.0, 1.501), Enums.AlertState.UNAWARE, false, config),
		&"",
	)
	assert_eq(
		ResolverScript.resolve(&"Ground", Vector3(1.3, 0.0, 0.4), Enums.AlertState.UNAWARE, false, config),
		&"",
	)
	assert_eq(
		ResolverScript.resolve(&"Beam", Vector3(0.0, -4.001, 0.0), Enums.AlertState.UNAWARE, false, config),
		&"",
	)


func test_static_resolve_rejects_combat_seen_and_invalid_contexts() -> void:
	var config := load(CONFIG_PATH) as AssassinationConfig
	for state: Enums.AlertState in [
		Enums.AlertState.UNAWARE,
		Enums.AlertState.SUSPICIOUS,
		Enums.AlertState.SEARCHING,
		Enums.AlertState.RETURN,
	]:
		assert_eq(
			ResolverScript.resolve(&"Ground", Vector3(0.0, 0.0, 1.0), Enums.AlertState.COMBAT, false, config),
			&"",
		)
		assert_eq(
			ResolverScript.resolve(&"Ground", Vector3(0.0, 0.0, 1.0), state, true, config),
			&"",
		)
	assert_eq(
		ResolverScript.resolve(&"Sprint", Vector3(0.0, 0.0, 1.0), Enums.AlertState.UNAWARE, false, config),
		&"",
	)
	assert_eq(
		ResolverScript.resolve(&"Ground", Vector3(NAN, 0.0, 1.0), Enums.AlertState.UNAWARE, false, config),
		&"",
	)


func test_prompt_and_one_input_execution_lock_both_sides() -> void:
	var player := PlayerScene.instantiate() as PlayerController
	add_child_autofree(player)
	var enemy := EnemyScene.instantiate() as EnemyBase
	enemy.position = Vector3(0.0, 0.0, 1.0)
	add_child_autofree(enemy)
	var resolver := player.get_node("AssassinationResolver") as AssassinationResolver
	watch_signals(resolver)
	var interactor := player.get_node("Interactor") as Area3D
	var target_area := enemy.get_node("AssassinateTarget") as Area3D
	var overlaps_target := false
	for _i in range(4):
		await get_tree().physics_frame
		overlaps_target = interactor.get_overlapping_areas().has(target_area)
		if overlaps_target:
			break
	assert_true(overlaps_target)
	assert_eq(resolver.evaluate(enemy), &"back")
	assert_eq(resolver.prompt_enemy(), enemy)
	assert_eq(resolver.prompt_context(), &"back")
	assert_signal_emitted_with_parameters(resolver, "prompt_changed", [enemy, &"back"])

	assert_true(resolver.confirm())
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_ASSASSINATE)
	assert_true(enemy.is_assassinating())
	assert_true(enemy.is_assassinated())
	assert_eq(enemy.assassination_context(), &"back")
	assert_true((enemy.get_node("Brain") as EnemyBrain).is_incapacitated())
	assert_eq((enemy.get_node("Brain") as EnemyBrain).incapacitated_kind(), &"dead")
	assert_false(resolver.confirm())
	assert_true(resolver.release())
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_GROUND)


func test_prompt_and_evaluate_reject_enemy_in_combat() -> void:
	var player := PlayerScene.instantiate() as PlayerController
	add_child_autofree(player)
	var enemy := EnemyScene.instantiate() as EnemyBase
	enemy.position = Vector3(0.0, 0.0, 1.0)
	add_child_autofree(enemy)
	await get_tree().process_frame
	(enemy.get_node("Brain") as EnemyBrain).force_state(Enums.AlertState.COMBAT, &"test")

	var resolver := player.get_node("AssassinationResolver") as AssassinationResolver
	assert_eq(resolver.evaluate(enemy), &"")
	assert_eq(resolver.prompt_context(), &"")
	assert_false(resolver.confirm())


func test_prompt_and_evaluate_reject_enemy_seen_by_perception() -> void:
	var player := PlayerScene.instantiate() as PlayerController
	add_child_autofree(player)
	var enemy := EnemyScene.instantiate() as EnemyBase
	enemy.position = Vector3(0.0, 0.0, 1.0)
	add_child_autofree(enemy)
	await get_tree().process_frame
	var perception := enemy.get_node("Perception") as EnemyPerception
	perception.set("_target_visible", true)

	var resolver := player.get_node("AssassinationResolver") as AssassinationResolver
	assert_eq(resolver.evaluate(enemy), &"")
	assert_eq(resolver.prompt_context(), &"")
	assert_false(resolver.confirm())
