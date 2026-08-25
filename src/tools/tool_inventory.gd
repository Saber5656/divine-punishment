class_name ToolInventory
extends Node


## Bounded player tool slots and remaining-use accounting.
##
## The inventory owns counts; ToolBase only validates and applies an effect.  A
## failed use consequently never consumes a count, which keeps UI state and
## gameplay state in one place.
const DEFAULT_SLOT_COUNT := 3
const MAX_SLOT_COUNT := 8
const MAX_TOOL_COUNT := ToolDefinition.MAX_COUNT

signal slot_changed(index: int, definition: ToolDefinition, remaining: int)
signal count_changed(index: int, definition: ToolDefinition, remaining: int)

@export_range(1, MAX_SLOT_COUNT, 1) var slot_limit: int = DEFAULT_SLOT_COUNT

var _definitions: Array[ToolDefinition] = []
var _remaining: Array[int] = []
var _selected_slot := 0


func _ready() -> void:
	_resize_slots(slot_limit)


func configure(definitions: Array[ToolDefinition], requested_slot_limit: int = DEFAULT_SLOT_COUNT) -> void:
	slot_limit = clampi(requested_slot_limit, 1, MAX_SLOT_COUNT)
	_resize_slots(slot_limit)
	for index in slot_limit:
		_definitions[index] = null
		_remaining[index] = 0
	for index in mini(definitions.size(), slot_limit):
		var definition := definitions[index]
		if definition == null:
			continue
		_definitions[index] = definition
		_remaining[index] = definition.safe_default_count()
	_selected_slot = clampi(_selected_slot, 0, slot_limit - 1)
	_emit_all_slots()


func set_slot(index: int, definition: ToolDefinition, remaining: int = -1) -> bool:
	if not _is_valid_slot(index):
		return false
	_definitions[index] = definition
	_remaining[index] = _clamp_count(
		remaining if remaining >= 0 else (definition.safe_default_count() if definition != null else 0),
		definition,
	)
	slot_changed.emit(index, definition, _remaining[index])
	count_changed.emit(index, definition, _remaining[index])
	return true


func clear_slot(index: int) -> bool:
	return set_slot(index, null, 0)


func slot_count() -> int:
	return slot_limit


func capacity() -> int:
	return slot_limit


func selected_slot() -> int:
	return _selected_slot


func current_slot() -> int:
	return selected_slot()


func select_slot(index: int) -> bool:
	if not _is_valid_slot(index):
		return false
	if _selected_slot == index:
		return true
	_selected_slot = index
	slot_changed.emit(index, current_definition(), remaining_count(index))
	return true


func cycle(direction: int = 1) -> bool:
	if direction == 0 or slot_limit <= 0:
		return false
	var step := 1 if direction > 0 else -1
	var next := posmod(_selected_slot + step, slot_limit)
	return select_slot(next)


func cycle_slot(direction: int = 1) -> bool:
	return cycle(direction)


func current_definition() -> ToolDefinition:
	return definition_at(_selected_slot)


func selected_definition() -> ToolDefinition:
	return current_definition()


func definition_at(index: int) -> ToolDefinition:
	if not _is_valid_slot(index):
		return null
	return _definitions[index]


func remaining_count(index: int = -1) -> int:
	var resolved := _selected_slot if index < 0 else index
	if not _is_valid_slot(resolved):
		return 0
	return _remaining[resolved]


func count_at(index: int) -> int:
	return remaining_count(index)


func can_use(index: int = -1) -> bool:
	var resolved := _selected_slot if index < 0 else index
	return definition_at(resolved) != null and remaining_count(resolved) > 0


func consume(index: int = -1, amount: int = 1) -> bool:
	var resolved := _selected_slot if index < 0 else index
	if not _is_valid_slot(resolved) or amount <= 0 or not can_use(resolved):
		return false
	var next := maxi(_remaining[resolved] - amount, 0)
	if next == _remaining[resolved]:
		return false
	_remaining[resolved] = next
	count_changed.emit(resolved, _definitions[resolved], next)
	return true


func set_remaining_count(index: int, count: int) -> bool:
	if not _is_valid_slot(index) or _definitions[index] == null:
		return false
	var next := _clamp_count(count, _definitions[index])
	if next == _remaining[index]:
		return true
	_remaining[index] = next
	count_changed.emit(index, _definitions[index], next)
	return true


func add_count(index: int, amount: int) -> bool:
	if not _is_valid_slot(index) or amount <= 0 or _definitions[index] == null:
		return false
	return set_remaining_count(index, _remaining[index] + amount)


func loadout(definitions: Array[ToolDefinition], counts: Dictionary = {}) -> void:
	configure(definitions, slot_limit)
	for index in slot_limit:
		if not counts.has(index) or _definitions[index] == null:
			continue
		set_remaining_count(index, int(counts[index]))


func _resize_slots(size: int) -> void:
	var bounded := clampi(size, 1, MAX_SLOT_COUNT)
	_definitions.resize(bounded)
	_remaining.resize(bounded)
	for index in bounded:
		if _remaining[index] < 0:
			_remaining[index] = 0
	_selected_slot = clampi(_selected_slot, 0, bounded - 1)


func _emit_all_slots() -> void:
	for index in slot_limit:
		slot_changed.emit(index, _definitions[index], _remaining[index])
		count_changed.emit(index, _definitions[index], _remaining[index])


func _is_valid_slot(index: int) -> bool:
	return index >= 0 and index < _definitions.size() and index < _remaining.size()


func _clamp_count(count: int, definition: ToolDefinition) -> int:
	var upper := MAX_TOOL_COUNT
	if definition != null:
		upper = MAX_TOOL_COUNT
	return clampi(count, 0, upper)
