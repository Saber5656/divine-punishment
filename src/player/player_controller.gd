class_name PlayerController
extends CharacterBody3D


const WallClingRules := preload("res://src/player/player_wall_cling.gd")
const ClimbRules := preload("res://src/player/player_climb.gd")
const WORLD_COLLISION_MASK := 1
const MIN_WALL_PROBE_DISTANCE := 0.1
const MAX_WALL_PROBE_DISTANCE := 2.0
const MIN_WALL_PROBE_HEIGHT := 0.0
const MAX_WALL_PROBE_HEIGHT := 2.0
const MAX_CLIMB_EDGE_CANDIDATES := 64
const TRAVERSAL_ENDPOINT_EPSILON := 0.001


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
var _active_climb_edge: ClimbEdge
var _active_beam_path: BeamPath
var _traversal_distance := 0.0
var _beam_axis_direction := 1.0


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
	if _is_traversing():
		advance_traversal(Input.get_axis(&"move_backward", &"move_forward"), delta)
		return
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


func active_climb_edge() -> ClimbEdge:
	return _active_climb_edge if is_instance_valid(_active_climb_edge) else null


func active_beam_path() -> BeamPath:
	return _active_beam_path if is_instance_valid(_active_beam_path) else null


func traversal_distance() -> float:
	return _traversal_distance


func try_enter_climb(edge: ClimbEdge = null) -> bool:
	var current := state_machine.current_state()
	if (
		current != PlayerStateMachine.STATE_GROUND
		and current != PlayerStateMachine.STATE_CROUCH
		and current != PlayerStateMachine.STATE_WALL_CLING
	):
		return false
	if current == PlayerStateMachine.STATE_CROUCH and not _has_standing_clearance():
		return false

	var candidate := edge if edge != null else _nearest_climb_edge()
	if (
		candidate == null
		or not is_instance_valid(candidate)
		or not candidate.can_accept_body(self)
		or not candidate.is_near_bottom(global_position)
	):
		return false
	return _enter_climb_at_distance(candidate, candidate.nearest_distance(global_position))


func try_descend_from_beam() -> bool:
	if state_machine.current_state() != PlayerStateMachine.STATE_BEAM:
		return false
	var beam := active_beam_path()
	if beam == null or not beam.can_accept_body(self):
		_leave_traversal()
		return false
	var edge := beam.descent_edge_for_distance(_traversal_distance)
	if edge != null:
		return _enter_climb_at_distance(edge, edge.span_length())
	return false


func drop_from_beam() -> bool:
	if state_machine.current_state() != PlayerStateMachine.STATE_BEAM:
		return false
	_leave_traversal()
	return true


func advance_traversal(axis: float, delta: float) -> void:
	match state_machine.current_state():
		PlayerStateMachine.STATE_CLIMB:
			_advance_climb(axis, delta)
		PlayerStateMachine.STATE_BEAM:
			_advance_beam(axis, delta)


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

	if interact_just_pressed and try_enter_climb():
		return

	if state_machine.current_state() == PlayerStateMachine.STATE_CLIMB:
		return

	if state_machine.current_state() == PlayerStateMachine.STATE_BEAM:
		if Input.is_action_pressed(&"sprint"):
			drop_from_beam()
			return
		if interact_just_pressed:
			try_descend_from_beam()
		return

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
	if to != PlayerStateMachine.STATE_CLIMB:
		_active_climb_edge = null
	if to != PlayerStateMachine.STATE_BEAM:
		_active_beam_path = null
		_beam_axis_direction = 1.0
	if to != PlayerStateMachine.STATE_CLIMB and to != PlayerStateMachine.STATE_BEAM:
		_traversal_distance = 0.0
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
	if _is_traversing():
		velocity = Vector3.ZERO
		return
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
		return
	velocity += get_gravity() * delta


func _apply_movement() -> void:
	if _is_traversing():
		velocity = Vector3.ZERO
		return
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


func _is_traversing() -> bool:
	return (
		state_machine.current_state() == PlayerStateMachine.STATE_CLIMB
		or state_machine.current_state() == PlayerStateMachine.STATE_BEAM
	)


func _enter_climb_at_distance(edge: ClimbEdge, distance: float) -> bool:
	if edge == null or not is_instance_valid(edge) or not edge.can_accept_body(self):
		return false
	_active_climb_edge = edge
	_active_beam_path = null
	_traversal_distance = ClimbRules.bounded_distance(distance, edge.span_length())
	var destination := edge.world_position_at_distance(_traversal_distance)
	if not ClimbRules.is_safe_world_position(destination):
		_active_climb_edge = null
		_traversal_distance = 0.0
		return false
	velocity = Vector3.ZERO
	if not state_machine.change_state(PlayerStateMachine.STATE_CLIMB):
		_active_climb_edge = null
		_traversal_distance = 0.0
		return false
	global_position = destination
	return true


func _enter_beam(path: BeamPath, distance: float) -> bool:
	return _enter_beam_with_sample(path, distance, {})


func _enter_beam_with_sample(path: BeamPath, distance: float, supplied_sample: Dictionary) -> bool:
	if path == null or not is_instance_valid(path) or not path.can_accept_body(self):
		return false
	_active_beam_path = path
	_active_climb_edge = null
	_traversal_distance = ClimbRules.bounded_distance(distance, path.path_length())
	_beam_axis_direction = (
		-1.0
		if path.path_length() - _traversal_distance <= TRAVERSAL_ENDPOINT_EPSILON
		else 1.0
	)
	var destination_sample := supplied_sample
	if not bool(destination_sample.get(&"valid", false)):
		destination_sample = path.world_sample_at_distance(_traversal_distance)
	if not bool(destination_sample.get(&"valid", false)):
		_active_beam_path = null
		_traversal_distance = 0.0
		_beam_axis_direction = 1.0
		return false
	var destination: Vector3 = destination_sample[&"position"]
	if not ClimbRules.is_safe_world_position(destination):
		_active_beam_path = null
		_traversal_distance = 0.0
		_beam_axis_direction = 1.0
		return false
	velocity = Vector3.ZERO
	if not state_machine.change_state(PlayerStateMachine.STATE_BEAM):
		_active_beam_path = null
		_traversal_distance = 0.0
		_beam_axis_direction = 1.0
		return false
	global_position = destination
	return true


func _advance_climb(axis: float, delta: float) -> void:
	var edge := active_climb_edge()
	if edge == null or not edge.can_accept_body(self):
		_leave_traversal()
		return
	var span := edge.span_length()
	var sanitized_axis := ClimbRules.sanitize_axis(axis)
	var speed := float(state_machine.movement_params().get(&"speed", 0.0))
	_traversal_distance = ClimbRules.advance_distance(
		_traversal_distance,
		sanitized_axis,
		speed,
		delta,
		span,
	)
	var destination := edge.world_position_at_distance(_traversal_distance)
	if not ClimbRules.is_safe_world_position(destination):
		_leave_traversal()
		return
	global_position = destination
	velocity = Vector3.ZERO
	if sanitized_axis > 0.0 and span - _traversal_distance <= TRAVERSAL_ENDPOINT_EPSILON:
		var connection := edge.connected_beam_connection()
		var connected := connection.get(&"path") as BeamPath
		if (
			bool(connection.get(&"valid", false))
			and connected != null
			and _enter_beam_with_sample(
				connected,
				float(connection[&"distance"]),
				{&"valid": true, &"position": connection[&"position"]},
			)
		):
			return
		_leave_traversal()
	elif sanitized_axis < 0.0 and _traversal_distance <= TRAVERSAL_ENDPOINT_EPSILON:
		_leave_traversal()


func _advance_beam(axis: float, delta: float) -> void:
	var path := active_beam_path()
	if path == null or not path.can_accept_body(self):
		_leave_traversal()
		return
	var speed := float(state_machine.movement_params().get(&"speed", 0.0))
	var next_distance := ClimbRules.advance_distance(
		_traversal_distance,
		axis * _beam_axis_direction,
		speed,
		delta,
		path.path_length(),
	)
	var destination_sample := path.world_sample_at_distance(next_distance)
	if not bool(destination_sample.get(&"valid", false)):
		_leave_traversal()
		return
	var destination: Vector3 = destination_sample[&"position"]
	if not ClimbRules.is_safe_world_position(destination):
		_leave_traversal()
		return
	_traversal_distance = next_distance
	global_position = destination
	velocity = Vector3.ZERO


func _leave_traversal() -> void:
	state_machine.change_state(PlayerStateMachine.STATE_GROUND)
	_active_climb_edge = null
	_active_beam_path = null
	_traversal_distance = 0.0
	_beam_axis_direction = 1.0
	velocity = Vector3.ZERO


func _nearest_climb_edge() -> ClimbEdge:
	if not is_inside_tree():
		return null
	var candidates := get_tree().get_nodes_in_group(&"climb_edges")
	if candidates.size() > MAX_CLIMB_EDGE_CANDIDATES:
		return null
	var nearest: ClimbEdge
	var nearest_distance_squared := INF
	for candidate: Node in candidates:
		if candidate is not ClimbEdge:
			continue
		var edge := candidate as ClimbEdge
		if not edge.can_accept_body(self) or not edge.is_near_bottom(global_position):
			continue
		var distance_squared := global_position.distance_squared_to(edge.bottom_world_position())
		if distance_squared < nearest_distance_squared:
			nearest = edge
			nearest_distance_squared = distance_squared
	return nearest


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
