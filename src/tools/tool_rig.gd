class_name ToolRig
extends Node3D


const ToolInventoryScript := preload("res://src/tools/tool_inventory.gd")
const ToolBaseScript := preload("res://src/tools/tool_base.gd")

const AIM_DISTANCE := 24.0

signal tool_changed(index: int, definition: ToolDefinition, remaining: int)
signal tool_count_changed(index: int, definition: ToolDefinition, remaining: int)
signal aiming_changed(active: bool)

@export_range(1.0, 100.0, 0.5) var aim_distance := AIM_DISTANCE
@export var inventory: ToolInventory

var _camera: Camera3D
var _aiming := false


func _init() -> void:
	if inventory == null:
		inventory = ToolInventoryScript.new()
		inventory.name = "ToolInventory"
		add_child(inventory)


func _ready() -> void:
	if inventory == null:
		inventory = ToolInventoryScript.new()
		inventory.name = "ToolInventory"
		add_child(inventory)
	if not inventory.slot_changed.is_connected(_on_inventory_slot_changed):
		inventory.slot_changed.connect(_on_inventory_slot_changed)
	if not inventory.count_changed.is_connected(_on_inventory_count_changed):
		inventory.count_changed.connect(_on_inventory_count_changed)
	_camera = _find_camera()
	_load_default_definitions_if_empty()
	_update_trajectory()


func _process(_delta: float) -> void:
	if _aiming:
		_update_trajectory()


func set_camera(camera: Camera3D) -> void:
	_camera = camera
	_update_trajectory()


func camera() -> Camera3D:
	return _camera


func set_tool_definitions(definitions: Array[ToolDefinition], slot_limit: int = ToolInventory.DEFAULT_SLOT_COUNT) -> void:
	inventory.configure(definitions, slot_limit)
	_update_trajectory()


func set_inventory(next_inventory: ToolInventory) -> bool:
	if next_inventory == null or next_inventory == inventory:
		return next_inventory != null
	if inventory != null:
		if inventory.slot_changed.is_connected(_on_inventory_slot_changed):
			inventory.slot_changed.disconnect(_on_inventory_slot_changed)
		if inventory.count_changed.is_connected(_on_inventory_count_changed):
			inventory.count_changed.disconnect(_on_inventory_count_changed)
	if inventory != null and inventory.get_parent() == self:
		remove_child(inventory)
	inventory = next_inventory
	if inventory.get_parent() == null:
		add_child(inventory)
	if not inventory.slot_changed.is_connected(_on_inventory_slot_changed):
		inventory.slot_changed.connect(_on_inventory_slot_changed)
	if not inventory.count_changed.is_connected(_on_inventory_count_changed):
		inventory.count_changed.connect(_on_inventory_count_changed)
	_update_trajectory()
	return true


func selected_definition() -> ToolDefinition:
	return inventory.current_definition() if inventory != null else null


func selected_slot() -> int:
	return inventory.selected_slot() if inventory != null else 0


func select_slot(index: int) -> bool:
	return inventory.select_slot(index) if inventory != null else false


func cycle_slot(direction: int = 1) -> bool:
	return inventory.cycle(direction) if inventory != null else false


func remaining_count() -> int:
	return inventory.remaining_count() if inventory != null else 0


func set_aiming(active: bool) -> bool:
	var next := bool(active)
	if next and selected_definition() == null:
		next = false
	if _aiming == next:
		_update_trajectory()
		return _aiming
	_aiming = next
	if not _aiming:
		_clear_trajectory()
	else:
		_update_trajectory()
	aiming_changed.emit(_aiming)
	return _aiming


func is_aiming() -> bool:
	return _aiming


func aim() -> Dictionary:
	var origin := global_position
	var direction := -global_transform.basis.z.normalized()
	if _camera != null and is_instance_valid(_camera):
		origin = _camera.global_position
		direction = -_camera.global_transform.basis.z.normalized()
	if not direction.is_finite() or direction.length_squared() <= 0.000001:
		direction = Vector3.FORWARD
	return {&"origin": origin, &"dir": direction, &"target": null}


func current_aim() -> Dictionary:
	return aim()


func trajectory(origin: Vector3 = Vector3.ZERO, direction: Vector3 = Vector3.FORWARD) -> PackedVector3Array:
	var definition := selected_definition()
	if definition == null or not definition.supports_aiming():
		return PackedVector3Array()
	var safe_direction := direction.normalized()
	if not origin.is_finite() or not safe_direction.is_finite() or safe_direction.length_squared() <= 0.000001:
		return PackedVector3Array()
	var points := PackedVector3Array()
	var velocity := safe_direction * clampf(definition.projectile_speed, ToolDefinition.MIN_PROJECTILE_SPEED, ToolDefinition.MAX_PROJECTILE_SPEED)
	var duration := definition.trajectory_duration()
	var count := definition.trajectory_sample_count()
	for index in count:
		var t := duration * float(index) / float(count - 1)
		var point := origin + velocity * t + Vector3.DOWN * (0.5 * definition.trajectory_gravity * t * t)
		if not point.is_finite():
			return PackedVector3Array()
		points.append(point)
	return points


func trajectory_points() -> PackedVector3Array:
	var aim_data := aim()
	return trajectory(aim_data[&"origin"], aim_data[&"dir"])


func use_selected(user: Node3D = null) -> bool:
	var definition := selected_definition()
	if definition == null or inventory == null or not inventory.can_use():
		return false
	var actor := user if user != null else _default_user()
	if actor == null:
		return false
	var effect := _create_effect(definition)
	if effect == null:
		return false
	var attached := effect.get_parent() != null
	if not attached:
		add_child(effect)
	var did_use := effect.use(actor, aim())
	if not did_use:
		if effect.get_parent() == self:
			remove_child(effect)
		effect.queue_free()
		return false
	if not inventory.consume():
		if effect.get_parent() == self:
			remove_child(effect)
		effect.queue_free()
		return false
	return true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"tool_cycle"):
		cycle_slot(1)
	if event.is_action_pressed(&"tool_use"):
		use_selected()
	if event.is_action_pressed(&"aim"):
		set_aiming(true)
	if event.is_action_released(&"aim"):
		set_aiming(false)


func _find_camera() -> Camera3D:
	var candidate := get_node_or_null("../CameraRig/SpringArm3D/Camera3D") as Camera3D
	return candidate


func _default_user() -> Node3D:
	var candidate := owner as Node3D
	return candidate if candidate != null else (get_parent() as Node3D)


func _create_effect(definition: ToolDefinition) -> ToolBase:
	var effect: ToolBase = null
	if definition.effect_scene != null:
		effect = definition.effect_scene.instantiate() as ToolBase
	if effect == null:
		effect = ToolBaseScript.new()
	effect.tool_definition = definition
	return effect


func _load_default_definitions_if_empty() -> void:
	if inventory.current_definition() != null:
		return
	var paths := [
		"res://data/tools/stone.tres",
		"res://data/tools/dart.tres",
		"res://data/tools/smoke.tres",
	]
	var definitions: Array[ToolDefinition] = []
	for path in paths:
		var loaded := load(path) as ToolDefinition
		if loaded != null:
			definitions.append(loaded)
	if not definitions.is_empty():
		inventory.configure(definitions, inventory.slot_limit)


func _update_trajectory() -> void:
	var display := get_node_or_null("AimArc") as TrajectoryDisplay
	if display == null or not _aiming:
		if display != null:
			display.clear()
		return
	var points := trajectory_points()
	display.set_points(points)


func _clear_trajectory() -> void:
	var display := get_node_or_null("AimArc") as TrajectoryDisplay
	if display != null:
		display.clear()


func _on_inventory_slot_changed(index: int, definition: ToolDefinition, remaining: int) -> void:
	tool_changed.emit(index, definition, remaining)
	_update_trajectory()


func _on_inventory_count_changed(index: int, definition: ToolDefinition, remaining: int) -> void:
	tool_count_changed.emit(index, definition, remaining)
