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
	stimulus.priority = stimulus_priority
	stimulus.position = stimulus_position
	stimulus.confidence = clampf(stimulus_confidence, 0.0, 1.0)
	stimulus.anomaly = stimulus_anomaly
	return stimulus
