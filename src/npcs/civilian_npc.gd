class_name CivilianNPC
extends CharacterBody3D

const SCAN_INTERVAL := 0.5
const SCREAM_RADIUS := 15.0
@export_range(1.0,20.0,0.5) var view_distance := 8.0
var _scan_elapsed := 0.0
var _scream_cooldown := 0.0
var _health := 1
var _body: MeshInstance3D

func _ready() -> void:
	add_to_group(&"civilians")
	collision_layer = 1 << 3
	collision_mask = 1
	var shape := CollisionShape3D.new()
	shape.name = "BodyCollision"
	shape.shape = CapsuleShape3D.new()
	(shape.shape as CapsuleShape3D).height = 1.65
	(shape.shape as CapsuleShape3D).radius = 0.25
	shape.position.y = 0.825
	add_child(shape)
	_body = MeshInstance3D.new()
	_body.name = "Body"
	_body.mesh = civilian_mesh()
	_body.position.y = 0.825
	add_child(_body)

static func civilian_mesh() -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.25
	mesh.height = 1.65
	mesh.radial_segments = 12
	mesh.rings = 4
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("766b50")
	mesh.material = material
	return mesh

func _physics_process(delta: float) -> void:
	advance_perception(delta,get_tree().get_first_node_in_group(&"player") as PlayerController)

func advance_perception(delta: float, player: PlayerController) -> void:
	if is_defeated() or not is_finite(delta) or delta <= 0.0: return
	_scream_cooldown = maxf(0.0,_scream_cooldown-delta)
	_scan_elapsed += delta
	if _scan_elapsed + 0.000001 < SCAN_INTERVAL: return
	_scan_elapsed = fmod(_scan_elapsed,SCAN_INTERVAL)
	if can_see_player(player): scream()

func can_see_player(player: PlayerController) -> bool:
	if not is_instance_valid(player) or not player.is_inside_tree() or player.is_visibility_excluded() or is_defeated(): return false
	var offset := player.global_position-global_position
	if not offset.is_finite() or offset.length() > view_distance*WeatherSystem.view_multiplier(): return false
	var horizontal := Vector3(offset.x,0,offset.z)
	if horizontal.length_squared() > 0.001 and (-global_basis.z).dot(horizontal.normalized()) < 0.5: return false
	var query := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*1.4,player.global_position+Vector3.UP,1|16)
	query.exclude = [get_rid(),player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func scream() -> bool:
	if is_defeated() or _scream_cooldown > 0.0: return false
	_scream_cooldown = 5.0
	var event := NoiseEvent.create(global_position,SCREAM_RADIUS,Enums.NoiseKind.SCREAM,self)
	event.audio_cue = &"civilian_scream"
	NoiseEventSystem.emit(event,get_tree())
	EventBus.mission_event.emit(&"civilian_scream",{"position":global_position})
	return true

func health() -> int:
	return _health

func is_defeated() -> bool:
	return _health <= 0

func receive_combat_damage(amount: int, source: Node = null) -> int:
	if amount <= 0 or is_defeated(): return 0
	var applied := mini(amount,_health)
	_health -= applied
	if is_defeated():
		collision_layer = 1 << 8
		if _body != null:
			_body.rotation.z = PI/2
			_body.position.y = 0.25
		_report_death(source)
	else: scream()
	return applied

func _report_death(_source: Node) -> void:
	EventBus.civilian_killed.emit(self)

## Restore without reporting a fresh death or changing mission counters.
func restore_checkpoint_health(value: int) -> bool:
	if value < 0 or value > 1 or _body == null: return false
	_health = value
	_scream_cooldown = 0.0
	_scan_elapsed = 0.0
	collision_layer = (1 << 8) if value == 0 else (1 << 3)
	_body.rotation.z = PI/2 if value == 0 else 0.0
	_body.position.y = 0.25 if value == 0 else 0.825
	return true
