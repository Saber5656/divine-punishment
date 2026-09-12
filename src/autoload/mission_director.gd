extends Node


var _definition: MissionDefinition
var _mission_scene_id := 0
var _stats: MissionStats = MissionStats.new()
var _current_objective_index: int = 0
var _failed_reason: StringName = &""
var _running := false
var _completed := false
var _monologue_sent := false
var _target_kills := 0
var _all_target_kills_assassinated := true
var _killed_entities: Dictionary = {}
var _neutralized_entities: Dictionary = {}
var _contact_entities: Dictionary = {}
var _spotted_corpse_anomalies: Dictionary = {}

const MAX_AREA_ALERT_LEVEL := 5


func _ready() -> void:
	EventBus.anomaly_spotted.connect(_on_anomaly_spotted)
	EventBus.player_detected.connect(_on_player_detected)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.civilian_killed.connect(_on_civilian_killed)
	EventBus.alert_changed.connect(_on_contact_alert)
	EventBus.enemy_neutralized.connect(_on_enemy_neutralized)
	EventBus.mission_event.connect(_on_mission_event)


func _exit_tree() -> void:
	EventBus.anomaly_spotted.disconnect(_on_anomaly_spotted)
	EventBus.player_detected.disconnect(_on_player_detected)
	EventBus.enemy_killed.disconnect(_on_enemy_killed)
	EventBus.civilian_killed.disconnect(_on_civilian_killed)
	EventBus.alert_changed.disconnect(_on_contact_alert)
	EventBus.enemy_neutralized.disconnect(_on_enemy_neutralized)
	EventBus.mission_event.disconnect(_on_mission_event)


func _process(delta: float) -> void:
	if _running and is_finite(delta) and delta > 0.0:
		_stats.elapsed_sec += delta


func start_mission(def: MissionDefinition) -> void:
	WeatherSystem.start(def.weather if def != null else MissionDefinition.Weather.CLEAR)
	AudioDirector.play_bgm_set(&"normal")
	AudioDirector.set_ambience(&"night")
	_definition = def
	_mission_scene_id = 0
	_stats = MissionStats.new()
	_stats.one_strike = false
	_current_objective_index = 0
	_failed_reason = &""
	_running = def != null
	_completed = false
	_monologue_sent = false
	_target_kills = 0
	_all_target_kills_assassinated = true
	_killed_entities.clear()
	_neutralized_entities.clear()
	_contact_entities.clear()
	_spotted_corpse_anomalies.clear()
	if def != null:
		GameState.reset_for_mission(def.id)
		_emit_current_objective()


func complete_objective(id: StringName) -> void:
	if not _running or id.is_empty():
		return
	if _definition.side_objective != null and id == _definition.side_objective.id:
		if not _stats.side_objective_completed:
			_stats.side_objective_completed = true
			EventBus.mission_event.emit(EventBus.EV_OBJECTIVE_COMPLETED, { "id": id, "side_objective": true })
		return
	var objective := current_objective()
	if objective == null or objective.id != id:
		return
	_current_objective_index += 1
	if _current_objective_index >= _definition.objectives.size():
		_running = false
		_completed = true
	EventBus.mission_event.emit(EventBus.EV_OBJECTIVE_COMPLETED, { "id": id })
	_emit_current_objective()


func fail_mission(reason: StringName) -> void:
	if not _running or reason.is_empty():
		return
	_running = false
	_failed_reason = reason
	EventBus.mission_event.emit(EventBus.EV_MISSION_FAILED, { "reason": reason })


func current_objective() -> ObjectiveData:
	if _definition == null or _current_objective_index >= _definition.objectives.size():
		return null
	return _definition.objectives[_current_objective_index]


func stats() -> MissionStats:
	return _stats


func _emit_current_objective() -> void:
	var objective := current_objective()
	var id: StringName = objective.id if objective != null else &""
	EventBus.mission_event.emit(EventBus.EV_OBJECTIVE_CHANGED, { "id": id })
	if objective != null and objective.kind == &"ESCAPE":
		EventBus.mission_event.emit(EventBus.EV_ESCAPE_OPENED, { "id": id })


func _on_player_detected() -> void:
	if _running:
		_stats.detections += 1


func _on_enemy_killed(enemy: Node, method: String) -> void:
	if not _running or not is_instance_valid(enemy):
		return
	var identity := enemy.get_instance_id()
	if _killed_entities.has(identity):
		return
	_killed_entities[identity] = true
	if _definition.kill_policy == MissionDefinition.KillPolicy.FORBIDDEN:
		fail_mission(&"killing_forbidden")
		return
	if enemy.is_in_group(&"civilians"):
		_stats.civilian_kills += 1
	elif _is_mission_target(enemy):
		if not _definition.last_words_id.is_empty():
			EventBus.mission_event.emit(&"target_last_words",{"text_id":_definition.last_words_id})
		if method == "assassination" and not _monologue_sent and not _definition.inner_monologue_id.is_empty():
			_monologue_sent = true
			EventBus.inner_monologue_requested.emit(_definition.inner_monologue_id)
		_target_kills += 1
		_all_target_kills_assassinated = _all_target_kills_assassinated and method == "assassination"
		_stats.one_strike = _target_kills > 0 and _all_target_kills_assassinated
		var objective := current_objective()
		if _target_matches(objective, enemy):
			complete_objective(objective.id)
	else:
		_stats.nontarget_kills += 1


func _on_civilian_killed(civilian: Node) -> void:
	if not _running or not is_instance_valid(civilian):
		return
	var identity := civilian.get_instance_id()
	if _killed_entities.has(identity):
		return
	_killed_entities[identity] = true
	if _definition.kill_policy == MissionDefinition.KillPolicy.FORBIDDEN:
		fail_mission(&"killing_forbidden")
		return
	_stats.civilian_kills += 1


func _on_enemy_neutralized(enemy: Node, method: String) -> void:
	if not _running or not is_instance_valid(enemy) or method != "knockout":
		return
	var identity := enemy.get_instance_id()
	if _neutralized_entities.has(identity) or _killed_entities.has(identity):
		return
	_neutralized_entities[identity] = true
	_stats.knockouts += 1
	_register_contact(enemy)


func _on_mission_event(event_name: StringName, payload: Dictionary) -> void:
	if not _running:
		return
	if event_name == EventBus.EV_TARGET_KILLED:
		var target := payload.get("target") as Node
		if is_instance_valid(target) and _is_mission_target(target):
			_on_enemy_killed(target, String(payload.get("method", "unknown")))
	elif event_name == EventBus.EV_MISSION_FAILED:
		var reason := StringName(payload.get("reason", &""))
		if not reason.is_empty():
			_running = false
			_failed_reason = reason


func _is_mission_target(enemy: Node) -> bool:
	for objective in _definition.objectives:
		if _target_matches(objective, enemy):
			return true
	return false


func _target_matches(objective: ObjectiveData, enemy: Node) -> bool:
	if objective == null or objective.kind != &"KILL_TARGET":
		return false
	var group: StringName = objective.target_group if not objective.target_group.is_empty() else &"target_npcs"
	return enemy.is_in_group(group)


func _on_anomaly_spotted(anomaly: Anomaly, _by: Node) -> void:
	if (
		anomaly == null
		or anomaly.kind not in [Enums.AnomalyKind.CORPSE, Enums.AnomalyKind.RESTRAINED]
		or anomaly.severity < 1
		or anomaly.severity > 3
		or not is_finite(anomaly.expires_at)
		or anomaly.expires_at < 0.0
		or (anomaly.expires_at > 0.0 and Time.get_ticks_msec() / 1000.0 >= anomaly.expires_at)
	):
		return
	var corpse_key := _corpse_key(anomaly)
	if corpse_key.is_empty() or _spotted_corpse_anomalies.has(corpse_key):
		return
	_spotted_corpse_anomalies[corpse_key] = true
	if _running:
		_stats.bodies_found += 1
	# Area alert belongs to the world even when no scored mission is running.
	GameState.area_alert_level = mini(int(GameState.area_alert_level) + 1, MAX_AREA_ALERT_LEVEL)
	EventBus.area_alert_changed.emit(GameState.area_alert_level)


## Prefer the physical body identity over the transient Anomaly wrapper.
func _corpse_key(anomaly: Anomaly) -> String:
	if anomaly == null:
		return ""
	var body := anomaly.node
	if is_instance_valid(body):
		return "body:%s" % body.get_instance_id()
	return "anomaly:%s" % anomaly.get_instance_id()


func build_result() -> MissionResult:
	if _definition == null:
		return MissionResult.create(0, &"shoden", { &"failed_reason": _failed_reason, &"completed": false })
	var result := compute_score(_stats, Tuning.scoring(), _definition)
	result.flags[&"failed_reason"] = _failed_reason
	result.flags[&"completed"] = _completed
	return result


static func compute_score(stats: MissionStats, cfg: ScoringConfig, def: MissionDefinition) -> MissionResult:
	if stats == null or cfg == null or def == null:
		return MissionResult.create(0, &"shoden", {})
	var score := 0
	var par_seconds := cfg.par_seconds(def.id, def.par_time_minutes)
	var flags := {
		&"shadow_walker": stats.detections == 0,
		&"no_traces": stats.bodies_found == 0,
		&"one_strike": maxi(stats.knockouts,0)*5 >= maxi(stats.enemy_contacts,0)*4 if def.id == &"m09" else stats.one_strike,
		&"swift": par_seconds > 0.0 and stats.elapsed_sec <= par_seconds,
		&"side_objective": def.side_objective != null and stats.side_objective_completed,
	}
	if flags[&"shadow_walker"]:
		score += cfg.shadow_walker_points
	if flags[&"no_traces"]:
		score += cfg.no_traces_points
	if flags[&"one_strike"]:
		score += cfg.one_strike_points
	if flags[&"swift"]:
		score += cfg.swift_points
	if flags[&"side_objective"]:
		score += cfg.side_objective_bonus
	score += maxi(maxi(stats.nontarget_kills, 0) * cfg.nontarget_kill_penalty, cfg.nontarget_kill_penalty_cap)
	score += maxi(stats.civilian_kills, 0) * cfg.civilian_kill_penalty
	var result := MissionResult.create(score, _rank_for_score(score, cfg), flags)
	result.narrative_counts = NarrativeTotals.snapshot(stats)
	return result


static func _rank_for_score(score: int, cfg: ScoringConfig) -> StringName:
	if score >= cfg.rank_kaiden_threshold:
		return &"kaiden"
	if score >= cfg.rank_okuden_threshold:
		return &"okuden"
	if score >= cfg.rank_chuden_threshold:
		return &"chuden"
	return &"shoden"


## Mission-local checkpoints use stable authored NPC keys, never saved instance IDs.
func active_mission_id() -> StringName:
	return _definition.id if _definition != null else &""


## A scene claims the run once. SceneDirector may have started it before the
## scene is instanced; a later fresh scene must not inherit a completed run.
func attach_mission_scene(scene: Node, definition: MissionDefinition) -> bool:
	if not is_instance_valid(scene) or definition == null:
		return false
	if _mission_scene_id == scene.get_instance_id():
		return active_mission_id() == definition.id
	if _mission_scene_id != 0 or active_mission_id() != definition.id:
		start_mission(definition)
	_mission_scene_id = scene.get_instance_id()
	return true


func capture_checkpoint_state(entities: Dictionary) -> Dictionary:
	var result := {
		"mission": String(active_mission_id()), "objective": _current_objective_index,
		"running": _running, "completed": _completed, "failed_reason": String(_failed_reason),
		"target_kills": _target_kills, "all_assassinated": _all_target_kills_assassinated,
		"stats": {}, "contacts": [], "killed": [], "neutralized": [], "corpses": [],
	}
	for key in ["detections", "nontarget_kills", "civilian_kills", "bodies_found", "knockouts", "enemy_contacts", "elapsed_sec", "one_strike", "side_objective_completed"]:
		result["stats"][key] = _stats.get(key)
	for key: String in entities:
		var entity := entities[key] as Node
		if not is_instance_valid(entity):
			continue
		var identity := entity.get_instance_id()
		if _contact_entities.has(identity): result["contacts"].append(key)
		if _killed_entities.has(identity): result["killed"].append(key)
		if _neutralized_entities.has(identity): result["neutralized"].append(key)
		if _spotted_corpse_anomalies.has("body:%s" % identity): result["corpses"].append(key)
	return result


func checkpoint_state_is_valid(value: Dictionary, entities: Dictionary) -> bool:
	if _definition == null or value.get("mission") != String(_definition.id): return false
	if not CheckpointSnapshot._whole_number(value.get("objective"), 0, _definition.objectives.size()): return false
	if not CheckpointSnapshot._whole_number(value.get("target_kills"), 0, entities.size()): return false
	for key in ["running", "completed", "all_assassinated"]:
		if not value.get(key) is bool: return false
	if not value.get("failed_reason") is String or not value.get("stats") is Dictionary: return false
	var stats_value: Dictionary = value["stats"]
	for key in ["detections", "nontarget_kills", "civilian_kills", "bodies_found", "knockouts", "enemy_contacts"]:
		if not CheckpointSnapshot._whole_number(stats_value.get(key, 0 if key == "enemy_contacts" else null), 0, 1000000): return false
	if not CheckpointSnapshot._finite_number(stats_value.get("elapsed_sec")) or float(stats_value["elapsed_sec"]) < 0: return false
	for key in ["one_strike", "side_objective_completed"]:
		if not stats_value.get(key) is bool: return false
	for key in ["killed", "neutralized", "corpses"]:
		if not value.get(key) is Array or value[key].size() > entities.size(): return false
		for identity in value[key]:
			if not identity is String or not entities.has(identity): return false
	if not value.get("contacts",[]) is Array or value.get("contacts",[]).size() > entities.size(): return false
	for identity in value.get("contacts",[]):
		if not identity is String or not entities.has(identity): return false
	var completed: bool = value["completed"]
	var running: bool = value["running"]
	var failed: bool = not String(value["failed_reason"]).is_empty()
	if completed != (int(value["objective"]) == _definition.objectives.size()): return false
	return running == (not completed and not failed) and not (completed and failed)


func restore_checkpoint_state(value: Dictionary, entities: Dictionary) -> bool:
	if not checkpoint_state_is_valid(value, entities): return false
	_current_objective_index = int(value["objective"])
	_running = value["running"]
	_completed = value["completed"]
	_failed_reason = StringName(value["failed_reason"])
	_target_kills = int(value["target_kills"])
	_all_target_kills_assassinated = value["all_assassinated"]
	for key: String in value["stats"]:
		if key in ["detections", "nontarget_kills", "civilian_kills", "bodies_found", "knockouts", "enemy_contacts", "elapsed_sec", "one_strike", "side_objective_completed"]:
			_stats.set(key, value["stats"][key])
	_killed_entities.clear()
	_neutralized_entities.clear()
	_contact_entities.clear()
	_spotted_corpse_anomalies.clear()
	_stats.enemy_contacts = int(value["stats"].get("enemy_contacts",0))
	for key: String in value.get("contacts",[]): _contact_entities[entities[key].get_instance_id()] = true
	for key: String in value["killed"]: _killed_entities[entities[key].get_instance_id()] = true
	for key: String in value["neutralized"]: _neutralized_entities[entities[key].get_instance_id()] = true
	for key: String in value["corpses"]: _spotted_corpse_anomalies["body:%s" % entities[key].get_instance_id()] = true
	_emit_current_objective()
	return true

func allows_action(action: StringName) -> bool:
	if _definition == null: return true
	var canonical: StringName = &"sword" if action in [&"attack", &"parry"] else &"assassinate_lethal" if action == &"assassinate" else action
	return canonical not in _definition.forbidden_actions

func _on_contact_alert(enemy: Node, _from_state: int, to_state: int) -> void:
	if to_state == Enums.AlertState.COMBAT: _register_contact(enemy)

func _register_contact(enemy: Node) -> void:
	if not _running or not is_instance_valid(enemy): return
	var identity := enemy.get_instance_id()
	if not _contact_entities.has(identity):
		_contact_entities[identity] = true
		_stats.enemy_contacts += 1

func assassination_variant_for(enemy: Node) -> String:
	if _definition == null or not is_instance_valid(enemy) or not _is_mission_target(enemy): return ""
	return _definition.assassination_variant
