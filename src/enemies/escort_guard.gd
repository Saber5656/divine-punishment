class_name EscortGuard
extends EnemyBase


## A bounded escort follower for TargetNpc.
##
## The guard never teleports or moves without a synchronized navigation map.
## It follows the target while UNAWARE and switches to COMBAT immediately when
## the target's one-shot defeat event is observed.

const MAX_FOLLOW_OFFSET := 10.0
const MAX_FOLLOW_SPEED := 12.0
const DEFAULT_FOLLOW_SPEED := 2.0
const MAX_TARGET_CANDIDATES := 64

@export_node_path("Node3D") var target_path: NodePath
@export var follow_offset := Vector3(-1.5, 0.0, 0.0):
	set(value):
		follow_offset = value if _valid_offset(value) else Vector3(-1.5, 0.0, 0.0)
@export var separation_offset := Vector3(0.0, 0.0, 2.0):
	set(value):
		separation_offset = value if _valid_offset(value) else Vector3(0.0, 0.0, 2.0)
@export_range(0.1, MAX_FOLLOW_SPEED, 0.1) var follow_speed := DEFAULT_FOLLOW_SPEED:
	set(value):
		follow_speed = clampf(value, 0.1, MAX_FOLLOW_SPEED) if is_finite(value) else DEFAULT_FOLLOW_SPEED

var _escort_target: TargetNpc
var _target_defeated := false


func _ready() -> void:
	super._ready()
	add_to_group(&"escort_guards")
	var enemy_brain := brain()
	if enemy_brain != null:
		enemy_brain.set_routine_type(&"escort")
		enemy_brain.set_routine_enabled(false)
	_resolve_escort_target()
	var event_bus := _escort_event_bus()
	if event_bus != null:
		var callback := Callable(self, &"_on_enemy_killed")
		if not event_bus.is_connected(&"enemy_killed", callback):
			event_bus.connect(&"enemy_killed", callback)


func _exit_tree() -> void:
	_unbind_target_signal()
	var event_bus := _escort_event_bus()
	if event_bus != null:
		var callback := Callable(self, &"_on_enemy_killed")
		if event_bus.is_connected(&"enemy_killed", callback):
			event_bus.disconnect(&"enemy_killed", callback)


func _physics_process(delta: float) -> void:
	var target := escort_target()
	if target == null:
		velocity = Vector3.ZERO
		return
	if target.is_target_defeated():
		_enter_target_combat()
		return
	var enemy_brain := brain()
	if enemy_brain == null or enemy_brain.alert_state() != Enums.AlertState.UNAWARE:
		return
	var desired := desired_escort_position()
	if not desired.is_finite():
		velocity = Vector3.ZERO
		return
	advance_navigation(delta, desired, follow_speed)
	face_routine_direction(desired - global_position, delta)


func set_escort_target(target: TargetNpc) -> bool:
	if target != null and (
		not is_instance_valid(target)
		or not target is TargetNpc
		or not target.is_inside_tree()
		or target.get_tree() != get_tree()
		or not target.global_position.is_finite()
	):
		return false
	_bind_target(target)
	return true


func escort_target() -> TargetNpc:
	if (
		_escort_target != null
		and is_instance_valid(_escort_target)
		and _escort_target.is_inside_tree()
		and _escort_target.get_tree() == get_tree()
		and _escort_target.global_position.is_finite()
	):
		return _escort_target
	_unbind_target_signal()
	_resolve_escort_target()
	return _escort_target if (
		_escort_target != null
		and is_instance_valid(_escort_target)
		and _escort_target.is_inside_tree()
		and _escort_target.get_tree() == get_tree()
		and _escort_target.global_position.is_finite()
	) else null


func desired_escort_position() -> Vector3:
	var target := escort_target()
	if target == null:
		return global_position if global_position.is_finite() else Vector3.ZERO
	var anchor := target.escort_anchor_position() if target.is_escort_separated() else target.global_position
	var offset := separation_offset if target.is_escort_separated() else follow_offset
	var desired := anchor + offset
	return desired if desired.is_finite() else (global_position if global_position.is_finite() else Vector3.ZERO)


func is_separated() -> bool:
	var target := escort_target()
	return target != null and target.is_escort_separated()


func target_defeated() -> bool:
	return _target_defeated or (escort_target() != null and escort_target().is_target_defeated())


func _resolve_escort_target() -> void:
	var candidate: TargetNpc = null
	if target_path != NodePath():
		candidate = get_node_or_null(target_path) as TargetNpc
	if candidate == null:
		var tree := get_tree()
		if tree != null:
			var candidates := tree.get_nodes_in_group(&"target_npcs")
			var candidate_count := mini(candidates.size(), MAX_TARGET_CANDIDATES)
			for candidate_index in candidate_count:
				var node: Node = candidates[candidate_index]
				if node is TargetNpc and is_instance_valid(node):
					var target := node as TargetNpc
					if target.is_inside_tree() and target.get_tree() == get_tree() and target.global_position.is_finite():
						candidate = target
						break
	_bind_target(candidate)


func _bind_target(target: TargetNpc) -> void:
	if target != null and (
		not is_instance_valid(target)
		or not target.is_inside_tree()
		or target.get_tree() != get_tree()
		or not target.global_position.is_finite()
	):
		return
	if _escort_target == target:
		return
	_unbind_target_signal()
	_escort_target = target
	if _escort_target != null and is_instance_valid(_escort_target):
		var callback := Callable(self, &"_on_target_defeated_event")
		if not _escort_target.is_connected(&"target_defeated_event", callback):
			_escort_target.connect(&"target_defeated_event", callback)


func _unbind_target_signal() -> void:
	if _escort_target == null or not is_instance_valid(_escort_target):
		_escort_target = null
		return
	var callback := Callable(self, &"_on_target_defeated_event")
	if _escort_target.is_connected(&"target_defeated_event", callback):
		_escort_target.disconnect(&"target_defeated_event", callback)


func _on_target_defeated_event(_method: StringName) -> void:
	_enter_target_combat()


func _on_enemy_killed(enemy: Node, _method: String) -> void:
	if enemy != null and enemy == escort_target():
		_enter_target_combat()


func _enter_target_combat() -> void:
	_target_defeated = true
	velocity = Vector3.ZERO
	var enemy_brain := brain()
	if enemy_brain != null and enemy_brain.alert_state() != Enums.AlertState.COMBAT:
		enemy_brain.force_state(Enums.AlertState.COMBAT, &"target_defeated")


static func _valid_offset(value: Vector3) -> bool:
	return value.is_finite() and value.length() <= MAX_FOLLOW_OFFSET


func _escort_event_bus() -> Node:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath("EventBus"))
