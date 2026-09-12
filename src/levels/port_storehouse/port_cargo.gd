extends RigidBody3D

signal disposed
const HALF_SIZE := 0.35
var _holder: PlayerController
var _disposed := false
var _built := false
var _box_shape: BoxShape3D

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	mass = 8
	if not _built:
		_built = true
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		(shape.shape as BoxShape3D).size = Vector3.ONE*HALF_SIZE*2
		_box_shape = shape.shape as BoxShape3D
		add_child(shape)
		var mesh := MeshInstance3D.new()
		mesh.mesh = BoxMesh.new()
		(mesh.mesh as BoxMesh).size = Vector3.ONE*HALF_SIZE*2
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("654b42")
		mesh.material_override = material
		add_child(mesh)

func _physics_process(_delta: float) -> void:
	if _disposed: return
	if is_carried():
		if _holder.state_machine.current_state() not in [&"Ground",&"Crouch",&"Sprint"]:
			_release(Vector3.ZERO)
		else:
			_move_in_hands()
		return
	for volume: WaterVolume in get_tree().get_nodes_in_group(&"water_volumes"):
		if volume.contains_world_position(global_position) and global_position.y+HALF_SIZE < volume.surface_world_y():
			_disposed = true
			disposed.emit()
			return

func try_interact(player: PlayerController) -> bool:
	if _disposed or not is_instance_valid(player) or not player.is_inside_tree(): return false
	if _holder == player:
		_release(-player.global_basis.z)
		return true
	if is_carried() or player.state_machine.current_state() not in [&"Ground",&"Crouch"]: return false
	if player.global_position.distance_to(global_position) > 2.0: return false
	var query := PhysicsRayQueryParameters3D.create(player.global_position+Vector3.UP*0.4,global_position,1|16)
	query.exclude = [player.get_rid(),get_rid()]
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): return false
	_holder = player
	freeze = true
	collision_layer = 0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	return true

func _release(velocity: Vector3) -> void:
	_holder = null
	freeze = false
	collision_layer = 1
	linear_velocity = velocity
	angular_velocity = Vector3.ZERO

func is_carried() -> bool:
	return is_instance_valid(_holder) and _holder.is_inside_tree()

func is_disposed() -> bool:
	return _disposed

func capture_checkpoint_state() -> Dictionary:
	# A posture transition may precede this body's next physics tick.
	if is_carried() and _holder.state_machine.current_state() not in [&"Ground",&"Crouch",&"Sprint"]: _release(Vector3.ZERO)
	return {"disposed":_disposed,"carried":is_carried(),"position":_array(global_position),"rotation":_array(global_rotation),"velocity":_array(linear_velocity)}

func checkpoint_state_is_valid(value: Dictionary) -> bool:
	if not value.get("disposed") is bool or not value.get("carried") is bool: return false
	if value["disposed"] and value["carried"]: return false
	for key in ["position","rotation","velocity"]:
		if not value.get(key) is Array or value[key].size() != 3: return false
		for coordinate in value[key]:
			if not CheckpointSnapshot._finite_number(coordinate) or absf(float(coordinate)) > 10000: return false
	return true

func restore_checkpoint_state(value: Dictionary,player: PlayerController) -> bool:
	if not checkpoint_state_is_valid(value): return false
	_disposed = value["disposed"]
	_holder = player if value["carried"] else null
	freeze = value["carried"]
	collision_layer = 0 if freeze else 1
	global_position = _vector(value["position"])
	global_rotation = _vector(value["rotation"])
	linear_velocity = _vector(value["velocity"])
	angular_velocity = Vector3.ZERO
	return true

static func _array(point: Vector3) -> Array:
	return [point.x,point.y,point.z]

static func _vector(value: Array) -> Vector3:
	return Vector3(value[0],value[1],value[2])

func _move_in_hands() -> void:
	var destination := _holder.global_position-_holder.global_basis.z
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _box_shape
	query.transform = Transform3D(Basis(Vector3.UP,_holder.global_rotation.y),global_position)
	query.motion = destination-global_position
	query.margin = 0.001
	query.collision_mask = 1|16
	query.exclude = [get_rid(),_holder.get_rid()]
	var space := get_world_3d().direct_space_state
	var fraction := space.cast_motion(query)
	var point := global_position+query.motion*(fraction[0] if fraction.size() > 0 else 0.0)
	query.motion = Vector3.ZERO
	query.transform.origin = point
	# Also reject overlap introduced by rotating the held box at a corner.
	if space.intersect_shape(query,1).is_empty(): global_transform = query.transform
