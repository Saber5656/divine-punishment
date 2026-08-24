class_name PlayerVisibility
extends Node


const UPDATE_INTERVAL := 0.1
const MAX_LIGHTS := 3
const LIGHT_OCCLUSION_MASK := 1 | 5

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
	var chest := player.get_node_or_null("DetectPoints/Chest") as Node3D
	var target_position := chest.global_position if chest != null else player.global_position
	var contributions: Array[float] = []
	for node in get_tree().get_nodes_in_group("lights"):
		var light := node as LightSource
		if light == null or not light.is_on():
			continue
		var distance := light.global_position.distance_to(target_position)
		var base := light.gameplay_contribution(distance, _is_occluded(light.global_position, target_position, player))
		if base > 0.0:
			contributions.append(base)
	contributions.sort()
	contributions.reverse()
	var light_sum := 0.0
	for index in mini(MAX_LIGHTS, contributions.size()):
		light_sum += contributions[index]
	var stance_mod := 1.0
	var move_mod := 1.0
	var state_machine := player.get("state_machine") as PlayerStateMachine
	if state_machine != null:
		var movement := state_machine.movement_params()
		stance_mod = float(movement.get(&"visibility_mod", 1.0))
		var velocity_value: Variant = player.get("velocity")
		var is_moving := velocity_value is Vector3 and velocity_value.length_squared() > 0.0001
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


func _is_occluded(from: Vector3, to: Vector3, player: Node3D) -> bool:
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = LIGHT_OCCLUSION_MASK
	query.exclude = [player]
	return not space_state.intersect_ray(query).is_empty()
