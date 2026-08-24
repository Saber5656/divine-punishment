class_name PlayerCameraRig
extends Node3D


@export_range(-89.0, 0.0, 1.0) var pitch_min_degrees: float = -75.0
@export_range(0.0, 89.0, 1.0) var pitch_max_degrees: float = 75.0
@export var max_peek_offset: Vector3 = Vector3(0.75, 0.3, 0.0)

var _camera_config: CameraConfig
var _base_position: Vector3
var _pitch: float


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
	var bounded_offset := Vector3(
		_clamp_offset_component(requested_offset.x, max_peek_offset.x),
		_clamp_offset_component(requested_offset.y, max_peek_offset.y),
		_clamp_offset_component(requested_offset.z, max_peek_offset.z),
	)
	position = _base_position + bounded_offset


func reset_peek_offset() -> void:
	position = _base_position


func peek_offset() -> Vector3:
	return position - _base_position


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


static func _clamp_offset_component(value: float, limit: float) -> float:
	if not is_finite(value) or not is_finite(limit):
		return 0.0
	var absolute_limit := absf(limit)
	return clampf(value, -absolute_limit, absolute_limit)
