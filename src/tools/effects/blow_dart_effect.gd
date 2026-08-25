class_name BlowDartTool
extends ToolBase


const MAX_SLEEP_SECONDS := 20.0
const MAX_TARGET_ANCESTRY := 8


func _apply_effect(hit: Dictionary) -> void:
	var definition := tool_definition
	if definition == null:
		return
	var duration := definition.parameter_float(&"knockout_duration", -1.0)
	if duration < 0.0:
		duration = definition.parameter_float(&"sleep", MAX_SLEEP_SECONDS)
	if not is_finite(duration) or duration <= 0.0:
		return
	duration = minf(duration, MAX_SLEEP_SECONDS)
	var max_range := clampf(
		definition.parameter_float(&"max_range", MAX_IMPACT_DISTANCE),
		0.1,
		MAX_IMPACT_DISTANCE,
	)
	var impact := _impact_hit(hit, max_range)
	var target := impact.get(&"collider") as Node
	var light := _find_light_source(target)
	if light != null:
		light.try_extinguish_from_projectile()
		if is_inside_tree():
			queue_free()
		return
	var enemy := _find_enemy(target)
	if enemy != null and _incapacitate(enemy, duration):
		_emit_knockout(enemy, duration)
	if is_inside_tree():
		queue_free()


func _find_light_source(target: Node) -> LightSource:
	var cursor := target
	for _index in MAX_TARGET_ANCESTRY:
		if cursor == null:
			return null
		if cursor is LightSource:
			return cursor as LightSource
		cursor = cursor.get_parent()
	return null


func _find_enemy(target: Node) -> Node:
	var cursor := target
	for _index in MAX_TARGET_ANCESTRY:
		if cursor == null:
			return null
		if cursor is EnemyBase or cursor.has_method(&"set_incapacitated"):
			return cursor
		if cursor.get_node_or_null(NodePath("Brain")) is EnemyBrain:
			return cursor
		cursor = cursor.get_parent()
	return null


func _incapacitate(enemy: Node, duration: float) -> bool:
	if not enemy is Node3D or not _is_runtime_node(enemy):
		return false
	if enemy.has_method(&"set_incapacitated"):
		return bool(enemy.call(&"set_incapacitated", &"knockout", duration))
	var brain := enemy.get_node_or_null(NodePath("Brain")) as EnemyBrain
	return brain != null and brain.set_incapacitated(&"knockout", duration)


func _emit_knockout(enemy: Node, duration: float) -> void:
	if not has_node("/root/EventBus") or not enemy is Node3D or not _is_runtime_node(enemy):
		return
	var position := (enemy as Node3D).global_position
	if not position.is_finite():
		return
	var expires_at := float(Time.get_ticks_msec()) / 1000.0 + duration
	var anomaly := Anomaly.create(
		Enums.AnomalyKind.KNOCKOUT,
		position,
		enemy as Node3D,
		1,
		expires_at,
	)
	EventBus.anomaly_registered.emit(anomaly)
	EventBus.enemy_neutralized.emit(enemy, "dart_sleep")
