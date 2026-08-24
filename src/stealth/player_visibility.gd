class_name PlayerVisibility
extends Node


const UPDATE_INTERVAL := 0.1
const MAX_LIGHTS := 3
const DETECTION_POINT_NAMES: Array[StringName] = [&"Head", &"Chest", &"Hips"]
const DARKNESS_FLOOR := 0.05
# Collision layers are numbered from one in the design docs, while Godot
# expects a bit mask (layer N is represented by 1 << (N - 1)).
const LIGHT_OCCLUSION_MASK := (1 << 0) | (1 << 4)

signal visibility_changed(v: float)

var _visibility := 0.0
var _elapsed := 0.0
var _soft_cover_modifier := 1.0


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < UPDATE_INTERVAL:
		return
	_elapsed = fmod(_elapsed, UPDATE_INTERVAL)
	recompute()


func visibility() -> float:
	return _visibility


func set_soft_cover_modifier(modifier: float) -> void:
	_soft_cover_modifier = clampf(modifier, 0.0, 1.0)


func soft_cover_modifier() -> float:
	return _soft_cover_modifier


func recompute() -> float:
	var player := get_parent() as Node3D
	if player == null or not is_inside_tree():
		return _visibility
	if player.has_method(&"is_visibility_excluded") and player.call(&"is_visibility_excluded"):
		_visibility = 0.0
		visibility_changed.emit(_visibility)
		return _visibility
	var chest := player.get_node_or_null("DetectPoints/Chest") as Node3D
	var target_position := chest.global_position if chest != null else player.global_position
	var detection_points := _detection_points(player, target_position)
	var candidates: Array[Dictionary] = []
	for node in get_tree().get_nodes_in_group("lights"):
		var light := node as LightSource
		if light == null or not light.is_on():
			continue
		var distance: float = light.global_position.distance_to(target_position)
		var unoccluded_base: float = light.gameplay_contribution(distance, false)
		if unoccluded_base > 0.0:
			candidates.append({
				&"light": light,
				&"distance": distance,
				&"base": unoccluded_base,
			})
	candidates.sort_custom(_sort_light_candidates)
	var contributions: Array[float] = []
	for index in mini(MAX_LIGHTS, candidates.size()):
		var candidate: Dictionary = candidates[index]
		var light: LightSource = candidate.get(&"light") as LightSource
		var distance: float = float(candidate.get(&"distance", 0.0))
		var base: float = light.gameplay_contribution(distance, false)
		base *= _light_visibility_factor(light.global_position, detection_points, player)
		if base > 0.0:
			contributions.append(base)
	var light_sum := 0.0
	for index in contributions.size():
		light_sum += contributions[index]
	light_sum = apply_darkness_floor(light_sum)
	var stance_mod := 1.0
	var move_mod := 1.0
	var state_machine := player.get("state_machine") as PlayerStateMachine
	if state_machine != null:
		var movement := state_machine.movement_params()
		stance_mod = float(movement.get(&"visibility_mod", 1.0))
		var velocity_value: Variant = player.get("velocity")
		var is_moving: bool = false
		if velocity_value is Vector3:
			is_moving = (velocity_value as Vector3).length_squared() > 0.0001
		move_mod = 1.0 if is_moving else _stationary_modifier(state_machine)
	_visibility = combine(light_sum, stance_mod, move_mod, _soft_cover_modifier)
	visibility_changed.emit(_visibility)
	return _visibility


static func light_contribution(dist: float, gameplay_radius: float, occluded: bool) -> float:
	if gameplay_radius <= 0.0 or dist >= gameplay_radius:
		return 0.0
	if occluded:
		return 0.0
	var attenuation := clampf(1.0 - dist / gameplay_radius, 0.0, 1.0)
	return attenuation


static func combine(light_sum: float, stance_mod: float, move_mod: float, cover_mod: float) -> float:
	return clampf(light_sum * stance_mod * move_mod * cover_mod, 0.0, 1.0)


func _stationary_modifier(state_machine: PlayerStateMachine) -> float:
	var profile := state_machine.player_profile
	if profile != null:
		return profile.stationary_visibility_mod
	var movement := Tuning.movement()
	return movement.stationary_visibility_mod if movement != null else 0.8


static func _sort_light_candidates(left: Dictionary, right: Dictionary) -> bool:
	return float(left.get(&"base", 0.0)) > float(right.get(&"base", 0.0))


static func apply_darkness_floor(light_sum: float) -> float:
	return maxf(light_sum, DARKNESS_FLOOR)


func _detection_points(player: Node3D, fallback: Vector3) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for point_name in DETECTION_POINT_NAMES:
		var point := player.get_node_or_null(NodePath("DetectPoints/%s" % point_name)) as Node3D
		if point != null:
			points.append(point.global_position)
	if points.is_empty():
		points.append(fallback)
	return points


func _light_visibility_factor(from: Vector3, points: Array[Vector3], player: Node3D) -> float:
	if points.is_empty():
		return 0.0
	var world_root := get_parent() as Node3D
	if world_root == null or world_root.get_world_3d() == null:
		return 1.0
	var space_state: PhysicsDirectSpaceState3D = world_root.get_world_3d().direct_space_state
	var visible_points := 0
	for point in points:
		var query := PhysicsRayQueryParameters3D.create(from, point)
		query.collision_mask = LIGHT_OCCLUSION_MASK
		query.exclude = [player]
		if space_state.intersect_ray(query).is_empty():
			visible_points += 1
	return float(visible_points) / float(points.size())
