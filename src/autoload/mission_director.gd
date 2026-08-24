extends Node


var _definition: MissionDefinition
var _stats: MissionStats = MissionStats.new()
var _current_objective_index: int = 0
var _failed_reason: StringName = &""


func start_mission(def: MissionDefinition) -> void:
	_definition = def
	_stats = MissionStats.new()
	_current_objective_index = 0
	_failed_reason = &""
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
		&"swift": def.par_time_minutes <= 0.0 or stats.elapsed_sec <= def.par_time_minutes * 60.0,
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
