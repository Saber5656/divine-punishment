class_name ArrowShot
extends Node3D

const SPEED := 12.0
var _direction := Vector3.FORWARD
var _source: WeakRef
var _remaining := 3.0
var _spent := false
var _launched := false

func _ready() -> void:
	add_to_group(&"enemy_arrows")
	var visual := MeshInstance3D.new()
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.01
	shaft.bottom_radius = 0.015
	shaft.height = 0.6
	shaft.radial_segments = 6
	visual.mesh = shaft
	visual.rotation.x = PI/2
	add_child(visual)

func launch(origin: Vector3,direction: Vector3,source: Node) -> bool:
	if not origin.is_finite() or not direction.is_finite() or direction.length_squared() < 0.0001: return false
	_launched = true
	global_position = origin
	_direction = direction.normalized()
	_source = weakref(source) if source != null else null
	look_at(origin+_direction,Vector3.FORWARD if absf(_direction.y)>0.99 else Vector3.UP)
	return true

func _physics_process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if not _launched or _spent or not is_finite(delta) or delta <= 0.0: return
	_remaining -= delta
	if _remaining <= 0.0:
		queue_free()
		return
	var destination := global_position+_direction*SPEED*minf(delta,0.1)
	var query := PhysicsRayQueryParameters3D.create(global_position,destination,1|2|16)
	var source: Object = _source.get_ref() if _source != null else null
	if source is CollisionObject3D: query.exclude = [source.get_rid()]
	var collision := get_world_3d().direct_space_state.intersect_ray(query)
	if not collision.is_empty():
		global_position = collision.position
		hit(collision.collider)
	else: global_position = destination

func hit(body: Node) -> void:
	if _spent: return
	_spent = true
	if body is PlayerController:
		body.combat.receive_damage(1,_source.get_ref() if _source != null else self)
	queue_free()
