class_name SwimHud
extends CanvasLayer


@onready var breath_gauge: ProgressBar = $BreathPanel/BreathGauge as ProgressBar
@onready var ripple_cue: Control = $RippleCue as Control
@onready var underwater_veil: ColorRect = $UnderwaterVeil as ColorRect
@onready var visibility_ring: VisibilityRing = $VisibilityRing as VisibilityRing
@onready var noise_ripple_cue: NoiseRippleCue = $NoiseRippleCue as NoiseRippleCue
@onready var tool_slots: HBoxContainer = $ToolSlots as HBoxContainer

var _player: Node
var _visibility_source: PlayerVisibility
var _tool_inventory: ToolInventory


func _ready() -> void:
	visible = true
	_player = get_parent().get_parent()
	_visibility_source = get_parent() as PlayerVisibility
	if _visibility_source != null:
		if not _visibility_source.visibility_changed.is_connected(_on_visibility_changed):
			_visibility_source.visibility_changed.connect(_on_visibility_changed)
		set_visibility(_visibility_source.visibility())
	if not EventBus.noise_emitted.is_connected(_on_noise_emitted):
		EventBus.noise_emitted.connect(_on_noise_emitted)
	_bind_player_tools()
	set_underwater(false, 0.0, 1.0)


func _exit_tree() -> void:
	if _visibility_source != null and _visibility_source.visibility_changed.is_connected(_on_visibility_changed):
		_visibility_source.visibility_changed.disconnect(_on_visibility_changed)
	if EventBus.noise_emitted.is_connected(_on_noise_emitted):
		EventBus.noise_emitted.disconnect(_on_noise_emitted)
	_unbind_tool_inventory()


func set_underwater(active: bool, remaining: float, capacity: float) -> void:
	var safe_capacity := capacity if is_finite(capacity) and capacity > 0.0 else 1.0
	var safe_remaining := remaining if is_finite(remaining) else 0.0
	breath_gauge.max_value = safe_capacity
	breath_gauge.value = clampf(safe_remaining, 0.0, safe_capacity)
	underwater_veil.visible = active
	ripple_cue.visible = active
	$BreathPanel.visible = active


func set_visibility(value: float) -> void:
	visibility_ring.set_visibility(value)


func set_visibility_value(value: float) -> void:
	set_visibility(value)


func visibility() -> float:
	return visibility_ring.visibility()


func visibility_value() -> float:
	return visibility()


func displayed_visibility() -> float:
	return visibility_ring.displayed_visibility()


func is_visibility_ring_open() -> bool:
	return visibility_ring.is_open()


func show_noise_ripple(event: NoiseEvent = null) -> void:
	noise_ripple_cue.pulse(event)


func is_noise_ripple_visible() -> bool:
	return noise_ripple_cue.is_pulsing()


func noise_ripple_count() -> int:
	return noise_ripple_cue.pulse_count()


func tool_slot_count() -> int:
	return tool_slots.get_child_count()


func tool_slot_frame(index: int) -> Control:
	if index < 0 or index >= tool_slots.get_child_count():
		return null
	return tool_slots.get_child(index) as Control


func bind_tool_inventory(inventory: ToolInventory) -> void:
	_unbind_tool_inventory()
	_tool_inventory = inventory
	if _tool_inventory == null:
		_render_tool_slots()
		return
	if not _tool_inventory.slot_changed.is_connected(_on_tool_slot_changed):
		_tool_inventory.slot_changed.connect(_on_tool_slot_changed)
	if not _tool_inventory.count_changed.is_connected(_on_tool_count_changed):
		_tool_inventory.count_changed.connect(_on_tool_count_changed)
	_render_tool_slots()


func tool_slot_definition(index: int) -> ToolDefinition:
	return _tool_inventory.definition_at(index) if _tool_inventory != null else null


func tool_slot_remaining(index: int) -> int:
	return _tool_inventory.remaining_count(index) if _tool_inventory != null else 0


func selected_tool_slot() -> int:
	return _tool_inventory.selected_slot() if _tool_inventory != null else 0


func is_breath_gauge_visible() -> bool:
	return visible and $BreathPanel.visible and breath_gauge.visible


func is_ripple_cue_visible() -> bool:
	return visible and ripple_cue.visible


func breath_ratio() -> float:
	if breath_gauge.max_value <= 0.0:
		return 0.0
	return float(breath_gauge.value / breath_gauge.max_value)


func _on_visibility_changed(value: float) -> void:
	set_visibility(value)


func _on_noise_emitted(event: NoiseEvent) -> void:
	if _is_local_player_source(event.source):
		show_noise_ripple(event)


func _bind_player_tools() -> void:
	if _player == null:
		return
	var tool_rig := _player.get_node_or_null("ToolRig")
	if tool_rig == null:
		return
	var inventory: ToolInventory = tool_rig.get("inventory") as ToolInventory
	if inventory != null:
		bind_tool_inventory(inventory)


func _unbind_tool_inventory() -> void:
	if _tool_inventory == null:
		return
	if _tool_inventory.slot_changed.is_connected(_on_tool_slot_changed):
		_tool_inventory.slot_changed.disconnect(_on_tool_slot_changed)
	if _tool_inventory.count_changed.is_connected(_on_tool_count_changed):
		_tool_inventory.count_changed.disconnect(_on_tool_count_changed)
	_tool_inventory = null


func _render_tool_slots() -> void:
	for index in tool_slots.get_child_count():
		_render_tool_slot(index)


func _render_tool_slot(index: int) -> void:
	var frame := tool_slot_frame(index)
	if frame == null:
		return
	var index_label := frame.get_node_or_null("SlotIndex") as Label
	if index_label == null:
		return
	var definition := tool_slot_definition(index)
	var count := tool_slot_remaining(index)
	var label := str(index + 1)
	if definition != null:
		label += "  %s  ×%d" % [definition.display_name, count]
	else:
		label += "  —"
	index_label.text = label
	frame.modulate = Color(1.0, 0.86, 0.56, 1.0) if index == selected_tool_slot() else Color.WHITE


func _on_tool_slot_changed(_index: int, _definition: ToolDefinition, _remaining: int) -> void:
	_render_tool_slots()


func _on_tool_count_changed(index: int, _definition: ToolDefinition, _remaining: int) -> void:
	_render_tool_slot(index)


func _is_local_player_source(source: Node) -> bool:
	if source == null or _player == null:
		return false
	var cursor := source
	while cursor != null:
		if cursor == _player:
			return true
		cursor = cursor.get_parent()
	return false
