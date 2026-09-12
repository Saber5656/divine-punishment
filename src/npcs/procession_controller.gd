class_name ProcessionController
extends Node3D

@export var route: Curve3D
@export_node_path("TargetNpc") var target_path: NodePath
@export var guard_paths: Array[NodePath] = []
@export_range(0.1,3.0,0.1) var speed := 1.2
@export_range(0.1,120.0,0.1) var rest_seconds := 20.0
var phase: StringName = &"idle"
var _target: TargetNpc
var _guards: Array[EscortGuard] = []
var _distance := 0.0
var _next_rest := 0
var _rest_elapsed := 0.0
var _palanquin: Node3D
var _target_layer := 4

func _ready() -> void:
	_palanquin = Node3D.new()
	_palanquin.name = "Palanquin"
	add_child(_palanquin)
	var visual := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.2,1.2,1.6)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("543e31")
	box.material = material
	visual.mesh = box
	_palanquin.add_child(visual)
	if target_path != NodePath():
		var guards: Array[EscortGuard] = []
		for path in guard_paths:
			var guard := get_node_or_null(path) as EscortGuard
			if guard != null: guards.append(guard)
		configure(get_node_or_null(target_path) as TargetNpc,guards,route)

func configure(target: TargetNpc,guards: Array[EscortGuard],path: Curve3D) -> bool:
	if not is_instance_valid(target) or not target.is_inside_tree() or path == null or guards.size() > 12: return false
	if path.point_count < 2 or path.point_count > 64: return false
	for index in path.point_count:
		if not path.get_point_position(index).is_finite(): return false
	if not is_finite(path.get_baked_length()) or path.get_baked_length() <= 0.1 or path.get_baked_length() > 1000.0: return false
	for guard in guards:
		if not is_instance_valid(guard) or not guard.is_inside_tree(): return false
	_release_target()
	_target = target
	_target_layer = target.collision_layer
	_guards = guards.duplicate()
	route = path
	_distance = 0.0
	_next_rest = 0
	_rest_elapsed = 0.0
	_target.set_target_routine_enabled(false)
	for guard in _guards: guard.set_escort_target(target)
	phase = &"moving"
	_set_travel(true)
	_position_carriage()
	return true

func _physics_process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0 or not is_instance_valid(_target) or phase in [&"idle",&"finished"]: return
	if _target.is_target_defeated():
		phase = &"finished"
		_release_target()
		return
	if phase == &"resting":
		_rest_elapsed += delta
		var exit_position := _palanquin.global_position+_palanquin.global_basis.x*1.5
		if _target.alert_state() == Enums.AlertState.UNAWARE: _target.advance_navigation(minf(delta,0.25),exit_position,1.5)
		if _rest_elapsed >= rest_seconds and _target.alert_state() == Enums.AlertState.UNAWARE:
			phase = &"moving"
			_set_travel(true)
		return
	_distance = minf(route.get_baked_length(),_distance+speed*minf(delta,0.25))
	_position_carriage()
	if _next_rest < 3 and _distance >= route.get_baked_length()*float(_next_rest+1)/4.0:
		phase = &"resting"
		_rest_elapsed = 0.0
		_set_travel(false)
		EventBus.mission_event.emit(&"procession_rest",{"index":_next_rest})
		_next_rest += 1
	elif _distance >= route.get_baked_length():
		phase = &"finished"
		_set_travel(false)
		EventBus.mission_event.emit(&"procession_finished",{})

func _position_carriage() -> void:
	_palanquin.position = route.sample_baked(_distance)
	var tangent := global_basis*(route.sample_baked(minf(route.get_baked_length(),_distance+0.05))-route.sample_baked(maxf(0.0,_distance-0.05)))
	tangent.y = 0.0
	if tangent.length_squared() > 0.000001: _palanquin.look_at(_palanquin.global_position+tangent,Vector3.UP)
	_target.global_transform = _palanquin.global_transform
	_update_formation(phase == &"moving")

func _set_travel(traveling: bool) -> void:
	if not is_instance_valid(_target): return
	_target.inside_palanquin = traveling
	_target.get_node("Visual").visible = not traveling
	_target.collision_layer = 0 if traveling else _target_layer
	_target.get_node("AssassinateTarget").set_deferred("monitorable",not traveling)
	_target.brain().set_physics_process(not traveling)
	_target.combat().set_physics_process(not traveling)
	_update_formation(traveling)

func _update_formation(traveling: bool) -> void:
	for index in _guards.size():
		if not is_instance_valid(_guards[index]): continue
		var side := -1.0 if index%2 == 0 else 1.0
		_guards[index].follow_offset = _palanquin.global_basis*Vector3(side*(1.2 if traveling else 3.0),0,float(index/2)*(1.2 if traveling else 1.8)+1.5)

func _release_target() -> void:
	if not is_instance_valid(_target): return
	if _target.is_target_defeated():
		_target.inside_palanquin = false
		_target.get_node("Visual").show()
	else: _set_travel(false)

func _exit_tree() -> void:
	_release_target()
