class_name EnemyBrain
extends Node


var _stimulus_buffer: Array[PerceptionStimulus] = []


func submit_stimulus(stim: PerceptionStimulus) -> void:
	if stim != null:
		_stimulus_buffer.append(stim)


func drain_stimuli() -> Array[PerceptionStimulus]:
	var result := _stimulus_buffer
	_stimulus_buffer = []
	return result
