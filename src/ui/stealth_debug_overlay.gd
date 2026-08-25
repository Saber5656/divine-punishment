class_name StealthDebugOverlay
extends Node3D


## Runtime tuning aid for the stealth systems.
##
## The overlay deliberately consumes only public contracts:
## - `LightSource` nodes are discovered through the existing `lights` group.
## - `PlayerVisibility.visibility()` is read from the player or its `Visibility`
##   child.
## - `EventBus.noise_emitted` is telemetry.  Enemy perception remains on the
##   filtered `NoiseEventSystem` dispatch path selected for Issue #15.
##
## Enemy implementations can opt in without this overlay depending on an
## `EnemyBase` class that does not exist yet.  Register an enemy and provide a
## `debug_vision_cone()` method, or set `enemy_debug_provider` to a Callable
## returning the dictionary described by `_normalise_enemy_data()` below.

const DEBUG_TOGGLE_ACTION: StringName = &"debug_overlay_toggle"
const DEFAULT_NOISE_LIFETIME := 1.5
const MAX_NOISE_RINGS := 64
const LIGHT_RING_SEGMENTS := 32
const NOISE_RING_SEGMENTS := 32
const VISION_CONE_SEGMENTS := 16
const DEFAULT_ENEMY_METER_MAX := 3.0
const MIN_RADIUS := 0.001

@export var toggle_action: StringName = DEBUG_TOGGLE_ACTION
@export var visible_by_default := false
@export_range(0.1, 10.0, 0.1) var noise_lifetime := DEFAULT_NOISE_LIFETIME
@export_range(0.1, 10.0, 0.1) var enemy_meter_max := DEFAULT_ENEMY_METER_MAX
@export var player_path: NodePath

var _debug_visible := false
var _elapsed := 0.0
var _noise_rings: Array[Dictionary] = []
var _enemy_sources: Array[Node] = []
var _player: Node
var _enemy_debug_provider := Callable()

var _mesh := ImmediateMesh.new()
var _mesh_instance := MeshInstance3D.new()
var _canvas_layer := CanvasLayer.new()
var _status_label := Label.new()
var _light_material := _make_material(Color(1.0, 0.76, 0.25, 0.85))
var _extinguished_light_material := _make_material(Color(0.4, 0.4, 0.45, 0.55))
var _noise_material := _make_material(Color(0.25, 0.8, 1.0, 0.9))
var _vision_material := _make_material(Color(1.0, 0.3, 0.35, 0.9))
var _meter_material := _make_material(Color(1.0, 0.85, 0.2, 0.95))


func _ready() -> void:
	_mesh_instance.mesh = _mesh
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(_mesh_instance)

	_canvas_layer.layer = 100
	_canvas_layer.name = &"StealthDebugCanvas"
	add_child(_canvas_layer)
	_status_label.position = Vector2(16.0, 16.0)
	_status_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0, 0.95))
	_status_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	_status_label.add_theme_constant_override("shadow_offset_x", 2)
	_status_label.add_theme_constant_override("shadow_offset_y", 2)
	_status_label.add_theme_font_size_override("font_size", 16)
	_canvas_layer.add_child(_status_label)

	if has_node("/root/EventBus"):
		EventBus.noise_emitted.connect(_on_noise_emitted)
	_debug_visible = visible_by_default and OS.is_debug_build()
	_refresh_visibility()
	set_process(true)
	set_process_unhandled_input(true)


func _exit_tree() -> void:
	if has_node("/root/EventBus") and EventBus.noise_emitted.is_connected(_on_noise_emitted):
		EventBus.noise_emitted.disconnect(_on_noise_emitted)


func _process(delta: float) -> void:
	if is_finite(delta) and delta > 0.0:
		_elapsed += delta
	_prune_noise_rings()
	if not _debug_visible:
		return
	_rebuild_geometry()
	_update_status_label()


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not event.is_action_pressed(toggle_action):
		return
	toggle_debug_visible()
	get_viewport().set_input_as_handled()


func set_debug_visible(value: bool) -> void:
	_debug_visible = value
	_refresh_visibility()
	if _debug_visible:
		_rebuild_geometry()
		_update_status_label()


func toggle_debug_visible() -> bool:
	set_debug_visible(not _debug_visible)
	return _debug_visible


func is_debug_visible() -> bool:
	return _debug_visible


## Bind a player explicitly when the level owns more than one player-like node.
## If omitted, the overlay discovers the first node in the `player` group.
func set_player(player: Node) -> void:
	_player = player


func player() -> Node:
	if is_instance_valid(_player):
		return _player
	_player = _discover_player()
	return _player


## Register a perception component or enemy root for future M3 vision output.
## A registered node may expose `debug_vision_cone() -> Dictionary`.
func register_enemy(enemy: Node) -> void:
	if not is_instance_valid(enemy) or _enemy_sources.has(enemy):
		return
	_enemy_sources.append(enemy)


func unregister_enemy(enemy: Node) -> void:
	_enemy_sources.erase(enemy)


func set_enemy_sources(enemies: Array[Node]) -> void:
	_enemy_sources.clear()
	for enemy in enemies:
		register_enemy(enemy)


func clear_enemy_sources() -> void:
	_enemy_sources.clear()


## The provider receives each registered enemy and returns a Dictionary with:
## origin, forward, fov_degrees, view_distance, meter, meter_max, color, label.
## `origin`, `forward`, `fov_degrees`, and `view_distance` are required to draw
## a cone; meter fields are optional and add a 3D meter bar plus HUD text.
func set_enemy_debug_provider(provider: Callable) -> void:
	_enemy_debug_provider = provider


func enemy_debug_provider() -> Callable:
	return _enemy_debug_provider


func record_noise_event(event: NoiseEvent) -> void:
	if event == null or not is_finite(event.radius) or event.radius <= 0.0:
		return
	_noise_rings.append({
		&"position": event.position,
		&"radius": event.radius,
		&"kind": event.kind,
		&"age": 0.0,
	})
	while _noise_rings.size() > MAX_NOISE_RINGS:
		_noise_rings.pop_front()


func active_noise_count() -> int:
	return _noise_rings.size()


func active_noise_radii() -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for ring in _noise_rings:
		snapshot.append(ring.duplicate())
	return snapshot


func light_radius_snapshot() -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	if not is_inside_tree():
		return snapshot
	for node in get_tree().get_nodes_in_group("lights"):
		var light := node as LightSource
		if light == null or not is_finite(light.gameplay_radius) or light.gameplay_radius <= 0.0:
			continue
		snapshot.append({
			&"node": light,
			&"position": light.global_position,
			&"radius": light.gameplay_radius,
			&"active": light.is_on(),
		})
	return snapshot


func enemy_debug_snapshot() -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for enemy in _resolved_enemy_sources():
		var data := _enemy_data(enemy)
		if not data.is_empty():
			snapshot.append(data)
	return snapshot


func debug_geometry_snapshot() -> Dictionary:
	var enemies := enemy_debug_snapshot()
	var meter_count := 0
	for item in enemies:
		if item.has(&"meter"):
			meter_count += 1
	return {
		&"light_radii": light_radius_snapshot().size(),
		&"noise_radii": active_noise_count(),
		&"vision_cones": enemies.size(),
		&"meter_values": meter_count,
	}


func _on_noise_emitted(event: NoiseEvent) -> void:
	record_noise_event(event)


func _prune_noise_rings() -> void:
	var lifetime := noise_lifetime if is_finite(noise_lifetime) and noise_lifetime > 0.0 else DEFAULT_NOISE_LIFETIME
	for index in range(_noise_rings.size() - 1, -1, -1):
		_noise_rings[index][&"age"] = float(_noise_rings[index].get(&"age", 0.0)) + _elapsed
		if float(_noise_rings[index].get(&"age", 0.0)) >= lifetime:
			_noise_rings.remove_at(index)
	_elapsed = 0.0


func _refresh_visibility() -> void:
	_mesh_instance.visible = _debug_visible
	_canvas_layer.visible = _debug_visible
	if not _debug_visible:
		_mesh.clear_surfaces()


func _discover_player() -> Node:
	if not is_inside_tree():
		return null
	if not player_path.is_empty():
		var configured := get_node_or_null(player_path)
		if configured != null:
			return configured
	var grouped := get_tree().get_nodes_in_group("player")
	if not grouped.is_empty():
		return grouped[0] as Node
	var current_scene := get_tree().current_scene
	return current_scene.find_child("Player", true, false) if current_scene != null else null


func _resolved_enemy_sources() -> Array[Node]:
	var result: Array[Node] = []
	for enemy in _enemy_sources:
		if is_instance_valid(enemy):
			result.append(enemy)
	if not result.is_empty() or not is_inside_tree():
		return result
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is Node and not result.has(enemy):
			result.append(enemy as Node)
	return result


func _enemy_data(enemy: Node) -> Dictionary:
	var raw: Variant = null
	if _enemy_debug_provider.is_valid():
		raw = _enemy_debug_provider.call(enemy)
	elif enemy.has_method(&"debug_vision_cone"):
		raw = enemy.call(&"debug_vision_cone")
	elif enemy.has_method(&"debug_vision_data"):
		raw = enemy.call(&"debug_vision_data")
	if raw is Dictionary:
		return _normalise_enemy_data(enemy, raw as Dictionary)
	return {}


func _normalise_enemy_data(enemy: Node, raw: Dictionary) -> Dictionary:
	var origin := _vector_from(raw.get(&"origin", raw.get(&"position", _node_position(enemy))), _node_position(enemy))
	var forward := _vector_from(raw.get(&"forward", raw.get(&"direction", _node_forward(enemy))), Vector3.FORWARD)
	forward.y = 0.0
	if forward.length_squared() <= MIN_RADIUS * MIN_RADIUS:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	var fov := _finite_float(raw.get(&"fov_degrees", raw.get(&"fov", 0.0)), 0.0)
	var view_distance := _finite_float(raw.get(&"view_distance", raw.get(&"view_distance_m", 0.0)), 0.0)
	if fov <= 0.0 or view_distance <= 0.0:
		return {}
	var result := {
		&"enemy": enemy,
		&"origin": origin,
		&"forward": forward,
		&"fov_degrees": clampf(fov, 0.0, 360.0),
		&"view_distance": view_distance,
		&"color": raw.get(&"color", Color(1.0, 0.3, 0.35, 0.9)),
		&"label": str(raw.get(&"label", enemy.name)),
	}
	if raw.has(&"meter"):
		result[&"meter"] = _finite_float(raw.get(&"meter"), 0.0)
	elif enemy.has_method(&"meter"):
		result[&"meter"] = _finite_float(enemy.call(&"meter"), 0.0)
	elif enemy.get(&"detection_meter") != null:
		result[&"meter"] = _finite_float(enemy.get(&"detection_meter"), 0.0)
	if raw.has(&"meter_max"):
		result[&"meter_max"] = _finite_float(raw.get(&"meter_max"), enemy_meter_max)
	else:
		result[&"meter_max"] = enemy_meter_max
	return result


func _rebuild_geometry() -> void:
	_mesh.clear_surfaces()
	_draw_light_radii()
	_draw_noise_radii()
	_draw_enemy_debug()


func _draw_light_radii() -> void:
	for entry in light_radius_snapshot():
		var light := entry.get(&"node") as LightSource
		if light == null:
			continue
		var segments := light.gizmo_segments()
		if segments.is_empty():
			continue
		var material := _light_material if bool(entry.get(&"active", true)) else _extinguished_light_material
		_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
		for index in range(0, segments.size(), 2):
			_mesh.surface_add_vertex(to_local(light.to_global(segments[index])))
			_mesh.surface_add_vertex(to_local(light.to_global(segments[index + 1])))
		_mesh.surface_end()


func _draw_noise_radii() -> void:
	if _noise_rings.is_empty():
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _noise_material)
	for ring in _noise_rings:
		var center := to_local(ring.get(&"position", Vector3.ZERO))
		var radius := _finite_float(ring.get(&"radius", 0.0), 0.0)
		if radius <= 0.0:
			continue
		for index in NOISE_RING_SEGMENTS:
			var start_angle := TAU * float(index) / NOISE_RING_SEGMENTS
			var end_angle := TAU * float(index + 1) / NOISE_RING_SEGMENTS
			_mesh.surface_add_vertex(center + Vector3(cos(start_angle), 0.03, sin(start_angle)) * radius)
			_mesh.surface_add_vertex(center + Vector3(cos(end_angle), 0.03, sin(end_angle)) * radius)
	_mesh.surface_end()


func _draw_enemy_debug() -> void:
	var enemies := enemy_debug_snapshot()
	for data in enemies:
		var origin: Vector3 = data.get(&"origin", Vector3.ZERO)
		var forward: Vector3 = data.get(&"forward", Vector3.FORWARD)
		var half_angle := deg_to_rad(float(data.get(&"fov_degrees", 0.0))) * 0.5
		var distance := float(data.get(&"view_distance", 0.0))
		_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _vision_material)
		var left := forward.rotated(Vector3.UP, -half_angle)
		var right := forward.rotated(Vector3.UP, half_angle)
		_mesh.surface_add_vertex(to_local(origin))
		_mesh.surface_add_vertex(to_local(origin + left * distance))
		_mesh.surface_add_vertex(to_local(origin))
		_mesh.surface_add_vertex(to_local(origin + right * distance))
		var previous := origin + left * distance
		for index in range(1, VISION_CONE_SEGMENTS + 1):
			var angle := -half_angle + (half_angle * 2.0 * float(index) / VISION_CONE_SEGMENTS)
			var current := origin + forward.rotated(Vector3.UP, angle) * distance
			_mesh.surface_add_vertex(to_local(previous))
			_mesh.surface_add_vertex(to_local(current))
			previous = current
		_mesh.surface_end()
		if data.has(&"meter"):
			var meter := clampf(float(data.get(&"meter", 0.0)), 0.0, float(data.get(&"meter_max", enemy_meter_max)))
			var max_meter := maxf(float(data.get(&"meter_max", enemy_meter_max)), MIN_RADIUS)
			var meter_height := clampf(meter / max_meter, 0.0, 1.0)
			_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _meter_material)
			_mesh.surface_add_vertex(to_local(origin + Vector3(0.0, 0.03, 0.0)))
			_mesh.surface_add_vertex(to_local(origin + Vector3(0.0, 0.03 + meter_height, 0.0)))
			_mesh.surface_end()


func _update_status_label() -> void:
	var lines: Array[String] = ["STEALTH DEBUG  [F3]", ""]
	var player_node := player()
	var visibility_value := _player_visibility(player_node)
	if visibility_value == null:
		lines.append("Player V: --")
	else:
		lines.append("Player V: %.3f" % float(visibility_value))
	lines.append("Light radii: %d" % light_radius_snapshot().size())
	lines.append("Noise radii: %d" % active_noise_count())
	var enemies := enemy_debug_snapshot()
	lines.append("Vision cones: %d" % enemies.size())
	for data in enemies:
		if data.has(&"meter"):
			lines.append("  %s meter: %.2f / %.2f" % [
				str(data.get(&"label", "enemy")),
				float(data.get(&"meter", 0.0)),
				float(data.get(&"meter_max", enemy_meter_max)),
			])
	_status_label.text = "\n".join(lines)


func _player_visibility(player_node: Node) -> Variant:
	if player_node == null:
		return null
	if player_node.has_method(&"visibility"):
		return clampf(_finite_float(player_node.call(&"visibility"), 0.0), 0.0, 1.0)
	var visibility_node := player_node.get_node_or_null("Visibility")
	if visibility_node != null and visibility_node.has_method(&"visibility"):
		return clampf(_finite_float(visibility_node.call(&"visibility"), 0.0), 0.0, 1.0)
	return null


func _node_position(node: Node) -> Vector3:
	return (node as Node3D).global_position if node is Node3D else Vector3.ZERO


func _node_forward(node: Node) -> Vector3:
	return (node as Node3D).global_transform.basis * Vector3.FORWARD if node is Node3D else Vector3.FORWARD


func _vector_from(value: Variant, fallback: Vector3) -> Vector3:
	return value as Vector3 if value is Vector3 else fallback


func _finite_float(value: Variant, fallback: float) -> float:
	if value is float or value is int:
		var result := float(value)
		return result if is_finite(result) else fallback
	return fallback


static func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	return material
