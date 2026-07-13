extends Node


const MissionStatsScript := preload("res://src/core/mission/mission_stats.gd")
const MissionResultScript := preload("res://src/core/mission/mission_result.gd")

var _definition: Resource
var _stats: RefCounted = MissionStatsScript.new()
var _current_objective_index: int = 0
var _failed_reason: StringName = &""


func start_mission(def: Resource) -> void:
	_definition = def
	_stats = MissionStatsScript.new()
	_current_objective_index = 0
	_failed_reason = &""
	if def != null:
		GameState.reset_for_mission(def.get("id"))
	push_warning("MissionDirector.start_mission is a M0 skeleton")


func complete_objective(id: StringName) -> void:
	if _definition == null:
		return
	EventBus.mission_event.emit(EventBus.EV_OBJECTIVE_COMPLETED, { "id": id })
	var objectives: Array = _definition.get("objectives")
	_current_objective_index = min(_current_objective_index + 1, max(objectives.size() - 1, 0))


func fail_mission(reason: StringName) -> void:
	_failed_reason = reason
	EventBus.mission_event.emit(EventBus.EV_MISSION_FAILED, { "reason": reason })


func current_objective() -> Resource:
	if _definition == null:
		return null
	var objectives: Array = _definition.get("objectives")
	if objectives.is_empty():
		return null
	return objectives[_current_objective_index]


func stats() -> RefCounted:
	return _stats


func build_result() -> RefCounted:
	if _definition == null:
		return MissionResultScript.create(0, &"shoden", { "failed_reason": _failed_reason })
	return compute_score(_stats, Tuning.scoring(), _definition)


static func compute_score(stats: RefCounted, cfg: Resource, def: Resource) -> RefCounted:
	var score := 0
	var flags := {
		&"shadow_walker": stats.get("detections") == 0,
		&"no_traces": stats.get("bodies_found") == 0,
		&"one_strike": stats.get("one_strike"),
		&"swift": def.get("par_time_minutes") <= 0.0 or stats.get("elapsed_sec") <= def.get("par_time_minutes") * 60.0,
	}
	if flags[&"shadow_walker"]:
		score += cfg.get("shadow_walker_points")
	if flags[&"no_traces"]:
		score += cfg.get("no_traces_points")
	if flags[&"one_strike"]:
		score += cfg.get("one_strike_points")
	if flags[&"swift"]:
		score += cfg.get("swift_points")
	score += max(stats.get("nontarget_kills") * cfg.get("nontarget_kill_penalty"), cfg.get("nontarget_kill_penalty_cap"))
	score += stats.get("civilian_kills") * cfg.get("civilian_kill_penalty")
	return MissionResultScript.create(score, _rank_for_score(score, cfg), flags)


static func _rank_for_score(score: int, cfg: Resource) -> StringName:
	if score >= cfg.get("rank_kaiden_threshold"):
		return &"kaiden"
	if score >= cfg.get("rank_okuden_threshold"):
		return &"okuden"
	if score >= cfg.get("rank_chuden_threshold"):
		return &"chuden"
	return &"shoden"
