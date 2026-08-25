class_name PerceptionStimulus
extends RefCounted


var kind: Enums.StimulusKind
var priority: int
var position: Vector3
var confidence: float
var anomaly: Anomaly


static func create(
	stimulus_kind: Enums.StimulusKind,
	stimulus_priority: int,
	stimulus_position: Vector3,
	stimulus_confidence: float,
	stimulus_anomaly: Anomaly = null,
) -> PerceptionStimulus:
	var stimulus := PerceptionStimulus.new()
	stimulus.kind = stimulus_kind
	stimulus.priority = clampi(stimulus_priority, 1, 5)
	stimulus.position = stimulus_position if _valid_vector(stimulus_position) else Vector3.ZERO
	stimulus.confidence = (
		clampf(stimulus_confidence, 0.0, 1.0)
		if is_finite(stimulus_confidence)
		else 0.0
	)
	stimulus.anomaly = stimulus_anomaly
	return stimulus


static func _valid_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
