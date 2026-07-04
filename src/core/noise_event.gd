class_name NoiseEvent
extends RefCounted


var position: Vector3
var radius: float
var kind: int
var source: Node


static func create(event_position: Vector3, event_radius: float, event_kind: int, event_source: Node) -> RefCounted:
	var script: GDScript = load("res://src/core/noise_event.gd")
	var event: RefCounted = script.new()
	event.position = event_position
	event.radius = event_radius
	event.kind = event_kind
	event.source = event_source
	return event
