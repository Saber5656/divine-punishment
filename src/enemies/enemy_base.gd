class_name EnemyBase
extends CharacterBody3D


var _assassination_locked := false
var _assassinated := false
var _assassination_context: StringName = &""
var _corpse_anomaly: Anomaly
var _corpse_anomaly_registered := false


const MIN_ROUTINE_SPEED := 0.1
const MAX_ROUTINE_SPEED := 12.0
const DEFAULT_ROUTINE_SPEED := 1.5
const MAX_NAVIGATION_STEP_DELTA := 0.25
const NAVIGATION_ARRIVAL_TOLERANCE := 0.5

@export var routine_type: StringName = &"guard"
@export_node_path("Path3D") var patrol_path_path: NodePath
@export_node_path("LightSource") var lantern_light_path: NodePath
@export_range(MIN_ROUTINE_SPEED, MAX_ROUTINE_SPEED, 0.1) var routine_speed := DEFAULT_ROUTINE_SPEED:
	set(value):
		routine_speed = clampf(value, MIN_ROUTINE_SPEED, MAX_ROUTINE_SPEED) if is_finite(value) else DEFAULT_ROUTINE_SPEED


func _ready() -> void:
	add_to_group(&"enemies")
	var enemy_brain := brain()
	if enemy_brain != null:
		enemy_brain.set_routine_type(routine_type)
		enemy_brain.set_routine_path(configured_patrol_path())
		enemy_brain.set_lantern_light(configured_lantern_light())


func on_noise(event: NoiseEvent) -> void:
	var perception := get_node_or_null(NodePath("Perception")) as EnemyPerception
	if perception != null:
		perception.on_noise(event)


func on_anomaly(anomaly: Anomaly) -> void:
	var perception := get_node_or_null(NodePath("Perception")) as EnemyPerception
	if perception != null:
		perception.on_anomaly(anomaly)


func brain() -> EnemyBrain:
	return get_node_or_null(NodePath("Brain")) as EnemyBrain


func configured_routine_type() -> StringName:
	return routine_type


func configured_patrol_path() -> PatrolPath:
	if patrol_path_path != NodePath():
		var configured := get_node_or_null(patrol_path_path) as PatrolPath
		if configured != null:
			return configured
	return get_node_or_null(NodePath("PatrolPath")) as PatrolPath


func configured_lantern_light() -> LightSource:
	if lantern_light_path != NodePath():
		var configured := get_node_or_null(lantern_light_path) as LightSource
		if configured != null:
			return configured
	return get_node_or_null(NodePath("Lantern")) as LightSource


func set_routine_type(value: StringName) -> bool:
	routine_type = value
	var enemy_brain := brain()
	return enemy_brain != null and enemy_brain.set_routine_type(value)


func routine_role() -> StringName:
	var enemy_brain := brain()
	return enemy_brain.routine_type() if enemy_brain != null else routine_type


func set_patrol_path(path: PatrolPath) -> bool:
	var enemy_brain := brain()
	if enemy_brain == null:
		return false
	return enemy_brain.set_patrol_path(path)


func patrol_path() -> PatrolPath:
	var enemy_brain := brain()
	return enemy_brain.patrol_path() if enemy_brain != null else configured_patrol_path()


func routine_target() -> Vector3:
	var enemy_brain := brain()
	return enemy_brain.routine_target() if enemy_brain != null else global_position


func current_routine_stop() -> RoutineStop:
	var enemy_brain := brain()
	return enemy_brain.current_routine_stop() if enemy_brain != null else null


func advance_navigation(delta: float, target: Vector3, speed: float = DEFAULT_ROUTINE_SPEED) -> bool:
	if not is_finite(delta) or delta <= 0.0 or not target.is_finite() or not is_finite(speed) or speed <= 0.0:
		return false
	var bounded_delta := minf(delta, MAX_NAVIGATION_STEP_DELTA)
	var bounded_speed := clampf(speed, MIN_ROUTINE_SPEED, MAX_ROUTINE_SPEED)
	var agent := get_node_or_null(NodePath("NavigationAgent3D")) as NavigationAgent3D
	var tolerance := NAVIGATION_ARRIVAL_TOLERANCE
	if agent != null and is_finite(agent.target_desired_distance):
		# Do not let the engine's broad default desired distance (often 1 m)
		# advance a multi-stop patrol before it reaches the authored point.
		tolerance = minf(maxf(tolerance, agent.target_desired_distance), NAVIGATION_ARRIVAL_TOLERANCE)
	var distance := global_position.distance_to(target)
	if not is_finite(distance):
		return false
	if distance <= tolerance:
		velocity = Vector3.ZERO
		return true
	var next_position := target
	if agent != null and _navigation_map_ready(agent):
		agent.target_position = target
		var candidate := agent.get_next_path_position()
		# An unmapped NavigationAgent3D can return its previous map origin.  Use
		# it only when it is a finite step that actually gets closer to the
		# authored target; otherwise the bounded direct fallback keeps fixtures
		# and agents outside a synchronized NavigationRegion3D moving safely.
		var current_target_distance := global_position.distance_to(target)
		var candidate_target_distance := candidate.distance_to(target) if candidate.is_finite() else INF
		if (
			candidate.is_finite()
			and candidate.distance_to(global_position) > 0.000001
			and is_finite(candidate_target_distance)
			and candidate_target_distance < current_target_distance
		):
			next_position = candidate
	var direction := next_position - global_position
	if not direction.is_finite() or direction.length_squared() <= 0.000001:
		direction = target - global_position
	if direction.length_squared() <= 0.000001:
		velocity = Vector3.ZERO
		return true
	direction = direction.normalized()
	# `move_and_slide()` derives its step from the engine physics clock.  Brain
	# ticks are also driven by deterministic callers (tests, cut-scenes, and
	# low-frequency AI updates), so use the bounded routine delta explicitly
	# while retaining CharacterBody collision resolution.
	var motion := direction * bounded_speed * bounded_delta
	velocity = motion / bounded_delta
	move_and_collide(motion, false, 0.001, false, 1)
	velocity = Vector3.ZERO
	return global_position.distance_to(target) <= tolerance


## NavigationAgent3D emits runtime errors when path queries happen before its
## map has completed at least one synchronization iteration.  Route fixtures
## and enemies outside a NavigationRegion3D intentionally use the bounded
## direct-target fallback until the map is ready.
static func _navigation_map_ready(agent: NavigationAgent3D) -> bool:
	if agent == null or not is_instance_valid(agent):
		return false
	var navigation_map := agent.get_navigation_map()
	if not navigation_map.is_valid():
		return false
	return NavigationServer3D.map_get_iteration_id(navigation_map) > 0
func face_routine_direction(direction: Vector3, delta: float = 0.016) -> void:
	if not direction.is_finite() or direction.length_squared() <= 0.000001 or not is_finite(delta) or delta <= 0.0:
		return
	var planar := Vector3(direction.x, 0.0, direction.z)
	if planar.length_squared() <= 0.000001:
		return
	var desired_yaw := atan2(-planar.x, -planar.z)
	rotation.y = lerp_angle(rotation.y, desired_yaw, clampf(delta * 12.0, 0.0, 1.0))


func alert_state() -> Enums.AlertState:
	var enemy_brain := brain()
	return enemy_brain.alert_state() if enemy_brain != null else Enums.AlertState.UNAWARE


func set_incapacitated(kind: StringName, duration_seconds: float = 0.0) -> bool:
	var enemy_brain := brain()
	return enemy_brain != null and enemy_brain.set_incapacitated(kind, duration_seconds)


## Persistent body anomaly exposed to visual observers.  The object identity is
## stable for this body, so MissionDirector can count a corpse once even when
## more than one visual scan or Anomaly wrapper reaches the AI.
func corpse_anomaly() -> Anomaly:
	var enemy_brain := brain()
	if (
		enemy_brain == null
		or enemy_brain.incapacitated_kind() != &"dead"
		or not global_position.is_finite()
	):
		return null
	if _corpse_anomaly == null:
		_corpse_anomaly = Anomaly.create(
			Enums.AnomalyKind.CORPSE,
			global_position,
			self,
			3,
		)
	else:
		_corpse_anomaly.position = global_position
	if not _corpse_anomaly_registered and is_inside_tree():
		var event_bus := get_node_or_null(NodePath("/root/EventBus"))
		if event_bus != null and event_bus.has_signal(&"anomaly_registered"):
			event_bus.emit_signal(&"anomaly_registered", _corpse_anomaly)
			_corpse_anomaly_registered = true
	return _corpse_anomaly


func set_incapacitation_wake_by_noise(value: bool) -> void:
	var enemy_brain := brain()
	if enemy_brain != null:
		enemy_brain.set_incapacitation_wake_by_noise(value)


func can_be_assassinated() -> bool:
	var enemy_brain := brain()
	return (
		not _assassination_locked
		and not _assassinated
		and enemy_brain != null
		and not enemy_brain.is_incapacitated()
		and enemy_brain.incapacitated_kind() != &"dead"
		and alert_state() != Enums.AlertState.COMBAT
	)


## Lock and resolve a deterministic assassination.  Animation/camera systems
## can use the exposed context and state while the target is already dead to
## prevent duplicate confirmation inputs or a second kill.
func begin_assassination(context: StringName) -> bool:
	if context not in [&"back", &"above", &"below", &"corner"] or not can_be_assassinated():
		return false
	var enemy_brain := brain()
	if enemy_brain == null or not enemy_brain.set_incapacitated(&"dead"):
		return false
	_assassination_locked = true
	_assassinated = true
	_assassination_context = context
	var event_bus := get_node_or_null(NodePath("/root/EventBus"))
	if event_bus != null and event_bus.has_signal(&"enemy_killed"):
		event_bus.emit_signal(&"enemy_killed", self, "assassination")
	corpse_anomaly()
	return true


func is_assassinating() -> bool:
	return _assassination_locked


func assassination_state() -> StringName:
	return &"Assassinate" if _assassination_locked else &""


func is_assassinated() -> bool:
	return _assassinated


func assassination_context() -> StringName:
	return _assassination_context


func hearing_position() -> Vector3:
	var perception := get_node_or_null(NodePath("Perception")) as EnemyPerception
	if perception != null:
		var eye := perception.get_node_or_null(NodePath("EyePoint")) as Node3D
		if eye != null:
			return eye.global_position
	return global_position
