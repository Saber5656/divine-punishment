class_name MissionNpcSnapshot
extends RefCounted


## JSON-compatible physical/AI state for one authored NPC. Stable ID mapping,
## doors/lights and body storage remain owned by the containing mission.
static func capture(npc: EnemyBase) -> Dictionary:
	var point := npc.global_position
	return {
		"escort_reacted":npc.has_reacted_to_target_defeat() if npc is EscortGuard else false,
		"position":[point.x,point.y,point.z], "yaw":npc.global_rotation.y,
		"brain":npc.brain().capture_checkpoint_state(),
		"combat":(npc.get_node("Combat") as EnemyCombat).capture_checkpoint_state(),
		"meter":(npc.get_node("Perception") as EnemyPerception).meter(),
	}


static func is_valid(value: Dictionary, npc: EnemyBase) -> bool:
	if not is_instance_valid(npc): return false
	if not value.get("escort_reacted",false) is bool: return false
	if not value.get("position") is Array or value["position"].size() != 3: return false
	for coordinate in value["position"]:
		if not CheckpointSnapshot._finite_number(coordinate) or absf(float(coordinate)) > 10000.0: return false
	if not CheckpointSnapshot._finite_number(value.get("yaw")) or not value.get("brain") is Dictionary: return false
	if not npc.brain().checkpoint_state_is_valid(value["brain"]): return false
	if not value.get("combat") is Dictionary or not (npc.get_node("Combat") as EnemyCombat).checkpoint_state_is_valid(value["combat"]): return false
	return CheckpointSnapshot._finite_number(value.get("meter")) and float(value["meter"]) >= 0 and float(value["meter"]) <= 3


static func restore(value: Dictionary, npc: EnemyBase) -> bool:
	if not is_valid(value,npc): return false
	var point: Array = value["position"]
	npc.global_position = Vector3(point[0],point[1],point[2])
	npc.global_rotation.y = float(value["yaw"])
	npc.brain().restore_checkpoint_state(value["brain"])
	(npc.get_node("Combat") as EnemyCombat).restore_checkpoint_state(value["combat"])
	(npc.get_node("Perception") as EnemyPerception).restore_checkpoint_meter(float(value["meter"]))
	npc.restore_checkpoint_lifecycle()
	if npc is EscortGuard: (npc as EscortGuard).restore_checkpoint_reaction(value.get("escort_reacted",false))
	if npc is TargetNpc: (npc as TargetNpc).restore_checkpoint_defeat(npc.brain().incapacitated_kind() == &"dead")
	if npc.brain().incapacitated_kind() == &"dead": npc.collision_layer = EnemyBase.CORPSE_LAYER
	return true
