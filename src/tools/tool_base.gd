class_name ToolBase
extends Node3D


## Runtime root for a ToolDefinition.effect_scene.
##
## The framework intentionally does not prescribe a hit/effect implementation.
## Concrete tools (Issue #33) override `_apply_effect` while retaining this
## validation and use contract.
signal used(user: Node3D, aim: Dictionary)

@export var tool_definition: ToolDefinition


func definition() -> ToolDefinition:
	return tool_definition


func use(user: Node3D, aim: Dictionary) -> bool:
	if user == null or tool_definition == null or not _valid_aim(aim):
		return false
	_apply_effect({
		&"user": user,
		&"origin": aim[&"origin"],
		&"dir": aim[&"dir"],
		&"target": aim.get(&"target"),
	})
	used.emit(user, aim)
	return true


func _apply_effect(_hit: Dictionary) -> void:
	# Concrete effects own projectile spawning, collision response, and gameplay
	# consequences.  The base implementation is a successful no-op so the
	# framework can be exercised before Issue #33 supplies individual tools.
	pass


func _valid_aim(aim: Dictionary) -> bool:
	if not aim.has(&"origin") or not aim.has(&"dir"):
		return false
	var origin: Variant = aim[&"origin"]
	var direction: Variant = aim[&"dir"]
	if not origin is Vector3 or not direction is Vector3:
		return false
	var origin_vector := origin as Vector3
	var direction_vector := direction as Vector3
	return origin_vector.is_finite() and direction_vector.is_finite() and direction_vector.length_squared() > 0.000001
