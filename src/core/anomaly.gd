class_name Anomaly
extends RefCounted


var kind: int
var position: Vector3
var node: Node3D
var severity: int
var expires_at: float
var seen_by: Dictionary = {}


static func create(anomaly_kind: int, anomaly_position: Vector3, anomaly_node: Node3D, anomaly_severity: int, anomaly_expires_at: float = 0.0) -> RefCounted:
	var script: GDScript = load("res://src/core/anomaly.gd")
	var anomaly: RefCounted = script.new()
	anomaly.kind = anomaly_kind
	anomaly.position = anomaly_position
	anomaly.node = anomaly_node
	anomaly.severity = anomaly_severity
	anomaly.expires_at = anomaly_expires_at
	return anomaly
