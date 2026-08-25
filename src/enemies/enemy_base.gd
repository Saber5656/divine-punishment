class_name EnemyBase
extends CharacterBody3D


var _assassination_locked := false
var _assassinated := false
var _assassination_context: StringName = &""


func _ready() -> void:
	add_to_group(&"enemies")


func on_noise(event: NoiseEvent) -> void:
	var perception := get_node_or_null(NodePath("Perception")) as EnemyPerception
	if perception != null:
		perception.on_noise(event)


func on_anomaly(anomaly: Anomaly) -> void:
	var perception := get_node_or_null(NodePath("Perception")) as EnemyPerception
	if perception != null:
		perception.on_anomaly(anomaly)


func brain() -> EnemyBrain:
	return get_node_or_null(NodePath("Brain")) as EnemyBrain


func alert_state() -> Enums.AlertState:
	var enemy_brain := brain()
	return enemy_brain.alert_state() if enemy_brain != null else Enums.AlertState.UNAWARE


func set_incapacitated(kind: StringName, duration_seconds: float = 0.0) -> bool:
	var enemy_brain := brain()
	return enemy_brain != null and enemy_brain.set_incapacitated(kind, duration_seconds)


func set_incapacitation_wake_by_noise(value: bool) -> void:
	var enemy_brain := brain()
	if enemy_brain != null:
		enemy_brain.set_incapacitation_wake_by_noise(value)


func can_be_assassinated() -> bool:
	var enemy_brain := brain()
	return (
		not _assassination_locked
		and not _assassinated
		and enemy_brain != null
		and not enemy_brain.is_incapacitated()
		and enemy_brain.incapacitated_kind() != &"dead"
		and alert_state() != Enums.AlertState.COMBAT
	)


## Lock and resolve a deterministic assassination.  Animation/camera systems
## can use the exposed context and state while the target is already dead to
## prevent duplicate confirmation inputs or a second kill.
func begin_assassination(context: StringName) -> bool:
	if context not in [&"back", &"above", &"below", &"corner"] or not can_be_assassinated():
		return false
	var enemy_brain := brain()
	if enemy_brain == null or not enemy_brain.set_incapacitated(&"dead"):
		return false
	_assassination_locked = true
	_assassinated = true
	_assassination_context = context
	var event_bus := get_node_or_null(NodePath("/root/EventBus"))
	if event_bus != null and event_bus.has_signal(&"enemy_killed"):
		event_bus.emit_signal(&"enemy_killed", self, "assassination")
	return true


func is_assassinating() -> bool:
	return _assassination_locked


func assassination_state() -> StringName:
	return &"Assassinate" if _assassination_locked else &""


func is_assassinated() -> bool:
	return _assassinated


func assassination_context() -> StringName:
	return _assassination_context


func hearing_position() -> Vector3:
	var perception := get_node_or_null(NodePath("Perception")) as EnemyPerception
	if perception != null:
		var eye := perception.get_node_or_null(NodePath("EyePoint")) as Node3D
		if eye != null:
			return eye.global_position
	return global_position
