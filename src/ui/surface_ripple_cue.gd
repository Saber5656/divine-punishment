class_name SurfaceRippleCue
extends Control


const RIPPLE_COLOR := Color(0.45, 0.85, 1.0, 0.8)
const RIPPLE_RADII := [42.0, 68.0, 96.0]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	for radius: float in RIPPLE_RADII:
		draw_arc(center, radius, 0.0, TAU, 64, RIPPLE_COLOR, 2.0, true)
