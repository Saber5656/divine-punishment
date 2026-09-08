class_name CheckpointSnapshot
extends RefCounted


const VERSION := 1
const MAX_POSITION := 100000.0


static func capture(player: PlayerController, scene_path: String, checkpoint_id: StringName) -> Dictionary:
	var posture := player.checkpoint_posture()
	if posture.is_empty(): return {}
	var inventory := (player.get_node("ToolRig") as ToolRig).inventory
	var tools: Array[Dictionary] = []
	for index in inventory.slot_count():
		var definition := inventory.definition_at(index)
		tools.append({"id": String(definition.id) if definition != null else "", "count": inventory.remaining_count(index)})
	var position := player.global_position
	return {
		"version": VERSION, "scene": scene_path, "id": String(checkpoint_id),
		"position": [position.x, position.y, position.z], "yaw": player.global_rotation.y,
		"posture": String(posture),
		"tools": tools, "selected_slot": inventory.selected_slot(),
		"area_alert": GameState.area_alert_level,
	}


static func is_valid(snapshot: Dictionary, scene_path: String) -> bool:
	if snapshot.get("version") != VERSION or snapshot.get("scene") != scene_path or scene_path.is_empty():
		return false
	if snapshot.get("posture", "Ground") not in ["Ground","Crouch","Crawlspace"]:
		return false
	var position: Variant = snapshot.get("position")
	if not position is Array or position.size() != 3:
		return false
	for coordinate: Variant in position:
		if not _finite_number(coordinate) or absf(float(coordinate)) > MAX_POSITION:
			return false
	if not _finite_number(snapshot.get("yaw")):
		return false
	var alert: Variant = snapshot.get("area_alert")
	if not _whole_number(alert, 0, 5):
		return false
	var tools: Variant = snapshot.get("tools")
	if not tools is Array or tools.is_empty() or tools.size() > ToolInventory.MAX_SLOT_COUNT:
		return false
	for slot: Variant in tools:
		if not slot is Dictionary or not slot.get("id") is String:
			return false
		if not _whole_number(slot.get("count"), 0, ToolInventory.MAX_TOOL_COUNT):
			return false
	return _whole_number(snapshot.get("selected_slot"), 0, tools.size() - 1)


static func matches_inventory(snapshot: Dictionary, inventory: ToolInventory) -> bool:
	var slots: Array = snapshot["tools"]
	if slots.size() != inventory.slot_count():
		return false
	for index in slots.size():
		var definition := inventory.definition_at(index)
		var expected_id := String(definition.id) if definition != null else ""
		if slots[index]["id"] != expected_id:
			return false
	return true


static func restore(snapshot: Dictionary, player: PlayerController, scene_path: String) -> bool:
	if not is_valid(snapshot, scene_path):
		return false
	var inventory := (player.get_node("ToolRig") as ToolRig).inventory
	if not matches_inventory(snapshot, inventory):
		return false
	var position: Array = snapshot["position"]
	var destination := Vector3(float(position[0]), float(position[1]), float(position[2]))
	if not player.restore_checkpoint_posture(StringName(snapshot.get("posture","Ground")),destination):
		return false
	player.global_position = destination
	player.global_rotation.y = float(snapshot["yaw"])
	player.velocity = Vector3.ZERO
	for index in inventory.slot_count():
		inventory.set_remaining_count(index, int(snapshot["tools"][index]["count"]))
	inventory.select_slot(int(snapshot["selected_slot"]))
	GameState.area_alert_level = int(snapshot["area_alert"])
	EventBus.area_alert_changed.emit(GameState.area_alert_level)
	return true


static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _whole_number(value: Variant, minimum: int, maximum: int) -> bool:
	return _finite_number(value) and float(value) == floorf(float(value)) and float(value) >= minimum and float(value) <= maximum
