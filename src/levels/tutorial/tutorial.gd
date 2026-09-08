class_name TutorialLevel
extends Node3D

signal learning_observed(id: StringName, evidence: Dictionary)
signal route_completed(route: StringName)

const Geometry := preload("res://src/levels/tutorial/tutorial_geometry.gd")
const OBJECTIVES: Array[StringName] = [&"tutorial_sneak", &"tutorial_hide", &"tutorial_lure", &"tutorial_lights", &"tutorial_assassinate", &"tutorial_body", &"tutorial_document", &"tutorial_escape"]
const STONE := preload("res://data/tools/stone.tres")
var actors: Dictionary = {}
var learned: Dictionary = {}
var chosen_route: StringName = &""
var _previous_position := Vector3.ZERO
var _sneak_distance := 0.0
var _min_visibility := 1.0
var _max_visibility := 0.0
var _hidden_seconds := 0.0
var _hidden_patrol_distance := 0.0
var _patrol_previous := Vector3.ZERO
var _hidden_passed := false
var _exited_hide := false
var _peeked := false
var _gravel_heard := false
var _pending_lure: Dictionary = {}
var _lure_done := false
var _gate_lure_done := false
var _carried_target := false
var _roof_started := false
var _roof_climbed := false
var _ground_passed := false
var _failed := false
var _hint: Label
var _last_hint := ""


func _ready() -> void:
	MissionDirector.attach_mission_scene(self, load("res://data/missions/tutorial.tres"))
	actors = Geometry.new().build(self)
	_previous_position = actors.player.global_position
	_patrol_previous = actors.patrol_b.global_position
	var tools: ToolRig = actors.player.get_node("ToolRig")
	tools.set_tool_definitions([STONE], 3)
	EventBus.noise_emitted.connect(_on_noise)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.mission_event.connect(_on_mission_event)
	_create_standalone_hint()
	_sync_gates()


func _exit_tree() -> void:
	EventBus.noise_emitted.disconnect(_on_noise)
	EventBus.enemy_killed.disconnect(_on_enemy_killed)
	EventBus.mission_event.disconnect(_on_mission_event)


func _physics_process(delta: float) -> void:
	if actors.is_empty() or _failed:
		return
	var player: PlayerController = actors.player
	var position_now := player.global_position
	var displacement := position_now.distance_to(_previous_position)
	_previous_position = position_now
	var id := _objective_id()
	if id.is_empty() or GameState.current_mission_id != &"m01":
		return
	if position_now.y < -8.0:
		_fail(&"tutorial.retry_fall")
		return
	match id:
		&"tutorial_sneak":
			if _in_zone(1) and player.is_on_floor() and player.state_machine.current_state() == PlayerStateMachine.STATE_CROUCH:
				if displacement > 0.001 and displacement < maxf(0.1, delta * 12.0):
					_sneak_distance += displacement
				var visibility := (player.get_node("Visibility") as PlayerVisibility).visibility()
				# The shade sample must come from beneath the actual canopy;
				# ordinary distance falloff in open moonlight is not this lesson.
				if _canopy_blocks_moonlight():
					_min_visibility = minf(_min_visibility, visibility)
				_max_visibility = maxf(_max_visibility, visibility)
				if _sneak_distance >= 3.0 and _max_visibility - _min_visibility >= 0.08:
					_complete(id, {"distance": _sneak_distance, "visibility_min": _min_visibility, "visibility_max": _max_visibility, "shade_occluder": "PineCanopy"})
		&"tutorial_hide":
			_observe_hiding(delta)
		&"tutorial_lure":
			_observe_lure()
			if _gravel_heard and _lure_done:
				_complete(id, {"gravel_footstep": true, "sentry_displaced_by_stone": true})
		&"tutorial_lights":
			if not actors.lamp_a.is_on() and not actors.lamp_b.is_on():
				_complete(id, {"lights_off": ["HutLanternA", "HutLanternB"]})
		&"tutorial_body":
			if player.is_carrying_body() and player.carried_body() == actors.patrol_d:
				_carried_target = true
			if _carried_target and actors.body_hide.stored_body() == actors.patrol_d:
				_complete(id, {"body": "HutPatrol", "stored_in": "BodyHide"})
		&"tutorial_document":
			if not player.is_carrying_body() and player.global_position.distance_to(actors.document.global_position) <= 1.5 and Input.is_action_just_pressed(&"interact"):
				actors.document.hide()
				_complete(id, {"interacted_document": true})
		&"tutorial_escape":
			_observe_lure()
			if _gate_lure_done and not actors.gate_lamp.is_on():
				_open_gate(&"GroundGate", true)
			if player.state_machine.current_state() == PlayerStateMachine.STATE_CLIMB and player.active_climb_edge() == actors.roof_climb:
				_roof_started = true
			if _roof_started and player.state_machine.current_state() == PlayerStateMachine.STATE_GROUND and position_now.y >= 3.6:
				_roof_climbed = true
			if _gate_lure_done and not actors.gate_lamp.is_on() and position_now.z < -74 and position_now.x >= 6 and position_now.x <= 10 and position_now.y < 2:
				_ground_passed = true
			if position_now.z < -79 and position_now.z > -87 and position_now.x >= -4 and position_now.x <= 10 and player.is_on_floor() and position_now.y < 2:
				if _roof_climbed or _ground_passed:
					chosen_route = &"roof" if _roof_climbed else &"ground"
					_complete(id, {"route": String(chosen_route)})
					route_completed.emit(chosen_route)
	if Input.is_action_just_pressed(&"interact"):
		for box in [actors.stone_box, actors.gate_stone_box]:
			if position_now.distance_to(box.global_position) < 1.8:
				var tools: ToolRig = player.get_node("ToolRig")
				tools.inventory.set_remaining_count(0, STONE.safe_default_count())
	_update_hint()


func _observe_hiding(delta: float) -> void:
	var player: PlayerController = actors.player
	var patrol: EnemyBase = actors.patrol_b
	var movement := patrol.global_position.distance_to(_patrol_previous)
	_patrol_previous = patrol.global_position
	if player.is_hidden() and player.active_hide_spot() == actors.brush:
		_hidden_seconds += minf(delta, 0.25)
		if movement < maxf(0.1, delta * 12.0):
			_hidden_patrol_distance += movement
		_hidden_passed = _hidden_seconds >= 3.0 and _hidden_patrol_distance >= 2.0
	elif _hidden_passed:
		_exited_hide = true
	if _in_zone(2) and player.state_machine.current_state() == PlayerStateMachine.STATE_WALL_CLING and player.camera_peek_offset().length() > 0.05:
		_peeked = true
	if _exited_hide and _peeked:
		_complete(&"tutorial_hide", {"hidden_sec": _hidden_seconds, "patrol_distance": _hidden_patrol_distance, "peeked": true})


func _on_noise(event: NoiseEvent) -> void:
	if _failed or actors.is_empty() or event == null:
		return
	var id := _objective_id()
	var player: PlayerController = actors.player
	if id == &"tutorial_lure" and event.source == player.get_node("NoiseEmitter") and event.kind == Enums.NoiseKind.FOOTSTEP and _in_zone(3):
		var expected := NoiseEmitter.footstep_radius(player.state_machine.stance(), &"gravel", Tuning.movement())
		if player.global_position.z <= -41 and player.global_position.z >= -49 and absf(player.global_position.x) < 5 and is_equal_approx(event.radius, expected):
			_gravel_heard = true
	if id not in [&"tutorial_lure", &"tutorial_escape"] or event.source != player or event.kind != Enums.NoiseKind.TOOL:
		return
	var tools: ToolRig = player.get_node("ToolRig")
	if tools.selected_definition() == null or tools.selected_definition().id != &"stone":
		return
	var sentry: EnemyBase = actors.guard_c
	if event.position.distance_to(sentry.global_position) > event.radius or event.radius > 6.0:
		return
	_pending_lure = {"objective": id, "impact": event.position, "before": sentry.global_position}


func _observe_lure() -> void:
	if _pending_lure.is_empty() or _pending_lure.objective != _objective_id():
		return
	var sentry: EnemyBase = actors.guard_c
	var brain := sentry.brain()
	if brain.current_state() not in [Enums.AlertState.SUSPICIOUS, Enums.AlertState.SEARCHING]:
		return
	if brain.investigation_position().distance_to(_pending_lure.impact) > 0.75:
		return
	if sentry.global_position.distance_to(_pending_lure.before) < 0.5:
		return
	if sentry.global_position.distance_to(_pending_lure.impact) >= (_pending_lure.before as Vector3).distance_to(_pending_lure.impact):
		return
	if _pending_lure.objective == &"tutorial_lure":
		_lure_done = true
	else:
		_gate_lure_done = true
	_pending_lure.clear()


func _on_enemy_killed(enemy: Node, method: String) -> void:
	if _failed or actors.is_empty():
		return
	if enemy == actors.guard_c and _objective_id() != &"":
		_fail(&"tutorial.retry_sentry")
	elif enemy == actors.patrol_b and not learned.has(&"tutorial_hide"):
		_fail(&"tutorial.retry_patrol")
	elif enemy == actors.patrol_d:
		if not learned.has(&"tutorial_lights") or method != "assassination" or actors.patrol_d.assassination_context() != &"back":
			_fail(&"tutorial.retry_assassinate")
		else:
			# MissionDirector owns this KILL_TARGET advance and its score counter.
			learned[&"tutorial_assassinate"] = {"method": method, "context": "back"}
			learning_observed.emit(&"tutorial_assassinate", learned[&"tutorial_assassinate"])


func _on_mission_event(event_name: StringName, _payload: Dictionary) -> void:
	if event_name == EventBus.EV_CHECKPOINT_REACHED and not actors.is_empty():
		GameState.checkpoint_ref["tutorial_world"] = capture_checkpoint_world()
	elif event_name == EventBus.EV_MISSION_FAILED:
		_failed = true
	elif event_name == EventBus.EV_OBJECTIVE_CHANGED:
		_sync_gates()


func _complete(id: StringName, evidence: Dictionary) -> void:
	if _failed or _objective_id() != id:
		return
	learned[id] = evidence.duplicate(true)
	learning_observed.emit(id, evidence.duplicate(true))
	MissionDirector.complete_objective(id)
	_sync_gates()


func _objective_id() -> StringName:
	var current := MissionDirector.current_objective()
	return current.id if current != null and current.id in OBJECTIVES else &""


func _sync_gates() -> void:
	if actors.is_empty():
		return
	var index := OBJECTIVES.find(_objective_id())
	_open_gate(&"SneakGate", index >= 1)
	_open_gate(&"HideGate", index >= 2)
	_open_gate(&"LureGate", index >= 3)
	_open_gate(&"DocumentGate", index >= 7)


func _open_gate(id: StringName, opened: bool) -> void:
	var gate: StaticBody3D = actors[id]
	gate.visible = not opened
	gate.collision_layer = 0 if opened else 1 | (1 << 4) | (1 << 5)


func _in_zone(zone: int) -> bool:
	var point: Vector3 = actors.player.global_position
	match zone:
		1: return absf(point.x) < 7.5 and point.z > -18 and point.z < 8
		2: return absf(point.x) < 7.5 and point.z <= -18 and point.z > -38
		3: return absf(point.x) < 8 and point.z <= -38 and point.z > -59
	return false


func _fail(reason: StringName) -> void:
	if _failed:
		return
	_failed = true
	MissionDirector.fail_mission(StringName(_text(reason)))


func _update_hint() -> void:
	var key := StringName("tutorial.hint." + String(_objective_id()).trim_prefix("tutorial_"))
	var text := _text(key)
	for action in [&"stance_toggle", &"interact", &"peek", &"aim", &"tool_use", &"assassinate", &"move_forward", &"move_left", &"move_right"]:
		text = text.replace("{" + String(action) + "}", _binding(action))
	if text == _last_hint:
		return
	_last_hint = text
	var director := _scene_director()
	if director != null and director.has_method("set_mission_hint"):
		director.set_mission_hint(text)
	elif is_instance_valid(_hint):
		_hint.text = text


func _scene_director() -> Node:
	return get_tree().get_first_node_in_group(&"scene_director")


func _create_standalone_hint() -> void:
	if _scene_director() != null:
		return
	var layer := CanvasLayer.new()
	add_child(layer)
	_hint = Label.new()
	_hint.position = Vector2(24, 24)
	_hint.size = Vector2(900, 90)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_font_override("font", load("res://assets/fonts/NotoSerifJP.ttf"))
	_hint.add_theme_font_size_override("font_size", 22)
	layer.add_child(_hint)


static func _binding(action: StringName) -> String:
	return GameText.binding_text(action)


static func _text(key: StringName) -> String:
	if ResourceLoader.exists("res://src/ui/game_text.gd"):
		var catalog = load("res://src/ui/game_text.gd")
		return catalog.get_text(key)
	return String(key)


func _entities() -> Dictionary:
	return {"guard_a": actors.guard_a, "patrol_b": actors.patrol_b, "guard_c": actors.guard_c, "patrol_d": actors.patrol_d}


func capture_checkpoint_world() -> Dictionary:
	var npcs := {}
	for id: String in _entities():
		npcs[id] = MissionNpcSnapshot.capture(_entities()[id])
	var flags := {}
	for key in ["_hidden_passed", "_exited_hide", "_peeked", "_gravel_heard", "_lure_done", "_gate_lure_done", "_carried_target", "_roof_started", "_roof_climbed", "_ground_passed"]:
		flags[key] = get(key)
	var measures := {}
	for key in ["_sneak_distance", "_min_visibility", "_max_visibility", "_hidden_seconds", "_hidden_patrol_distance"]:
		measures[key] = get(key)
	return {"version": 1, "mission": MissionDirector.capture_checkpoint_state(_entities()), "npcs": npcs, "learned": learned.keys().map(func(id): return String(id)), "flags": flags, "measures": measures, "lights": [actors.lamp_a.is_on(), actors.lamp_b.is_on(), actors.gate_lamp.is_on()], "stored": actors.patrol_d.is_stored()}


func restore_checkpoint_world(snapshot: Dictionary) -> bool:
	var value: Variant = snapshot.get("tutorial_world")
	if not value is Dictionary or value.get("version") != 1:
		return false
	var entities := _entities()
	if not value.get("npcs") is Dictionary or value.npcs.size() != entities.size() or not value.get("mission") is Dictionary:
		return false
	if not MissionDirector.checkpoint_state_is_valid(value.mission, entities):
		return false
	for id: String in entities:
		if not value.npcs.get(id) is Dictionary or not MissionNpcSnapshot.is_valid(value.npcs[id], entities[id]):
			return false
	if not value.get("learned") is Array or value.learned.size() != int(value.mission.objective):
		return false
	for index in value.learned.size():
		if value.learned[index] != String(OBJECTIVES[index]):
			return false
	if not value.get("flags") is Dictionary or not value.get("measures") is Dictionary:
		return false
	for key in ["_hidden_passed", "_exited_hide", "_peeked", "_gravel_heard", "_lure_done", "_gate_lure_done", "_carried_target", "_roof_started", "_roof_climbed", "_ground_passed"]:
		if not value.flags.get(key) is bool: return false
	for key in ["_sneak_distance", "_min_visibility", "_max_visibility", "_hidden_seconds", "_hidden_patrol_distance"]:
		if not CheckpointSnapshot._finite_number(value.measures.get(key)) or float(value.measures[key]) < 0 or float(value.measures[key]) > 1000000:
			return false
	if not value.get("lights") is Array or value.lights.size() != 3 or not value.get("stored") is bool:
		return false
	for light in value.lights:
		if not light is bool: return false
	var target_dead: bool = value.npcs.patrol_d.brain.kind == "dead"
	if (int(value.mission.objective) >= 5) != target_dead or (value.stored and not target_dead):
		return false
	# Validate the complete payload before changing live entities or counters.
	var supported := capture_checkpoint_world()
	for key: String in supported.flags:
		set(key, value.flags[key])
	for key: String in supported.measures:
		set(key, float(value.measures[key]))
	for index in 3:
		var source: LightSource = [actors.lamp_a, actors.lamp_b, actors.gate_lamp][index]
		source.set_extinguished(not value.lights[index])
	for id: String in entities:
		MissionNpcSnapshot.restore(value.npcs[id], entities[id])
	learned.clear()
	for id in value.learned:
		learned[StringName(id)] = {"restored": true}
	actors.document.visible = not learned.has(&"tutorial_document")
	_failed = false
	_pending_lure.clear()
	_previous_position = actors.player.global_position
	_patrol_previous = actors.patrol_b.global_position
	if value.stored:
		if not actors.body_hide.restore_stored_body(actors.patrol_d): return false
	MissionDirector.restore_checkpoint_state(value.mission, entities)
	_sync_gates()
	_open_gate(&"GroundGate", _gate_lure_done and not actors.gate_lamp.is_on())
	return true


func _canopy_blocks_moonlight() -> bool:
	var player: PlayerController = actors.player
	var chest: Node3D = player.get_node("DetectPoints/Chest")
	var query := PhysicsRayQueryParameters3D.create(get_node("MoonPool").global_position, chest.global_position, 1 | (1 << 4))
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.get("collider") == get_node("PineCanopy")
