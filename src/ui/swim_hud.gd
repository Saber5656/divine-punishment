class_name SwimHud
extends CanvasLayer


@onready var breath_gauge: ProgressBar = $BreathPanel/BreathGauge as ProgressBar
@onready var ripple_cue: Control = $RippleCue as Control


func _ready() -> void:
	set_underwater(false, 0.0, 1.0)


func set_underwater(active: bool, remaining: float, capacity: float) -> void:
	var safe_capacity := capacity if is_finite(capacity) and capacity > 0.0 else 1.0
	var safe_remaining := remaining if is_finite(remaining) else 0.0
	breath_gauge.max_value = safe_capacity
	breath_gauge.value = clampf(safe_remaining, 0.0, safe_capacity)
	visible = active


func is_breath_gauge_visible() -> bool:
	return visible and breath_gauge.visible


func is_ripple_cue_visible() -> bool:
	return visible and ripple_cue.visible


func breath_ratio() -> float:
	if breath_gauge.max_value <= 0.0:
		return 0.0
	return float(breath_gauge.value / breath_gauge.max_value)
