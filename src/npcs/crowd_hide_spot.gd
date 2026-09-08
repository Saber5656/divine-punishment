class_name CrowdHideSpot
extends HideSpot

@export var route: Curve3D
@export_range(0.0,2.0,0.05) var route_speed := 0.4
var members: Array[CivilianNPC] = []
var _instances: MultiMeshInstance3D
var _distance := 0.0
var _disrupted := false

func _ready() -> void:
	entry_radius = 2.0
	add_to_group(&"crowd_hide_spots")
	_instances = MultiMeshInstance3D.new()
	_instances.name = "CrowdInstances"
	_instances.multimesh = MultiMesh.new()
	_instances.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_instances.multimesh.mesh = CivilianNPC.civilian_mesh()
	_instances.multimesh.instance_count = 5
	add_child(_instances)
	for index in range(5):
		var member := CivilianNPC.new()
		member.position = Vector3((index%3-1)*0.7,0,(index/3-0.5)*0.9)
		add_child(member)
		member.get_node("Body").hide()
		members.append(member)
	_sync_instances()

func _physics_process(delta: float) -> void:
	advance_route(delta)
	check_disruption(get_tree().get_first_node_in_group(&"player") as PlayerController)
	_sync_instances()

func advance_route(delta: float) -> void:
	if route == null or not is_finite(delta) or delta <= 0.0: return
	var length := route.get_baked_length()
	if length <= 0.001: return
	_distance = fmod(_distance+route_speed*minf(delta,0.25),length)
	position = route.sample_baked(_distance)

func conceals(player: PlayerController) -> bool:
	if not is_instance_valid(player) or not is_near_entry(player.global_position): return false
	var query := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP,player.global_position+Vector3.UP,1|16)
	query.exclude = [player.get_rid()]
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): return false
	if members.filter(func(member): return is_instance_valid(member) and not member.is_defeated()).size() < 3: return false
	return player.state_machine.current_state() in [&"Ground",&"Crouch"] and not Input.is_action_pressed(&"sprint")

static func conceals_player(player: PlayerController) -> bool:
	if not is_instance_valid(player) or not player.is_inside_tree(): return false
	for crowd in player.get_tree().get_nodes_in_group(&"crowd_hide_spots"):
		if crowd is CrowdHideSpot and crowd.conceals(player): return true
	return false

func check_disruption(player: PlayerController) -> bool:
	if not is_instance_valid(player) or not is_near_entry(player.global_position):
		_disrupted = false
		return false
	var unsafe := player.state_machine.current_state() in [&"Sprint",&"Combat",&"Assassinate"] or Input.is_action_pressed(&"sprint")
	if not unsafe:
		_disrupted = false
		return false
	if _disrupted: return false
	_disrupted = true
	for member in members:
		if is_instance_valid(member) and member.scream(): return true
	return false

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"sword"): return
	var player := get_tree().get_first_node_in_group(&"player") as PlayerController
	if player == null or not is_near_entry(player.global_position) or not MissionDirector.allows_action(&"sword"): return
	if player.state_machine.current_state() not in [&"Ground",&"Crouch"]: return
	for member in members:
		if is_instance_valid(member) and member.scream():
			_disrupted = true
			return

func _sync_instances() -> void:
	for index in members.size():
		var member := members[index]
		if not is_instance_valid(member):
			_instances.multimesh.set_instance_transform(index,Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),Vector3.ZERO))
			continue
		if member.is_defeated():
			if member.get_parent() == self:
				member.reparent(get_parent(),true)
				member.get_node("Body").show()
			_instances.multimesh.set_instance_transform(index,Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),Vector3.ZERO))
		else:
			_instances.multimesh.set_instance_transform(index,Transform3D(Basis.IDENTITY,member.position+Vector3.UP*0.825))

func can_enter(_body: CollisionObject3D, _close_range_seen: bool = false) -> bool:
	return false # Crowd concealment is automatic while walking, without a locked hide pose.

func can_store_body(_body: Node3D) -> bool:
	return false
