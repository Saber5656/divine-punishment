class_name NoiseRippleCue
extends Control


## One-beat HUD cue for noise emitted by the local player.
const PULSE_DURATION := 0.45
const INNER_RADIUS := 34.0
const OUTER_RADIUS := 88.0
const LINE_WIDTH := 3.0
const RIPPLE_COLOR := Color(0.63, 0.19, 0.15, 0.9)

var _age := PULSE_DURATION
var _pulse_count := 0
var _last_kind: Enums.NoiseKind = Enums.NoiseKind.FOOTSTEP


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(true)


func pulse(event: NoiseEvent = null) -> void:
	_age = 0.0
	_pulse_count += 1
	if event != null:
		_last_kind = event.kind
	visible = true
	queue_redraw()


func is_pulsing() -> bool:
	return _age < PULSE_DURATION


func pulse_count() -> int:
	return _pulse_count


func last_kind() -> Enums.NoiseKind:
	return _last_kind


func _process(delta: float) -> void:
	if not visible:
		return
	_age += maxf(delta, 0.0)
	if _age >= PULSE_DURATION:
		_age = PULSE_DURATION
		visible = false
	queue_redraw()


func _draw() -> void:
	if not is_pulsing():
		return
	var center := size * 0.5
	var progress := clampf(_age / PULSE_DURATION, 0.0, 1.0)
	var radius := lerpf(INNER_RADIUS, OUTER_RADIUS, progress)
	var alpha := 1.0 - progress
	var color := RIPPLE_COLOR
	color.a = RIPPLE_COLOR.a * alpha
	draw_arc(center, radius, 0.0, TAU, 64, color, LINE_WIDTH, true)
