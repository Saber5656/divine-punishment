class_name PlayerCameraRig
extends Node3D


@export_range(-89.0, 0.0, 1.0) var pitch_min_degrees: float = -75.0
@export_range(0.0, 89.0, 1.0) var pitch_max_degrees: float = 75.0
@export var max_peek_offset: Vector3 = Vector3(0.75, 0.3, 0.0)
@export_range(0.0, 1.4, 0.05) var max_posture_drop: float = 1.1

var _camera_config: CameraConfig
var _base_position: Vector3
var _pitch: float
var _peek_offset := Vector3.ZERO
var _posture_drop := 0.0
var _assassination_context: StringName = &""
var _assassination_progress := 0.0


func _ready() -> void:
	_base_position = position
	_pitch = rotation.x
	_refresh_camera_config()
	if not Tuning.reloaded.is_connected(_refresh_camera_config):
		Tuning.reloaded.connect(_refresh_camera_config)


func apply_mouse_look(screen_relative: Vector2) -> float:
	if _camera_config == null:
		return 0.0
	return _apply_look(screen_relative * _camera_config.mouse_look_sensitivity)


func apply_gamepad_look(input_vector: Vector2, delta: float) -> float:
	if _camera_config == null:
		return 0.0
	return _apply_look(input_vector * _camera_config.gamepad_look_speed * delta)


func set_peek_offset(requested_offset: Vector3) -> void:
	_peek_offset = Vector3(
		_clamp_offset_component(requested_offset.x, max_peek_offset.x),
		_clamp_offset_component(requested_offset.y, max_peek_offset.y),
		_clamp_offset_component(requested_offset.z, max_peek_offset.z),
	)
	_sync_position()


func reset_peek_offset() -> void:
	_peek_offset = Vector3.ZERO
	_sync_position()


func peek_offset() -> Vector3:
	return _peek_offset


func set_posture_drop(requested_drop: float) -> void:
	_posture_drop = PlayerCrawlRules.bounded_posture_drop(requested_drop, max_posture_drop)
	_sync_position()


func reset_posture_drop() -> void:
	_posture_drop = 0.0
	_sync_position()


func posture_drop() -> float:
	return _posture_drop


## Presentation hook.  The offset is intentionally small and returns to zero
## at both ends of the blend, so missing animation assets cannot leave the
## gameplay camera displaced.
func begin_assassination_blend(context: StringName, _duration_sec: float) -> bool:
	if context not in [&"back", &"above", &"below", &"corner"]:
		return false
	_assassination_context = context
	_assassination_progress = 0.0
	_sync_position()
	return true


func set_assassination_progress(progress: float) -> void:
	if _assassination_context == &"" or not is_finite(progress):
		return
	_assassination_progress = clampf(progress, 0.0, 1.0)
	_sync_position()


func end_assassination_blend() -> void:
	_assassination_context = &""
	_assassination_progress = 0.0
	_sync_position()


func assassination_context() -> StringName:
	return _assassination_context


func assassination_progress() -> float:
	return _assassination_progress


func camera_config() -> CameraConfig:
	return _camera_config


func _apply_look(scaled_look: Vector2) -> float:
	if not is_finite(scaled_look.x) or not is_finite(scaled_look.y):
		return 0.0
	_pitch = clampf(
		_pitch - scaled_look.y,
		deg_to_rad(pitch_min_degrees),
		deg_to_rad(pitch_max_degrees),
	)
	rotation.x = _pitch
	return -scaled_look.x


func _refresh_camera_config() -> void:
	_camera_config = Tuning.camera()


func _sync_position() -> void:
	position = _base_position + _peek_offset - Vector3.UP * _posture_drop + _assassination_offset()


func _assassination_offset() -> Vector3:
	if _assassination_context == &"" or not is_finite(_assassination_progress):
		return Vector3.ZERO
	var envelope := sin(_assassination_progress * PI)
	var direction := Vector3.ZERO
	match _assassination_context:
		&"back":
			direction = Vector3(0.0, 0.05, 0.12)
		&"above":
			direction = Vector3(0.0, -0.06, 0.04)
		&"below":
			direction = Vector3(0.0, 0.08, -0.08)
		&"corner":
			direction = Vector3(0.08, 0.04, 0.06)
	return direction * envelope


static func _clamp_offset_component(value: float, limit: float) -> float:
	if not is_finite(value) or not is_finite(limit):
		return 0.0
	var absolute_limit := absf(limit)
	return clampf(value, -absolute_limit, absolute_limit)
