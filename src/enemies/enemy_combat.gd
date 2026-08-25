class_name EnemyCombat
extends Node


signal attack_started(target: Node)
signal attack_hit(target: Node, damage: int)
signal damage_received(amount: int, remaining_health: int, source: Node)
signal reinforcements_called(count: int)
signal defeated(source: Node)

const MAX_TARGETS_TO_SCAN := 64
const MAX_DELTA_SECONDS := 10.0

@export var combat_config: CombatConfig
@export var enemy_stats: EnemyStats

var _config: CombatConfig
var _stats: EnemyStats
var _enemy: Node3D
var _target: Node
var _health := 3
var _max_health := 3
var _attack_cooldown_remaining := 0.0
var _reinforcements_called := false
var _defeated := false


func _ready() -> void:
	_enemy = get_parent() as Node3D
	_config = _resolve_config()
	_stats = _resolve_stats()
	_max_health = _stats.max_health if _stats != null else _config.enemy_max_health
	_health = _max_health
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	tick(delta)


## The FSM remains the owner of alert state.  This component only performs the
## bounded combat action while its parent is in Combat, so perception behavior
## and the #21 EnemyBrain contract remain unchanged.
func tick(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0 or _defeated:
		return
	var step := minf(delta, MAX_DELTA_SECONDS)
	_attack_cooldown_remaining = maxf(_attack_cooldown_remaining - step, 0.0)
	if not _is_in_combat():
		_reinforcements_called = false
		return
	if not _reinforcements_called:
		call_for_help()
	if _target == null or not is_instance_valid(_target):
		_target = _find_player()
	if _target != null:
		attack_target()


func set_target(target: Node) -> bool:
	if _defeated or target == null or not is_instance_valid(target):
		return false
	_target = target
	var brain := _brain()
	if brain != null:
		if brain.alert_state() != Enums.AlertState.COMBAT:
			brain.force_state(Enums.AlertState.COMBAT, &"combat_target")
	return true


func target() -> Node:
	return _target if is_instance_valid(_target) else null


func attack_target() -> bool:
	if _defeated or _attack_cooldown_remaining > 0.0:
		return false
	if _target == null or not is_instance_valid(_target):
		return false
	var range_m := _stats.attack_range_m if _stats != null else _config.enemy_attack_range_m
	if not _target_in_range(_target, range_m):
		return false
	var damage := _stats.attack_power if _stats != null else _config.enemy_attack_power
	var cooldown := (
		_stats.attack_cooldown_seconds
		if _stats != null
		else _config.enemy_attack_cooldown_seconds
	)
	_attack_cooldown_remaining = maxf(cooldown, 0.05)
	attack_started.emit(_target)
	var applied := _apply_damage_to_target(_target, damage)
	if applied > 0:
		attack_hit.emit(_target, applied)
		_emit_event(&"combat_attack", [_enemy if _enemy != null else self, _target, applied])
	return applied > 0


func attack(target: Node = null) -> bool:
	if target != null:
		set_target(target)
	return attack_target()


func receive_damage(amount: int, source: Node = null) -> int:
	if _defeated:
		return 0
	var bounded_amount := clampi(amount, 0, CombatConfig.MAX_DAMAGE)
	if bounded_amount <= 0:
		return 0
	var applied := mini(bounded_amount, _health)
	_health -= applied
	damage_received.emit(applied, _health, source)
	_emit_event(&"enemy_damaged", [_enemy if _enemy != null else self, applied, _health, source])
	var brain := _brain()
	if brain != null:
		if brain.alert_state() != Enums.AlertState.COMBAT:
			brain.force_state(Enums.AlertState.COMBAT, &"combat_damage")
	if _health <= 0:
		_defeated = true
		if _enemy != null and _enemy.has_method(&"set_incapacitated"):
			_enemy.call(&"set_incapacitated", &"dead", 0.0)
		var event_bus := _event_bus()
		if event_bus != null and event_bus.has_signal(&"enemy_killed"):
			event_bus.emit_signal(&"enemy_killed", _enemy, "combat")
		defeated.emit(source)
	return applied


func receive_combat_damage(amount: int, source: Node = null) -> int:
	return receive_damage(amount, source)


func take_damage(amount: int, source: Node = null) -> int:
	return receive_damage(amount, source)


func health() -> int:
	return _health


func current_health() -> int:
	return health()


func max_health() -> int:
	return _max_health


func is_defeated() -> bool:
	return _defeated


func attack_ready() -> bool:
	return not _defeated and _attack_cooldown_remaining <= 0.0


func reinforcement_count() -> int:
	var radius := _stats.reinforcement_radius_m if _stats != null else _config.reinforcement_radius_m
	var limit := _stats.max_reinforcements if _stats != null else _config.max_reinforcements
	return _count_nearby_reinforcements(radius, limit)


## Raise nearby enemies to at least Suspicious using EnemyBrain's bounded
## propagation API.  No new nodes are spawned and the scan is capped.
func call_for_help() -> int:
	if _enemy == null or not is_instance_valid(_enemy):
		return 0
	_reinforcements_called = true
	var radius := _stats.reinforcement_radius_m if _stats != null else _config.reinforcement_radius_m
	var limit := _stats.max_reinforcements if _stats != null else _config.max_reinforcements
	var count := 0
	var examined := 0
	var tree := get_tree()
	if tree == null:
		reinforcements_called.emit(0)
		return 0
	for candidate in tree.get_nodes_in_group(&"enemies"):
		if examined >= MAX_TARGETS_TO_SCAN or count >= limit:
			break
		examined += 1
		if candidate == _enemy or not candidate is Node3D:
			continue
		var candidate_node := candidate as Node3D
		var distance := _enemy.global_position.distance_to(candidate_node.global_position)
		if not is_finite(distance) or distance > radius:
			continue
		var candidate_brain := candidate_node.get_node_or_null(NodePath("Brain")) as EnemyBrain
		if candidate_brain == null or candidate_brain.is_incapacitated():
			continue
		candidate_brain.receive_propagated_alert(_enemy.global_position)
		count += 1
	reinforcements_called.emit(count)
	return count


func reset_combat() -> void:
	_health = _max_health
	_attack_cooldown_remaining = 0.0
	_reinforcements_called = false
	_defeated = false


func _is_in_combat() -> bool:
	var brain := _brain()
	return brain != null and brain.alert_state() == Enums.AlertState.COMBAT


func _find_player() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var examined := 0
	for candidate in tree.get_nodes_in_group(&"player"):
		if examined >= MAX_TARGETS_TO_SCAN:
			break
		examined += 1
		if candidate is Node and is_instance_valid(candidate):
			return candidate
	return null


func _apply_damage_to_target(target: Node, damage: int) -> int:
	var result: Variant
	if target.has_method(&"receive_combat_damage"):
		result = target.call(&"receive_combat_damage", damage, self)
	elif target.has_method(&"receive_damage"):
		result = target.call(&"receive_damage", damage, self)
	else:
		var combat := target.get_node_or_null(NodePath("Combat"))
		if combat == null:
			for candidate in target.get_children():
				if candidate is PlayerCombat:
					combat = candidate
					break
		if combat == null or not combat.has_method(&"receive_damage"):
			return 0
		result = combat.call(&"receive_damage", damage, self)
	if result is bool:
		return damage if result else 0
	return maxi(int(result), 0)


func _target_in_range(target: Node, range_m: float) -> bool:
	if _enemy == null or not target is Node3D:
		return true
	var distance := _enemy.global_position.distance_to((target as Node3D).global_position)
	return is_finite(distance) and distance <= maxf(range_m, 0.1)


func _count_nearby_reinforcements(radius: float, limit: int) -> int:
	if _enemy == null or get_tree() == null:
		return 0
	var count := 0
	var examined := 0
	for candidate in get_tree().get_nodes_in_group(&"enemies"):
		if examined >= MAX_TARGETS_TO_SCAN or count >= limit:
			break
		examined += 1
		if candidate == _enemy or not candidate is Node3D:
			continue
		var distance := _enemy.global_position.distance_to((candidate as Node3D).global_position)
		if is_finite(distance) and distance <= radius:
			count += 1
	return count


func _resolve_config() -> CombatConfig:
	if combat_config != null:
		return combat_config.normalized()
	var tree := get_tree()
	if tree != null and tree.root != null:
		var tuning := tree.root.get_node_or_null(NodePath("Tuning"))
		if tuning != null and tuning.has_method(&"combat"):
			var configured: Variant = tuning.call(&"combat")
			if configured is CombatConfig:
				return (configured as CombatConfig).normalized()
	return CombatConfig.new().normalized()


func _resolve_stats() -> EnemyStats:
	return enemy_stats.normalized() if enemy_stats != null else null


func _brain() -> EnemyBrain:
	return _enemy.get_node_or_null(NodePath("Brain")) as EnemyBrain if _enemy != null else null


func _event_bus() -> Node:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath("EventBus"))


func _emit_event(signal_name: StringName, args: Array) -> void:
	var event_bus := _event_bus()
	if event_bus == null or not event_bus.has_signal(signal_name):
		return
	event_bus.callv(&"emit_signal", [signal_name] + args)
