class_name EnemyBase
extends CharacterBody3D


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


func hearing_position() -> Vector3:
	var perception := get_node_or_null(NodePath("Perception")) as EnemyPerception
	if perception != null:
		var eye := perception.get_node_or_null(NodePath("EyePoint")) as Node3D
		if eye != null:
			return eye.global_position
	return global_position
