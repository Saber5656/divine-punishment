class_name EnemyBrain
extends Node


## Five-state enemy decision layer.
##
## EnemyPerception owns only sensing and emits PerceptionStimulus values.  The
## brain buffers those values, chooses one deterministic winner per physics
## frame, and applies the transition contract in docs/08-content-specs.md §10.4.
## Movement, combat animation, and patrol authoring can be layered on top of
## this component without changing the state or stimulus API.

const INVESTIGATION_DURATION_SEC := 3.0
const SEARCH_DURATION_SEC := 60.0
const COMBAT_LOST_SIGHT_DURATION_SEC := 3.0
const RELIGHT_DELAY_SEC := 60.0
const MAX_STIMULI_PER_FRAME := 32
const MAX_STIMULUS_BUFFER := MAX_STIMULI_PER_FRAME
const MAX_SEEN_ANOMALIES := 128
const MAX_ANOMALY_DISTANCE := 30.0
const INVESTIGATION_DURATION := INVESTIGATION_DURATION_SEC
const SEARCH_DURATION := SEARCH_DURATION_SEC
const COMBAT_LOST_SIGHT_DURATION := COMBAT_LOST_SIGHT_DURATION_SEC
const RELIGHT_DELAY := RELIGHT_DELAY_SEC
const RETURN_ARRIVAL_DURATION := 1.0
const DEFAULT_RETURN_VIGILANCE_MULTIPLIER := 1.5
const DEFAULT_RETURN_VIGILANCE_DURATION := 120.0
const MAX_AREA_ALERT_LEVEL := 5
const NO_POSITION := Vector3(NAN, NAN, NAN)

signal state_changed(from_state: Enums.AlertState, to_state: Enums.AlertState)
signal substate_changed(from_substate: StringName, to_substate: StringName)
signal investigation_started(position: Vector3)
signal investigation_completed(position: Vector3)
signal relight_requested(light: LightSource)

var _state: Enums.AlertState = Enums.AlertState.UNAWARE
var _substate: StringName = &"none"
var _stimulus_buffer: Array[PerceptionStimulus] = []
var _stimulus_memory: PerceptionStimulus
var _last_known_position := Vector3.ZERO
var _has_last_known_position := false
var _investigation_elapsed := 0.0
var _search_elapsed := 0.0
var _combat_lost_sight_elapsed := 0.0
var _return_elapsed := 0.0
var _return_vigilance_remaining := 0.0
var _relight_elapsed := 0.0
var _relight_light: LightSource
var _relight_pending := false
var _relight_request_sent := false
var _seen_anomalies: Dictionary = {}
var _incapacitated := false
var _incapacitated_kind: StringName = &""
var _target_visible := false
var _routine_arrived := false
var _last_transition_reason: StringName = &""


func _ready() -> void:
	set_physics_process(true)
	var event_bus := _event_bus()
	if event_bus != null:
		var callback := Callable(self, &"_on_anomaly_registered")
		if not event_bus.is_connected(&"anomaly_registered", callback):
			event_bus.connect(&"anomaly_registered", callback)


func _exit_tree() -> void:
	var event_bus := _event_bus()
	if event_bus != null:
		var callback := Callable(self, &"_on_anomaly_registered")
		if event_bus.is_connected(&"anomaly_registered", callback):
			event_bus.disconnect(&"anomaly_registered", callback)


func _physics_process(delta: float) -> void:
	tick(delta)


## Advance sensing and decision-making without requiring a SceneTree physics
## tick.  This is intentionally public so transition tests can be deterministic.
func tick(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0:
		return
	if _incapacitated:
		return

	var perception := _perception()
	if perception != null:
		perception.set_vigilance_multiplier(vigilance_multiplier())
		perception.tick(delta)

	_advance_timers(delta)
	var stimulus := _pop_highest_stimulus()
	if stimulus != null:
		_process_stimulus(stimulus)
	else:
		_advance_state_without_stimulus(delta)

	# A transition may have entered Return during this frame.  Keep the sensing
	# component synchronized before its next 10 Hz update.
	if perception != null:
		perception.set_vigilance_multiplier(vigilance_multiplier())


func alert_state() -> Enums.AlertState:
	return _state


func current_state() -> Enums.AlertState:
	return alert_state()


func state() -> Enums.AlertState:
	return alert_state()


func substate() -> StringName:
	return _substate


func current_substate() -> StringName:
	return substate()


func investigation_position() -> Vector3:
	return _last_known_position if _has_last_known_position else Vector3.ZERO


func search_focus_position() -> Vector3:
	return investigation_position()


func last_known_position() -> Vector3:
	return investigation_position()


func return_vigilance_remaining() -> float:
	return maxf(_return_vigilance_remaining, 0.0)


func vigilance_multiplier() -> float:
	if _return_vigilance_remaining <= 0.0:
		return 1.0
	var multiplier := DEFAULT_RETURN_VIGILANCE_MULTIPLIER
	var config := _perception_config()
	if config != null and is_finite(config.return_vigilance_mult) and config.return_vigilance_mult > 0.0:
		multiplier = config.return_vigilance_mult
	return maxf(multiplier, 1.0)


func relight_remaining() -> float:
	if not _relight_pending:
		return 0.0
	return maxf(RELIGHT_DELAY_SEC - _relight_elapsed, 0.0)


func is_relight_pending() -> bool:
	return _relight_pending and not _relight_request_sent


func relight_pending() -> bool:
	return is_relight_pending()


func residual_alert_active() -> bool:
	return _return_vigilance_remaining > 0.0


func detection_multiplier() -> float:
	return vigilance_multiplier()


func investigation_target() -> Vector3:
	return investigation_position()


func search_focus() -> Vector3:
	return search_focus_position()


func stimulus_memory() -> PerceptionStimulus:
	return _stimulus_memory


func is_incapacitated() -> bool:
	return _incapacitated


func incapacitated_kind() -> StringName:
	return _incapacitated_kind


func last_transition_reason() -> StringName:
	return _last_transition_reason


func target_visible() -> bool:
	return _target_visible


func set_target_visible(value: bool) -> void:
	_target_visible = value
	if value:
		_combat_lost_sight_elapsed = 0.0


func set_routine_arrived(value: bool) -> void:
	_routine_arrived = value


func mark_routine_arrived() -> void:
	set_routine_arrived(true)


func set_arrived(value: bool) -> void:
	set_routine_arrived(value)


func set_target_position(position: Vector3) -> void:
	if _valid_vector(position):
		_last_known_position = position
		_has_last_known_position = true


## Queue one stimulus.  Anomaly stimuli are deduplicated per enemy as required
## by §10.4, while all other stimuli remain available to the next frame winner.
func submit_stimulus(stim: PerceptionStimulus) -> void:
	if not _valid_stimulus(stim):
		return
	if _stimulus_buffer.size() >= MAX_STIMULI_PER_FRAME:
		_stimulus_buffer.pop_front()
	if stim.kind == Enums.StimulusKind.ANOMALY and stim.anomaly != null:
		if not _anomaly_is_relevant(stim.anomaly):
			return
		var seen_key := get_instance_id()
		if stim.anomaly.seen_by.has(seen_key) or _seen_anomalies.has(stim.anomaly):
			return
		stim.anomaly.seen_by[seen_key] = true
		if _seen_anomalies.size() >= MAX_SEEN_ANOMALIES:
			var oldest: Variant = _seen_anomalies.keys()[0]
			_seen_anomalies.erase(oldest)
		_seen_anomalies[stim.anomaly] = true
		_register_anomaly_memory(stim.anomaly)
		_emit_anomaly_spotted(stim.anomaly)
	_stimulus_buffer.append(stim)


func submit_anomaly(anomaly: Anomaly, priority: int = 1) -> void:
	if anomaly == null or not _anomaly_is_relevant(anomaly):
		return
	var stim := PerceptionStimulus.create(
		Enums.StimulusKind.ANOMALY,
		priority,
		anomaly.position,
		clampf(float(anomaly.severity) / 3.0, 0.0, 1.0),
		anomaly,
	)
	submit_stimulus(stim)


## Preserve the legacy test/debug API.  Draining is intentionally a read-side
## operation and does not advance the FSM.
func drain_stimuli() -> Array[PerceptionStimulus]:
	var result := _stimulus_buffer
	_stimulus_buffer = []
	return result


func pending_stimulus_count() -> int:
	return _stimulus_buffer.size()


func force_state(state_value: Enums.AlertState, reason: StringName = &"forced") -> void:
	if not _valid_alert_state(state_value):
		return
	_last_transition_reason = reason
	_transition_to(state_value, null, reason)


## Incapacitation is outside the five-state FSM.  Passing an empty kind wakes
## the enemy and returns it to Searching, preserving the fact that it was
## attacked while asleep/knocked out/restrained.
func set_incapacitated(kind: StringName) -> void:
	if kind.is_empty():
		if not _incapacitated:
			return
		_incapacitated = false
		_incapacitated_kind = &""
		_target_visible = false
		var wake_stimulus := PerceptionStimulus.create(
			Enums.StimulusKind.DAMAGE,
			3,
			investigation_position(),
			1.0,
		)
		_transition_to(Enums.AlertState.SEARCHING, wake_stimulus, &"incapacitated_wake")
		return
	if kind not in [&"sleep", &"knockout", &"restrained", &"dead"]:
		return
	_incapacitated = true
	_incapacitated_kind = kind
	_stimulus_buffer.clear()


func wake() -> void:
	set_incapacitated(&"")


## Pure transition helper used by the table tests and by the stateful brain.
## Timer/arrival conditions are deliberately explicit so callers can validate
## the five-state contract without constructing an enemy scene.
static func transition_for_stimulus(
	current: Enums.AlertState,
	priority: int,
) -> Enums.AlertState:
	var bounded_priority := clampi(priority, 1, 5)
	match current:
		Enums.AlertState.UNAWARE:
			if bounded_priority >= 4:
				return Enums.AlertState.COMBAT
			if bounded_priority >= 3:
				return Enums.AlertState.SEARCHING
			return Enums.AlertState.SUSPICIOUS
		Enums.AlertState.SUSPICIOUS:
			if bounded_priority >= 4:
				return Enums.AlertState.COMBAT
			if bounded_priority >= 2:
				return Enums.AlertState.SEARCHING
			return Enums.AlertState.SUSPICIOUS
		Enums.AlertState.SEARCHING:
			if bounded_priority >= 4:
				return Enums.AlertState.COMBAT
			return Enums.AlertState.SEARCHING
		Enums.AlertState.COMBAT:
			return Enums.AlertState.COMBAT
		Enums.AlertState.RETURN:
			if bounded_priority >= 4:
				return Enums.AlertState.COMBAT
			if bounded_priority >= 2:
				return Enums.AlertState.SEARCHING
			return Enums.AlertState.SUSPICIOUS
	return current


static func next_state_for_stimulus(
	current: Enums.AlertState,
	priority: int,
) -> Enums.AlertState:
	return transition_for_stimulus(current, priority)


static func residual_alert_multiplier(remaining_seconds: float, configured_multiplier: float = 1.5) -> float:
	if not is_finite(remaining_seconds) or not is_finite(configured_multiplier):
		return 1.0
	return maxf(configured_multiplier, 1.0) if remaining_seconds > 0.0 else 1.0


func _advance_timers(delta: float) -> void:
	if _return_vigilance_remaining > 0.0:
		_return_vigilance_remaining = maxf(_return_vigilance_remaining - delta, 0.0)
	if _relight_pending and not _relight_request_sent:
		_relight_elapsed += delta
		_try_request_relight()


func _advance_state_without_stimulus(delta: float) -> void:
	match _state:
		Enums.AlertState.UNAWARE:
			return
		Enums.AlertState.SUSPICIOUS:
			_investigation_elapsed += delta
			_set_navigation_target(investigation_position())
			if _investigation_elapsed >= INVESTIGATION_DURATION_SEC:
				_complete_investigation()
		Enums.AlertState.SEARCHING:
			_search_elapsed += delta
			_set_navigation_target(search_focus_position())
			if _search_elapsed >= SEARCH_DURATION_SEC:
				_transition_to(Enums.AlertState.RETURN, null, &"search_timeout")
		Enums.AlertState.COMBAT:
			# A visual stimulus is an instantaneous observation.  If no new
			# observation arrives, the target has been lost for this frame.
			_combat_lost_sight_elapsed += delta
			if _combat_lost_sight_elapsed >= COMBAT_LOST_SIGHT_DURATION_SEC:
				_transition_to(Enums.AlertState.SEARCHING, null, &"lost_sight")
		Enums.AlertState.RETURN:
			_return_elapsed += delta
			_set_navigation_target(_routine_target())
			if _routine_arrived or _return_elapsed >= RETURN_ARRIVAL_DURATION:
				_transition_to(Enums.AlertState.UNAWARE, null, &"routine_arrived")


func _process_stimulus(stim: PerceptionStimulus) -> void:
	var priority := _effective_priority(stim)
	_stimulus_memory = stim
	_last_known_position = stim.position
	_has_last_known_position = true
	if stim.kind == Enums.StimulusKind.VISUAL or stim.kind == Enums.StimulusKind.DAMAGE:
		_target_visible = stim.kind == Enums.StimulusKind.VISUAL
		if stim.kind == Enums.StimulusKind.DAMAGE:
			_target_visible = true
	if _state == Enums.AlertState.COMBAT:
		if priority >= 4:
			_combat_lost_sight_elapsed = 0.0
			_target_visible = true
		return
	var next := transition_for_stimulus(_state, priority)
	if _state == Enums.AlertState.SEARCHING and priority < 4:
		_search_elapsed = 0.0
		_set_substate(&"search")
	elif _state == Enums.AlertState.SUSPICIOUS and priority <= 1:
		_investigation_elapsed = 0.0
		_set_substate(&"investigate")
	elif _state == Enums.AlertState.RETURN and priority <= 1:
		_investigation_elapsed = 0.0
	_transition_to(next, stim, &"stimulus")


func _complete_investigation() -> void:
	var position := investigation_position()
	_investigation_elapsed = 0.0
	_emit_signal_if_available(&"investigation_completed", position)
	if _relight_light != null and is_instance_valid(_relight_light) and not _relight_light.is_on():
		_relight_pending = true
		_set_substate(&"relight")
	else:
		_set_substate(&"none")
	_transition_to(Enums.AlertState.RETURN, null, &"investigation_complete")


func _transition_to(
	next: Enums.AlertState,
	stim: PerceptionStimulus,
	reason: StringName,
) -> void:
	if not _valid_alert_state(next):
		return
	if stim != null:
		_stimulus_memory = stim
		_last_known_position = stim.position
		_has_last_known_position = true
	var previous := _state
	_last_transition_reason = reason
	if previous == next:
		if next == Enums.AlertState.SUSPICIOUS:
			_set_substate(&"investigate")
		return
	_state = next
	_routine_arrived = false
	if next != Enums.AlertState.RETURN and next != Enums.AlertState.UNAWARE:
		# A fresh alert supersedes the residual return-vigilance window.
		_return_vigilance_remaining = 0.0
	match next:
		Enums.AlertState.UNAWARE:
			_set_substate(&"none")
			_target_visible = false
		Enums.AlertState.SUSPICIOUS:
			_investigation_elapsed = 0.0
			_set_substate(&"investigate")
			_emit_signal_if_available(&"investigation_started", investigation_position())
		Enums.AlertState.SEARCHING:
			_search_elapsed = 0.0
			_set_substate(&"search")
		Enums.AlertState.COMBAT:
			_combat_lost_sight_elapsed = 0.0
			_set_substate(&"none")
			_on_combat_enter(previous)
		Enums.AlertState.RETURN:
			_return_elapsed = 0.0
			_start_return_vigilance()
			_set_substate(&"relight" if _relight_pending else &"return")
	_set_navigation_target(
		_last_known_position
		if next == Enums.AlertState.SUSPICIOUS or next == Enums.AlertState.SEARCHING
		else _routine_target()
	)
	state_changed.emit(previous, next)
	var event_bus := _event_bus()
	if event_bus != null:
		event_bus.emit_signal(&"alert_changed", _enemy_node(), int(previous), int(next))
	if next == Enums.AlertState.SEARCHING and stim != null:
		_raise_area_alert_if_severe(stim)


func _start_return_vigilance() -> void:
	var config := _perception_config()
	var duration := DEFAULT_RETURN_VIGILANCE_DURATION
	if config != null and is_finite(config.return_vigilance_duration) and config.return_vigilance_duration > 0.0:
		duration = config.return_vigilance_duration
	_return_vigilance_remaining = duration


func _on_combat_enter(previous: Enums.AlertState) -> void:
	if previous == Enums.AlertState.COMBAT:
		return
	var event_bus := _event_bus()
	if event_bus != null:
		event_bus.emit_signal(&"player_detected")
	_increment_detection_stats()
	_raise_area_alert()


func _increment_detection_stats() -> void:
	var director := _autoload(&"MissionDirector")
	if director == null or not director.has_method(&"stats"):
		return
	var stats: Variant = director.call(&"stats")
	if stats != null:
		stats.detections = int(stats.detections) + 1


func _raise_area_alert() -> void:
	var game_state := _autoload(&"GameState")
	if game_state == null:
		return
	game_state.area_alert_level = mini(int(game_state.area_alert_level) + 1, MAX_AREA_ALERT_LEVEL)
	var event_bus := _event_bus()
	if event_bus != null:
		event_bus.emit_signal(&"area_alert_changed", int(game_state.area_alert_level))


func _raise_area_alert_if_severe(stim: PerceptionStimulus) -> void:
	if stim == null or stim.anomaly == null or stim.anomaly.severity < 3:
		return
	_raise_area_alert()


func _register_anomaly_memory(anomaly: Anomaly) -> void:
	if anomaly == null:
		return
	if anomaly.kind == Enums.AnomalyKind.LIGHT_OUT:
		var light := anomaly.node as LightSource
		if light != null:
			_relight_light = light
			_relight_pending = true
			_relight_elapsed = 0.0
			_relight_request_sent = false


func _try_request_relight() -> void:
	if not _relight_pending or _relight_request_sent:
		return
	if _relight_light == null or not is_instance_valid(_relight_light):
		_relight_pending = false
		return
	if _relight_light.is_on():
		_relight_pending = false
		return
	if _relight_elapsed < RELIGHT_DELAY_SEC:
		return
	var enemy := _enemy_node()
	if enemy == null or not enemy.is_inside_tree():
		return
	if _relight_light.request_relight(enemy):
		_relight_light.set_extinguished(false)
		_relight_request_sent = true
		_set_substate(&"none")
		relight_requested.emit(_relight_light)


func _emit_anomaly_spotted(anomaly: Anomaly) -> void:
	var event_bus := _event_bus()
	if event_bus != null:
		event_bus.emit_signal(&"anomaly_spotted", anomaly, _enemy_node())


func _on_anomaly_registered(anomaly: Anomaly) -> void:
	submit_anomaly(anomaly)


func _pop_highest_stimulus() -> PerceptionStimulus:
	if _stimulus_buffer.is_empty():
		return null
	var selected_index := 0
	var selected_priority := -1
	var selected_distance := INF
	var enemy_position := _enemy_position()
	for index: int in _stimulus_buffer.size():
		var candidate := _stimulus_buffer[index]
		var priority := _effective_priority(candidate)
		var distance := selected_distance
		if _valid_vector(enemy_position) and _valid_vector(candidate.position):
			distance = enemy_position.distance_to(candidate.position)
		if priority > selected_priority or (priority == selected_priority and distance < selected_distance):
			selected_index = index
			selected_priority = priority
			selected_distance = distance
	var result := _stimulus_buffer[selected_index]
	_stimulus_buffer = []
	return result


func _effective_priority(stim: PerceptionStimulus) -> int:
	if stim == null:
		return 0
	var priority := clampi(stim.priority, 1, 5)
	if stim.kind == Enums.StimulusKind.DAMAGE:
		return 5
	if stim.kind == Enums.StimulusKind.ANOMALY and stim.anomaly != null:
		if stim.anomaly.severity >= 3:
			return maxi(priority, 3)
		if stim.anomaly.severity >= 2:
			return maxi(priority, 2)
	return priority


func _anomaly_is_relevant(anomaly: Anomaly) -> bool:
	if anomaly == null or not _valid_vector(anomaly.position):
		return false
	var enemy_position := _enemy_position()
	if not _valid_vector(enemy_position):
		return true
	var distance := enemy_position.distance_to(anomaly.position)
	return is_finite(distance) and distance <= MAX_ANOMALY_DISTANCE


func _set_substate(next: StringName) -> void:
	if _substate == next:
		return
	var previous := _substate
	_substate = next
	substate_changed.emit(previous, next)


func _perception() -> EnemyPerception:
	var enemy := _enemy_node()
	if enemy == null:
		return null
	return enemy.get_node_or_null(NodePath("Perception")) as EnemyPerception


func _perception_config() -> PerceptionConfig:
	var perception := _perception()
	return perception.perception_config if perception != null else null


func _enemy_node() -> Node:
	return get_parent()


func _enemy_position() -> Vector3:
	var enemy := _enemy_node()
	if enemy is Node3D:
		return (enemy as Node3D).global_position
	return NO_POSITION


func _routine_target() -> Vector3:
	var enemy := _enemy_node()
	if enemy == null:
		return Vector3.ZERO
	var marker := enemy.get_node_or_null(NodePath("RoutineTarget")) as Node3D
	if marker != null and _valid_vector(marker.global_position):
		return marker.global_position
	return (enemy as Node3D).global_position if enemy is Node3D else Vector3.ZERO


func _set_navigation_target(target: Vector3) -> void:
	if not _valid_vector(target):
		return
	var enemy := _enemy_node()
	if enemy == null:
		return
	var agent := enemy.get_node_or_null(NodePath("NavigationAgent3D")) as NavigationAgent3D
	if agent != null:
		agent.target_position = target


func _event_bus() -> Node:
	return _autoload(&"EventBus")


func _autoload(name: StringName) -> Node:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath(String(name)))


func _emit_signal_if_available(signal_name: StringName, value: Variant) -> void:
	if has_signal(signal_name):
		emit_signal(signal_name, value)


static func _valid_alert_state(value: Enums.AlertState) -> bool:
	return value >= Enums.AlertState.UNAWARE and value <= Enums.AlertState.RETURN


static func _valid_stimulus(stim: PerceptionStimulus) -> bool:
	return (
		stim != null
		and stim.kind >= Enums.StimulusKind.VISUAL
		and stim.kind <= Enums.StimulusKind.DAMAGE
		and stim.priority >= 1
		and stim.priority <= 5
		and _valid_vector(stim.position)
		and is_finite(stim.confidence)
	)


static func _valid_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
