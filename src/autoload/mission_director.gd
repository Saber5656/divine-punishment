extends Node


var _definition: MissionDefinition
var _stats: MissionStats = MissionStats.new()
var _current_objective_index: int = 0
var _failed_reason: StringName = &""
var _running := false
var _completed := false
var _target_kills := 0
var _all_target_kills_assassinated := true
var _killed_entities: Dictionary = {}
var _neutralized_entities: Dictionary = {}
var _spotted_corpse_anomalies: Dictionary = {}

const MAX_AREA_ALERT_LEVEL := 5


func _ready() -> void:
	EventBus.anomaly_spotted.connect(_on_anomaly_spotted)
	EventBus.player_detected.connect(_on_player_detected)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.civilian_killed.connect(_on_civilian_killed)
	EventBus.enemy_neutralized.connect(_on_enemy_neutralized)
	EventBus.mission_event.connect(_on_mission_event)


func _exit_tree() -> void:
	EventBus.anomaly_spotted.disconnect(_on_anomaly_spotted)
	EventBus.player_detected.disconnect(_on_player_detected)
	EventBus.enemy_killed.disconnect(_on_enemy_killed)
	EventBus.civilian_killed.disconnect(_on_civilian_killed)
	EventBus.enemy_neutralized.disconnect(_on_enemy_neutralized)
	EventBus.mission_event.disconnect(_on_mission_event)


func _process(delta: float) -> void:
	if _running and is_finite(delta) and delta > 0.0:
		_stats.elapsed_sec += delta


func start_mission(def: MissionDefinition) -> void:
	_definition = def
	_stats = MissionStats.new()
	_stats.one_strike = false
	_current_objective_index = 0
	_failed_reason = &""
	_running = def != null
	_completed = false
	_target_kills = 0
	_all_target_kills_assassinated = true
	_killed_entities.clear()
	_neutralized_entities.clear()
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
	if enemy.is_in_group(&"civilians"):
		_stats.civilian_kills += 1
	elif _is_mission_target(enemy):
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
	_stats.civilian_kills += 1


func _on_enemy_neutralized(enemy: Node, method: String) -> void:
	if not _running or not is_instance_valid(enemy) or method != "knockout":
		return
	var identity := enemy.get_instance_id()
	if _neutralized_entities.has(identity) or _killed_entities.has(identity):
		return
	_neutralized_entities[identity] = true
	_stats.knockouts += 1


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
		or anomaly.kind != Enums.AnomalyKind.CORPSE
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
	var flags := {
		&"shadow_walker": stats.detections == 0,
		&"no_traces": stats.bodies_found == 0,
		&"one_strike": stats.one_strike,
		&"swift": def.par_time_minutes > 0.0 and stats.elapsed_sec <= def.par_time_minutes * 60.0,
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
	return MissionResult.create(score, _rank_for_score(score, cfg), flags)


static func _rank_for_score(score: int, cfg: ScoringConfig) -> StringName:
	if score >= cfg.rank_kaiden_threshold:
		return &"kaiden"
	if score >= cfg.rank_okuden_threshold:
		return &"okuden"
	if score >= cfg.rank_chuden_threshold:
		return &"chuden"
	return &"shoden"
