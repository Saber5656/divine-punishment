class_name PlayerController
extends CharacterBody3D


const WallClingRules := preload("res://src/player/player_wall_cling.gd")
const ClimbRules := preload("res://src/player/player_climb.gd")
const CrawlRules := preload("res://src/player/player_crawl.gd")
const SwimRules := preload("res://src/player/player_swim.gd")
const NOISE_FOOTSTEP_DISTANCE := 1.5
const MAX_NOISE_DELTA := 0.5
const HideRules := preload("res://src/player/player_hide.gd")
const WORLD_COLLISION_MASK := 1
const MIN_WALL_PROBE_DISTANCE := 0.1
const MAX_WALL_PROBE_DISTANCE := 2.0
const MIN_WALL_PROBE_HEIGHT := 0.0
const MAX_WALL_PROBE_HEIGHT := 2.0
const MAX_CLIMB_EDGE_CANDIDATES := 64
const MAX_CLIMB_EDGE_SPATIAL_RESULTS := 256
const MAX_CRAWL_ENTRANCE_CANDIDATES := 64
const MAX_CRAWL_ENTRANCE_SPATIAL_RESULTS := 256
const MAX_HIDE_SPOT_CANDIDATES := 64
const MAX_HIDE_SPOT_SPATIAL_RESULTS := 256
const MAX_WATER_VOLUME_CANDIDATES := 64
const MAX_WATER_VOLUME_SPATIAL_RESULTS := 256
const MAX_LIGHT_SOURCE_CANDIDATES := 64
const MAX_LIGHT_SOURCE_SPATIAL_RESULTS := 256
# Clearance probes keep the authored foot support from counting as an obstruction.
const CAPSULE_CLEARANCE_SUPPORT_EPSILON := 0.005
const TRAVERSAL_ENDPOINT_EPSILON := 0.001
const MAX_CRAWL_SWEEP_DISTANCE := (
	CrawlEntrance.MAX_PASSAGE_LENGTH + CrawlEntrance.MAX_ENTRY_RADIUS
)
const CRAWL_MOTION_SAFE_FRACTION := 0.9999
const MAX_WATER_SWEEP_DISTANCE := SwimRules.MAX_TRANSITION_DISTANCE
const SWIM_DEPTH_EPSILON := 0.001


@export var player_profile: PlayerProfile
@export_range(0.7, 1.8, 0.05) var crouch_capsule_height: float = 1.1
@export_range(0.7, 1.1, 0.05) var crawl_capsule_height: float = 0.7
@export_range(0.7, 1.2, 0.05) var swim_capsule_height: float = 0.9
@export_range(0.0, 1.1, 0.05) var crawl_camera_drop: float = 0.9
@export_range(0.1, 2.0, 0.05) var wall_probe_distance: float = 0.75
@export_range(0.0, 2.0, 0.05) var wall_probe_height: float = 0.5

@onready var state_machine: PlayerStateMachine = $StateMachine as PlayerStateMachine
@onready var collision_shape: CollisionShape3D = $CollisionShape3D as CollisionShape3D
@onready var camera_rig: PlayerCameraRig = $CameraRig as PlayerCameraRig
@onready var player_model: Node3D = $Visual/Model as Node3D
@onready var surface_ripples: Node3D = $Visual/SurfaceRipples as Node3D
@onready var swim_hud: SwimHud = $Visibility/SwimHud as SwimHud
@onready var noise_emitter: NoiseEmitter = $NoiseEmitter as NoiseEmitter
@onready var tool_rig: ToolRig = $ToolRig as ToolRig

var _standing_capsule_height: float
var _standing_collision_transform: Transform3D
var _wall_normal: Vector3 = Vector3.ZERO
var _interact_was_pressed: bool = false
var _active_climb_edge: ClimbEdge
var _active_beam_path: BeamPath
var _active_crawl_entrance: CrawlEntrance
var _active_water_volume: WaterVolume
var _active_hide_spot: HideSpot
var _crawl_contract_outside_position := Vector3.ZERO
var _crawl_contract_inside_position := Vector3.ZERO
var _crawl_contract_transform := Transform3D.IDENTITY
var _crawl_contract_entry_radius := 0.0
var _crawl_contract_capsule_height := 0.0
var _crawl_contract_camera_drop := 0.0
var _crawl_contract_valid := false
var _crawl_contract_invalidated := false
var _hide_contract_transform := Transform3D.IDENTITY
var _hide_contract_entry_radius := 0.0
var _hide_contract_shape_id := 0
var _hide_contract_valid := false
var _hide_contract_invalidated := false
var _traversal_distance := 0.0
var _beam_axis_direction := 1.0
var _water_contract_transform := Transform3D.IDENTITY
var _water_contract_size := Vector3.ZERO
var _water_contract_surface_body_depth := 0.0
var _water_contract_underwater_body_depth := 0.0
var _water_contract_capsule_height := 0.0
var _water_contract_breath_capacity := 0.0
var _water_contract_swim_speed := 0.0
var _water_contract_swim_noise_radius := 0.0
var _water_contract_exhaustion_noise_radius := 0.0
var _water_contract_valid := false
var _water_contract_invalidated := false
var _water_recovery_pending := false
var _breath_remaining := 0.0
var _forced_surface_pending := false
var _exhaustion_noise_emitted := false
var _footstep_distance := 0.0
var _close_range_seen := false
var _stance_toggle_queued := false
var _stance_was_pressed := false


func _ready() -> void:
	if player_profile != null:
		state_machine.player_profile = player_profile

	_initialize_collision_shape()
	if not state_machine.state_changed.is_connected(_on_state_changed):
		state_machine.state_changed.connect(_on_state_changed)
	_apply_collision_shape_for_state(state_machine.current_state())
	_apply_camera_posture_for_state(state_machine.current_state())
	_reset_breath()
	_apply_swim_presentation(state_machine.current_state())


func _process(delta: float) -> void:
	var gamepad_look := Input.get_vector(&"camera_left", &"camera_right", &"camera_up", &"camera_down")
	if gamepad_look.length_squared() > 0.0:
		rotate_y(camera_rig.apply_gamepad_look(gamepad_look, delta))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"stance_toggle"):
		_stance_toggle_queued = true
	if event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		rotate_y(camera_rig.apply_mouse_look(mouse_motion.screen_relative))


func _physics_process(delta: float) -> void:
	_refresh_water_membership()
	if state_machine.current_state() == PlayerStateMachine.STATE_ASSASSINATE:
		# AssassinationResolver owns the short presentation lock.  Movement and
		# traversal input must not move the player until release() is called.
		velocity = Vector3.ZERO
		return
	if _water_recovery_pending:
		velocity = Vector3.ZERO
		return
	_update_state_from_input()
	if state_machine.current_state() == PlayerStateMachine.STATE_HIDDEN:
		velocity = Vector3.ZERO
		return
	if _is_water_state():
		_update_breath(delta)
		if _water_recovery_pending:
			velocity = Vector3.ZERO
			return
		if _is_forced_surface_movement_blocked():
			velocity = Vector3.ZERO
			return
		_apply_movement()
		_move_swimming(delta)
		_refresh_water_membership()
		return
	if _is_traversing():
		advance_traversal(Input.get_axis(&"move_backward", &"move_forward"), delta)
		return
	_apply_gravity(delta)
	_apply_movement()
	var was_on_floor := is_on_floor()
	move_and_slide()
	_emit_ground_noise(delta, was_on_floor)


func current_movement_params() -> Dictionary:
	return state_machine.movement_params()


func current_tool_definition() -> ToolDefinition:
	return tool_rig.selected_definition() if tool_rig != null else null


func current_tool_remaining() -> int:
	return tool_rig.remaining_count() if tool_rig != null else 0


func set_tool_aiming(active: bool) -> bool:
	return tool_rig.set_aiming(active) if tool_rig != null else false


func is_tool_aiming() -> bool:
	return tool_rig.is_aiming() if tool_rig != null else false


func is_traversing() -> bool:
	return _is_traversing()


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


func active_water_volume() -> WaterVolume:
	return _active_water_volume if is_instance_valid(_active_water_volume) else null


func active_hide_spot() -> HideSpot:
	return _active_hide_spot if is_instance_valid(_active_hide_spot) else null


func is_visibility_excluded() -> bool:
	return state_machine.is_visibility_excluded()


func set_close_range_seen(seen: bool) -> void:
	_close_range_seen = seen


func close_range_seen() -> bool:
	return _close_range_seen


func is_hidden() -> bool:
	return state_machine.is_hidden()


func breath_remaining() -> float:
	return _breath_remaining


func is_forced_surfacing() -> bool:
	return _forced_surface_pending


func is_water_recovery_pending() -> bool:
	return _water_recovery_pending


func traversal_distance() -> float:
	return _traversal_distance


func try_enter_water(volume: WaterVolume = null) -> bool:
	var current := state_machine.current_state()
	if current not in [
		PlayerStateMachine.STATE_GROUND,
		PlayerStateMachine.STATE_CROUCH,
		PlayerStateMachine.STATE_SPRINT,
	]:
		return false
	if not _is_swim_configuration_valid():
		return false
	var candidate := volume if volume != null else _nearest_water_volume()
	if (
		candidate == null
		or not is_instance_valid(candidate)
		or not candidate.can_accept_body(self)
		or not candidate.can_enter_from_position(global_position)
	):
		return false
	var source := global_position
	var destination := candidate.surface_body_position_for(source)
	if not _is_safe_swim_reposition(source, destination):
		return false
	var source_velocity := velocity
	_capture_water_contract(candidate)
	global_position = destination
	velocity = Vector3.ZERO
	_reset_breath()
	if state_machine.change_state(PlayerStateMachine.STATE_SWIM_SURFACE):
		return true
	global_position = source
	velocity = source_velocity
	_clear_water_contract()
	return false


func try_dive_underwater() -> bool:
	if (
		state_machine.current_state() != PlayerStateMachine.STATE_SWIM_SURFACE
		or _forced_surface_pending
		or not _maintain_water_contract()
		or not _is_swim_configuration_valid()
	):
		return false
	var volume := active_water_volume()
	if volume == null:
		return false
	var source := global_position
	var destination := volume.underwater_body_position_for(source)
	if not _is_safe_swim_reposition(source, destination):
		return false
	var previous_breath := _breath_remaining
	global_position = destination
	velocity = Vector3.ZERO
	_reset_breath()
	if state_machine.change_state(PlayerStateMachine.STATE_SWIM_UNDERWATER):
		return true
	global_position = source
	_breath_remaining = previous_breath
	return false


func try_surface_from_underwater(forced: bool = false) -> bool:
	if (
		state_machine.current_state() != PlayerStateMachine.STATE_SWIM_UNDERWATER
		or (_forced_surface_pending and not forced)
		or not _maintain_water_contract()
	):
		return false
	var volume := active_water_volume()
	if volume == null:
		return false
	var source := global_position
	var destination := volume.surface_body_position_for(source)
	if not _is_safe_swim_reposition(source, destination):
		return false
	var previous_breath := _breath_remaining
	_breath_remaining = state_machine.breath_capacity()
	global_position = destination
	velocity = Vector3.ZERO
	if not state_machine.change_state(PlayerStateMachine.STATE_SWIM_SURFACE):
		global_position = source
		_breath_remaining = previous_breath
		return false
	_forced_surface_pending = false
	_exhaustion_noise_emitted = false
	return true


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


func try_enter_hide_spot(
	hide_spot: HideSpot = null,
	close_range_seen: bool = false,
) -> bool:
	var current := state_machine.current_state()
	if current != PlayerStateMachine.STATE_GROUND and current != PlayerStateMachine.STATE_CROUCH:
		return false
	if is_inside_tree() and not is_on_floor():
		return false
	var candidate := hide_spot if hide_spot != null else _nearest_hide_spot()
	if (
		candidate == null
		or not is_instance_valid(candidate)
		or not candidate.can_enter(self, close_range_seen)
	):
		return false
	_capture_hide_contract(candidate)
	var source_velocity := velocity
	velocity = Vector3.ZERO
	if not state_machine.change_state(PlayerStateMachine.STATE_HIDDEN):
		_clear_hide_contract()
		velocity = source_velocity
		return false
	return true


func try_exit_hide_spot(hide_spot: HideSpot = null) -> bool:
	if state_machine.current_state() != PlayerStateMachine.STATE_HIDDEN:
		return false
	if not _maintain_hide_contract():
		return false
	var candidate := hide_spot if hide_spot != null else active_hide_spot()
	if (
		candidate == null
		or not is_instance_valid(candidate)
		or not candidate.can_accept_body(self)
		or not candidate.is_near_entry(global_position)
	):
		return false
	var source_velocity := velocity
	velocity = Vector3.ZERO
	if state_machine.change_state(PlayerStateMachine.STATE_CROUCH):
		return true
	velocity = source_velocity
	return false


func invalidate_hidden_if_close_range_seen(close_range_seen: bool) -> bool:
	if not close_range_seen or state_machine.current_state() != PlayerStateMachine.STATE_HIDDEN:
		return false
	return try_exit_hide_spot()


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
	if state_machine.current_state() == PlayerStateMachine.STATE_ASSASSINATE:
		return
	var interact_pressed := Input.is_action_pressed(&"interact")
	var interact_just_pressed := interact_pressed and not _interact_was_pressed
	_interact_was_pressed = interact_pressed
	var stance_pressed := Input.is_action_pressed(&"stance_toggle")
	var stance_just_pressed := (
		_stance_toggle_queued or (stance_pressed and not _stance_was_pressed)
	)
	_stance_toggle_queued = false
	_stance_was_pressed = stance_pressed

	if state_machine.current_state() == PlayerStateMachine.STATE_SWIM_SURFACE:
		if stance_just_pressed:
			try_dive_underwater()
		return

	if state_machine.current_state() == PlayerStateMachine.STATE_SWIM_UNDERWATER:
		if stance_just_pressed and not _forced_surface_pending:
			try_surface_from_underwater()
		return

	if state_machine.current_state() == PlayerStateMachine.STATE_CRAWLSPACE:
		if not _maintain_crawlspace_contract():
			return
		if interact_just_pressed:
			try_exit_crawlspace()
		return

	if state_machine.current_state() == PlayerStateMachine.STATE_HIDDEN:
		if not _maintain_hide_contract():
			return
		if interact_just_pressed:
			try_exit_hide_spot()
		return

	if interact_just_pressed:
		var close_range_seen := _close_range_seen
		_close_range_seen = false
		if try_enter_hide_spot(null, close_range_seen):
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

	if interact_just_pressed and try_extinguish_adjacent_light():
		return

	if not Input.is_action_pressed(&"sprint") and state_machine.current_state() == PlayerStateMachine.STATE_SPRINT:
		state_machine.resume_from_sprint()

	if stance_just_pressed:
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


func try_extinguish_adjacent_light() -> bool:
	var current := state_machine.current_state()
	if current != PlayerStateMachine.STATE_GROUND and current != PlayerStateMachine.STATE_CROUCH:
		return false
	var candidate := _nearest_light_source()
	return candidate != null and candidate.try_extinguish(self)


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
	if (
		to != PlayerStateMachine.STATE_CRAWLSPACE
		and not (
			from == PlayerStateMachine.STATE_CRAWLSPACE
			and to == PlayerStateMachine.STATE_ASSASSINATE
		)
	):
		_clear_crawl_contract()
	if to != PlayerStateMachine.STATE_HIDDEN:
		_clear_hide_contract()
	if not _is_water_state_name(to):
		_clear_water_contract()
	if to != PlayerStateMachine.STATE_CLIMB and to != PlayerStateMachine.STATE_BEAM:
		_traversal_distance = 0.0
	var posture_state := to
	if from == PlayerStateMachine.STATE_CRAWLSPACE and to == PlayerStateMachine.STATE_ASSASSINATE:
		posture_state = PlayerStateMachine.STATE_CRAWLSPACE
	_apply_collision_shape_for_state(posture_state)
	_apply_camera_posture_for_state(posture_state)
	_apply_swim_presentation(to)


func _apply_collision_shape_for_state(state: StringName) -> void:
	var capsule := collision_shape.shape as CapsuleShape3D
	if capsule == null or _standing_capsule_height <= 0.0:
		return

	var requested_height := _standing_capsule_height
	match state:
		PlayerStateMachine.STATE_CROUCH, PlayerStateMachine.STATE_HIDDEN:
			requested_height = crouch_capsule_height
		PlayerStateMachine.STATE_CRAWLSPACE:
			requested_height = crawl_capsule_height
		PlayerStateMachine.STATE_SWIM_SURFACE, PlayerStateMachine.STATE_SWIM_UNDERWATER:
			requested_height = swim_capsule_height
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
	local_collision_transform.origin.y += CAPSULE_CLEARANCE_SUPPORT_EPSILON
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


func _has_capsule_path_clear(
	height: float,
	from: Vector3,
	to: Vector3,
	max_distance: float = MAX_CRAWL_SWEEP_DISTANCE,
) -> bool:
	var capsule := collision_shape.shape as CapsuleShape3D
	if (
		capsule == null
		or _standing_capsule_height <= 0.0
		or not CrawlRules.is_safe_world_position(from)
		or not CrawlRules.is_safe_world_position(to)
		or not CrawlRules.is_capsule_height_valid(height, capsule.radius, _standing_capsule_height)
		or not is_finite(max_distance)
		or max_distance <= 0.0
		or max_distance > MAX_WATER_SWEEP_DISTANCE
		or not is_inside_tree()
		or get_world_3d() == null
	):
		return false
	var motion := to - from
	if not CrawlRules.is_finite_vector(motion):
		return false
	if motion.length_squared() > max_distance * max_distance:
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


func _capture_hide_contract(hide_spot: HideSpot) -> void:
	_clear_hide_contract()
	_active_hide_spot = hide_spot
	_hide_contract_transform = hide_spot.global_transform
	_hide_contract_entry_radius = hide_spot.entry_radius
	_hide_contract_shape_id = hide_spot.entry_shape_identity()
	_hide_contract_valid = true
	_hide_contract_invalidated = false
	if not hide_spot.tree_exiting.is_connected(_on_active_hide_spot_tree_exiting):
		hide_spot.tree_exiting.connect(_on_active_hide_spot_tree_exiting)


func _maintain_hide_contract() -> bool:
	if state_machine.current_state() != PlayerStateMachine.STATE_HIDDEN:
		return true
	if not _hide_contract_valid or _hide_contract_invalidated:
		return _abort_invalid_hide_spot()
	var hide_spot := active_hide_spot()
	if (
		hide_spot == null
		or not hide_spot.can_accept_body(self)
		or not hide_spot.global_transform.is_equal_approx(_hide_contract_transform)
		or not is_equal_approx(hide_spot.entry_radius, _hide_contract_entry_radius)
		or hide_spot.entry_shape_identity() != _hide_contract_shape_id
		or not hide_spot.is_near_entry(global_position)
	):
		return _abort_invalid_hide_spot()
	return true


func _abort_invalid_hide_spot() -> bool:
	_clear_hide_contract()
	velocity = Vector3.ZERO
	state_machine.change_state(PlayerStateMachine.STATE_CROUCH)
	return false


func _on_active_hide_spot_tree_exiting() -> void:
	_hide_contract_invalidated = true


func _release_active_hide_spot() -> void:
	if (
		is_instance_valid(_active_hide_spot)
		and _active_hide_spot.tree_exiting.is_connected(_on_active_hide_spot_tree_exiting)
	):
		_active_hide_spot.tree_exiting.disconnect(_on_active_hide_spot_tree_exiting)
	_active_hide_spot = null
	_hide_contract_invalidated = false


func _clear_hide_contract() -> void:
	_release_active_hide_spot()
	_hide_contract_transform = Transform3D.IDENTITY
	_hide_contract_entry_radius = 0.0
	_hide_contract_shape_id = 0
	_hide_contract_valid = false


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


func _is_swim_configuration_valid() -> bool:
	var capsule := collision_shape.shape as CapsuleShape3D
	var capacity := state_machine.breath_capacity()
	var exhaustion_radius := state_machine.swim_exhaustion_noise_radius()
	var normal_swim_radius := state_machine.swim_noise_radius()
	var swim_speed := state_machine.swim_speed()
	return (
		capsule != null
		and CrawlRules.is_capsule_height_valid(
			swim_capsule_height,
			capsule.radius,
			_standing_capsule_height,
		)
		and SwimRules.is_breath_capacity_valid(capacity)
		and SwimRules.is_swim_speed_valid(swim_speed)
		and SwimRules.is_exhaustion_noise_radius_valid(exhaustion_radius)
		and is_finite(normal_swim_radius)
		and normal_swim_radius >= 0.0
		and exhaustion_radius > normal_swim_radius
	)


func _is_safe_swim_reposition(from: Vector3, to: Vector3) -> bool:
	return (
		SwimRules.is_safe_world_position(from)
		and SwimRules.is_safe_world_position(to)
		and from.distance_squared_to(to) <= MAX_WATER_SWEEP_DISTANCE * MAX_WATER_SWEEP_DISTANCE
		and _has_capsule_clearance_at(swim_capsule_height, from)
		and _has_capsule_path_clear(
			swim_capsule_height,
			from,
			to,
			MAX_WATER_SWEEP_DISTANCE,
		)
		and _has_capsule_clearance_at(swim_capsule_height, to)
	)


func _reset_breath() -> void:
	var capacity := state_machine.breath_capacity()
	_breath_remaining = capacity if SwimRules.is_breath_capacity_valid(capacity) else 0.0
	_forced_surface_pending = false
	_exhaustion_noise_emitted = false


func _update_breath(delta: float) -> void:
	if _water_recovery_pending:
		velocity = Vector3.ZERO
		_apply_swim_presentation(state_machine.current_state())
		return
	if state_machine.current_state() != PlayerStateMachine.STATE_SWIM_UNDERWATER:
		_reset_breath()
		_apply_swim_presentation(state_machine.current_state())
		return
	var capacity := state_machine.breath_capacity()
	_breath_remaining = SwimRules.consume_breath(_breath_remaining, delta, capacity)
	if _breath_remaining <= 0.0:
		_forced_surface_pending = true
		_emit_exhaustion_noise_once()
		if not try_surface_from_underwater(true):
			velocity = Vector3.ZERO
	_apply_swim_presentation(state_machine.current_state())


func _emit_exhaustion_noise_once() -> void:
	if _exhaustion_noise_emitted:
		return
	var radius := state_machine.swim_exhaustion_noise_radius()
	if (
		not SwimRules.is_exhaustion_noise_radius_valid(radius)
		or radius <= state_machine.swim_noise_radius()
		or not SwimRules.is_safe_world_position(global_position)
	):
		return
	_exhaustion_noise_emitted = true
	NoiseEventSystem.emit(
		NoiseEvent.create(global_position, radius, Enums.NoiseKind.LANDING, self),
		get_tree(),
	)


func _emit_ground_noise(delta: float, was_on_floor: bool) -> void:
	if noise_emitter == null:
		return
	if not is_on_floor() or _is_water_state() or _is_traversing():
		_footstep_distance = 0.0
		return
	if not was_on_floor:
		noise_emitter.emit_landing()
		_footstep_distance = 0.0
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if horizontal_speed <= 0.001:
		return
	var material := noise_emitter.floor_material
	var floor_collider := _floor_collider_from_slide_collisions()
	if floor_collider != null:
		material = NoiseEmitter.floor_material_for(floor_collider, material)
	if not is_finite(delta) or delta <= 0.0:
		return
	_footstep_distance += horizontal_speed * minf(delta, MAX_NOISE_DELTA)
	if _footstep_distance >= NOISE_FOOTSTEP_DISTANCE:
		_footstep_distance = fmod(_footstep_distance, NOISE_FOOTSTEP_DISTANCE)
		noise_emitter.emit_footstep(state_machine.stance(), material)


func _floor_collider_from_slide_collisions() -> Object:
	var floor_normal := get_floor_normal()
	if floor_normal.is_zero_approx():
		floor_normal = up_direction
	if floor_normal.is_zero_approx():
		return null
	floor_normal = floor_normal.normalized()
	var minimum_floor_alignment := cos(floor_max_angle)
	var best_alignment := minimum_floor_alignment
	var best_collider: Object = null
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		if collision == null:
			continue
		var normal := collision.get_normal()
		if normal.is_zero_approx():
			continue
		var alignment := normal.normalized().dot(floor_normal)
		if alignment < best_alignment:
			continue
		best_alignment = alignment
		best_collider = collision.get_collider()
	return best_collider


func _apply_swim_presentation(state: StringName) -> void:
	var underwater := state == PlayerStateMachine.STATE_SWIM_UNDERWATER
	if is_instance_valid(player_model):
		player_model.visible = not underwater
	if is_instance_valid(surface_ripples):
		surface_ripples.visible = underwater
		var volume := active_water_volume()
		if underwater and volume != null:
			var surface_y := volume.surface_world_y()
			if is_finite(surface_y):
				surface_ripples.global_position = Vector3(
					global_position.x,
					surface_y + 0.02,
					global_position.z,
				)
	if is_instance_valid(swim_hud):
		swim_hud.set_underwater(
			underwater,
			_breath_remaining,
			state_machine.breath_capacity(),
		)


func _refresh_water_membership() -> void:
	if _is_water_state():
		if _water_recovery_pending:
			_try_finish_water_recovery()
			return
		var active := active_water_volume()
		if (
			not _maintain_water_contract()
			or not _is_swim_configuration_valid()
			or active == null
		):
			_begin_water_recovery()
			return
		if not active.contains_world_position(global_position):
			if _try_transfer_water_volume():
				return
			_begin_water_recovery()
			return
	if state_machine.current_state() in [
		PlayerStateMachine.STATE_GROUND,
		PlayerStateMachine.STATE_CROUCH,
		PlayerStateMachine.STATE_SPRINT,
	]:
		var candidate := _nearest_water_volume()
		if candidate != null:
			try_enter_water(candidate)


func _try_transfer_water_volume() -> bool:
	var state := state_machine.current_state()
	if not _is_water_state_name(state) or not _maintain_water_contract():
		return false
	var previous_volume := active_water_volume()
	var candidate := _nearest_safe_water_transfer_volume(state, previous_volume)
	if candidate == null or candidate == previous_volume:
		return false
	var source := global_position
	var destination := (
		candidate.underwater_body_position_for(source)
		if state == PlayerStateMachine.STATE_SWIM_UNDERWATER
		else candidate.surface_body_position_for(source)
	)
	if not _is_safe_swim_reposition(source, destination):
		return false
	var previous_breath := _breath_remaining
	var previous_forced_surface := _forced_surface_pending
	var previous_exhaustion_noise := _exhaustion_noise_emitted
	_capture_water_contract(candidate)
	global_position = destination
	_breath_remaining = previous_breath
	_forced_surface_pending = previous_forced_surface
	_exhaustion_noise_emitted = previous_exhaustion_noise
	_apply_swim_presentation(state)
	return true


func _nearest_safe_water_transfer_volume(
	state: StringName,
	previous_volume: WaterVolume,
) -> WaterVolume:
	if (
		not _is_water_state_name(state)
		or not is_inside_tree()
		or get_world_3d() == null
		or not SwimRules.is_safe_world_position(global_position)
	):
		return null
	var source := global_position
	var query := PhysicsPointQueryParameters3D.new()
	query.position = source
	query.collision_mask = WaterVolume.WATER_LAYER
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var intersections := get_world_3d().direct_space_state.intersect_point(
		query,
		MAX_WATER_VOLUME_SPATIAL_RESULTS + 1,
	)
	if intersections.size() > MAX_WATER_VOLUME_SPATIAL_RESULTS:
		return null
	var nearest: WaterVolume
	var nearest_distance_squared := INF
	var nearby_candidate_count := 0
	var seen_instance_ids: Dictionary = {}
	for intersection: Dictionary in intersections:
		var candidate := intersection.get(&"collider") as Node
		if candidate is not WaterVolume:
			continue
		var volume := candidate as WaterVolume
		var instance_id := volume.get_instance_id()
		if seen_instance_ids.has(instance_id):
			continue
		seen_instance_ids[instance_id] = true
		if (
			volume == previous_volume
			or not volume.can_accept_body(self)
			or not volume.contains_world_position(source)
		):
			continue
		nearby_candidate_count += 1
		if nearby_candidate_count > MAX_WATER_VOLUME_CANDIDATES:
			return null
		var destination := (
			volume.underwater_body_position_for(source)
			if state == PlayerStateMachine.STATE_SWIM_UNDERWATER
			else volume.surface_body_position_for(source)
		)
		if not _is_safe_swim_reposition(source, destination):
			continue
		var distance_squared := source.distance_squared_to(destination)
		if distance_squared < nearest_distance_squared:
			nearest = volume
			nearest_distance_squared = distance_squared
	return nearest


func _capture_water_contract(volume: WaterVolume) -> void:
	_clear_water_contract()
	_active_water_volume = volume
	_water_contract_transform = volume.global_transform
	_water_contract_size = volume.size
	_water_contract_surface_body_depth = volume.surface_body_depth
	_water_contract_underwater_body_depth = volume.underwater_body_depth
	_water_contract_capsule_height = swim_capsule_height
	_water_contract_breath_capacity = state_machine.breath_capacity()
	_water_contract_swim_speed = state_machine.swim_speed()
	_water_contract_swim_noise_radius = state_machine.swim_noise_radius()
	_water_contract_exhaustion_noise_radius = state_machine.swim_exhaustion_noise_radius()
	_water_contract_valid = true
	_water_contract_invalidated = false
	_water_recovery_pending = false
	if not volume.tree_exiting.is_connected(_on_active_water_volume_tree_exiting):
		volume.tree_exiting.connect(_on_active_water_volume_tree_exiting)


func _maintain_water_contract() -> bool:
	if not _water_contract_valid or _water_contract_invalidated:
		return false
	var volume := active_water_volume()
	return (
		volume != null
		and _is_water_configuration_snapshot_current()
		and volume.can_accept_body(self)
		and volume.global_transform.is_equal_approx(_water_contract_transform)
		and volume.size.is_equal_approx(_water_contract_size)
		and is_equal_approx(volume.surface_body_depth, _water_contract_surface_body_depth)
		and is_equal_approx(volume.underwater_body_depth, _water_contract_underwater_body_depth)
	)


func _is_water_configuration_snapshot_current() -> bool:
	return (
		_is_swim_configuration_valid()
		and is_equal_approx(swim_capsule_height, _water_contract_capsule_height)
		and is_equal_approx(state_machine.breath_capacity(), _water_contract_breath_capacity)
		and is_equal_approx(state_machine.swim_speed(), _water_contract_swim_speed)
		and is_equal_approx(state_machine.swim_noise_radius(), _water_contract_swim_noise_radius)
		and is_equal_approx(
			state_machine.swim_exhaustion_noise_radius(),
			_water_contract_exhaustion_noise_radius,
		)
	)


func _on_active_water_volume_tree_exiting() -> void:
	_water_contract_invalidated = true


func _release_active_water_volume() -> void:
	if (
		is_instance_valid(_active_water_volume)
		and _active_water_volume.tree_exiting.is_connected(
			_on_active_water_volume_tree_exiting,
		)
	):
		_active_water_volume.tree_exiting.disconnect(_on_active_water_volume_tree_exiting)
	_active_water_volume = null


func _begin_water_recovery() -> bool:
	_water_recovery_pending = true
	_water_contract_invalidated = true
	_release_active_water_volume()
	velocity = Vector3.ZERO
	_restore_captured_swim_capsule()
	return _try_finish_water_recovery()


func _try_finish_water_recovery() -> bool:
	if not _is_water_state():
		_water_recovery_pending = false
		return true
	velocity = Vector3.ZERO
	if not _has_capsule_clearance_at(_standing_capsule_height, global_position):
		_restore_captured_swim_capsule()
		return false
	return state_machine.change_state(PlayerStateMachine.STATE_GROUND)


func _restore_captured_swim_capsule() -> void:
	var capsule := collision_shape.shape as CapsuleShape3D
	if (
		capsule != null
		and CrawlRules.is_capsule_height_valid(
			_water_contract_capsule_height,
			capsule.radius,
			_standing_capsule_height,
		)
	):
		_apply_capsule_height(capsule, _water_contract_capsule_height)


func _clear_water_contract() -> void:
	_release_active_water_volume()
	_water_contract_transform = Transform3D.IDENTITY
	_water_contract_size = Vector3.ZERO
	_water_contract_surface_body_depth = 0.0
	_water_contract_underwater_body_depth = 0.0
	_water_contract_capsule_height = 0.0
	_water_contract_breath_capacity = 0.0
	_water_contract_swim_speed = 0.0
	_water_contract_swim_noise_radius = 0.0
	_water_contract_exhaustion_noise_radius = 0.0
	_water_contract_valid = false
	_water_contract_invalidated = false
	_water_recovery_pending = false
	_reset_breath()


func _is_water_state() -> bool:
	return _is_water_state_name(state_machine.current_state())


func _is_forced_surface_movement_blocked() -> bool:
	return (
		_forced_surface_pending
		and state_machine.current_state() == PlayerStateMachine.STATE_SWIM_UNDERWATER
	)


func _is_water_state_name(state: StringName) -> bool:
	return (
		state == PlayerStateMachine.STATE_SWIM_SURFACE
		or state == PlayerStateMachine.STATE_SWIM_UNDERWATER
	)


func _apply_gravity(delta: float) -> void:
	if _is_traversing() or _is_water_state():
		velocity = Vector3.ZERO
		return
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
		return
	velocity += get_gravity() * delta


func _apply_movement() -> void:
	if _is_traversing() or _is_forced_surface_movement_blocked():
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
	if _is_water_state() and not SwimRules.is_swim_speed_valid(speed):
		velocity = Vector3.ZERO
		return
	velocity.x = world_direction.x * speed
	velocity.z = world_direction.z * speed


func _move_swimming(delta: float) -> void:
	velocity.y = 0.0
	if (
		_water_recovery_pending
		or _is_forced_surface_movement_blocked()
		or not _is_swim_configuration_valid()
		or not SwimRules.is_physics_delta_valid(delta)
		or not SwimRules.is_finite_vector(velocity)
	):
		velocity = Vector3.ZERO
		if _is_water_state() and not _is_swim_configuration_valid():
			_begin_water_recovery()
		return
	var volume := active_water_volume()
	if volume == null or not _maintain_water_contract():
		_begin_water_recovery()
		return
	var source := global_position
	var depth_position := _water_depth_position_for(volume, source)
	if not SwimRules.is_safe_world_position(depth_position):
		_begin_water_recovery()
		return
	if absf(source.y - depth_position.y) > SWIM_DEPTH_EPSILON:
		if not _is_safe_swim_reposition(source, depth_position):
			_begin_water_recovery()
			return
		global_position = depth_position
		source = depth_position
	var motion := Vector3(velocity.x, 0.0, velocity.z) * delta
	if (
		not SwimRules.is_finite_vector(motion)
		or motion.length() > SwimRules.MAX_SWIM_SPEED * SwimRules.MAX_PHYSICS_DELTA
	):
		velocity = Vector3.ZERO
		return
	move_and_collide(motion, false, 0.001, false, 1)
	var restored_depth := _water_depth_position_for(volume, global_position)
	if not SwimRules.is_safe_world_position(restored_depth):
		if (
			not SwimRules.is_safe_world_position(global_position)
			or absf(global_position.y - source.y) > SWIM_DEPTH_EPSILON
		):
			global_position = source
			velocity = Vector3.ZERO
		return
	if (
		absf(global_position.y - restored_depth.y) > SWIM_DEPTH_EPSILON
	):
		global_position = source
		velocity = Vector3.ZERO
		return
	global_position.y = restored_depth.y
	velocity.y = 0.0


func _water_depth_position_for(volume: WaterVolume, world_position: Vector3) -> Vector3:
	if state_machine.current_state() == PlayerStateMachine.STATE_SWIM_SURFACE:
		return volume.surface_body_position_for(world_position)
	if state_machine.current_state() == PlayerStateMachine.STATE_SWIM_UNDERWATER:
		return volume.underwater_body_position_for(world_position)
	return Vector3(INF, INF, INF)


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


func _nearest_hide_spot() -> HideSpot:
	if (
		not is_inside_tree()
		or get_world_3d() == null
		or not HideRules.is_safe_world_position(global_position)
	):
		return null
	var query := PhysicsPointQueryParameters3D.new()
	query.position = global_position
	query.collision_mask = HideSpot.HIDE_SPOT_LAYER
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var intersections := get_world_3d().direct_space_state.intersect_point(
		query,
		MAX_HIDE_SPOT_SPATIAL_RESULTS + 1,
	)
	if intersections.size() > MAX_HIDE_SPOT_SPATIAL_RESULTS:
		return null
	var nearest: HideSpot
	var nearest_distance_squared := INF
	var nearby_candidate_count := 0
	var seen_instance_ids: Dictionary = {}
	for intersection: Dictionary in intersections:
		var candidate := intersection.get(&"collider") as Node
		if candidate is not HideSpot:
			continue
		var hide_spot := candidate as HideSpot
		var instance_id := hide_spot.get_instance_id()
		if seen_instance_ids.has(instance_id):
			continue
		seen_instance_ids[instance_id] = true
		if not hide_spot.can_accept_body(self) or not hide_spot.is_near_entry(global_position):
			continue
		nearby_candidate_count += 1
		if nearby_candidate_count > MAX_HIDE_SPOT_CANDIDATES:
			return null
		var distance_squared := global_position.distance_squared_to(hide_spot.entry_world_position())
		if distance_squared < nearest_distance_squared:
			nearest = hide_spot
			nearest_distance_squared = distance_squared
	return nearest


func _nearest_light_source() -> LightSource:
	if not is_inside_tree() or get_world_3d() == null:
		return null
	var query := PhysicsPointQueryParameters3D.new()
	query.position = global_position
	query.collision_mask = LightSource.INTERACTABLE_LAYER
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var intersections := get_world_3d().direct_space_state.intersect_point(
		query,
		MAX_LIGHT_SOURCE_SPATIAL_RESULTS + 1,
	)
	if intersections.size() > MAX_LIGHT_SOURCE_SPATIAL_RESULTS:
		return null
	var nearest: LightSource
	var nearest_distance_squared := INF
	var nearby_candidate_count := 0
	var seen_instance_ids: Dictionary = {}
	for intersection: Dictionary in intersections:
		var candidate := intersection.get(&"collider") as Node
		if candidate is not LightSource:
			continue
		var light := candidate as LightSource
		var instance_id := light.get_instance_id()
		if seen_instance_ids.has(instance_id):
			continue
		seen_instance_ids[instance_id] = true
		if not light.can_interact(self):
			continue
		nearby_candidate_count += 1
		if nearby_candidate_count > MAX_LIGHT_SOURCE_CANDIDATES:
			return null
		var distance_squared := global_position.distance_squared_to(light.global_position)
		if distance_squared < nearest_distance_squared:
			nearest = light
			nearest_distance_squared = distance_squared
	return nearest


func _nearest_water_volume() -> WaterVolume:
	if (
		not is_inside_tree()
		or get_world_3d() == null
		or not SwimRules.is_safe_world_position(global_position)
	):
		return null
	var query := PhysicsPointQueryParameters3D.new()
	query.position = global_position
	query.collision_mask = WaterVolume.WATER_LAYER
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var intersections := get_world_3d().direct_space_state.intersect_point(
		query,
		MAX_WATER_VOLUME_SPATIAL_RESULTS + 1,
	)
	if intersections.size() > MAX_WATER_VOLUME_SPATIAL_RESULTS:
		return null
	var nearest: WaterVolume
	var nearest_distance_squared := INF
	var nearby_candidate_count := 0
	var seen_instance_ids: Dictionary = {}
	for intersection: Dictionary in intersections:
		var candidate := intersection.get(&"collider") as Node
		if candidate is not WaterVolume:
			continue
		var volume := candidate as WaterVolume
		var instance_id := volume.get_instance_id()
		if seen_instance_ids.has(instance_id):
			continue
		seen_instance_ids[instance_id] = true
		if not volume.can_accept_body(self) or not volume.can_enter_from_position(global_position):
			continue
		var surface_position := volume.surface_body_position_for(global_position)
		if not SwimRules.is_safe_world_position(surface_position):
			continue
		nearby_candidate_count += 1
		if nearby_candidate_count > MAX_WATER_VOLUME_CANDIDATES:
			return null
		var distance_squared := global_position.distance_squared_to(surface_position)
		if distance_squared < nearest_distance_squared:
			nearest = volume
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
