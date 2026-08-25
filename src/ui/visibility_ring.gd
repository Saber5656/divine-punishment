class_name VisibilityRing
extends Control


## HUD ring for the player's current visibility value (V).
##
## The gameplay value is kept separate from the rendered value so the ring
## eases to a new value over the same 0.1 second cadence as PlayerVisibility.
const INTERPOLATION_SECONDS := 0.1
const MIN_RING_RADIUS := 28.0
const RING_WIDTH := 4.0
const INK_COLOR := Color(0.10, 0.10, 0.10, 0.96)
const PAPER_COLOR := Color(0.92, 0.90, 0.82, 0.88)
const ACCENT_COLOR := Color(0.63, 0.19, 0.15, 0.9)

var _target_visibility := 0.0
var _display_visibility := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	var step := delta / INTERPOLATION_SECONDS
	_display_visibility = move_toward(_display_visibility, _target_visibility, step)
	queue_redraw()


func set_visibility(value: float) -> void:
	_target_visibility = _safe_visibility(value)
	if not is_inside_tree():
		_display_visibility = _target_visibility
	queue_redraw()


func set_value(value: float) -> void:
	set_visibility(value)


func visibility() -> float:
	return _target_visibility


func value() -> float:
	return visibility()


func displayed_visibility() -> float:
	return _display_visibility


func is_open() -> bool:
	return _target_visibility > 0.0


func _draw() -> void:
	var center := size * 0.5
	var radius := maxf(MIN_RING_RADIUS, minf(size.x, size.y) * 0.5 - RING_WIDTH)
	# A quiet paper-coloured base keeps the open ring legible on dark scenes.
	draw_arc(center, radius, 0.0, TAU, 96, PAPER_COLOR, RING_WIDTH, true)
	var ink_coverage := 1.0 - _display_visibility
	if ink_coverage > 0.001:
		draw_arc(
			center,
			radius,
			-PI * 0.5,
			-PI * 0.5 + TAU * ink_coverage,
			96,
			INK_COLOR,
			RING_WIDTH,
			true,
		)
	# A small vermilion marker communicates that V is changing without adding
	# a numeric meter to the minimal HUD.
	if _display_visibility > 0.001 and _display_visibility < 0.999:
		var marker_angle := -PI * 0.5 + TAU * _display_visibility
		var marker := center + Vector2(cos(marker_angle), sin(marker_angle)) * radius
		draw_circle(marker, RING_WIDTH * 0.8, ACCENT_COLOR)


static func _safe_visibility(value: float) -> float:
	return clampf(value, 0.0, 1.0) if is_finite(value) else 0.0
