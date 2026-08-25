class_name EnemyBrain
extends Node


var _stimulus_buffer: Array[PerceptionStimulus] = []


func _physics_process(delta: float) -> void:
	# Brain owns the update driver; EnemyPerception applies the 10 Hz / LOD gate.
	var perception := get_parent().get_node_or_null(NodePath("Perception")) as EnemyPerception
	if perception != null:
		perception.tick(delta)


func submit_stimulus(stim: PerceptionStimulus) -> void:
	if stim != null:
		_stimulus_buffer.append(stim)


func drain_stimuli() -> Array[PerceptionStimulus]:
	var result := _stimulus_buffer
	_stimulus_buffer = []
	return result
