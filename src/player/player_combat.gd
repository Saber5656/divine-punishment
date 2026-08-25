class_name PlayerCombat
extends Node


signal attack_started(combo_index: int)
signal attack_hit(combo_index: int, target: Node, damage: int)
signal attack_finished(combo_index: int)
signal parry_started()
signal parry_successful(attacker: Node)
signal dodge_started(direction: Vector3)
signal damage_received(amount: int, remaining_health: int, source: Node)
signal health_changed(current_health: int, max_health: int)
signal defeated()

const MAX_DELTA_SECONDS := 10.0
const MAX_TARGETS_TO_SCAN := 64
const STATE_MACHINE_PATH := NodePath("StateMachine")

@export var combat_config: CombatConfig

var _config: CombatConfig
var _player: Node3D
var _health := 3
var _max_health := 3
var _combo_index := 0
var _combo_window_remaining := 0.0
var _attack_elapsed := -1.0
var _attack_recovery_remaining := 0.0
var _attack_hit_targets: Dictionary = {}
var _parry_remaining := 0.0
var _parry_cooldown_remaining := 0.0
var _dodge_remaining := 0.0
var _dodge_cooldown_remaining := 0.0
var _dodge_direction := Vector3.ZERO
var _hit_invulnerability_remaining := 0.0
var _defeated := false


func _ready() -> void:
	_player = get_parent() as Node3D
	_config = _resolve_config()
	_initialize_health()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	tick(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"attack"):
		attack()
	elif event.is_action_pressed(&"parry"):
		start_parry()
	elif event.is_action_pressed(&"dodge"):
		var direction := Input.get_vector(
			&"move_left",
			&"move_right",
			&"move_forward",
			&"move_backward",
		)
		start_dodge(Vector3(direction.x, 0.0, direction.y))


## Advance combat timers without requiring a SceneTree, for deterministic tests.
func tick(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0:
		return
	var step := minf(delta, MAX_DELTA_SECONDS)
	_combo_window_remaining = maxf(_combo_window_remaining - step, 0.0)
	_attack_recovery_remaining = maxf(_attack_recovery_remaining - step, 0.0)
	_parry_remaining = maxf(_parry_remaining - step, 0.0)
	_parry_cooldown_remaining = maxf(_parry_cooldown_remaining - step, 0.0)
	_dodge_cooldown_remaining = maxf(_dodge_cooldown_remaining - step, 0.0)
	_hit_invulnerability_remaining = maxf(_hit_invulnerability_remaining - step, 0.0)
	if _combo_window_remaining <= 0.0 and _attack_elapsed < 0.0 and _attack_recovery_remaining <= 0.0:
		_combo_index = 0
	_advance_attack(step)
	_advance_dodge(step)


func start_attack() -> bool:
	if _defeated or _attack_elapsed >= 0.0 or _attack_recovery_remaining > 0.0:
		return false
	if not _ensure_combat_state():
		return false
	var next_index := 1
	if _combo_index > 0 and _combo_window_remaining > 0.0:
		next_index = mini(_combo_index + 1, CombatConfig.MAX_COMBO_HITS)
	if _combo_index >= CombatConfig.MAX_COMBO_HITS:
		next_index = 1
	_combo_index = next_index
	_attack_elapsed = 0.0
	_attack_recovery_remaining = 0.0
	_attack_hit_targets.clear()
	_combo_window_remaining = _config.combo_window_seconds
	attack_started.emit(_combo_index)
	return true


## Convenience API for input and simple callers: starts a slash and resolves it
## once its startup window is reached.
func attack(target: Node = null) -> bool:
	if not start_attack():
		return false
	if _config.attack_startup_seconds > 0.0:
		tick(_config.attack_startup_seconds)
	if target == null:
		target = _nearest_enemy()
	return resolve_attack(target)


func queue_attack() -> bool:
	return start_attack()


func resolve_attack(target: Node) -> bool:
	if not is_attack_active() or target == null or not is_instance_valid(target):
		return false
	if target == self or target == _player:
		return false
	if not _target_in_range(target, _config.attack_range_m):
		return false
	var target_id := target.get_instance_id()
	if _attack_hit_targets.has(target_id):
		return false
	var damage := _config.damage_for_combo(_combo_index)
	var applied := _apply_damage_to_target(target, damage)
	if not applied:
		return false
	_attack_hit_targets[target_id] = true
	attack_hit.emit(_combo_index, target, damage)
	_emit_event(&"combat_attack", [_player if _player != null else self, target, damage])
	return true


func strike(target: Node) -> bool:
	return resolve_attack(target)


func is_attack_active() -> bool:
	if _attack_elapsed < 0.0:
		return false
	var active_start := _config.attack_startup_seconds
	var active_end := active_start + _config.attack_active_seconds
	return _attack_elapsed >= active_start and _attack_elapsed < active_end


func can_chain_attack() -> bool:
	return (
		_attack_elapsed < 0.0
		and _combo_index > 0
		and _combo_index < CombatConfig.MAX_COMBO_HITS
		and _combo_window_remaining > 0.0
	)


func combo_index() -> int:
	return _combo_index


func combo_step() -> int:
	return combo_index()


func start_parry() -> bool:
	if _defeated or _parry_remaining > 0.0 or _parry_cooldown_remaining > 0.0:
		return false
	if not _ensure_combat_state():
		return false
	_parry_remaining = _config.parry_window_seconds
	_parry_cooldown_remaining = _config.parry_cooldown_seconds
	parry_started.emit()
	return true


func parry() -> bool:
	return start_parry()


func is_parrying() -> bool:
	return _parry_remaining > 0.0


func start_dodge(direction: Vector3 = Vector3.ZERO) -> bool:
	if _defeated or _dodge_remaining > 0.0 or _dodge_cooldown_remaining > 0.0:
		return false
	if not _ensure_combat_state():
		return false
	var chosen := direction
	if not _valid_horizontal_vector(chosen):
		chosen = _default_dodge_direction()
	if not _valid_horizontal_vector(chosen):
		return false
	_dodge_direction = Vector3(chosen.x, 0.0, chosen.z).normalized()
	_dodge_remaining = _config.dodge_invulnerability_seconds
	_dodge_cooldown_remaining = _config.dodge_cooldown_seconds
	dodge_started.emit(_dodge_direction)
	return true


func dodge(direction: Vector3 = Vector3.ZERO) -> bool:
	return start_dodge(direction)


func is_dodging() -> bool:
	return _dodge_remaining > 0.0


func is_invulnerable() -> bool:
	return is_parrying() or is_dodging()


func receive_damage(amount: int, source: Node = null) -> int:
	if _defeated:
		return 0
	var bounded_amount := clampi(amount, 0, CombatConfig.MAX_DAMAGE)
	if bounded_amount <= 0:
		return 0
	if is_parrying():
		parry_successful.emit(source)
		_emit_event(&"combat_parried", [_player if _player != null else self, source])
		return 0
	if is_dodging():
		_emit_event(&"combat_dodged", [_player if _player != null else self, source])
		return 0
	if _hit_invulnerability_remaining > 0.0:
		return 0
	_ensure_combat_state()
	var applied := mini(bounded_amount, _health)
	_health -= applied
	_hit_invulnerability_remaining = _config.hit_invulnerability_seconds
	damage_received.emit(applied, _health, source)
	health_changed.emit(_health, _max_health)
	_emit_event(&"player_damaged", [_player if _player != null else self, applied, _health, source])
	if _health <= 0:
		_defeated = true
		var state_machine := _state_machine()
		if state_machine != null and state_machine.has_method(&"change_state"):
			state_machine.call(&"change_state", &"Dead")
		defeated.emit()
		_emit_event(&"player_defeated", [_player if _player != null else self])
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


func reset_combat() -> void:
	_health = _max_health
	_combo_index = 0
	_combo_window_remaining = 0.0
	_attack_elapsed = -1.0
	_attack_recovery_remaining = 0.0
	_attack_hit_targets.clear()
	_parry_remaining = 0.0
	_parry_cooldown_remaining = 0.0
	_dodge_remaining = 0.0
	_dodge_cooldown_remaining = 0.0
	_hit_invulnerability_remaining = 0.0
	_defeated = false
	health_changed.emit(_health, _max_health)


func _advance_attack(delta: float) -> void:
	if _attack_elapsed < 0.0:
		return
	_attack_elapsed += delta
	var end := _config.attack_startup_seconds + _config.attack_active_seconds
	if _attack_elapsed < end:
		return
	var finished_index := _combo_index
	_attack_elapsed = -1.0
	_attack_recovery_remaining = _config.attack_recovery_seconds
	attack_finished.emit(finished_index)


func _advance_dodge(delta: float) -> void:
	if _dodge_remaining <= 0.0:
		return
	var duration := maxf(_config.dodge_invulnerability_seconds, 0.001)
	var movement := _config.dodge_distance_m * minf(delta, _dodge_remaining) / duration
	_dodge_remaining = maxf(_dodge_remaining - delta, 0.0)
	if movement <= 0.0 or _player == null:
		return
	if _player is CharacterBody3D and _player.is_inside_tree():
		(_player as CharacterBody3D).move_and_collide(_dodge_direction * movement)
	elif _player is Node3D:
		(_player as Node3D).global_position += _dodge_direction * movement


func _initialize_health() -> void:
	_max_health = _config.player_max_health
	if _player is PlayerController:
		var profile := (_player as PlayerController).player_profile
		if profile != null and profile.max_health > 0:
			_max_health = clampi(profile.max_health, 1, CombatConfig.MAX_HEALTH)
	_health = _max_health


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


func _ensure_combat_state() -> bool:
	var state_machine := _state_machine()
	if state_machine == null:
		return true
	if state_machine.has_method(&"is_dead") and state_machine.call(&"is_dead"):
		return false
	if state_machine.has_method(&"current_state") and state_machine.call(&"current_state") != &"Combat":
		if not state_machine.call(&"change_state", &"Combat"):
			return false
	return true


func _state_machine() -> Node:
	return _player.get_node_or_null(STATE_MACHINE_PATH) if _player != null else null


func _nearest_enemy() -> Node:
	if get_tree() == null:
		return null
	var nearest: Node = null
	var nearest_distance := _config.attack_range_m
	var examined := 0
	for candidate in get_tree().get_nodes_in_group(&"enemies"):
		if examined >= MAX_TARGETS_TO_SCAN:
			break
		examined += 1
		if candidate == _player or not is_instance_valid(candidate):
			continue
		if candidate.has_method(&"is_defeated") and candidate.call(&"is_defeated"):
			continue
		if not _target_in_range(candidate, nearest_distance):
			continue
		var distance := _distance_to(candidate)
		if distance <= nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest


func _apply_damage_to_target(target: Node, damage: int) -> bool:
	if target.has_method(&"receive_combat_damage"):
		return _damage_result(target.call(&"receive_combat_damage", damage, self))
	if target.has_method(&"receive_damage"):
		return _damage_result(target.call(&"receive_damage", damage, self))
	var combat := target.get_node_or_null(NodePath("Combat"))
	if combat == null:
		for candidate in target.get_children():
			if candidate is EnemyCombat:
				combat = candidate
				break
	if combat != null and combat != self and combat.has_method(&"receive_damage"):
		return _damage_result(combat.call(&"receive_damage", damage, self))
	return false


func _damage_result(result: Variant) -> bool:
	if result is bool:
		return result
	return int(result) > 0


func _target_in_range(target: Node, range_m: float) -> bool:
	if not target is Node3D or _player == null:
		return true
	var distance := _distance_to(target)
	return is_finite(distance) and distance <= maxf(range_m, 0.1)


func _distance_to(target: Node) -> float:
	if _player == null or not target is Node3D:
		return 0.0
	return _player.global_position.distance_to((target as Node3D).global_position)


func _default_dodge_direction() -> Vector3:
	if _player == null:
		return Vector3.ZERO
	var forward := -_player.global_transform.basis.z
	return Vector3(forward.x, 0.0, forward.z)


func _valid_horizontal_vector(value: Vector3) -> bool:
	return (
		is_finite(value.x)
		and is_finite(value.y)
		and is_finite(value.z)
		and Vector2(value.x, value.z).length_squared() > 0.000001
	)


func _emit_event(signal_name: StringName, args: Array) -> void:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	var event_bus := tree.root.get_node_or_null(NodePath("EventBus"))
	if event_bus != null and event_bus.has_signal(signal_name):
		event_bus.callv(&"emit_signal", [signal_name] + args)
