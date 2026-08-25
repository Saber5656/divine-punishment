class_name EnemyBase
extends CharacterBody3D


func _ready() -> void:
	add_to_group(&"enemies")


func on_noise(event: NoiseEvent) -> void:
	var perception := get_node_or_null(NodePath("Perception")) as EnemyPerception
	if perception != null:
		perception.on_noise(event)


func hearing_position() -> Vector3:
	var perception := get_node_or_null(NodePath("Perception")) as EnemyPerception
	if perception != null:
		var eye := perception.get_node_or_null(NodePath("EyePoint")) as Node3D
		if eye != null:
			return eye.global_position
	return global_position
