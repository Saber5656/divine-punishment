class_name PlayerController
extends CharacterBody3D


@export var player_profile: PlayerProfile
@export_range(0.7, 1.8, 0.05) var crouch_capsule_height: float = 1.1
@export_range(0.0001, 0.02, 0.0001) var mouse_look_sensitivity: float = 0.0025
@export_range(0.1, 10.0, 0.1) var gamepad_look_speed: float = 2.5
@export_range(-89.0, 0.0, 1.0) var camera_pitch_min: float = -75.0
@export_range(0.0, 89.0, 1.0) var camera_pitch_max: float = 75.0

@onready var state_machine: PlayerStateMachine = $StateMachine as PlayerStateMachine
@onready var collision_shape: CollisionShape3D = $CollisionShape3D as CollisionShape3D
@onready var camera_rig: Node3D = $CameraRig as Node3D

var _standing_capsule_height: float
var _standing_collision_transform: Transform3D
var _camera_pitch: float


func _ready() -> void:
	if player_profile != null:
		state_machine.player_profile = player_profile

	_initialize_collision_shape()
	if not state_machine.state_changed.is_connected(_on_state_changed):
		state_machine.state_changed.connect(_on_state_changed)
	_apply_collision_shape_for_state(state_machine.current_state())
	_camera_pitch = camera_rig.rotation.x


func _process(delta: float) -> void:
	var gamepad_look := Input.get_vector(&"camera_left", &"camera_right", &"camera_up", &"camera_down")
	if gamepad_look.length_squared() > 0.0:
		_apply_camera_look(gamepad_look * gamepad_look_speed * delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		_apply_camera_look(mouse_motion.screen_relative * mouse_look_sensitivity)


func _physics_process(delta: float) -> void:
	_update_state_from_input()
	_apply_gravity(delta)
	_apply_movement()
	move_and_slide()


func current_movement_params() -> Dictionary:
	return state_machine.movement_params()


func _update_state_from_input() -> void:
	if not Input.is_action_pressed(&"sprint") and state_machine.current_state() == PlayerStateMachine.STATE_SPRINT:
		state_machine.resume_from_sprint()

	if Input.is_action_just_pressed(&"stance_toggle"):
		match state_machine.current_state():
			PlayerStateMachine.STATE_GROUND:
				state_machine.change_state(PlayerStateMachine.STATE_CROUCH)
			PlayerStateMachine.STATE_CROUCH:
				_try_enter_standing_state(PlayerStateMachine.STATE_GROUND)

	if Input.is_action_pressed(&"sprint"):
		if state_machine.current_state() == PlayerStateMachine.STATE_CROUCH:
			_try_enter_standing_state(PlayerStateMachine.STATE_SPRINT)
		else:
			state_machine.change_state(PlayerStateMachine.STATE_SPRINT)


func _try_enter_standing_state(next_state: StringName) -> bool:
	if not _has_standing_clearance():
		return false
	return state_machine.change_state(next_state)


func _initialize_collision_shape() -> void:
	var capsule := collision_shape.shape as CapsuleShape3D
	if capsule == null:
		return
	collision_shape.shape = capsule.duplicate() as CapsuleShape3D
	_standing_capsule_height = capsule.height
	_standing_collision_transform = collision_shape.transform


func _on_state_changed(_from: StringName, to: StringName) -> void:
	_apply_collision_shape_for_state(to)


func _apply_collision_shape_for_state(state: StringName) -> void:
	var capsule := collision_shape.shape as CapsuleShape3D
	if capsule == null or _standing_capsule_height <= 0.0:
		return

	collision_shape.transform = _standing_collision_transform
	if state != PlayerStateMachine.STATE_CROUCH:
		capsule.height = _standing_capsule_height
		return

	var minimum_height := capsule.radius * 2.0
	var resolved_crouch_height := clampf(crouch_capsule_height, minimum_height, _standing_capsule_height)
	capsule.height = resolved_crouch_height
	collision_shape.position.y -= (_standing_capsule_height - resolved_crouch_height) * 0.5


func _has_standing_clearance() -> bool:
	var capsule := collision_shape.shape as CapsuleShape3D
	if capsule == null or _standing_capsule_height <= 0.0:
		return true
	if is_equal_approx(capsule.height, _standing_capsule_height):
		return true

	var standing_capsule := capsule.duplicate() as CapsuleShape3D
	standing_capsule.height = _standing_capsule_height
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = standing_capsule
	query.transform = global_transform * _standing_collision_transform
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.margin = 0.001
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _apply_camera_look(look_delta: Vector2) -> void:
	rotate_y(-look_delta.x)
	_camera_pitch = clampf(
		_camera_pitch - look_delta.y,
		deg_to_rad(camera_pitch_min),
		deg_to_rad(camera_pitch_max),
	)
	camera_rig.rotation.x = _camera_pitch


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
		return
	velocity += get_gravity() * delta


func _apply_movement() -> void:
	var input_vector := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_backward")
	var local_direction := Vector3(input_vector.x, 0.0, input_vector.y)
	var world_direction := transform.basis * local_direction
	world_direction.y = 0.0
	if world_direction.length_squared() > 0.0:
		world_direction = world_direction.normalized() * input_vector.length()

	var speed := float(state_machine.movement_params().get(&"speed", 0.0))
	velocity.x = world_direction.x * speed
	velocity.z = world_direction.z * speed
