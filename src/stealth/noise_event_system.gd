class_name NoiseEventSystem
extends RefCounted


# NoiseEventSystem is the single gameplay dispatcher: EventBus is emitted once
# for telemetry, then eligible enemies receive one attenuated callback directly.
# Enemy perception components must implement on_noise without subscribing to the
# raw EventBus signal, otherwise one sound would be counted twice.
# Collision layer 6 is represented by bit 5 in Godot's collision mask.
const HEARING_OCCLUSION_MASK := 1 << 5
const OCCLUDED_RADIUS_MULTIPLIER := 0.5
const MAX_OCCLUSION_HITS := 16


static func emit(event: NoiseEvent, tree: SceneTree = null) -> NoiseEvent:
	if not _valid_event(event):
		return event
	EventBus.noise_emitted.emit(event)
	if tree != null:
		deliver_to_enemies(tree, event)
	return event


static func deliver_to_enemies(tree: SceneTree, event: NoiseEvent) -> void:
	if tree == null or not _valid_event(event):
		return
	for listener in tree.get_nodes_in_group("enemies"):
		if not listener.has_method("on_noise"):
			continue
		var listener_position := _listener_position(listener)
		if not _valid_vector(listener_position):
			continue
		var effective_radius := radius_at_listener(
			tree,
			event.position,
			listener_position,
			event.radius,
			event.source,
		)
		if event.position.distance_to(listener_position) > effective_radius:
			continue
		var delivered := NoiseEvent.create(event.position, effective_radius, event.kind, event.source)
		listener.on_noise(delivered)


static func radius_at_listener(
	tree: SceneTree,
	origin: Vector3,
	listener_position: Vector3,
	base_radius: float,
	source: Node = null,
) -> float:
	if (
		not _valid_vector(origin)
		or not _valid_vector(listener_position)
		or not is_finite(base_radius)
		or base_radius <= 0.0
	):
		return 0.0
	if tree == null or tree.get_root() == null:
		return base_radius
	var scene := tree.current_scene
	var world: World3D = null
	if scene is Node3D:
		world = (scene as Node3D).get_world_3d()
	if world == null and source is Node3D:
		world = (source as Node3D).get_world_3d()
	if world == null:
		for listener in tree.get_nodes_in_group("enemies"):
			if listener is Node3D:
				world = (listener as Node3D).get_world_3d()
				break
	if world == null:
		return base_radius
	var segment := listener_position - origin
	var remaining := segment.length()
	if remaining <= 0.001:
		return base_radius
	var direction := segment / remaining
	var current_origin := origin
	var exclusion_rids := _source_exclusion_rids(source)
	var blocker_count := 0
	for _index in MAX_OCCLUSION_HITS:
		if remaining <= 0.001:
			break
		var query := PhysicsRayQueryParameters3D.create(current_origin, listener_position)
		query.collision_mask = HEARING_OCCLUSION_MASK
		query.exclude = exclusion_rids
		var hit := world.direct_space_state.intersect_ray(query)
		if hit.is_empty():
			break
		var hit_position: Variant = hit.get(&"position", listener_position)
		if not hit_position is Vector3:
			break
		var advanced := (hit_position as Vector3).distance_to(current_origin)
		if advanced <= 0.0001:
			break
		var hit_rid: Variant = hit.get(&"rid")
		if hit_rid is RID:
			exclusion_rids.append(hit_rid as RID)
		blocker_count += 1
		current_origin = (hit_position as Vector3) + direction * 0.001
		remaining = current_origin.distance_to(listener_position)
	return base_radius * pow(OCCLUDED_RADIUS_MULTIPLIER, blocker_count)


static func _source_exclusion_rids(source: Node) -> Array[RID]:
	var result: Array[RID] = []
	var cursor := source
	while cursor != null:
		if cursor is CollisionObject3D:
			result.append((cursor as CollisionObject3D).get_rid())
			break
		cursor = cursor.get_parent()
	return result


static func _listener_position(listener: Node) -> Vector3:
	if listener.has_method("hearing_position"):
		return listener.hearing_position()
	if listener is Node3D:
		return (listener as Node3D).global_position
	return Vector3.ZERO


static func _valid_event(event: NoiseEvent) -> bool:
	return (
		event != null
		and _valid_vector(event.position)
		and is_finite(event.radius)
		and event.radius > 0.0
		and event.kind >= Enums.NoiseKind.FOOTSTEP
		and event.kind <= Enums.NoiseKind.FIREWORK
	)


static func _valid_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
