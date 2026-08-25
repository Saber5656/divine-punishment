class_name TrajectoryDisplay
extends Node3D


## Lightweight line-strip display used while aiming a projectile.
const MAX_POINTS := 128

@export var line_color := Color(0.94, 0.76, 0.28, 0.9)
@export_range(0.005, 0.2, 0.005) var line_width := 0.025

var _points := PackedVector3Array()
var _line_mesh: MeshInstance3D
var _material: StandardMaterial3D


func _ready() -> void:
	_ensure_mesh()
	visible = false


func set_points(points: PackedVector3Array) -> void:
	_points = _bounded_points(points)
	visible = _points.size() >= 2
	_rebuild_mesh()


func points() -> PackedVector3Array:
	return _points


func trajectory_points() -> PackedVector3Array:
	return points()


func set_trajectory(origin: Vector3, velocity: Vector3, gravity: float, duration: float, sample_count: int = 24) -> void:
	if not origin.is_finite() or not velocity.is_finite() or not is_finite(gravity) or not is_finite(duration):
		clear()
		return
	var safe_duration := clampf(duration, 0.05, 10.0)
	var count := clampi(sample_count, 2, MAX_POINTS)
	var samples := PackedVector3Array()
	for index in count:
		var t := safe_duration * float(index) / float(count - 1)
		var point := origin + velocity * t + Vector3.DOWN * (0.5 * gravity * t * t)
		if not point.is_finite():
			break
		samples.append(point)
	set_points(samples)


func clear() -> void:
	_points = PackedVector3Array()
	visible = false
	_rebuild_mesh()


func _ensure_mesh() -> void:
	if _line_mesh == null:
		_line_mesh = MeshInstance3D.new()
		_line_mesh.name = "TrajectoryLine"
		add_child(_line_mesh)
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material.albedo_color = line_color


func _rebuild_mesh() -> void:
	_ensure_mesh()
	if _points.size() < 2:
		_line_mesh.mesh = null
		return
	var immediate := ImmediateMesh.new()
	immediate.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, _material)
	for point in _points:
		immediate.surface_add_vertex(point)
	immediate.surface_end()
	_line_mesh.mesh = immediate
	_line_mesh.visible = visible


func _bounded_points(points: PackedVector3Array) -> PackedVector3Array:
	var bounded := PackedVector3Array()
	for point in points:
		if bounded.size() >= MAX_POINTS:
			break
		if point.is_finite():
			bounded.append(point)
	return bounded
