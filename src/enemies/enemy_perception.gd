class_name EnemyPerception
extends Node


const PerceptionFormulasScript := preload("res://src/core/perception_formulas.gd")
const PerceptionStimulusScript := preload("res://src/enemies/perception_stimulus.gd")

# Collision layers are one-based in the content contract and bit-based in
# Godot.  Vision must see world geometry and authored vision blockers only.
const VISION_OCCLUSION_MASK := (1 << 0) | (1 << 4)
const UPDATE_INTERVAL := 0.1
const LOD_UPDATE_INTERVAL := 0.5
const LOD_DISTANCE := 30.0
const CENTRAL_VIEW_DEGREES := 35.0
const MAX_DETECTION_POINTS := 3
const MAX_RAYCASTS_PER_UPDATE := MAX_DETECTION_POINTS
const MAX_METER := 3.0

signal stimulus(stim: PerceptionStimulus)

@export var perception_config: PerceptionConfig = PerceptionConfig.new()
@export var player_path: NodePath

var _meter := 0.0
var _elapsed := 0.0
var _player_override: Node3D


func _ready() -> void:
	# The brain owns the update loop.  Perception is deliberately not driven by
	# _process so a brain can apply the 10 Hz / 2 Hz distance LOD centrally.
	set_process(false)


func tick(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0:
		return
	if not _valid_config():
		return

	var target := _player_target()
	var interval := UPDATE_INTERVAL
	if target != null and _distance_to_target(target) > LOD_DISTANCE:
		interval = LOD_UPDATE_INTERVAL
	_elapsed += delta
	if _elapsed < interval:
		return

	var step_delta := _elapsed
	_elapsed = 0.0
	_evaluate_visual(step_delta, target)


func on_noise(event: NoiseEvent) -> void:
	# NoiseEventSystem delivers already distance/occlusion-filtered events
	# directly to this method.  Do not subscribe to EventBus.noise_emitted here:
	# that signal is telemetry and subscribing would count every noise twice.
	if event == null or not _valid_config():
		return
	if not _valid_vector(event.position) or not is_finite(event.radius) or event.radius <= 0.0:
		return
	if event.kind < Enums.NoiseKind.FOOTSTEP or event.kind > Enums.NoiseKind.FIREWORK:
		return
	if _is_self_noise(event.source):
		return

	var eye := _eye_point()
	if eye == null or not _valid_vector(eye.global_position):
		return
	var distance := eye.global_position.distance_to(event.position)
	var confidence := PerceptionFormulasScript.sound_contribution(distance, event.radius, 0)
	confidence = clampf(confidence * perception_config.hearing_multiplier, 0.0, 1.0)
	if confidence <= 0.0:
		return

	var priority := 1
	if event.kind == Enums.NoiseKind.COMBAT or event.kind == Enums.NoiseKind.SCREAM:
		priority = 3
	_emit_stimulus(
		Enums.StimulusKind.NOISE,
		priority,
		event.position,
		confidence,
	)


func meter() -> float:
	return _meter


func set_player_target(target: Node3D) -> void:
	_player_override = target


func set_perception_config(config: PerceptionConfig) -> void:
	perception_config = config


static func vision_gain(
	visibility: float,
	distance: float,
	view_dist: float,
	central: bool,
	base_gain: float,
) -> float:
	return PerceptionFormulasScript.vision_gain(
		visibility,
		distance,
		view_dist,
		central,
		base_gain,
	)


func _evaluate_visual(delta: float, target: Node3D) -> void:
	if target == null or not is_instance_valid(target):
		_advance_meter(delta, 0.0, false, Vector3.ZERO)
		return
	if target.has_method(&"is_visibility_excluded") and bool(target.call(&"is_visibility_excluded")):
		_advance_meter(delta, 0.0, false, target.global_position)
		return

	var eye := _eye_point()
	var points := _detection_points(target)
	if eye == null or points.size() != MAX_DETECTION_POINTS:
		# A malformed scene must never produce a false positive.
		_advance_meter(delta, 0.0, false, Vector3.ZERO)
		return
	if not _valid_vector(eye.global_position):
		_advance_meter(delta, 0.0, false, Vector3.ZERO)
		return

	var center := (points[1] as Node3D).global_position
	if not _valid_vector(center):
		_advance_meter(delta, 0.0, false, Vector3.ZERO)
		return
	var to_center := center - eye.global_position
	var distance := to_center.length()
	if not is_finite(distance) or distance <= 0.0 or distance > perception_config.view_distance_m:
		_advance_meter(delta, 0.0, false, center)
		return

	var enemy_root := get_parent() as Node3D
	if enemy_root == null:
		_advance_meter(delta, 0.0, false, center)
		return
	var forward: Vector3 = -enemy_root.global_transform.basis.z
	if not _valid_vector(forward) or forward.length_squared() <= 0.000001:
		_advance_meter(delta, 0.0, false, center)
		return
	forward = forward.normalized()
	var direction := to_center / distance
	var dot_value := clampf(forward.dot(direction), -1.0, 1.0)
	var angle_degrees := rad_to_deg(acos(dot_value))
	if not is_finite(angle_degrees) or angle_degrees > perception_config.fov_degrees * 0.5:
		_advance_meter(delta, 0.0, false, center)
		return

	var visibility_value := _player_visibility(target)
	if visibility_value <= 0.0:
		_advance_meter(delta, 0.0, false, center)
		return

	var exclusions := _ray_exclusions(target)
	var visible_points := 0
	for point_index in points.size():
		var point := points[point_index] as Node3D
		if _point_visible(eye.global_position, point.global_position, exclusions):
			visible_points += 1

	var visible_fraction := float(visible_points) / float(MAX_DETECTION_POINTS)
	var visible := visible_points > 0 and visible_fraction > 0.0
	var central := angle_degrees <= CENTRAL_VIEW_DEGREES
	var gain := vision_gain(
		visibility_value * visible_fraction,
		distance,
		perception_config.view_distance_m,
		central,
		perception_config.meter_gain_base,
	)
	_advance_meter(delta, gain, visible and gain > 0.0, center)


func _advance_meter(delta: float, gain: float, visible: bool, stimulus_position: Vector3) -> void:
	var old_meter := _meter
	_meter = PerceptionFormulasScript.meter_step(
		_meter,
		delta,
		gain,
		perception_config.meter_decay,
		visible,
		MAX_METER,
	)
	if not is_finite(_meter):
		_meter = 0.0
	_emit_visual_threshold_crossing(old_meter, _meter, stimulus_position)


func _emit_visual_threshold_crossing(old_meter: float, new_meter: float, position: Vector3) -> void:
	if not _valid_vector(position) or new_meter <= old_meter:
		return
	var threshold := -1.0
	var priority := 0
	if old_meter < perception_config.combat_threshold and new_meter >= perception_config.combat_threshold:
		threshold = perception_config.combat_threshold
		priority = 4
	elif old_meter < perception_config.search_threshold and new_meter >= perception_config.search_threshold:
		threshold = perception_config.search_threshold
		priority = 2
	elif old_meter < perception_config.suspicious_threshold and new_meter >= perception_config.suspicious_threshold:
		threshold = perception_config.suspicious_threshold
		priority = 1
	if threshold < 0.0 or priority == 0:
		return
	var confidence := clampf(new_meter / MAX_METER, 0.0, 1.0)
	_emit_stimulus(Enums.StimulusKind.VISUAL, priority, position, confidence)


func _emit_stimulus(
	kind: Enums.StimulusKind,
	priority: int,
	position: Vector3,
	confidence: float,
) -> void:
	var created := PerceptionStimulusScript.create(kind, priority, position, confidence)
	stimulus.emit(created)


func _valid_config() -> bool:
	if perception_config == null:
		return false
	return (
		is_finite(perception_config.fov_degrees)
		and perception_config.fov_degrees > 0.0
		and perception_config.fov_degrees <= 360.0
		and is_finite(perception_config.view_distance_m)
		and perception_config.view_distance_m > 0.0
		and is_finite(perception_config.meter_gain_base)
		and perception_config.meter_gain_base >= 0.0
		and is_finite(perception_config.meter_decay)
		and perception_config.meter_decay >= 0.0
		and is_finite(perception_config.suspicious_threshold)
		and is_finite(perception_config.search_threshold)
		and is_finite(perception_config.combat_threshold)
		and perception_config.suspicious_threshold >= 0.0
		and perception_config.suspicious_threshold <= perception_config.search_threshold
		and perception_config.search_threshold <= perception_config.combat_threshold
		and perception_config.combat_threshold <= MAX_METER
		and is_finite(perception_config.hearing_multiplier)
		and perception_config.hearing_multiplier >= 0.0
	)


func _eye_point() -> Node3D:
	var candidate := get_node_or_null(NodePath("EyePoint"))
	if candidate is Node3D:
		return candidate as Node3D
	return null


func _detection_points(target: Node3D) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for point_name in [&"Head", &"Chest", &"Hips"]:
		var candidate := target.get_node_or_null(NodePath("DetectPoints/%s" % point_name))
		if not candidate is Node3D:
			return []
		result.append(candidate as Node3D)
	return result


func _player_target() -> Node3D:
	if _player_override != null and is_instance_valid(_player_override):
		return _player_override
	if player_path != NodePath():
		var configured := get_node_or_null(player_path)
		if configured is Node3D:
			return configured as Node3D
		return null
	var tree := get_tree()
	if tree == null:
		return null
	var best: Node3D
	var best_distance := INF
	var eye := _eye_point()
	if eye == null:
		return null
	for marker in tree.get_nodes_in_group(&"player_detect_points"):
		if not marker is Node3D:
			continue
		var candidate := (marker as Node3D).get_parent()
		if not candidate is Node3D or candidate == get_parent():
			continue
		var distance := eye.global_position.distance_to((candidate as Node3D).global_position)
		if is_finite(distance) and distance < best_distance:
			best_distance = distance
			best = candidate as Node3D
	return best


func _distance_to_target(target: Node3D) -> float:
	var eye := _eye_point()
	if eye == null or target == null:
		return INF
	var distance := eye.global_position.distance_to(target.global_position)
	return distance if is_finite(distance) else INF


func _player_visibility(target: Node3D) -> float:
	var visibility_node: Node = target.get_node_or_null(NodePath("Visibility"))
	var value: Variant
	if visibility_node != null and visibility_node.has_method(&"visibility"):
		value = visibility_node.call(&"visibility")
	elif target.has_method(&"visibility"):
		value = target.call(&"visibility")
	else:
		return 0.0
	if not value is float and not value is int:
		return 0.0
	var result := float(value)
	return clampf(result, 0.0, 1.0) if is_finite(result) else 0.0


func _ray_exclusions(target: Node3D) -> Array[RID]:
	var result: Array[RID] = []
	var enemy_root := get_parent()
	if enemy_root is CollisionObject3D:
		result.append((enemy_root as CollisionObject3D).get_rid())
	if target is CollisionObject3D:
		result.append((target as CollisionObject3D).get_rid())
	return result


func _point_visible(from: Vector3, to: Vector3, exclusions: Array[RID]) -> bool:
	if not _valid_vector(from) or not _valid_vector(to):
		return false
	var owner := get_parent() as Node3D
	if owner == null:
		return false
	var world := owner.get_world_3d()
	if world == null:
		return false
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = VISION_OCCLUSION_MASK
	query.exclude = exclusions
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	return hit.is_empty()


func _is_self_noise(source: Node) -> bool:
	if source == null:
		return false
	var owner := get_parent()
	if source == self or source == owner:
		return true
	if source is Node and owner is Node:
		return (source as Node).is_ancestor_of(owner as Node) or (owner as Node).is_ancestor_of(source as Node)
	return false


static func _valid_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
