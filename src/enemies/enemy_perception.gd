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
const MAX_SMOKE_VOLUMES := 16
const MAX_SCANNED_ANOMALIES := 64
const MAX_METER := 3.0

signal stimulus(stim: PerceptionStimulus)

@export var perception_config: PerceptionConfig
@export var tuning_kind: StringName = &"ashigaru"
@export var player_path: NodePath

var _meter := 0.0
var _elapsed := 0.0
var _player_override: Node3D
var _uses_tuning := false
var _manual_vigilance_multiplier := 1.0
var _target_visible := false
var _anomaly_scan_group_index := 0
var _anomaly_scan_offsets: Dictionary = {}


func _ready() -> void:
	# The brain owns the update loop.  Perception is deliberately not driven by
	# _process so a brain can apply the 10 Hz / 2 Hz distance LOD centrally.
	set_process(false)
	_bind_tuning_default()
	var event_bus := _event_bus()
	if event_bus != null:
		var callback := Callable(self, &"_on_anomaly_registered")
		if not event_bus.is_connected(&"anomaly_registered", callback):
			event_bus.connect(&"anomaly_registered", callback)


func _exit_tree() -> void:
	_disconnect_tuning()
	var event_bus := _event_bus()
	if event_bus != null:
		var callback := Callable(self, &"_on_anomaly_registered")
		if event_bus.is_connected(&"anomaly_registered", callback):
			event_bus.disconnect(&"anomaly_registered", callback)


func tick(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0:
		return
	if not _valid_config():
		_meter = 0.0
		_elapsed = 0.0
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
	_scan_persistent_anomalies()


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
	if event.kind == Enums.NoiseKind.FIREWORK:
		return
	if _is_self_noise(event.source):
		return

	var eye := _eye_point()
	if eye == null or not _valid_vector(eye.global_position):
		return
	var distance := eye.global_position.distance_to(event.position)
	var confidence := PerceptionFormulasScript.sound_contribution(distance, event.radius, 0)
	confidence = clampf(
		confidence * perception_config.hearing_multiplier * _vigilance_multiplier(),
		0.0,
		1.0,
	)
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


## Global anomaly notifications are telemetry-like input, not an automatic
## sighting.  Apply the same range, FOV, and world occlusion checks as visual
## perception before handing an anomaly to the brain.
func on_anomaly(anomaly: Anomaly) -> void:
	if anomaly == null or not _valid_anomaly(anomaly) or not _valid_config():
		return
	if _is_self_anomaly(anomaly.node):
		return
	if anomaly.node != null:
		if (
			not is_instance_valid(anomaly.node)
			or not anomaly.node.is_inside_tree()
			or anomaly.node.get_tree() != get_tree()
		):
			return
		if anomaly.node.has_method(&"is_geometry_valid") and not bool(anomaly.node.call(&"is_geometry_valid")):
			return
	if not _valid_vector(anomaly.position):
		return
	var visible := _anomaly_visible(anomaly.position, anomaly.node)
	if not visible:
		return
	var eye := _eye_point()
	if eye == null:
		return
	var distance := eye.global_position.distance_to(anomaly.position)
	if not is_finite(distance) or distance > perception_config.view_distance_m:
		return
	var priority := 1
	if anomaly.severity >= 3:
		priority = 3
	elif anomaly.severity >= 2:
		priority = 2
	var confidence := clampf(1.0 - distance / perception_config.view_distance_m, 0.0, 1.0)
	_emit_stimulus(
		Enums.StimulusKind.ANOMALY,
		priority,
		anomaly.position,
		confidence,
		anomaly,
	)


func _on_anomaly_registered(anomaly: Anomaly) -> void:
	on_anomaly(anomaly)


## EventBus delivers anomalies that are created after this component subscribes.
## Persistent markers, extinguished lights, and dead bodies also need a bounded
## periodic scan so an enemy that enters a scene later still reacts visually.
func _scan_persistent_anomalies() -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	var owner := get_parent()
	var groups: Array[StringName] = [&"anomaly_markers", &"lights", &"enemies"]
	var group_nodes: Array = []
	for group_name: StringName in groups:
		# The tree owns these arrays; do not retain or grow a cross-group work
		# list.  The rotating cursors below keep per-update processing bounded
		# even when an authored group contains many nodes.
		group_nodes.append(tree.get_nodes_in_group(group_name))
	var seen_nodes: Dictionary = {}
	var examined := 0
	var empty_group_rounds := 0
	while examined < MAX_SCANNED_ANOMALIES and empty_group_rounds < groups.size():
		var group_index := _anomaly_scan_group_index
		_anomaly_scan_group_index = posmod(_anomaly_scan_group_index + 1, groups.size())
		var group_name: StringName = groups[group_index]
		var nodes: Array = group_nodes[group_index]
		if nodes.is_empty():
			empty_group_rounds += 1
			continue
		empty_group_rounds = 0
		var offset := int(_anomaly_scan_offsets.get(group_name, 0))
		if offset >= nodes.size():
			offset = 0
		var candidate: Variant = nodes[offset]
		_anomaly_scan_offsets[group_name] = posmod(offset + 1, nodes.size())
		examined += 1
		if candidate == null or not is_instance_valid(candidate) or not candidate is Node3D:
			continue
		if candidate == owner:
			continue
		var node := candidate as Node3D
		var node_id := node.get_instance_id()
		if seen_nodes.has(node_id):
			continue
		seen_nodes[node_id] = true
		var anomaly := _persistent_anomaly_for(node)
		if anomaly != null:
			on_anomaly(anomaly)


func _persistent_anomaly_for(node: Node3D) -> Anomaly:
	if node == null or not is_instance_valid(node):
		return null
	for method_name in [&"current_anomaly", &"corpse_anomaly", &"anomaly"]:
		if not node.has_method(method_name):
			continue
		var result: Variant = node.call(method_name)
		if result is Anomaly:
			return result as Anomaly
	return null


func _valid_anomaly(anomaly: Anomaly) -> bool:
	if anomaly == null:
		return false
	if (
		anomaly.kind < Enums.AnomalyKind.CORPSE
		or anomaly.kind > Enums.AnomalyKind.KNOCKOUT
		or anomaly.severity < 1
		or anomaly.severity > 3
		or not is_finite(anomaly.expires_at)
		or anomaly.expires_at < 0.0
	):
		return false
	return anomaly.expires_at <= 0.0 or Time.get_ticks_msec() / 1000.0 < anomaly.expires_at


func meter() -> float:
	return _meter


func target_visible() -> bool:
	return _target_visible


## Check an authored search target using the same bounded FOV, smoke, and
## world-occlusion rules as anomaly perception.  Search logic must not treat a
## nearby marker as automatically visible because distance alone is not sight.
func can_see_position(position: Vector3) -> bool:
	if not _valid_config() or not _valid_vector(position):
		return false
	var eye := _eye_point()
	var owner := get_parent() as Node3D
	if eye == null or owner == null or not is_inside_tree() or not _valid_vector(eye.global_position):
		return false
	var to_target := position - eye.global_position
	var distance := to_target.length()
	if not is_finite(distance) or distance <= 0.0 or distance > perception_config.view_distance_m:
		return false
	var forward: Vector3 = -owner.global_transform.basis.z
	if not _valid_vector(forward) or forward.length_squared() <= 0.000001:
		return false
	forward = forward.normalized()
	var horizontal_forward := Vector3(forward.x, 0.0, forward.z)
	var horizontal_target := Vector3(to_target.x, 0.0, to_target.z)
	if horizontal_forward.length_squared() <= 0.000001:
		return false
	if horizontal_target.length_squared() > 0.000001:
		horizontal_forward = horizontal_forward.normalized()
		horizontal_target = horizontal_target.normalized()
		var dot_value := clampf(horizontal_forward.dot(horizontal_target), -1.0, 1.0)
		var angle_degrees := rad_to_deg(acos(dot_value))
		if not is_finite(angle_degrees) or angle_degrees > perception_config.fov_degrees * 0.5:
			return false
	if _is_smoke_blocked(eye.global_position, position):
		return false
	return _point_visible(eye.global_position, position, _ray_exclusions(null))


func set_vigilance_multiplier(value: float) -> void:
	if not is_finite(value):
		_manual_vigilance_multiplier = 1.0
		return
	_manual_vigilance_multiplier = clampf(value, 1.0, 4.0)


func vigilance_multiplier() -> float:
	return _manual_vigilance_multiplier


func set_player_target(target: Node3D) -> void:
	_player_override = target


func set_perception_config(config: PerceptionConfig) -> void:
	_disconnect_tuning()
	perception_config = config
	_target_visible = false


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
	# Track the latest sampled visibility independently of threshold crossings;
	# a saturated meter must not make a continuously visible target look lost.
	_target_visible = false
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
	var horizontal_forward := Vector3(forward.x, 0.0, forward.z)
	var horizontal_target := Vector3(to_center.x, 0.0, to_center.z)
	if horizontal_forward.length_squared() <= 0.000001:
		_advance_meter(delta, 0.0, false, center)
		return
	horizontal_forward = horizontal_forward.normalized()
	var angle_degrees := 0.0
	if horizontal_target.length_squared() > 0.000001:
		horizontal_target = horizontal_target.normalized()
		var dot_value := clampf(horizontal_forward.dot(horizontal_target), -1.0, 1.0)
		angle_degrees = rad_to_deg(acos(dot_value))
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
		if _is_smoke_blocked(eye.global_position, point.global_position):
			continue
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
	_target_visible = visible and gain > 0.0
	_advance_meter(delta, gain, _target_visible, center)


func _advance_meter(delta: float, gain: float, visible: bool, stimulus_position: Vector3) -> void:
	var old_meter := _meter
	_meter = PerceptionFormulasScript.meter_step(
		_meter,
		delta,
		gain * _vigilance_multiplier(),
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
	anomaly: Anomaly = null,
) -> void:
	var created := PerceptionStimulusScript.create(kind, priority, position, confidence, anomaly)
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


func _bind_tuning_default() -> void:
	if perception_config != null:
		return
	var tuning := _tuning_service()
	if tuning == null or not tuning.has_method(&"perception"):
		return
	_uses_tuning = true
	_refresh_tuning()
	var callback := Callable(self, &"_refresh_tuning")
	if not tuning.is_connected(&"reloaded", callback):
		tuning.connect(&"reloaded", callback)


func _refresh_tuning() -> void:
	if not _uses_tuning:
		return
	var tuning := _tuning_service()
	if tuning == null:
		return
	var config := tuning.call(&"perception", tuning_kind) as PerceptionConfig
	if config != null:
		perception_config = config


func _disconnect_tuning() -> void:
	if not _uses_tuning:
		return
	var tuning := _tuning_service()
	if tuning != null:
		var callback := Callable(self, &"_refresh_tuning")
		if tuning.is_connected(&"reloaded", callback):
			tuning.disconnect(&"reloaded", callback)
	_uses_tuning = false


func _tuning_service() -> Node:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath("Tuning"))


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
		var point := candidate as Node3D
		if not _valid_vector(point.global_position):
			return []
		result.append(point)
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


func _is_smoke_blocked(observer: Vector3, target: Vector3) -> bool:
	if not is_inside_tree() or not _valid_vector(observer) or not _valid_vector(target):
		return false
	var tree := get_tree()
	if tree == null:
		return false
	var checked := 0
	for node in tree.get_nodes_in_group(&"smoke_volumes"):
		if checked >= MAX_SMOKE_VOLUMES:
			break
		checked += 1
		if node != null and node.has_method(&"blocks_visibility") and bool(node.call(&"blocks_visibility", observer, target)):
			return true
	return false


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


func _anomaly_visible(position: Vector3, anomaly_node: Node3D) -> bool:
	var eye := _eye_point()
	var owner := get_parent() as Node3D
	if eye == null or owner == null or not _valid_vector(eye.global_position):
		return false
	var to_target := position - eye.global_position
	var distance := to_target.length()
	if not is_finite(distance) or distance <= 0.0 or distance > perception_config.view_distance_m:
		return false
	var forward: Vector3 = -owner.global_transform.basis.z
	if not _valid_vector(forward) or forward.length_squared() <= 0.000001:
		return false
	forward = forward.normalized()
	var horizontal_forward := Vector3(forward.x, 0.0, forward.z)
	var horizontal_target := Vector3(to_target.x, 0.0, to_target.z)
	if horizontal_forward.length_squared() <= 0.000001:
		return false
	if horizontal_target.length_squared() > 0.000001:
		horizontal_forward = horizontal_forward.normalized()
		horizontal_target = horizontal_target.normalized()
		var dot_value := clampf(horizontal_forward.dot(horizontal_target), -1.0, 1.0)
		var angle_degrees := rad_to_deg(acos(dot_value))
		if not is_finite(angle_degrees) or angle_degrees > perception_config.fov_degrees * 0.5:
			return false
	var exclusions := _ray_exclusions(anomaly_node)
	return _point_visible(eye.global_position, position, exclusions)


func _event_bus() -> Node:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath("EventBus"))


func _is_self_anomaly(source: Node) -> bool:
	var owner := get_parent()
	if source == null or not is_instance_valid(source) or owner == null:
		return false
	return source == owner or (source.is_inside_tree() and owner.is_ancestor_of(source))


func _is_self_noise(source: Node) -> bool:
	if source == null:
		return false
	var owner := get_parent()
	if source == self or source == owner:
		return true
	if source is Node and owner is Node:
		return (owner as Node).is_ancestor_of(source as Node)
	return false


func _vigilance_multiplier() -> float:
	var owner := get_parent()
	if owner == null:
		return 1.0
	var brain := owner.get_node_or_null(NodePath("Brain"))
	if brain == null or not brain.has_method(&"detection_multiplier"):
		return _manual_vigilance_multiplier
	var value: Variant = brain.call(&"detection_multiplier")
	if not value is float and not value is int:
		return 1.0
	var multiplier := float(value)
	return multiplier if is_finite(multiplier) and multiplier > 0.0 else 1.0


static func _valid_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
