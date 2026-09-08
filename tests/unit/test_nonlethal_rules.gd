extends GutTest

func after_each() -> void:
	MissionDirector.start_mission(null)

func test_forbidden_kill_fails_before_completing_a_target_objective() -> void:
	var definition := MissionDefinition.new()
	definition.id = &"m09"
	definition.kill_policy = MissionDefinition.KillPolicy.FORBIDDEN
	var objective := ObjectiveData.new()
	objective.id = &"target"
	objective.kind = &"KILL_TARGET"
	objective.target_group = &"no_kill_fixture"
	definition.objectives = [objective]
	var enemy := Node3D.new()
	add_child_autofree(enemy)
	enemy.add_to_group(&"no_kill_fixture")
	MissionDirector.start_mission(definition)
	MissionDirector._on_enemy_killed(enemy,"combat")
	var result := MissionDirector.build_result()
	assert_false(result.flags.completed)
	assert_eq(result.flags.failed_reason, &"killing_forbidden")

func test_policy_blocks_aliases_and_dart_but_keeps_escape_tools() -> void:
	assert_true(MissionDirector.has_method(&"allows_action"))
	if not MissionDirector.has_method(&"allows_action"): return
	var definition := MissionDefinition.new()
	definition.forbidden_actions = [&"sword",&"assassinate_lethal",&"dart"]
	MissionDirector.start_mission(definition)
	for action in [&"sword", &"attack", &"assassinate", &"assassinate_lethal", &"dart"]:
		assert_false(MissionDirector.allows_action(action))
	for action in [&"knockout",&"rope",&"stone",&"smoke",&"dodge"]:
		assert_true(MissionDirector.allows_action(action))

func test_restrained_body_never_wakes_and_is_carryable_anomaly() -> void:
	var enemy = load("res://src/enemies/enemy_base.tscn").instantiate()
	add_child_autofree(enemy)
	assert_true(enemy.set_incapacitated(&"knockout",60.0))
	assert_true(enemy.set_incapacitated(&"restrained"))
	assert_false(enemy.brain().wake())
	assert_eq(enemy.brain().incapacitated_kind(), &"restrained")
	assert_true(enemy.is_body_carryable())
	var anomaly = enemy.corpse_anomaly()
	assert_not_null(anomaly)
	if anomaly != null: assert_eq(anomaly.kind, Enums.AnomalyKind.RESTRAINED)

func test_m9_one_strike_uses_eighty_percent_of_distinct_enemy_contacts() -> void:
	var stats := MissionStats.new()
	assert_true("enemy_contacts" in stats)
	if not "enemy_contacts" in stats: return
	var definition := MissionDefinition.new()
	definition.id = &"m09"
	stats.set("enemy_contacts",5)
	stats.knockouts = 3
	assert_false(MissionDirector.compute_score(stats,ScoringConfig.new(),definition).flags.one_strike)
	stats.knockouts = 4
	assert_true(MissionDirector.compute_score(stats,ScoringConfig.new(),definition).flags.one_strike)

func test_contact_checkpoint_deduplicates_and_rejects_invalid_counter() -> void:
	var definition := MissionDefinition.new()
	definition.id = &"m09"
	var objective := ObjectiveData.new()
	objective.id = &"rescue"
	definition.objectives = [objective]
	MissionDirector.start_mission(definition)
	var enemy := Node3D.new()
	add_child_autofree(enemy)
	MissionDirector._on_contact_alert(enemy,0,Enums.AlertState.COMBAT)
	MissionDirector._on_contact_alert(enemy,0,Enums.AlertState.COMBAT)
	assert_eq(MissionDirector.stats().enemy_contacts,1)
	var entities := {"guard":enemy}
	var snapshot: Dictionary = MissionDirector.capture_checkpoint_state(entities)
	MissionDirector.start_mission(definition)
	assert_true(MissionDirector.restore_checkpoint_state(snapshot,entities))
	MissionDirector._on_contact_alert(enemy,0,Enums.AlertState.COMBAT)
	assert_eq(MissionDirector.stats().enemy_contacts,1)
	snapshot.stats.enemy_contacts = -1
	assert_false(MissionDirector.checkpoint_state_is_valid(snapshot,entities))
