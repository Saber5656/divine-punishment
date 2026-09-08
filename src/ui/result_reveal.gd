class_name ResultReveal
extends Node

## Rank remains real text throughout; the animation never blocks navigation.
const DURATION := 0.9
var _label: Label
var _elapsed := 0.0

func start(label: Label) -> void:
	_label = label
	_elapsed = 0.0
	process_mode = Node.PROCESS_MODE_ALWAYS
	advance(0.0)
	AudioDirector.play_stinger(&"result")

func advance(delta: float) -> void:
	if not is_instance_valid(_label) or not is_finite(delta) or delta < 0.0: return
	_elapsed = minf(_elapsed + delta, DURATION)
	var t := _elapsed / DURATION
	var ease := 1.0 - pow(1.0 - t, 3.0)
	_label.modulate = Color(1.0, 1.0, 1.0, ease)
	_label.pivot_offset = _label.size * 0.5
	_label.scale = Vector2.ONE * lerpf(1.12, 1.0, ease)
	if _elapsed == DURATION: set_process(false)

func _process(delta: float) -> void:
	advance(delta)
