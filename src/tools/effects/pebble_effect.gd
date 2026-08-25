class_name PebbleTool
extends ToolBase


const MAX_NOISE_RADIUS := 6.0


func _apply_effect(hit: Dictionary) -> void:
	var definition := tool_definition
	if definition == null:
		return
	var radius := clampf(definition.parameter_float(&"radius", MAX_NOISE_RADIUS), 0.0, MAX_NOISE_RADIUS)
	if radius <= 0.0:
		return
	var max_range := clampf(
		definition.parameter_float(&"max_range", MAX_IMPACT_DISTANCE),
		0.1,
		MAX_IMPACT_DISTANCE,
	)
	var impact := _impact_position(hit, max_range)
	if not impact.is_finite():
		return
	var source := hit.get(&"user") as Node
	if source == null:
		source = self
	var tree: SceneTree = null
	if source.is_inside_tree():
		tree = source.get_tree()
	elif is_inside_tree():
		tree = get_tree()
	NoiseEventSystem.emit(
		NoiseEvent.create(impact, radius, Enums.NoiseKind.TOOL, source),
		tree,
	)
	if is_inside_tree():
		queue_free()
