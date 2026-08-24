@tool
class_name LightSource
extends Node3D


@export_range(0.1, 100.0, 0.1) var gameplay_radius: float = 6.0
@export_range(0.0, 10.0, 0.05) var gameplay_intensity: float = 1.0
@export var render_light: Light3D
@export var starts_extinguished: bool = false

var _is_on := true


func _ready() -> void:
	add_to_group("lights")
	if render_light == null:
		render_light = _find_render_light()
	_is_on = not starts_extinguished
	_sync_render_light()


func is_on() -> bool:
	return _is_on


func set_extinguished(extinguished: bool) -> void:
	if _is_on == (not extinguished):
		return
	_is_on = not extinguished
	_sync_render_light()
	if not is_inside_tree() or not has_node("/root/EventBus"):
		return
	if _is_on:
		EventBus.light_relit.emit(self)
	else:
		EventBus.light_extinguished.emit(self)


func gameplay_contribution(distance: float, occluded: bool) -> float:
	if not _is_on:
		return 0.0
	return PlayerVisibility.light_contribution(distance, gameplay_radius, occluded) * gameplay_intensity


func _find_render_light() -> Light3D:
	for child in get_children():
		if child is Light3D:
			return child as Light3D
	return null


func _sync_render_light() -> void:
	if render_light != null:
		render_light.visible = _is_on
