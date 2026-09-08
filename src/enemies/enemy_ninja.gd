class_name EnemyNinja
extends EnemyBase

const MAX_CALTROPS := 3
const MAX_WORLD_CALTROPS := 12
var _caltrops: Array[Area3D] = []
var _caltrop_cooldown := 0.0

func _physics_process(delta: float) -> void:
	advance_tactics(delta)

func active_caltrops() -> Array[Area3D]:
	_caltrops = _caltrops.filter(func(trap): return is_instance_valid(trap) and not trap.is_queued_for_deletion())
	return _caltrops

func advance_tactics(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0: return
	_caltrop_cooldown = maxf(0.0,_caltrop_cooldown-delta)
	if brain() == null or brain().is_incapacitated() or alert_state() != Enums.AlertState.SEARCHING: return
	if _caltrop_cooldown > 0.0 or active_caltrops().size() >= MAX_CALTROPS: return
	if get_tree().get_nodes_in_group(&"caltrops").size() >= MAX_WORLD_CALTROPS: return
	var trap := CaltropTrap.new()
	get_parent().add_child(trap)
	trap.global_position = global_position-Vector3.UP*0.82
	_caltrops.append(trap)
	_caltrop_cooldown = 10.0
