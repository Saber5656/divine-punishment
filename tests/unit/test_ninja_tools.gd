extends GutTest


const ToolDefinitionScript := preload("res://src/tools/tool_definition.gd")
const NoiseEventScript := preload("res://src/core/noise_event.gd")
const EnemyPerceptionScript := preload("res://src/enemies/enemy_perception.gd")


class FakeEnemy extends Node3D:
	var active := false
	var active_kind: StringName = &""
	var active_duration := 0.0

	func set_incapacitated(kind: StringName, duration_seconds: float = 0.0) -> bool:
		if kind != &"knockout" or not is_finite(duration_seconds) or duration_seconds < 0.0:
			return false
		active = true
		active_kind = kind
		active_duration = duration_seconds
		return true

	func is_incapacitated() -> bool:
		return active

	func incapacitated_kind() -> StringName:
		return active_kind

	func on_noise(_event: NoiseEvent) -> bool:
		if not active:
			return false
		active = false
		active_kind = &""
		return true


func test_tool_resources_bind_effect_scenes_and_keep_bounded_parameters() -> void:
	var stone := load("res://data/tools/stone.tres") as ToolDefinition
	var dart := load("res://data/tools/dart.tres") as ToolDefinition
	var smoke := load("res://data/tools/smoke.tres") as ToolDefinition
	assert_not_null(stone)
	assert_not_null(dart)
	assert_not_null(smoke)
	assert_true(stone.is_valid())
	assert_true(dart.is_valid())
	assert_true(smoke.is_valid())
	assert_not_null(stone.effect_scene)
	assert_not_null(dart.effect_scene)
	assert_not_null(smoke.effect_scene)
	assert_eq(stone.parameter_float(&"radius"), 6.0)
	assert_eq(dart.parameter_float(&"sleep"), 20.0)
	assert_eq(smoke.parameter_float(&"radius"), 5.0)
	assert_eq(smoke.parameter_float(&"duration"), 5.0)


func test_pebble_emits_one_bounded_tool_noise_at_impact() -> void:
	var user := Node3D.new()
	add_child_autofree(user)
	var definition := load("res://data/tools/stone.tres") as ToolDefinition
	var effect := definition.effect_scene.instantiate() as ToolBase
	add_child_autofree(effect)
	effect.tool_definition = definition
	watch_signals(EventBus)

	assert_true(effect.use(user, {
		&"origin": Vector3(1.0, 0.0, 2.0),
		&"dir": Vector3.FORWARD,
		&"target": null,
	}))
	assert_signal_emit_count(EventBus, "noise_emitted", 1)
	var parameters: Array = get_signal_parameters(EventBus, "noise_emitted", 0)
	var event := parameters[0] as NoiseEvent
	assert_not_null(event)
	assert_eq(event.kind, Enums.NoiseKind.TOOL)
	assert_eq(event.radius, 6.0)
	assert_eq(event.position, Vector3(1.0, 0.0, -22.0))


func test_blow_dart_extinguishes_only_eligible_light() -> void:
	var light := LightSource.new()
	add_child_autofree(light)
	var user := Node3D.new()
	add_child_autofree(user)
	await get_tree().physics_frame
	var definition := load("res://data/tools/dart.tres") as ToolDefinition
	var effect := definition.effect_scene.instantiate() as ToolBase
	add_child_autofree(effect)
	effect.tool_definition = definition
	watch_signals(EventBus)

	assert_true(effect.use(user, {
		&"origin": Vector3.ZERO,
		&"dir": Vector3.FORWARD,
		&"target": light,
	}))
	assert_false(light.is_on())
	assert_signal_emit_count(EventBus, "light_extinguished", 1)

	var protected_light := LightSource.new()
	protected_light.extinguishable = false
	add_child_autofree(protected_light)
	await get_tree().physics_frame
	var second_effect := definition.effect_scene.instantiate() as ToolBase
	add_child_autofree(second_effect)
	second_effect.tool_definition = definition
	assert_true(second_effect.use(user, {
		&"origin": Vector3.ZERO,
		&"dir": Vector3.FORWARD,
		&"target": protected_light,
	}))
	assert_true(protected_light.is_on())


func test_blow_dart_knockout_is_anomaly_and_noise_wakes_enemy() -> void:
	var enemy := FakeEnemy.new()
	add_child_autofree(enemy)
	var user := Node3D.new()
	add_child_autofree(user)
	await get_tree().physics_frame
	var definition := load("res://data/tools/dart.tres") as ToolDefinition
	var effect := definition.effect_scene.instantiate() as ToolBase
	add_child_autofree(effect)
	effect.tool_definition = definition
	watch_signals(EventBus)

	assert_true(effect.use(user, {
		&"origin": Vector3.ZERO,
		&"dir": Vector3.FORWARD,
		&"target": enemy,
	}))
	assert_true(enemy.is_incapacitated())
	assert_eq(enemy.incapacitated_kind(), &"knockout")
	assert_signal_emit_count(EventBus, "enemy_neutralized", 1)
	var anomaly_parameters: Array = get_signal_parameters(EventBus, "anomaly_registered", 0)
	var anomaly := anomaly_parameters[0] as Anomaly
	assert_not_null(anomaly)
	assert_eq(anomaly.kind, Enums.AnomalyKind.KNOCKOUT)
	assert_eq(anomaly.node, enemy)

	enemy.on_noise(NoiseEventScript.create(Vector3.ZERO, 1.0, Enums.NoiseKind.TOOL, user))
	assert_false(enemy.is_incapacitated())


func test_smoke_bomb_blocks_only_finite_segment_inside_five_meter_volume() -> void:
	var user := Node3D.new()
	add_child_autofree(user)
	var impact := Node3D.new()
	add_child_autofree(impact)
	var definition := load("res://data/tools/smoke.tres") as ToolDefinition
	var effect := definition.effect_scene.instantiate() as SmokeBombTool
	add_child_autofree(effect)
	effect.tool_definition = definition

	assert_true(effect.use(user, {
		&"origin": Vector3.ZERO,
		&"dir": Vector3.FORWARD,
		&"target": impact,
	}))
	assert_true(effect.is_active())
	assert_eq(effect.smoke_radius(), 5.0)
	assert_lte(effect.remaining_seconds(), 5.0)
	assert_true(effect.blocks_visibility(Vector3(0.0, 0.0, 8.0), Vector3(0.0, 0.0, -8.0)))
	assert_false(effect.blocks_visibility(Vector3(6.0, 0.0, 8.0), Vector3(6.0, 0.0, -8.0)))
	var perception := EnemyPerceptionScript.new() as EnemyPerception
	add_child_autofree(perception)
	assert_true(perception._is_smoke_blocked(Vector3(0.0, 0.0, 8.0), Vector3(0.0, 0.0, -8.0)))
	assert_false(perception._is_smoke_blocked(Vector3(6.0, 0.0, 8.0), Vector3(6.0, 0.0, -8.0)))


func test_enemy_incapacitation_duration_is_hard_bounded() -> void:
	var enemy := FakeEnemy.new()
	add_child_autofree(enemy)
	var definition := load("res://data/tools/dart.tres") as ToolDefinition
	var effect := definition.effect_scene.instantiate() as ToolBase
	add_child_autofree(effect)
	effect.tool_definition = definition
	assert_true(effect.use(enemy, {
		&"origin": Vector3.ZERO,
		&"dir": Vector3.FORWARD,
		&"target": enemy,
	}))
	assert_true(enemy.is_incapacitated())
	assert_lte(enemy.active_duration, BlowDartTool.MAX_SLEEP_SECONDS)
