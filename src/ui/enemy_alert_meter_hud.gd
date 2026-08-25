class_name EnemyAlertMeterHud
extends CanvasLayer


## Runtime HUD for the enemy detection meter.
##
## The enemy remains the source of truth: its MeterAnchor supplies a world
## position, Perception supplies a bounded meter value, and Brain supplies the
## alert phase.  This node only projects and renders those public contracts.

const MAX_ENEMY_CANDIDATES := 128
const MAX_METERS := 64
const MAX_METER := 3.0
const METER_WIDTH := 56.0
const METER_HEIGHT := 6.0
const METER_OFFSET_Y := 14.0
const SCREEN_MARGIN := 8.0
const MIN_VIEWPORT_SIZE := 1.0
const MAX_WORLD_COORDINATE := 10000.0
const OCCLUSION_COLLISION_MASK := 1
const OCCLUSION_INDICATOR_MARGIN := 16.0

const SUSPICIOUS_COLOR := Color(0.96, 0.96, 0.92, 0.96)
const SEARCHING_COLOR := Color(1.0, 0.78, 0.12, 0.98)
const COMBAT_COLOR := Color(0.86, 0.16, 0.12, 0.98)
const RETURN_COLOR := Color(0.78, 0.78, 0.82, 0.9)
const BACKGROUND_COLOR := Color(0.04, 0.04, 0.04, 0.78)

@export var camera_path: NodePath = NodePath("")
@export var enemy_group: StringName = &"enemies"
@export var visible_by_default := true

var _camera_override: Camera3D
var _enemy_override: Array[Node] = []
var _has_enemy_override := false
var _entries: Dictionary = {}
var _canvas: Control


func _ready() -> void:
	layer = 50
	_canvas = Control.new()
	_canvas.name = &"EnemyAlertMeters"
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.visible = visible_by_default
	add_child(_canvas)
	set_process(true)
	refresh()


func _exit_tree() -> void:
	_clear_entries()


func _process(_delta: float) -> void:
	refresh()


func set_camera(camera: Camera3D) -> void:
	_camera_override = camera if camera != null and is_instance_valid(camera) else null
	refresh()


func camera() -> Camera3D:
	return _resolve_camera()


func set_enemy_candidates(candidates: Array) -> void:
	_enemy_override.clear()
	_has_enemy_override = true
	var limit := mini(candidates.size(), MAX_ENEMY_CANDIDATES)
	for index in limit:
		var candidate: Variant = candidates[index]
		if candidate is Node:
			_enemy_override.append(candidate as Node)
	refresh()


func clear_enemy_candidates() -> void:
	_enemy_override.clear()
	_has_enemy_override = false
	refresh()


func refresh() -> void:
	if _canvas == null:
		return
	var camera_node := _resolve_camera()
	var viewport_size := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2.ZERO
	var seen: Dictionary = {}
	var candidates := _candidate_nodes()
	var inspected := mini(candidates.size(), MAX_ENEMY_CANDIDATES)
	var accepted := 0
	for index in inspected:
		var candidate: Variant = candidates[index]
		var enemy := candidate as Node if candidate is Node else null
		if not _valid_enemy(enemy):
			continue
		var instance_id := enemy.get_instance_id()
		seen[instance_id] = true
		var data := _enemy_meter_data(enemy)
		if data.is_empty():
			_remove_entry(instance_id)
			continue
		var projection := project_anchor(
			camera_node,
			data[&"world_position"],
			viewport_size,
		)
		if not bool(projection.get(&"valid", false)):
			# Offscreen/invalid candidates must not allocate or retain a capped
			# meter entry.  A later visible candidate must remain eligible.
			_remove_entry(instance_id)
			continue
		if accepted >= MAX_METERS:
			_remove_entry(instance_id)
			continue
		var entry := _entry_for(instance_id)
		accepted += 1
		if _world_occluded(camera_node, enemy, data[&"world_position"]):
			_update_occluded_entry(
				entry,
				projection[&"position"],
				viewport_size,
				data[&"state"],
			)
		else:
			_update_entry(entry, projection[&"position"], data[&"meter"], data[&"state"])
	for instance_id: Variant in _entries.keys():
		if not seen.has(instance_id):
			_remove_entry(instance_id)


func meter_count() -> int:
	var count := 0
	for entry: Dictionary in _entries.values():
		var holder := entry.get(&"holder") as Control
		if holder != null and holder.visible:
			count += 1
	return count


func meter_screen_position(enemy: Node) -> Vector2:
	if enemy == null or not is_instance_valid(enemy):
		return Vector2(NAN, NAN)
	var entry: Variant = _entries.get(enemy.get_instance_id())
	if not entry is Dictionary:
		return Vector2(NAN, NAN)
	var holder := (entry as Dictionary).get(&"holder") as Control
	if holder == null or not holder.visible:
		return Vector2(NAN, NAN)
	return holder.position


static func phase_color(state: int) -> Color:
	if state == Enums.AlertState.COMBAT:
		return COMBAT_COLOR
	if state == Enums.AlertState.SEARCHING:
		return SEARCHING_COLOR
	if state == Enums.AlertState.SUSPICIOUS:
		return SUSPICIOUS_COLOR
	if state == Enums.AlertState.RETURN:
		return RETURN_COLOR
	return Color(0.0, 0.0, 0.0, 0.0)


static func phase_symbol(state: int) -> String:
	match state:
		Enums.AlertState.COMBAT:
			return "◆"
		Enums.AlertState.SEARCHING:
			return "▲"
		Enums.AlertState.SUSPICIOUS:
			return "●"
		Enums.AlertState.RETURN:
			return "●"
		_:
			return ""


## Project a finite world position and reject positions behind the camera or
## outside the viewport.  Returning a Dictionary keeps invalid projection
## distinguishable from the valid screen origin (0,0) for callers/tests.
static func project_anchor(
	camera_node: Camera3D,
	world_position: Vector3,
	viewport_size: Vector2,
) -> Dictionary:
	if (
		camera_node == null
		or not is_instance_valid(camera_node)
		or not _valid_world_position(world_position)
		or not _valid_vector2(viewport_size)
		or viewport_size.x < MIN_VIEWPORT_SIZE
		or viewport_size.y < MIN_VIEWPORT_SIZE
	):
		return {&"valid": false}
	if camera_node.is_position_behind(world_position):
		return {&"valid": false}
	var screen_position := camera_node.unproject_position(world_position)
	if (
		not _valid_vector2(screen_position)
		or screen_position.x < -SCREEN_MARGIN
		or screen_position.y < -SCREEN_MARGIN
		or screen_position.x > viewport_size.x + SCREEN_MARGIN
		or screen_position.y > viewport_size.y + SCREEN_MARGIN
	):
		return {&"valid": false}
	return {&"valid": true, &"position": screen_position}


func _candidate_nodes() -> Array[Node]:
	if _has_enemy_override:
		return _enemy_override.duplicate()
	var result: Array[Node] = []
	if not is_inside_tree() or get_tree() == null:
		return result
	var candidates := get_tree().get_nodes_in_group(enemy_group)
	var limit := mini(candidates.size(), MAX_ENEMY_CANDIDATES)
	for index in limit:
		var candidate: Variant = candidates[index]
		if candidate is Node:
			result.append(candidate as Node)
	return result


func _enemy_meter_data(enemy: Node) -> Dictionary:
	if not _valid_enemy(enemy):
		return {}
	var perception := enemy.get_node_or_null(NodePath("Perception"))
	var brain := enemy.get_node_or_null(NodePath("Brain"))
	if (
		perception == null
		or brain == null
		or not perception.has_method(&"meter")
		or not brain.has_method(&"alert_state")
	):
		return {}
	if _is_incapacitated(brain):
		return {}
	var anchor := enemy.get_node_or_null(NodePath("MeterAnchor")) as Node3D
	if anchor == null or not _valid_world_position(anchor.global_position):
		return {}
	var meter_value: Variant = perception.call(&"meter")
	var state_value: Variant = brain.call(&"alert_state")
	if (
		not (meter_value is int or meter_value is float)
		or not is_finite(float(meter_value))
		or not (state_value is int or state_value is float)
	):
		return {}
	var state := int(state_value)
	if state < Enums.AlertState.UNAWARE or state > Enums.AlertState.RETURN:
		return {}
	var meter_value_bounded := clampf(float(meter_value), 0.0, MAX_METER)
	if state == Enums.AlertState.UNAWARE and meter_value_bounded <= 0.0:
		return {}
	if state == Enums.AlertState.RETURN and meter_value_bounded <= 0.0:
		return {}
	if phase_color(state) == Color(0.0, 0.0, 0.0, 0.0):
		return {}
	return {
		&"world_position": anchor.global_position,
		&"meter": meter_value_bounded,
		&"state": state,
	}


func _entry_for(instance_id: int) -> Dictionary:
	var existing: Variant = _entries.get(instance_id)
	if existing is Dictionary and is_instance_valid((existing as Dictionary).get(&"holder")):
		return existing as Dictionary
	if existing is Dictionary:
		_entries.erase(instance_id)
	if _entries.size() >= MAX_METERS:
		var eviction_id: Variant = _entries.keys()[0] if not _entries.is_empty() else null
		if eviction_id != null:
			_remove_entry(eviction_id)
	var holder := Control.new()
	holder.name = "EnemyMeter_%d" % instance_id
	holder.size = Vector2(METER_WIDTH, METER_HEIGHT + METER_OFFSET_Y)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(holder)
	var background := ColorRect.new()
	background.name = &"Background"
	background.position = Vector2(0.0, METER_OFFSET_Y)
	background.size = Vector2(METER_WIDTH, METER_HEIGHT)
	background.color = BACKGROUND_COLOR
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(background)
	var fill := ColorRect.new()
	fill.name = &"Fill"
	fill.position = Vector2.ZERO
	fill.size = background.size
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.add_child(fill)
	var symbol := Label.new()
	symbol.name = &"PhaseSymbol"
	symbol.position = Vector2(-18.0, 0.0)
	symbol.size = Vector2(16.0, METER_OFFSET_Y + METER_HEIGHT)
	symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	symbol.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	symbol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(symbol)
	var entry := {&"holder": holder, &"background": background, &"fill": fill, &"symbol": symbol}
	_entries[instance_id] = entry
	return entry


func _update_entry(entry: Dictionary, screen_position: Vector2, meter_value: float, state: int) -> void:
	var holder := entry.get(&"holder") as Control
	var background := entry.get(&"background") as ColorRect
	var fill := entry.get(&"fill") as ColorRect
	var symbol := entry.get(&"symbol") as Label
	if holder == null or background == null or fill == null or symbol == null:
		return
	var color := phase_color(state)
	if color.a <= 0.0 or not is_finite(meter_value):
		holder.visible = false
		return
	holder.position = screen_position - Vector2(METER_WIDTH * 0.5, METER_OFFSET_Y + METER_HEIGHT)
	symbol.position = Vector2(-18.0, 0.0)
	background.visible = true
	fill.visible = true
	fill.size = Vector2(METER_WIDTH * clampf(meter_value / MAX_METER, 0.0, 1.0), METER_HEIGHT)
	fill.color = color
	symbol.text = phase_symbol(state)
	symbol.add_theme_color_override("font_color", color)
	holder.visible = true


func _update_occluded_entry(
	entry: Dictionary,
	screen_position: Vector2,
	viewport_size: Vector2,
	state: int,
) -> void:
	var holder := entry.get(&"holder") as Control
	var background := entry.get(&"background") as ColorRect
	var fill := entry.get(&"fill") as ColorRect
	var symbol := entry.get(&"symbol") as Label
	if holder == null or background == null or fill == null or symbol == null:
		return
	var color := phase_color(state)
	if color.a <= 0.0:
		holder.visible = false
		return
	holder.position = _occlusion_indicator_position(screen_position, viewport_size) - holder.size * 0.5
	# The regular meter keeps its symbol left of the bar, but an edge
	# indicator has no bar.  Center the arrow on the clamped indicator so its
	# full label bounds remain inside the viewport at either horizontal edge.
	symbol.position = Vector2((holder.size.x - symbol.size.x) * 0.5, 0.0)
	background.visible = false
	fill.visible = false
	symbol.text = _occlusion_symbol(screen_position, viewport_size)
	symbol.add_theme_color_override("font_color", color)
	holder.visible = true


func _world_occluded(camera_node: Camera3D, enemy: Node, world_position: Vector3) -> bool:
	if (
		camera_node == null
		or not is_instance_valid(camera_node)
		or not _valid_enemy(enemy)
		or not _valid_world_position(world_position)
		or not _valid_world_position(camera_node.global_position)
	):
		return true
	var distance := camera_node.global_position.distance_to(world_position)
	if not is_finite(distance) or distance <= 0.001 or distance > MAX_WORLD_COORDINATE * 2.0:
		return true
	var world := camera_node.get_world_3d()
	if world == null:
		return true
	var query := PhysicsRayQueryParameters3D.create(camera_node.global_position, world_position)
	query.collision_mask = OCCLUSION_COLLISION_MASK
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [enemy.get_rid()] if enemy is CollisionObject3D else []
	var hit := world.direct_space_state.intersect_ray(query)
	return not hit.is_empty()


static func _occlusion_indicator_position(screen_position: Vector2, viewport_size: Vector2) -> Vector2:
	if not _valid_vector2(screen_position) or not _valid_vector2(viewport_size):
		return viewport_size * 0.5
	var center := viewport_size * 0.5
	var direction := screen_position - center
	if direction.length_squared() <= 0.000001:
		direction = Vector2.UP
	var scale := INF
	if absf(direction.x) > 0.0001:
		scale = minf(scale, (viewport_size.x * 0.5 - OCCLUSION_INDICATOR_MARGIN) / absf(direction.x))
	if absf(direction.y) > 0.0001:
		scale = minf(scale, (viewport_size.y * 0.5 - OCCLUSION_INDICATOR_MARGIN) / absf(direction.y))
	if not is_finite(scale) or scale <= 0.0:
		return center
	return center + direction * scale


static func _occlusion_symbol(screen_position: Vector2, viewport_size: Vector2) -> String:
	var direction := screen_position - viewport_size * 0.5
	if absf(direction.x) > absf(direction.y):
		return "→" if direction.x > 0.0 else "←"
	return "↓" if direction.y > 0.0 else "↑"


func _hide_entry(instance_id: int) -> void:
	var entry: Variant = _entries.get(instance_id)
	if not entry is Dictionary:
		return
	var holder := (entry as Dictionary).get(&"holder") as Control
	if holder != null:
		holder.visible = false


func _remove_entry(instance_id: Variant) -> void:
	var entry: Variant = _entries.get(instance_id)
	if entry is Dictionary:
		var holder := (entry as Dictionary).get(&"holder") as Control
		if holder != null and is_instance_valid(holder):
			holder.queue_free()
	_entries.erase(instance_id)


func _clear_entries() -> void:
	for entry: Dictionary in _entries.values():
		var holder := entry.get(&"holder") as Control
		if holder != null and is_instance_valid(holder):
			holder.queue_free()
	_entries.clear()


func _resolve_camera() -> Camera3D:
	if _camera_override != null and is_instance_valid(_camera_override):
		return _camera_override
	if not is_inside_tree():
		return null
	if camera_path != NodePath(""):
		var configured := get_node_or_null(camera_path) as Camera3D
		if configured != null:
			return configured
	var viewport := get_viewport()
	return viewport.get_camera_3d() if viewport != null else null


func _valid_enemy(enemy: Node) -> bool:
	return (
		enemy != null
		and is_instance_valid(enemy)
		and enemy is Node3D
		and is_inside_tree()
		and enemy.get_tree() == get_tree()
		and _valid_world_position((enemy as Node3D).global_position)
	)


static func _valid_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)


static func _valid_world_position(value: Vector3) -> bool:
	return (
		_valid_vector(value)
		and absf(value.x) <= MAX_WORLD_COORDINATE
		and absf(value.y) <= MAX_WORLD_COORDINATE
		and absf(value.z) <= MAX_WORLD_COORDINATE
	)


static func _is_incapacitated(brain: Node) -> bool:
	return brain != null and brain.has_method(&"is_incapacitated") and bool(brain.call(&"is_incapacitated"))


static func _valid_vector2(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)
