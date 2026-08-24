class_name PlayerController
extends CharacterBody3D


const WallClingRules := preload("res://src/player/player_wall_cling.gd")
const WORLD_COLLISION_MASK := 1
const MIN_WALL_PROBE_DISTANCE := 0.1
const MAX_WALL_PROBE_DISTANCE := 2.0
const MIN_WALL_PROBE_HEIGHT := 0.0
const MAX_WALL_PROBE_HEIGHT := 2.0


@export var player_profile: PlayerProfile
@export_range(0.7, 1.8, 0.05) var crouch_capsule_height: float = 1.1
@export_range(0.1, 2.0, 0.05) var wall_probe_distance: float = 0.75
@export_range(0.0, 2.0, 0.05) var wall_probe_height: float = 0.5

@onready var state_machine: PlayerStateMachine = $StateMachine as PlayerStateMachine
@onready var collision_shape: CollisionShape3D = $CollisionShape3D as CollisionShape3D
@onready var camera_rig: PlayerCameraRig = $CameraRig as PlayerCameraRig

var _standing_capsule_height: float
var _standing_collision_transform: Transform3D
var _wall_normal: Vector3 = Vector3.ZERO
var _interact_was_pressed: bool = false


func _ready() -> void:
	if player_profile != null:
		state_machine.player_profile = player_profile

	_initialize_collision_shape()
	if not state_machine.state_changed.is_connected(_on_state_changed):
		state_machine.state_changed.connect(_on_state_changed)
	_apply_collision_shape_for_state(state_machine.current_state())


func _process(delta: float) -> void:
	var gamepad_look := Input.get_vector(&"camera_left", &"camera_right", &"camera_up", &"camera_down")
	if gamepad_look.length_squared() > 0.0:
		rotate_y(camera_rig.apply_gamepad_look(gamepad_look, delta))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		rotate_y(camera_rig.apply_mouse_look(mouse_motion.screen_relative))


func _physics_process(delta: float) -> void:
	_update_state_from_input()
	_apply_gravity(delta)
	_apply_movement()
	move_and_slide()


func current_movement_params() -> Dictionary:
	return state_machine.movement_params()


func set_camera_peek_offset(offset: Vector3) -> void:
	camera_rig.set_peek_offset(offset)


func reset_camera_peek_offset() -> void:
	camera_rig.reset_peek_offset()


func camera_peek_offset() -> Vector3:
	return camera_rig.peek_offset()


func wall_cling_normal() -> Vector3:
	return _wall_normal


func try_enter_wall_cling() -> bool:
	var current := state_machine.current_state()
	if current != PlayerStateMachine.STATE_GROUND and current != PlayerStateMachine.STATE_CROUCH:
		return false

	var detected_normal := _find_wall_normal()
	if detected_normal == Vector3.ZERO:
		return false
	if current == PlayerStateMachine.STATE_CROUCH and not _has_standing_clearance():
		return false

	_wall_normal = detected_normal
	if state_machine.change_state(PlayerStateMachine.STATE_WALL_CLING):
		return true
	_wall_normal = Vector3.ZERO
	return false


func _update_state_from_input() -> void:
	var interact_pressed := Input.is_action_pressed(&"interact")
	var interact_just_pressed := interact_pressed and not _interact_was_pressed
	_interact_was_pressed = interact_pressed

	if state_machine.current_state() == PlayerStateMachine.STATE_WALL_CLING:
		if Input.is_action_pressed(&"sprint"):
			state_machine.change_state(PlayerStateMachine.STATE_GROUND)
			return
		if not _refresh_wall_cling():
			state_machine.change_state(PlayerStateMachine.STATE_GROUND)
			return
		_update_wall_cling_peek()
		return

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

	if interact_just_pressed:
		try_enter_wall_cling()


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


func _on_state_changed(from: StringName, to: StringName) -> void:
	if from == PlayerStateMachine.STATE_WALL_CLING and to != PlayerStateMachine.STATE_WALL_CLING:
		_wall_normal = Vector3.ZERO
		reset_camera_peek_offset()
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


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
		return
	velocity += get_gravity() * delta


func _apply_movement() -> void:
	var wall_clinging := state_machine.current_state() == PlayerStateMachine.STATE_WALL_CLING
	var world_direction := Vector3.ZERO
	if wall_clinging:
		var longitudinal_axis := Input.get_axis(&"move_forward", &"move_backward")
		world_direction = WallClingRules.wall_tangent(_wall_normal) * WallClingRules.sanitize_axis(longitudinal_axis)
		world_direction = WallClingRules.project_movement(world_direction, _wall_normal)
	else:
		var input_vector := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_backward")
		var local_direction := Vector3(input_vector.x, 0.0, input_vector.y)
		world_direction = transform.basis * local_direction
		world_direction.y = 0.0
		if world_direction.length_squared() > 0.0:
			world_direction = world_direction.normalized() * input_vector.length()

	var speed := float(state_machine.movement_params().get(&"speed", 0.0))
	velocity.x = world_direction.x * speed
	velocity.z = world_direction.z * speed


func _refresh_wall_cling() -> bool:
	var detected_normal := _find_wall_normal(_wall_normal)
	if detected_normal == Vector3.ZERO:
		return false
	_wall_normal = detected_normal
	return true


func _update_wall_cling_peek() -> void:
	if not Input.is_action_pressed(&"peek"):
		reset_camera_peek_offset()
		return
	var peek_axis := WallClingRules.sanitize_axis(Input.get_axis(&"move_left", &"move_right"))
	var horizontal_limit := absf(camera_rig.max_peek_offset.x)
	set_camera_peek_offset(Vector3(peek_axis * horizontal_limit, 0.0, 0.0))


func _find_wall_normal(preferred_normal: Vector3 = Vector3.ZERO) -> Vector3:
	if not is_inside_tree() or get_world_3d() == null:
		return Vector3.ZERO
	if (
		not is_finite(wall_probe_distance)
		or wall_probe_distance < MIN_WALL_PROBE_DISTANCE
		or wall_probe_distance > MAX_WALL_PROBE_DISTANCE
	):
		return Vector3.ZERO
	if (
		not is_finite(wall_probe_height)
		or wall_probe_height < MIN_WALL_PROBE_HEIGHT
		or wall_probe_height > MAX_WALL_PROBE_HEIGHT
	):
		return Vector3.ZERO

	var origin := global_position + Vector3.UP * wall_probe_height
	if not _is_finite_vector(origin):
		return Vector3.ZERO
	var normalized_preference := WallClingRules.normalized_wall_normal(preferred_normal)
	if normalized_preference != Vector3.ZERO:
		var preferred_hit := _cast_wall_probe(origin, -normalized_preference)
		if not preferred_hit.is_empty():
			var retained_normal: Vector3 = preferred_hit[&"normal"]
			return retained_normal

	var directions: Array[Vector3] = []
	for index: int in 8:
		var angle := TAU * float(index) / 8.0
		var local_direction := Vector3(cos(angle), 0.0, sin(angle))
		var world_direction := global_transform.basis * local_direction
		world_direction.y = 0.0
		if world_direction.length_squared() > WallClingRules.NORMAL_EPSILON_SQUARED:
			directions.append(world_direction.normalized())

	var closest_distance_squared := INF
	var closest_normal := Vector3.ZERO
	for direction: Vector3 in directions:
		var hit := _cast_wall_probe(origin, direction)
		if hit.is_empty():
			continue
		var candidate: Vector3 = hit[&"normal"]
		var distance_squared := float(hit[&"distance_squared"])
		if distance_squared < closest_distance_squared:
			closest_distance_squared = distance_squared
			closest_normal = candidate
	return closest_normal


func _cast_wall_probe(origin: Vector3, direction: Vector3) -> Dictionary:
	if not _is_finite_vector(origin) or not _is_finite_vector(direction):
		return {}
	if direction.length_squared() <= WallClingRules.NORMAL_EPSILON_SQUARED:
		return {}
	var normalized_direction := direction.normalized()
	var endpoint := origin + normalized_direction * wall_probe_distance
	if not _is_finite_vector(endpoint):
		return {}
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		endpoint,
		WORLD_COLLISION_MASK,
		[get_rid()],
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}

	var candidate := WallClingRules.normalized_wall_normal(hit.get(&"normal", Vector3.ZERO))
	if candidate == Vector3.ZERO:
		return {}
	var hit_position: Vector3 = hit.get(&"position", endpoint)
	return {
		&"normal": candidate,
		&"distance_squared": origin.distance_squared_to(hit_position),
	}


func _is_finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
