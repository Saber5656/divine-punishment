class_name CaltropTrap
extends Area3D

var remaining := 30.0
var _spent := false

func _ready() -> void:
	add_to_group(&"caltrops")
	collision_layer = 0
	collision_mask = 1 << 1
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	(shape.shape as SphereShape3D).radius = 0.35
	add_child(shape)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("675f53")
	metal.metallic = 0.7
	for angle in [0.0,PI/3,2*PI/3]:
		var spike := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.0
		mesh.bottom_radius = 0.045
		mesh.height = 0.3
		mesh.radial_segments = 4
		mesh.material = metal
		spike.mesh = mesh
		spike.rotation = Vector3(PI/3,angle,0)
		add_child(spike)
	body_entered.connect(trigger)

func _process(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0: return
	remaining -= delta
	if remaining <= 0.0: queue_free()

func trigger(body: Node3D) -> void:
	if _spent or not body is PlayerController: return
	_spent = true
	(body as PlayerController).combat.receive_damage(1,self)
	queue_free()
