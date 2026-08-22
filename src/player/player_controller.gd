class_name PlayerController
extends CharacterBody3D


const WallClingRules := preload("res://src/player/player_wall_cling.gd")
const ClimbRules := preload("res://src/player/player_climb.gd")
const CrawlRules := preload("res://src/player/player_crawl.gd")
const WORLD_COLLISION_MASK := 1
const MIN_WALL_PROBE_DISTANCE := 0.1
const MAX_WALL_PROBE_DISTANCE := 2.0
const MIN_WALL_PROBE_HEIGHT := 0.0
const MAX_WALL_PROBE_HEIGHT := 2.0
const MAX_CLIMB_EDGE_CANDIDATES := 64
const MAX_CLIMB_EDGE_SPATIAL_RESULTS := 256
const MAX_CRAWL_ENTRANCE_CANDIDATES := 64
const MAX_CRAWL_ENTRANCE_SPATIAL_RESULTS := 256
const TRAVERSAL_ENDPOINT_EPSILON := 0.001
const MAX_CRAWL_SWEEP_DISTANCE := (
	CrawlEntrance.MAX_PASSAGE_LENGTH + CrawlEntrance.MAX_ENTRY_RADIUS
)
const CRAWL_MOTION_SAFE_FRACTION := 0.9999


@export var player_profile: PlayerProfile
@export_range(0.7, 1.8, 0.05) var crouch_capsule_height: float = 1.1
@export_range(0.7, 1.1, 0.05) var crawl_capsule_height: float = 0.7
@export_range(0.0, 1.1, 0.05) var crawl_camera_drop: float = 0.9
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
var _active_crawl_entrance: CrawlEntrance
var _crawl_contract_outside_position := Vector3.ZERO
var _crawl_contract_inside_position := Vector3.ZERO
var _crawl_contract_transform := Transform3D.IDENTITY
var _crawl_contract_entry_radius := 0.0
var _crawl_contract_capsule_height := 0.0
var _crawl_contract_camera_drop := 0.0
var _crawl_contract_valid := false
var _crawl_contract_invalidated := false
var _traversal_distance := 0.0
var _beam_axis_direction := 1.0


func _ready() -> void:
	if player_profile != null:
		state_machine.player_profile = player_profile

	_initialize_collision_shape()
	if not state_machine.state_changed.is_connected(_on_state_changed):
		state_machine.state_changed.connect(_on_state_changed)
	_apply_collision_shape_for_state(state_machine.current_state())
	_apply_camera_posture_for_state(state_machine.current_state())


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


func active_crawl_entrance() -> CrawlEntrance:
	return _active_crawl_entrance if is_instance_valid(_active_crawl_entrance) else null


func traversal_distance() -> float:
	return _traversal_distance


func try_enter_crawlspace(entrance: CrawlEntrance = null) -> bool:
	var current := state_machine.current_state()
	if current != PlayerStateMachine.STATE_GROUND and current != PlayerStateMachine.STATE_CROUCH:
		return false
	if not _is_crawl_configuration_valid():
		return false
	var candidate := entrance if entrance != null else _nearest_crawl_entrance(true)
	if (
		candidate == null
		or not is_instance_valid(candidate)
		or not candidate.can_accept_body(self)
		or not candidate.is_near_outside(global_position)
	):
		return false
	var source := global_position
	var destination := candidate.inside_world_position()
	if (
		not CrawlRules.is_safe_world_position(source)
		or not CrawlRules.is_safe_world_position(destination)
		or not _has_capsule_clearance_at(crawl_capsule_height, source)
		or not _has_capsule_path_clear(crawl_capsule_height, source, destination)
		or not _has_capsule_clearance_at(crawl_capsule_height, destination)
	):
		return false
	var source_velocity := velocity
	_capture_crawl_contract(candidate)
	velocity = Vector3.ZERO
	if not state_machine.change_state(PlayerStateMachine.STATE_CRAWLSPACE):
		_clear_crawl_contract()
		velocity = source_velocity
		return false
	global_position = destination
	return true


func try_exit_crawlspace(entrance: CrawlEntrance = null) -> bool:
	if state_machine.current_state() != PlayerStateMachine.STATE_CRAWLSPACE:
		return false
	if (
		not _maintain_crawlspace_contract()
		or state_machine.current_state() != PlayerStateMachine.STATE_CRAWLSPACE
	):
		return false
	var candidate := entrance if entrance != null else _nearest_crawl_entrance(false)
	if (
		candidate == null
		or not is_instance_valid(candidate)
		or not candidate.can_accept_body(self)
		or not candidate.is_near_inside(global_position)
	):
		return false
	var source := global_position
	var destination := candidate.outside_world_position()
	if (
		not CrawlRules.is_safe_world_position(source)
		or not CrawlRules.is_safe_world_position(destination)
		or not _has_capsule_clearance_at(crawl_capsule_height, source)
		or not _has_capsule_path_clear(crawl_capsule_height, source, destination)
		or not _has_capsule_clearance_at(crawl_capsule_height, destination)
		or not _has_capsule_clearance_at(crouch_capsule_height, destination)
	):
		return false
	var crawl_position := source
	var crawl_velocity := velocity
	global_position = destination
	velocity = Vector3.ZERO
	if not state_machine.change_state(PlayerStateMachine.STATE_CROUCH):
		global_position = crawl_position
		velocity = crawl_velocity
		return false
	return true


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

	if state_machine.current_state() == PlayerStateMachine.STATE_CRAWLSPACE:
		if not _maintain_crawlspace_contract():
			return
		if interact_just_pressed:
			try_exit_crawlspace()
		return

	if interact_just_pressed and try_enter_crawlspace():
		return

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
	if to != PlayerStateMachine.STATE_CRAWLSPACE:
		_clear_crawl_contract()
	if to != PlayerStateMachine.STATE_CLIMB and to != PlayerStateMachine.STATE_BEAM:
		_traversal_distance = 0.0
	_apply_collision_shape_for_state(to)
	_apply_camera_posture_for_state(to)


func _apply_collision_shape_for_state(state: StringName) -> void:
	var capsule := collision_shape.shape as CapsuleShape3D
	if capsule == null or _standing_capsule_height <= 0.0:
		return

	var requested_height := _standing_capsule_height
	match state:
		PlayerStateMachine.STATE_CROUCH:
			requested_height = crouch_capsule_height
		PlayerStateMachine.STATE_CRAWLSPACE:
			requested_height = crawl_capsule_height
	if not CrawlRules.is_capsule_height_valid(
		requested_height,
		capsule.radius,
		_standing_capsule_height,
	):
		requested_height = _standing_capsule_height
	_apply_capsule_height(capsule, requested_height)


func _apply_capsule_height(capsule: CapsuleShape3D, height: float) -> void:
	collision_shape.transform = _standing_collision_transform
	capsule.height = height
	collision_shape.position.y -= (_standing_capsule_height - height) * 0.5


func _apply_camera_posture_for_state(state: StringName) -> void:
	if state == PlayerStateMachine.STATE_CRAWLSPACE:
		camera_rig.set_posture_drop(crawl_camera_drop)
	else:
		camera_rig.reset_posture_drop()


func _has_standing_clearance() -> bool:
	var capsule := collision_shape.shape as CapsuleShape3D
	if capsule == null or _standing_capsule_height <= 0.0:
		return true
	if is_equal_approx(capsule.height, _standing_capsule_height):
		return true

	return _has_capsule_clearance_at(_standing_capsule_height, global_position)


func _has_capsule_clearance_at(height: float, world_position: Vector3) -> bool:
	var capsule := collision_shape.shape as CapsuleShape3D
	if (
		capsule == null
		or _standing_capsule_height <= 0.0
		or not CrawlRules.is_safe_world_position(world_position)
		or not CrawlRules.is_capsule_height_valid(height, capsule.radius, _standing_capsule_height)
		or not is_inside_tree()
		or get_world_3d() == null
	):
		return false
	var requested_capsule := capsule.duplicate() as CapsuleShape3D
	requested_capsule.height = height
	var local_collision_transform := _standing_collision_transform
	local_collision_transform.origin.y -= (_standing_capsule_height - height) * 0.5
	var target_body_transform := global_transform
	target_body_transform.origin = world_position
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = requested_capsule
	query.transform = target_body_transform * local_collision_transform
	query.collision_mask = WORLD_COLLISION_MASK
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.margin = 0.001
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _has_capsule_path_clear(height: float, from: Vector3, to: Vector3) -> bool:
	var capsule := collision_shape.shape as CapsuleShape3D
	if (
		capsule == null
		or _standing_capsule_height <= 0.0
		or not CrawlRules.is_safe_world_position(from)
		or not CrawlRules.is_safe_world_position(to)
		or not CrawlRules.is_capsule_height_valid(height, capsule.radius, _standing_capsule_height)
		or not is_inside_tree()
		or get_world_3d() == null
	):
		return false
	var motion := to - from
	if not CrawlRules.is_finite_vector(motion):
		return false
	if motion.length_squared() > MAX_CRAWL_SWEEP_DISTANCE * MAX_CRAWL_SWEEP_DISTANCE:
		return false
	if motion.length_squared() <= CrawlRules.EPSILON_SQUARED:
		return true
	var requested_capsule := capsule.duplicate() as CapsuleShape3D
	requested_capsule.height = height
	var local_collision_transform := _standing_collision_transform
	local_collision_transform.origin.y -= (_standing_capsule_height - height) * 0.5
	var source_body_transform := global_transform
	source_body_transform.origin = from
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = requested_capsule
	query.transform = source_body_transform * local_collision_transform
	query.motion = motion
	query.collision_mask = WORLD_COLLISION_MASK
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.margin = 0.001
	var result := get_world_3d().direct_space_state.cast_motion(query)
	return result.size() >= 2 and result[0] >= CRAWL_MOTION_SAFE_FRACTION


func _capture_crawl_contract(entrance: CrawlEntrance) -> void:
	_clear_crawl_contract()
	_active_crawl_entrance = entrance
	_crawl_contract_outside_position = entrance.outside_world_position()
	_crawl_contract_inside_position = entrance.inside_world_position()
	_crawl_contract_transform = entrance.global_transform
	_crawl_contract_entry_radius = entrance.entry_radius
	_crawl_contract_capsule_height = crawl_capsule_height
	_crawl_contract_camera_drop = crawl_camera_drop
	_crawl_contract_valid = true
	_crawl_contract_invalidated = false
	if not entrance.tree_exiting.is_connected(_on_active_crawl_entrance_tree_exiting):
		entrance.tree_exiting.connect(_on_active_crawl_entrance_tree_exiting)


func _maintain_crawlspace_contract() -> bool:
	if state_machine.current_state() != PlayerStateMachine.STATE_CRAWLSPACE:
		return true
	if not _crawl_contract_valid:
		return _abort_invalid_crawlspace()

	# Once the player has crawled away from the entry endpoint, the marker is no
	# longer an active transition dependency. A later exit is discovered locally.
	if (
		CrawlRules.is_safe_world_position(global_position)
		and global_position.distance_squared_to(_crawl_contract_inside_position)
			> _crawl_contract_entry_radius * _crawl_contract_entry_radius
	):
		_release_active_crawl_entrance()

	if not _is_crawl_configuration_snapshot_current():
		return _abort_invalid_crawlspace()
	var entrance := active_crawl_entrance()
	if entrance == null:
		return (
			_abort_invalid_crawlspace()
			if _crawl_contract_invalidated
			else true
		)
	if (
		_crawl_contract_invalidated
		or not entrance.can_accept_body(self)
		or not entrance.global_transform.is_equal_approx(_crawl_contract_transform)
		or not entrance.outside_world_position().is_equal_approx(_crawl_contract_outside_position)
		or not entrance.inside_world_position().is_equal_approx(_crawl_contract_inside_position)
		or not is_equal_approx(entrance.entry_radius, _crawl_contract_entry_radius)
	):
		return _abort_invalid_crawlspace()
	return true


func _is_crawl_configuration_snapshot_current() -> bool:
	return (
		_is_crawl_configuration_valid()
		and is_equal_approx(crawl_capsule_height, _crawl_contract_capsule_height)
		and is_equal_approx(crawl_camera_drop, _crawl_contract_camera_drop)
	)


func _abort_invalid_crawlspace() -> bool:
	var original_position := global_position
	var recovery_height := _crawl_contract_capsule_height
	var can_recover_at_entrance := (
		_crawl_contract_valid
		and CrawlRules.is_safe_world_position(original_position)
		and CrawlRules.is_safe_world_position(_crawl_contract_outside_position)
		and _has_capsule_clearance_at(recovery_height, original_position)
		and _has_capsule_path_clear(
			recovery_height,
			original_position,
			_crawl_contract_outside_position,
		)
		and _has_capsule_clearance_at(recovery_height, _crawl_contract_outside_position)
		and _has_capsule_clearance_at(crouch_capsule_height, _crawl_contract_outside_position)
	)
	if can_recover_at_entrance:
		global_position = _crawl_contract_outside_position
		velocity = Vector3.ZERO
		if state_machine.change_state(PlayerStateMachine.STATE_CROUCH):
			return true
		global_position = original_position

	# Do not enlarge the body into world geometry. Restore the last validated
	# crawl posture, drop the stale marker reference, and require another valid
	# nearby entrance for a normal exit.
	crawl_capsule_height = _crawl_contract_capsule_height
	crawl_camera_drop = _crawl_contract_camera_drop
	_apply_collision_shape_for_state(PlayerStateMachine.STATE_CRAWLSPACE)
	_apply_camera_posture_for_state(PlayerStateMachine.STATE_CRAWLSPACE)
	_release_active_crawl_entrance()
	velocity = Vector3.ZERO
	return false


func _on_active_crawl_entrance_tree_exiting() -> void:
	_crawl_contract_invalidated = true


func _release_active_crawl_entrance() -> void:
	if (
		is_instance_valid(_active_crawl_entrance)
		and _active_crawl_entrance.tree_exiting.is_connected(
			_on_active_crawl_entrance_tree_exiting,
		)
	):
		_active_crawl_entrance.tree_exiting.disconnect(_on_active_crawl_entrance_tree_exiting)
	_active_crawl_entrance = null
	_crawl_contract_invalidated = false


func _clear_crawl_contract() -> void:
	_release_active_crawl_entrance()
	_crawl_contract_outside_position = Vector3.ZERO
	_crawl_contract_inside_position = Vector3.ZERO
	_crawl_contract_transform = Transform3D.IDENTITY
	_crawl_contract_entry_radius = 0.0
	_crawl_contract_capsule_height = 0.0
	_crawl_contract_camera_drop = 0.0
	_crawl_contract_valid = false


func _is_crawl_configuration_valid() -> bool:
	var capsule := collision_shape.shape as CapsuleShape3D
	return (
		capsule != null
		and CrawlRules.is_capsule_height_valid(
			crawl_capsule_height,
			capsule.radius,
			_standing_capsule_height,
		)
		and is_finite(crawl_camera_drop)
		and crawl_camera_drop >= 0.0
		and crawl_camera_drop <= camera_rig.max_posture_drop
	)


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
	if not is_inside_tree() or not ClimbRules.is_safe_world_position(global_position):
		return null
	var query := PhysicsPointQueryParameters3D.new()
	query.position = global_position
	query.collision_mask = ClimbEdge.CLIMB_MARKER_LAYER
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var intersections := get_world_3d().direct_space_state.intersect_point(
		query,
		MAX_CLIMB_EDGE_SPATIAL_RESULTS + 1,
	)
	if intersections.size() > MAX_CLIMB_EDGE_SPATIAL_RESULTS:
		return null
	var nearest: ClimbEdge
	var nearest_distance_squared := INF
	var nearby_candidate_count := 0
	for intersection: Dictionary in intersections:
		var candidate := intersection.get(&"collider") as Node
		if candidate is not ClimbEdge:
			continue
		var edge := candidate as ClimbEdge
		if not edge.can_accept_body(self) or not edge.is_near_bottom(global_position):
			continue
		nearby_candidate_count += 1
		if nearby_candidate_count > MAX_CLIMB_EDGE_CANDIDATES:
			return null
		var distance_squared := global_position.distance_squared_to(edge.bottom_world_position())
		if distance_squared < nearest_distance_squared:
			nearest = edge
			nearest_distance_squared = distance_squared
	return nearest


func _nearest_crawl_entrance(for_entry: bool) -> CrawlEntrance:
	if not is_inside_tree() or not CrawlRules.is_safe_world_position(global_position):
		return null
	var query := PhysicsPointQueryParameters3D.new()
	query.position = global_position
	query.collision_mask = CrawlEntrance.CRAWL_MARKER_LAYER
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var intersections := get_world_3d().direct_space_state.intersect_point(
		query,
		MAX_CRAWL_ENTRANCE_SPATIAL_RESULTS + 1,
	)
	if intersections.size() > MAX_CRAWL_ENTRANCE_SPATIAL_RESULTS:
		return null
	var nearest: CrawlEntrance
	var nearest_distance_squared := INF
	var nearby_candidate_count := 0
	var seen_instance_ids: Dictionary = {}
	for intersection: Dictionary in intersections:
		var candidate := intersection.get(&"collider") as Node
		if candidate is not CrawlEntrance:
			continue
		var entrance := candidate as CrawlEntrance
		var instance_id := entrance.get_instance_id()
		if seen_instance_ids.has(instance_id):
			continue
		seen_instance_ids[instance_id] = true
		if not entrance.can_accept_body(self):
			continue
		var endpoint := (
			entrance.outside_world_position()
			if for_entry
			else entrance.inside_world_position()
		)
		var is_near := (
			entrance.is_near_outside(global_position)
			if for_entry
			else entrance.is_near_inside(global_position)
		)
		if not is_near:
			continue
		nearby_candidate_count += 1
		if nearby_candidate_count > MAX_CRAWL_ENTRANCE_CANDIDATES:
			return null
		var distance_squared := global_position.distance_squared_to(endpoint)
		if distance_squared < nearest_distance_squared:
			nearest = entrance
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
