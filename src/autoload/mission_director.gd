extends Node


var _definition: MissionDefinition
var _stats: MissionStats = MissionStats.new()
var _current_objective_index: int = 0
var _failed_reason: StringName = &""
var _spotted_corpse_anomalies: Dictionary = {}

const MAX_AREA_ALERT_LEVEL := 5


func _ready() -> void:
	if not EventBus.anomaly_spotted.is_connected(_on_anomaly_spotted):
		EventBus.anomaly_spotted.connect(_on_anomaly_spotted)


func _exit_tree() -> void:
	if EventBus.anomaly_spotted.is_connected(_on_anomaly_spotted):
		EventBus.anomaly_spotted.disconnect(_on_anomaly_spotted)


func start_mission(def: MissionDefinition) -> void:
	_definition = def
	_stats = MissionStats.new()
	_current_objective_index = 0
	_failed_reason = &""
	_spotted_corpse_anomalies.clear()
	if def != null:
		GameState.reset_for_mission(def.id)
	push_warning("MissionDirector.start_mission is a M0 skeleton")


func complete_objective(id: StringName) -> void:
	if _definition == null:
		return
	EventBus.mission_event.emit(EventBus.EV_OBJECTIVE_COMPLETED, { "id": id })
	var objectives: Array[ObjectiveData] = _definition.objectives
	_current_objective_index = min(_current_objective_index + 1, max(objectives.size() - 1, 0))


func fail_mission(reason: StringName) -> void:
	_failed_reason = reason
	EventBus.mission_event.emit(EventBus.EV_MISSION_FAILED, { "reason": reason })


func current_objective() -> ObjectiveData:
	if _definition == null:
		return null
	var objectives: Array[ObjectiveData] = _definition.objectives
	if objectives.is_empty():
		return null
	return objectives[_current_objective_index]


func stats() -> MissionStats:
	return _stats


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
	_stats.bodies_found += 1
	GameState.area_alert_level = mini(int(GameState.area_alert_level) + 1, MAX_AREA_ALERT_LEVEL)
	EventBus.area_alert_changed.emit(GameState.area_alert_level)


## Prefer the physical body identity over the transient Anomaly wrapper.  A
## body can be observed through a persistent marker and a fresh event without
## increasing bodies_found or area alert twice.
func _corpse_key(anomaly: Anomaly) -> String:
	if anomaly == null:
		return ""
	var body := anomaly.node
	if body != null and is_instance_valid(body):
		return "body:%s" % body.get_instance_id()
	return "anomaly:%s" % anomaly.get_instance_id()


func build_result() -> MissionResult:
	if _definition == null:
		return MissionResult.create(0, &"shoden", { "failed_reason": _failed_reason })
	return compute_score(_stats, Tuning.scoring(), _definition)


static func compute_score(stats: MissionStats, cfg: ScoringConfig, def: MissionDefinition) -> MissionResult:
	var score := 0
	var flags := {
		&"shadow_walker": stats.detections == 0,
		&"no_traces": stats.bodies_found == 0,
		&"one_strike": stats.one_strike,
		&"swift": def.par_time_minutes > 0.0 and stats.elapsed_sec <= def.par_time_minutes * 60.0,
	}
	if flags[&"shadow_walker"]:
		score += cfg.shadow_walker_points
	if flags[&"no_traces"]:
		score += cfg.no_traces_points
	if flags[&"one_strike"]:
		score += cfg.one_strike_points
	if flags[&"swift"]:
		score += cfg.swift_points
	score += max(stats.nontarget_kills * cfg.nontarget_kill_penalty, cfg.nontarget_kill_penalty_cap)
	score += stats.civilian_kills * cfg.civilian_kill_penalty
	return MissionResult.create(score, _rank_for_score(score, cfg), flags)


static func _rank_for_score(score: int, cfg: ScoringConfig) -> StringName:
	if score >= cfg.rank_kaiden_threshold:
		return &"kaiden"
	if score >= cfg.rank_okuden_threshold:
		return &"okuden"
	if score >= cfg.rank_chuden_threshold:
		return &"chuden"
	return &"shoden"
