class_name NoiseEventSystem
extends RefCounted


# Collision layer 6 is represented by bit 5 in Godot's collision mask.
const HEARING_OCCLUSION_MASK := 1 << 5
const OCCLUDED_RADIUS_MULTIPLIER := 0.5


static func emit(event: NoiseEvent, tree: SceneTree = null) -> NoiseEvent:
	EventBus.noise_emitted.emit(event)
	if tree != null:
		deliver_to_enemies(tree, event)
	return event


static func deliver_to_enemies(tree: SceneTree, event: NoiseEvent) -> void:
	for listener in tree.get_nodes_in_group("enemies"):
		if not listener.has_method("on_noise"):
			continue
		var listener_position := _listener_position(listener)
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
	if tree == null or tree.get_root() == null:
		return base_radius
	var scene := tree.current_scene
	var world: World3D = null
	if scene is Node3D:
		world = (scene as Node3D).get_world_3d()
	if world == null:
		return base_radius
	var query := PhysicsRayQueryParameters3D.create(origin, listener_position)
	query.collision_mask = HEARING_OCCLUSION_MASK
	if source != null:
		query.exclude = [source]
	if world.direct_space_state.intersect_ray(query).is_empty():
		return base_radius
	return base_radius * OCCLUDED_RADIUS_MULTIPLIER


static func _listener_position(listener: Node) -> Vector3:
	if listener.has_method("hearing_position"):
		return listener.hearing_position()
	if listener is Node3D:
		return (listener as Node3D).global_position
	return Vector3.ZERO
