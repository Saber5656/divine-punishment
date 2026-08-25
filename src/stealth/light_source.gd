@tool
class_name LightSource
extends Area3D


const INTERACTABLE_LAYER := 1 << 6
const PLAYER_BODY_LAYER := 1 << 1
const ENEMY_BODY_LAYER := 1 << 2
const MIN_INTERACTION_RADIUS := 0.1
const MAX_INTERACTION_RADIUS := 2.0
const UNIT_SCALE_TOLERANCE := 0.001
const INTERACTION_SHAPE_NODE_NAME := &"_InteractionShape"


@export_range(0.1, 100.0, 0.1) var gameplay_radius: float = 6.0:
	set(value):
		gameplay_radius = value
		if Engine.is_editor_hint() and is_inside_tree():
			update_gizmos()
@export_range(0.0, 10.0, 0.05) var gameplay_intensity: float = 1.0
@export_range(MIN_INTERACTION_RADIUS, MAX_INTERACTION_RADIUS, 0.05) var interaction_radius: float = 1.0:
	set(value):
		interaction_radius = value
		_sync_interaction_shape()
		_update_editor_state()
@export var render_light: Light3D
@export var starts_extinguished: bool = false
@export var extinguishable: bool = true

var _interaction_shape: CollisionShape3D
var _expected_interaction_shape: SphereShape3D
var _is_on := true


func _enter_tree() -> void:
	collision_layer = INTERACTABLE_LAYER
	collision_mask = PLAYER_BODY_LAYER
	monitoring = true
	monitorable = true
	_ensure_interaction_shape()
	if not is_in_group(&"lights"):
		add_to_group(&"lights")
	_update_editor_state()


func _ready() -> void:
	if render_light == null:
		render_light = _find_render_light()
	if starts_extinguished:
		_is_on = false
	_sync_render_light()


func is_on() -> bool:
	return _is_on


func set_extinguished(extinguished: bool) -> void:
	if _is_on == (not extinguished):
		return
	_is_on = not extinguished
	_sync_render_light()
	if not is_inside_tree() or not has_node("/root/EventBus"):
		return
	if _is_on:
		EventBus.light_relit.emit(self)
	else:
		var anomaly := Anomaly.create(
			Enums.AnomalyKind.LIGHT_OUT,
			global_position,
			self,
			1,
		)
		EventBus.anomaly_registered.emit(anomaly)
		EventBus.light_extinguished.emit(self)


func can_accept_body(body: CollisionObject3D) -> bool:
	return (
		body != null
		and is_instance_valid(body)
		and body.is_inside_tree()
		and body.get_tree() == get_tree()
		and is_geometry_valid()
		and collision_layer == INTERACTABLE_LAYER
		and collision_mask == PLAYER_BODY_LAYER
		and (body.collision_layer & PLAYER_BODY_LAYER) != 0
		and (body.collision_layer & ENEMY_BODY_LAYER) == 0
		and (body.collision_layer & INTERACTABLE_LAYER) == 0
	)


func is_near_interaction(world_position: Vector3) -> bool:
	return (
		is_geometry_valid()
		and _is_finite_vector(world_position)
		and global_position.distance_squared_to(world_position)
			<= interaction_radius * interaction_radius
	)


func can_interact(actor: Node3D) -> bool:
	if not is_on() or not extinguishable or actor == null or not is_instance_valid(actor):
		return false
	var body := actor as CollisionObject3D
	return body != null and can_accept_body(body) and is_near_interaction(actor.global_position)


func try_extinguish(actor: Node3D) -> bool:
	if not can_interact(actor):
		return false
	set_extinguished(true)
	return true


func request_relight(requester: Node) -> bool:
	if (
		is_on()
		or requester == null
		or not is_instance_valid(requester)
		or not requester.is_inside_tree()
		or requester.get_tree() != get_tree()
		or requester == self
		or not has_node("/root/EventBus")
	):
		return false
	EventBus.light_relight_requested.emit(RelightRequest.create(self, requester))
	return true


func is_geometry_valid() -> bool:
	return (
		is_inside_tree()
		and is_world_transform_within_contract(global_transform)
		and is_finite(gameplay_radius)
		and gameplay_radius > 0.0
		and is_finite(gameplay_intensity)
		and gameplay_intensity >= 0.0
		and is_finite(interaction_radius)
		and interaction_radius >= MIN_INTERACTION_RADIUS
		and interaction_radius <= MAX_INTERACTION_RADIUS
		and _is_interaction_shape_valid()
	)


func gameplay_contribution(distance: float, occluded: bool) -> float:
	if not _is_on:
		return 0.0
	return PlayerVisibility.light_contribution(distance, gameplay_radius, occluded) * gameplay_intensity


func gizmo_segments() -> PackedVector3Array:
	if not is_finite(gameplay_radius) or gameplay_radius <= 0.0:
		return PackedVector3Array()
	var segments := PackedVector3Array()
	const SEGMENT_COUNT := 32
	for index in SEGMENT_COUNT:
		var start_angle := TAU * float(index) / SEGMENT_COUNT
		var end_angle := TAU * float(index + 1) / SEGMENT_COUNT
		segments.append(Vector3(cos(start_angle), 0.0, sin(start_angle)) * gameplay_radius)
		segments.append(Vector3(cos(end_angle), 0.0, sin(end_angle)) * gameplay_radius)
	return segments


func _find_render_light() -> Light3D:
	for child in get_children():
		if child is Light3D:
			return child as Light3D
	return null


func _sync_render_light() -> void:
	if render_light != null:
		render_light.visible = _is_on


func _ensure_interaction_shape() -> void:
	if not is_instance_valid(_interaction_shape):
		_interaction_shape = get_node_or_null(
			NodePath(String(INTERACTION_SHAPE_NODE_NAME)),
		) as CollisionShape3D
	if _interaction_shape == null:
		_interaction_shape = CollisionShape3D.new()
		_interaction_shape.name = INTERACTION_SHAPE_NODE_NAME
		add_child(_interaction_shape, false, Node.INTERNAL_MODE_BACK)
	if _interaction_shape.shape is not SphereShape3D:
		_interaction_shape.shape = SphereShape3D.new()
	_expected_interaction_shape = _interaction_shape.shape as SphereShape3D
	_sync_interaction_shape()


func _sync_interaction_shape() -> void:
	if not is_instance_valid(_interaction_shape):
		return
	var sphere := _interaction_shape.shape as SphereShape3D
	if sphere == null:
		return
	var safe_radius := interaction_radius if is_finite(interaction_radius) else MIN_INTERACTION_RADIUS
	sphere.radius = clampf(safe_radius, MIN_INTERACTION_RADIUS, MAX_INTERACTION_RADIUS)
	_interaction_shape.position = Vector3.ZERO


func _is_interaction_shape_valid() -> bool:
	if not is_instance_valid(_interaction_shape) or not is_instance_valid(_expected_interaction_shape):
		return false
	var sphere := _interaction_shape.shape as SphereShape3D
	return (
		sphere != null
		and _interaction_shape.get_parent() == self
		and _interaction_shape.is_inside_tree()
		and _interaction_shape.get_tree() == get_tree()
		and not _interaction_shape.disabled
		and _interaction_shape.shape == _expected_interaction_shape
		and _interaction_shape.transform.is_equal_approx(Transform3D.IDENTITY)
		and is_finite(sphere.radius)
		and is_equal_approx(sphere.radius, interaction_radius)
	)


static func is_world_transform_within_contract(world_transform: Transform3D) -> bool:
	if not _is_finite_vector(world_transform.origin):
		return false
	var axes: Array[Vector3] = [world_transform.basis.x, world_transform.basis.y, world_transform.basis.z]
	for axis: Vector3 in axes:
		if not _is_finite_vector(axis) or absf(axis.length() - 1.0) > UNIT_SCALE_TOLERANCE:
			return false
	return (
		absf(axes[0].dot(axes[1])) <= UNIT_SCALE_TOLERANCE
		and absf(axes[0].dot(axes[2])) <= UNIT_SCALE_TOLERANCE
		and absf(axes[1].dot(axes[2])) <= UNIT_SCALE_TOLERANCE
		and absf(absf(world_transform.basis.determinant()) - 1.0) <= UNIT_SCALE_TOLERANCE
	)


static func _is_finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not is_geometry_valid():
		warnings.append(
			"LightSource requires finite gameplay values, a %.2f–%.2f m interaction radius, and a unit-scale world transform."
			% [MIN_INTERACTION_RADIUS, MAX_INTERACTION_RADIUS],
		)
	return warnings


func _update_editor_state() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		update_configuration_warnings()
		update_gizmos()
