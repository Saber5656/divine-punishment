@tool
class_name CheckpointArea
extends Area3D


@export var checkpoint_id: StringName = &"checkpoint"


func _ready() -> void:
	collision_layer = 1 << 14
	collision_mask = 1 << 1
	add_to_group(&"checkpoint_areas")
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body is PlayerController:
		return
	var flow := body.get_node_or_null("RetryFlow") as PlayerRetryFlow
	if flow != null:
		flow.capture_checkpoint(checkpoint_id)
