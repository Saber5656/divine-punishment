class_name ToolBase
extends Node3D


## Runtime root for a ToolDefinition.effect_scene.
##
## The framework intentionally does not prescribe a hit/effect implementation.
## Concrete tools (Issue #33) override `_apply_effect` while retaining this
## validation and use contract.
signal used(user: Node3D, aim: Dictionary)

const MAX_IMPACT_DISTANCE := 24.0
const PROJECTILE_COLLISION_MASK := (1 << 0) | (1 << 2) | (1 << 6)

@export var tool_definition: ToolDefinition


func definition() -> ToolDefinition:
	return tool_definition


func use(user: Node3D, aim: Dictionary) -> bool:
	if not _is_runtime_node(user) or tool_definition == null or not _valid_aim(aim):
		return false
	_apply_effect({
		&"user": user,
		&"origin": aim[&"origin"],
		&"dir": aim[&"dir"],
		&"target": aim.get(&"target"),
	})
	used.emit(user, aim)
	return true


func _apply_effect(_hit: Dictionary) -> void:
	# Concrete effects own projectile spawning, collision response, and gameplay
	# consequences.  The base implementation is a successful no-op so the
	# framework can be exercised before Issue #33 supplies individual tools.
	pass


func _impact_hit(hit: Dictionary, max_distance: float = MAX_IMPACT_DISTANCE) -> Dictionary:
	var origin: Variant = hit.get(&"origin", Vector3.ZERO)
	var direction: Variant = hit.get(&"dir", Vector3.FORWARD)
	if not origin is Vector3 or not direction is Vector3:
		return {&"position": Vector3.ZERO, &"collider": null}
	var safe_origin := origin as Vector3
	var safe_direction := direction as Vector3
	if not safe_origin.is_finite() or not safe_direction.is_finite() or safe_direction.length_squared() <= 0.000001:
		return {&"position": Vector3.ZERO, &"collider": null}
	safe_direction = safe_direction.normalized()
	var bounded_distance := clampf(max_distance if is_finite(max_distance) else MAX_IMPACT_DISTANCE, 0.1, MAX_IMPACT_DISTANCE)
	var explicit_target: Variant = hit.get(&"target")
	if explicit_target is Node3D and _is_runtime_node(explicit_target as Node3D):
		var target_position := (explicit_target as Node3D).global_position
		if target_position.is_finite() and target_position.distance_to(safe_origin) <= bounded_distance:
			return {&"position": target_position, &"collider": explicit_target}
	var definition := tool_definition
	var path := trajectory_points_for_definition(definition, safe_origin, safe_direction, bounded_distance)
	if path.is_empty():
		path.append(safe_origin + safe_direction * bounded_distance)
	var world := _world_for_hit(hit)
	if world != null:
		var user: Variant = hit.get(&"user")
		var exclusions: Array[RID] = []
		if user is CollisionObject3D:
			exclusions.append((user as CollisionObject3D).get_rid())
		for index in range(1, path.size()):
			var from := path[index - 1]
			var to := path[index]
			if from.distance_squared_to(to) <= 0.000001:
				continue
			var query := PhysicsRayQueryParameters3D.create(from, to)
			query.collision_mask = PROJECTILE_COLLISION_MASK
			query.collide_with_areas = true
			query.exclude = exclusions
			var result := world.direct_space_state.intersect_ray(query)
			if result.is_empty():
				continue
			var impact: Variant = result.get(&"position")
			if impact is Vector3 and (impact as Vector3).is_finite():
				return {&"position": impact, &"collider": result.get(&"collider")}
	var endpoint := path[path.size() - 1]
	return {&"position": endpoint, &"collider": null}


static func trajectory_points_for_definition(
	definition: ToolDefinition,
	origin: Vector3,
	direction: Vector3,
	max_distance: float = MAX_IMPACT_DISTANCE,
) -> PackedVector3Array:
	if definition == null or not definition.supports_aiming() or not origin.is_finite() or not direction.is_finite():
		return PackedVector3Array()
	var safe_direction := direction.normalized()
	if safe_direction.length_squared() <= 0.000001:
		return PackedVector3Array()
	var speed := clampf(definition.projectile_speed, ToolDefinition.MIN_PROJECTILE_SPEED, ToolDefinition.MAX_PROJECTILE_SPEED)
	var duration := definition.trajectory_duration()
	var bounded_distance := clampf(max_distance if is_finite(max_distance) else MAX_IMPACT_DISTANCE, 0.1, MAX_IMPACT_DISTANCE)
	if speed > 0.0:
		duration = minf(duration, bounded_distance / speed)
	var points := PackedVector3Array()
	var count := definition.trajectory_sample_count()
	var velocity := safe_direction * speed
	for index in count:
		var t := duration * float(index) / float(count - 1)
		var point := origin + velocity * t + Vector3.DOWN * (0.5 * definition.trajectory_gravity * t * t)
		if not point.is_finite():
			return PackedVector3Array()
		points.append(point)
	return points


func _impact_position(hit: Dictionary, max_distance: float = MAX_IMPACT_DISTANCE) -> Vector3:
	return _impact_hit(hit, max_distance).get(&"position", Vector3.ZERO) as Vector3


func _impact_target(hit: Dictionary, max_distance: float = MAX_IMPACT_DISTANCE) -> Node:
	return _impact_hit(hit, max_distance).get(&"collider") as Node


func _world_for_hit(hit: Dictionary) -> World3D:
	var user: Variant = hit.get(&"user")
	if user is Node3D and (user as Node3D).get_world_3d() != null:
		return (user as Node3D).get_world_3d()
	if get_world_3d() != null:
		return get_world_3d()
	return null


func _is_runtime_node(node: Node) -> bool:
	return (
		node != null
		and is_instance_valid(node)
		and node.is_inside_tree()
		and node.get_tree() == get_tree()
	)


func _valid_aim(aim: Dictionary) -> bool:
	if not aim.has(&"origin") or not aim.has(&"dir"):
		return false
	var origin: Variant = aim[&"origin"]
	var direction: Variant = aim[&"dir"]
	if not origin is Vector3 or not direction is Vector3:
		return false
	var origin_vector := origin as Vector3
	var direction_vector := direction as Vector3
	return origin_vector.is_finite() and direction_vector.is_finite() and direction_vector.length_squared() > 0.000001
