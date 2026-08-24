class_name NoiseEvent
extends RefCounted


var position: Vector3
var radius: float
var kind: Enums.NoiseKind
var source: Node


static func create(event_position: Vector3, event_radius: float, event_kind: Enums.NoiseKind, event_source: Node) -> NoiseEvent:
	var event := NoiseEvent.new()
	event.position = event_position
	event.radius = event_radius
	event.kind = event_kind
	event.source = event_source
	return event
