class_name TargetNpc
extends EnemyBase


## A mission target with a bounded, authored timed routine.
##
## PatrolPath/RoutineStop remain the source of truth for movement and dwell
## timing.  This variant only adds the target role, the escort-separation
## contract, and the one-shot mission event emitted on defeat.

const MIN_ROUTINE_CYCLE_SECONDS := 1.0
const MAX_ROUTINE_CYCLE_SECONDS := 86400.0
const TARGET_KILLED_EVENT := &"target_killed"

signal target_defeated_event(method: StringName)

@export_range(MIN_ROUTINE_CYCLE_SECONDS, MAX_ROUTINE_CYCLE_SECONDS, 1.0) var routine_cycle_seconds := 360.0:
	set(value):
		routine_cycle_seconds = clampf(value, MIN_ROUTINE_CYCLE_SECONDS, MAX_ROUTINE_CYCLE_SECONDS) if is_finite(value) else 360.0
@export var target_routine_enabled := true

var _target_defeat_event_emitted := false
var _last_seen_stop_index := -1
var _last_non_separation_position := Vector3.ZERO
var _escort_anchor_position := Vector3.ZERO
var _separation_active := false


func _ready() -> void:
	super._ready()
	add_to_group(&"target_npcs")
	var enemy_brain := brain()
	if enemy_brain != null:
		enemy_brain.set_routine_type(&"target")
		enemy_brain.set_routine_enabled(target_routine_enabled)
		enemy_brain.set_routine_cycle_seconds(routine_cycle_seconds)
	var event_bus := _target_event_bus()
	if event_bus != null:
		var callback := Callable(self, &"_on_enemy_killed")
		if not event_bus.is_connected(&"enemy_killed", callback):
			event_bus.connect(&"enemy_killed", callback)
	_last_non_separation_position = global_position if global_position.is_finite() else Vector3.ZERO
	_escort_anchor_position = _last_non_separation_position


func _exit_tree() -> void:
	var event_bus := _target_event_bus()
	if event_bus != null:
		var callback := Callable(self, &"_on_enemy_killed")
		if event_bus.is_connected(&"enemy_killed", callback):
			event_bus.disconnect(&"enemy_killed", callback)


func _physics_process(_delta: float) -> void:
	_sync_separation_state()


func set_target_routine_path(path: PatrolPath) -> bool:
	var enemy_brain := brain()
	if enemy_brain == null or not enemy_brain.set_routine_type(&"target"):
		return false
	var applied := enemy_brain.set_routine_path(path)
	if applied:
		_last_seen_stop_index = -1
		_separation_active = false
		_last_non_separation_position = global_position if global_position.is_finite() else Vector3.ZERO
	return applied


func target_routine_path() -> PatrolPath:
	return patrol_path()


func set_target_routine_enabled(value: bool) -> void:
	target_routine_enabled = value
	var enemy_brain := brain()
	if enemy_brain != null:
		enemy_brain.set_routine_enabled(value)


func is_target_routine_enabled() -> bool:
	var enemy_brain := brain()
	return target_routine_enabled and enemy_brain != null and enemy_brain.routine_enabled()


func set_routine_cycle_seconds(value: float) -> bool:
	if not is_finite(value) or value < MIN_ROUTINE_CYCLE_SECONDS:
		return false
	var bounded := minf(value, MAX_ROUTINE_CYCLE_SECONDS)
	var enemy_brain := brain()
	if enemy_brain == null or not enemy_brain.set_routine_cycle_seconds(bounded):
		return false
	routine_cycle_seconds = bounded
	return true


func target_routine_cycle_seconds() -> float:
	return routine_cycle_seconds


func target_routine_clock() -> float:
	var enemy_brain := brain()
	if enemy_brain == null:
		return 0.0
	return enemy_brain.routine_clock()


func target_routine_cycle_elapsed() -> float:
	var cycle := target_routine_cycle_seconds()
	return fmod(target_routine_clock(), cycle) if cycle > 0.0 else 0.0


func target_routine_stop() -> RoutineStop:
	return current_routine_stop()


func target_routine_stop_index() -> int:
	var enemy_brain := brain()
	return enemy_brain.current_routine_stop_index() if enemy_brain != null else -1


func target_routine_stop_elapsed() -> float:
	var enemy_brain := brain()
	return enemy_brain.routine_stop_elapsed() if enemy_brain != null else 0.0


func routine_action() -> StringName:
	var stop := target_routine_stop()
	return stop.routine_action if stop != null else &"stand"


func is_escort_separated() -> bool:
	return _separation_active


func escort_anchor_position() -> Vector3:
	if _separation_active and _escort_anchor_position.is_finite():
		return _escort_anchor_position
	return global_position if global_position.is_finite() else Vector3.ZERO


func target_defeat_event_emitted() -> bool:
	return _target_defeat_event_emitted


func is_target_defeated() -> bool:
	return _target_defeat_event_emitted or is_defeated()


## Preserve EnemyBase's bool API while making every death path converge on the
## same one-shot target_killed mission event.
func set_incapacitated(kind: StringName, duration_seconds: float = 0.0) -> bool:
	var applied := super.set_incapacitated(kind, duration_seconds)
	if applied and kind == &"dead" and not is_assassinating():
		notify_target_defeated(&"combat")
	return applied


func notify_target_defeated(method: StringName = &"unknown") -> bool:
	if _target_defeat_event_emitted or method.is_empty():
		return false
	_target_defeat_event_emitted = true
	var event_bus := _target_event_bus()
	if event_bus != null and event_bus.has_signal(&"mission_event"):
		event_bus.emit_signal(
			&"mission_event",
			TARGET_KILLED_EVENT,
			{"target": self, "method": method},
		)
	target_defeated_event.emit(method)
	return true


func _on_enemy_killed(enemy: Node, method: String) -> void:
	if enemy != self:
		return
	notify_target_defeated(StringName(method))


func _sync_separation_state() -> void:
	if not is_inside_tree():
		return
	var stop := target_routine_stop()
	var index := target_routine_stop_index()
	if stop == null:
		_separation_active = false
		_last_seen_stop_index = index
		return
	if index != _last_seen_stop_index:
		if _is_separation_action(stop.routine_action):
			_escort_anchor_position = (
				_last_non_separation_position
				if _last_non_separation_position.is_finite()
				else global_position
			)
			_separation_active = _escort_anchor_position.is_finite()
		else:
			_separation_active = false
			var authored_position := stop.target_position()
			if authored_position.is_finite():
				_last_non_separation_position = authored_position
			elif global_position.is_finite():
				_last_non_separation_position = global_position
		_last_seen_stop_index = index
	elif not _is_separation_action(stop.routine_action) and global_position.is_finite():
		_last_non_separation_position = global_position


static func _is_separation_action(action: StringName) -> bool:
	var normalized := String(action).to_lower().strip_edges().replace("-", "_").replace(" ", "_")
	return normalized in ["separate", "separate_escort", "escort_separation", "toilet"]


func _target_event_bus() -> Node:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath("EventBus"))
