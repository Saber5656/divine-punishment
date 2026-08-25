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
const MAX_INCAPACITATION_DURATION_SEC := 300.0
const MAX_AREA_ALERT_LEVEL := 5
const SEARCH_PROPAGATION_RADIUS := 12.0
const MAX_PROPAGATED_ENEMIES := 64
const MAX_SEARCH_POINTS := 32
const MAX_SEARCH_POINT_CANDIDATES := 128
const MAX_SEARCH_POINT_SCAN := 1024
const MAX_SEARCH_HIDE_SPOTS := 8
const MAX_SEARCH_HIDE_SPOT_CANDIDATES := 64
const MAX_SEARCH_HIDE_SPOT_SCAN := 256
const MAX_SEARCH_PLAYER_CANDIDATES := 8
const SEARCH_POINT_RADIUS := 30.0
const SEARCH_HIDE_SPOT_RADIUS := 12.0
const MAX_SEARCH_STEP_DELTA := 0.25
const SEARCH_VERTICAL_REACH_TOLERANCE := 1.5
const SEARCH_NAVIGATION_SNAP_DISTANCE := 1.5
const MIN_SEARCH_SPEED := 3.0
const DEFAULT_ROUTINE_SPEED := 1.5
const MAX_ROUTINE_CLOCK_SECONDS := 86400.0
const MAX_ROUTINE_STEP_DELTA := 0.25
const NO_POSITION := Vector3(NAN, NAN, NAN)

signal state_changed(from_state: Enums.AlertState, to_state: Enums.AlertState)
signal substate_changed(from_substate: StringName, to_substate: StringName)
signal investigation_started(position: Vector3)
signal investigation_completed(position: Vector3)
signal search_hide_spot_inspected(hide_spot: HideSpot, visible: bool)
signal relight_requested(light: LightSource)

var _state: Enums.AlertState = Enums.AlertState.UNAWARE
var _substate: StringName = &"none"
var _stimulus_buffer: Array[PerceptionStimulus] = []
var _stimulus_memory: PerceptionStimulus
var _last_known_position := Vector3.ZERO
var _has_last_known_position := false
var _investigation_elapsed := 0.0
var _investigation_arrived := false
var _search_elapsed := 0.0
var _search_points: Array[SearchPoint] = []
var _search_point_index := -1
var _search_route_complete := false
var _search_hide_spot_checks := 0
var _search_hide_spot_visible_count := 0
var _last_search_hide_spot: HideSpot
var _last_search_hide_spot_visible := false
var _search_hide_spot_anchor := Vector3.ZERO
var _search_route_anchor := Vector3.ZERO
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
var _incapacitation_remaining := 0.0
var _wake_by_noise := true
var _started := false
var _target_visible := false
var _target_visible_override := -1
var _routine_arrived := false
var _last_transition_reason: StringName = &""
var _routine_path: PatrolPath
var _routine_type: StringName = &"guard"
var _routine_enabled := true
var _routine_stop_index := 0
var _routine_stop_elapsed := 0.0
var _routine_clock := 0.0
var _routine_curve_distance := 0.0
var _routine_holding_final_stop := false
var _last_area_alert_level := -1
var _lantern_light: LightSource
var _lantern_offset := Vector3(0.0, 1.4, 0.0)


func _ready() -> void:
	_started = true
	set_physics_process(true)
	var event_bus := _event_bus()
	if event_bus != null:
		var callback := Callable(self, &"_on_area_alert_changed")
		if not event_bus.is_connected(&"area_alert_changed", callback):
			event_bus.connect(&"area_alert_changed", callback)


func _exit_tree() -> void:
	_started = false
	var event_bus := _event_bus()
	if event_bus != null:
		var callback := Callable(self, &"_on_area_alert_changed")
		if event_bus.is_connected(&"area_alert_changed", callback):
			event_bus.disconnect(&"area_alert_changed", callback)


func _physics_process(delta: float) -> void:
	tick(delta)


## Advance sensing and decision-making without requiring a SceneTree physics
## tick.  This is intentionally public so transition tests can be deterministic.
func tick(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0:
		return
	if _incapacitated:
		_advance_incapacitation(delta)
		return

	var perception := _perception()
	if perception != null:
		perception.set_vigilance_multiplier(vigilance_multiplier())
		perception.tick(delta)
		if _state == Enums.AlertState.COMBAT and _target_visible_override < 0 and perception.target_visible():
			_target_visible = true
			_combat_lost_sight_elapsed = 0.0

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


func current_search_target() -> Vector3:
	var point := current_search_point()
	if point != null:
		return point.target_position()
	return search_focus_position()


func search_point_count() -> int:
	return _search_points.size()


func current_search_point() -> SearchPoint:
	if _search_point_index < 0 or _search_point_index >= _search_points.size():
		return null
	return _search_points[_search_point_index]


func search_point_order() -> Array[StringName]:
	var result: Array[StringName] = []
	for point: SearchPoint in _search_points:
		if point != null and is_instance_valid(point):
			result.append(StringName(point.name))
	return result


func inspected_hide_spot_count() -> int:
	return _search_hide_spot_checks


func visible_search_hide_spot_count() -> int:
	return _search_hide_spot_visible_count


func last_search_hide_spot() -> HideSpot:
	return _last_search_hide_spot if _last_search_hide_spot != null and is_instance_valid(_last_search_hide_spot) else null


func last_search_hide_spot_visible() -> bool:
	return _last_search_hide_spot_visible


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
	return _relight_pending


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


func set_incapacitation_wake_by_noise(value: bool) -> void:
	_wake_by_noise = value


func incapacitation_wakes_on_noise() -> bool:
	return _wake_by_noise


func last_transition_reason() -> StringName:
	return _last_transition_reason


func target_visible() -> bool:
	return _target_visible


func set_target_visible(value: bool) -> void:
	_target_visible = value
	_target_visible_override = 1 if value else 0
	if value:
		_combat_lost_sight_elapsed = 0.0


## Bind the authored route and role used while the enemy is UNAWARE.
## A null path intentionally disables routine movement while preserving the
## five-state brain contract for enemies that have no authored route yet.
func set_routine_path(path: PatrolPath) -> bool:
	if path != null and (not is_instance_valid(path) or not path is PatrolPath):
		return false
	_routine_path = path
	_routine_stop_index = 0
	_routine_stop_elapsed = 0.0
	_routine_curve_distance = 0.0
	_routine_holding_final_stop = false
	_routine_arrived = false
	_last_area_alert_level = -1
	return true


func set_patrol_path(path: PatrolPath) -> bool:
	return set_routine_path(path)


func routine_path() -> PatrolPath:
	_sync_routine_binding()
	return _routine_path if _routine_path != null and is_instance_valid(_routine_path) else null


func patrol_path() -> PatrolPath:
	return routine_path()


func set_routine_type(value: StringName) -> bool:
	var normalized := _normalize_routine_type(value)
	if normalized.is_empty():
		return false
	_routine_type = normalized
	_routine_stop_elapsed = 0.0
	_routine_holding_final_stop = false
	return true


func routine_type() -> StringName:
	return _routine_type


func set_routine_enabled(value: bool) -> void:
	_routine_enabled = value
	if not value:
		_routine_arrived = false


func routine_enabled() -> bool:
	return _routine_enabled


func is_patrol() -> bool:
	return _routine_type == &"ashigaru_patrol"


func is_guard() -> bool:
	return _routine_type == &"guard"


func is_lantern_bearer() -> bool:
	return _routine_type == &"lantern_bearer"


func current_routine_stop_index() -> int:
	return _routine_stop_index


func current_stop_index() -> int:
	return current_routine_stop_index()


func current_routine_stop() -> RoutineStop:
	var path := routine_path()
	_sync_routine_alert_level()
	return path.stop_at(_routine_stop_index) if path != null else null


func routine_target() -> Vector3:
	return _routine_target()


func set_lantern_light(light: LightSource) -> bool:
	if light != null and (not is_instance_valid(light) or not light is LightSource):
		return false
	_lantern_light = light
	_update_lantern_light()
	return true


func lantern_light() -> LightSource:
	if _lantern_light != null and is_instance_valid(_lantern_light):
		return _lantern_light
	var enemy := _enemy_node()
	if enemy != null:
		var candidate := enemy.get_node_or_null(NodePath("Lantern")) as LightSource
		if candidate != null:
			_lantern_light = candidate
	return _lantern_light if _lantern_light != null and is_instance_valid(_lantern_light) else null


func set_lantern_offset(offset: Vector3) -> bool:
	if not _valid_vector(offset) or offset.length() > 10.0:
		return false
	_lantern_offset = offset
	_update_lantern_light()
	return true


func set_routine_arrived(value: bool) -> void:
	_routine_arrived = value
	if value and _state == Enums.AlertState.SUSPICIOUS:
		_investigation_arrived = true
	if value:
		_complete_relight_if_arrived()


func mark_routine_arrived() -> void:
	set_routine_arrived(true)


func set_arrived(value: bool) -> void:
	set_routine_arrived(value)


func set_target_position(position: Vector3) -> void:
	if _valid_vector(position):
		_last_known_position = position
		_has_last_known_position = true


func set_investigation_arrived(value: bool) -> void:
	_investigation_arrived = value


func mark_investigation_arrived() -> void:
	set_investigation_arrived(true)


## Queue one stimulus.  Anomaly stimuli are deduplicated per enemy as required
## by §10.4, while all other stimuli remain available to the next frame winner.
func submit_stimulus(stim: PerceptionStimulus) -> void:
	if not _valid_stimulus(stim):
		return
	var seen_key := get_instance_id()
	if (
		_incapacitated
		and stim.kind == Enums.StimulusKind.NOISE
	):
		if _wake_by_noise and _incapacitated_kind != &"dead":
			# Sleep/knockout/restrained enemies wake when the noise reaches their
			# perception component.  Keep the stimulus so the normal FSM can process
			# the waking sound on the next brain tick.
			wake()
		else:
			# A deliberately suppressed wake must not leave stale noise queued for
			# a later incapacitation or re-enable operation.
			return
	if stim.kind == Enums.StimulusKind.ANOMALY and stim.anomaly != null:
		if not _anomaly_is_relevant(stim.anomaly):
			return
		if stim.anomaly.seen_by.has(seen_key) or _seen_anomalies.has(stim.anomaly):
			return
	if not _append_stimulus_bounded(stim):
		return
	if stim.kind == Enums.StimulusKind.ANOMALY and stim.anomaly != null:
		stim.anomaly.seen_by[seen_key] = true
		if _seen_anomalies.size() >= MAX_SEEN_ANOMALIES:
			var oldest: Variant = _seen_anomalies.keys()[0]
			_seen_anomalies.erase(oldest)
		_seen_anomalies[stim.anomaly] = true
		_register_anomaly_memory(stim.anomaly)
		_emit_anomaly_spotted(stim.anomaly)


func _append_stimulus_bounded(stim: PerceptionStimulus) -> bool:
	if _stimulus_buffer.size() < MAX_STIMULI_PER_FRAME:
		_stimulus_buffer.append(stim)
		return true
	var new_priority := _effective_priority(stim)
	var weakest_index := 0
	var weakest_priority := _effective_priority(_stimulus_buffer[0])
	var weakest_distance := _stimulus_distance(_stimulus_buffer[0])
	for index in range(1, _stimulus_buffer.size()):
		var candidate := _stimulus_buffer[index]
		var candidate_priority := _effective_priority(candidate)
		var candidate_distance := _stimulus_distance(candidate)
		if (
			candidate_priority < weakest_priority
			or (
				candidate_priority == weakest_priority
				and candidate_distance > weakest_distance
			)
		):
			weakest_index = index
			weakest_priority = candidate_priority
			weakest_distance = candidate_distance
	var new_distance := _stimulus_distance(stim)
	if (
		new_priority < weakest_priority
		or (
			new_priority == weakest_priority
			and new_distance >= weakest_distance
		)
	):
		return false
	_stimulus_buffer.remove_at(weakest_index)
	_stimulus_buffer.append(stim)
	return true


func _stimulus_distance(stim: PerceptionStimulus) -> float:
	if stim == null or not _valid_vector(stim.position):
		return INF
	var enemy_position := _enemy_position()
	if not _valid_vector(enemy_position):
		return INF
	var distance := enemy_position.distance_to(stim.position)
	return distance if is_finite(distance) else INF


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


## Raise a nearby enemy to at least SUSPICIOUS without downgrading an enemy
## that is already searching or fighting.  This is the bounded call-for-help
## path used when a search begins.
func receive_propagated_alert(position: Vector3) -> void:
	if _incapacitated or not _valid_vector(position):
		return
	if _state == Enums.AlertState.COMBAT or _state == Enums.AlertState.SEARCHING:
		return
	var stimulus := PerceptionStimulus.create(
		Enums.StimulusKind.NOISE,
		1,
		position,
		1.0,
	)
	_transition_to(Enums.AlertState.SUSPICIOUS, stimulus, &"propagated_alert")


## Incapacitation is outside the five-state FSM.  Passing an empty kind wakes
## the enemy and returns it to Searching, preserving the fact that it was
## attacked while asleep/knocked out/restrained.  A positive duration is
## bounded and auto-wakes through the same path as an explicit wake call.
func set_incapacitated(kind: StringName, duration_seconds: float = 0.0) -> bool:
	if not _started or not is_finite(duration_seconds) or duration_seconds < 0.0:
		return false
	if kind.is_empty():
		if not _incapacitated or _incapacitated_kind == &"dead":
			return false
		_incapacitated = false
		_incapacitated_kind = &""
		_incapacitation_remaining = 0.0
		_target_visible = false
		var wake_stimulus := PerceptionStimulus.create(
			Enums.StimulusKind.DAMAGE,
			3,
			investigation_position(),
			1.0,
		)
		_transition_to(Enums.AlertState.SEARCHING, wake_stimulus, &"incapacitated_wake")
		return true
	if kind not in [&"sleep", &"knockout", &"restrained", &"dead"]:
		return false
	if kind == &"dead" and duration_seconds > 0.0:
		# Death is permanent until a separate corpse/revive system changes it;
		# never allow a timer to wake a dead enemy back into the FSM.
		return false
	# Each incapacitation starts with the documented default.  A caller that
	# deliberately disables noise wake can apply the hook after this state set.
	_wake_by_noise = true
	_incapacitated = true
	_incapacitated_kind = kind
	_incapacitation_remaining = _bounded_incapacitation_duration(duration_seconds)
	_stimulus_buffer.clear()
	return true


func wake() -> bool:
	return set_incapacitated(&"")


func incapacitation_remaining() -> float:
	return maxf(_incapacitation_remaining, 0.0)


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
	if _relight_pending:
		if not _relight_request_sent:
			_relight_elapsed += delta
			_try_request_relight()
		else:
			# The request is asynchronous; arrival may happen on any later frame.
			_complete_relight_if_arrived()


func _advance_incapacitation(delta: float) -> void:
	if _incapacitation_remaining <= 0.0:
		return
	_incapacitation_remaining = maxf(_incapacitation_remaining - delta, 0.0)
	if _incapacitation_remaining <= 0.0001:
		_incapacitation_remaining = 0.0
		wake()


func _advance_state_without_stimulus(delta: float) -> void:
	match _state:
		Enums.AlertState.UNAWARE:
			_advance_routine(delta)
		Enums.AlertState.SUSPICIOUS:
			_set_navigation_target(investigation_position())
			if _investigation_arrived or _navigation_has_reached(investigation_position()):
				_investigation_arrived = true
				_investigation_elapsed += delta
			if _investigation_arrived and _investigation_elapsed >= INVESTIGATION_DURATION_SEC:
				_complete_investigation()
		Enums.AlertState.SEARCHING:
			_advance_search(delta)
		Enums.AlertState.COMBAT:
			var perception := _perception()
			var visible := _target_visible
			if perception != null and _target_visible_override < 0:
				visible = perception.target_visible()
			if visible:
				_target_visible = true
				_combat_lost_sight_elapsed = 0.0
				return
			_target_visible = false
			_combat_lost_sight_elapsed += delta
			if _combat_lost_sight_elapsed >= COMBAT_LOST_SIGHT_DURATION_SEC:
				_transition_to(Enums.AlertState.SEARCHING, null, &"lost_sight")
		Enums.AlertState.RETURN:
			_set_navigation_target(_return_target())
			if (
				not _relight_pending
				and (_routine_arrived or _navigation_has_reached(_routine_target()))
			):
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
		_begin_search_route()
		_set_substate(&"search")
	elif _state == Enums.AlertState.SUSPICIOUS and priority <= 1:
		_investigation_elapsed = 0.0
		_investigation_arrived = false
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
			_investigation_arrived = false
			_set_substate(&"investigate")
			_emit_signal_if_available(&"investigation_started", investigation_position())
		Enums.AlertState.SEARCHING:
			_search_elapsed = 0.0
			_begin_search_route()
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
		if next == Enums.AlertState.SUSPICIOUS
		else current_search_target() if next == Enums.AlertState.SEARCHING
		else _return_target() if next == Enums.AlertState.RETURN else _routine_target()
	)
	state_changed.emit(previous, next)
	var event_bus := _event_bus()
	if event_bus != null:
		event_bus.emit_signal(&"alert_changed", _enemy_node(), int(previous), int(next))
	if next == Enums.AlertState.SEARCHING:
		_propagate_search_alert(_last_known_position)
		if stim != null:
			_raise_area_alert_if_severe(stim)


func _begin_search_route() -> void:
	var anchor := search_focus_position()
	if not _valid_vector(anchor):
		anchor = _enemy_position()
	_search_route_anchor = anchor if _valid_vector(anchor) else Vector3.ZERO
	_search_points = _collect_search_points(_search_route_anchor)
	_search_point_index = 0 if not _search_points.is_empty() else -1
	_search_route_complete = _search_points.is_empty()
	_search_hide_spot_checks = 0
	_search_hide_spot_visible_count = 0
	_search_hide_spot_anchor = _search_route_anchor
	_last_search_hide_spot = null
	_last_search_hide_spot_visible = false


func _collect_search_points(anchor: Vector3) -> Array[SearchPoint]:
	var result: Array[SearchPoint] = []
	var tree := get_tree()
	if tree == null:
		return result
	var scanned := 0
	for candidate in tree.get_nodes_in_group(&"search_points"):
		if scanned >= MAX_SEARCH_POINT_SCAN:
			break
		scanned += 1
		var point := candidate as SearchPoint
		if point == null or not is_instance_valid(point) or not point.is_searchable():
			continue
		if not _search_point_is_reachable(point):
			continue
		var distance := point.target_position().distance_to(anchor) if _valid_vector(anchor) else 0.0
		if not is_finite(distance) or distance > SEARCH_POINT_RADIUS:
			continue
		result.append(point)
		if result.size() > MAX_SEARCH_POINT_CANDIDATES:
			result.sort_custom(_sort_search_points)
			result.resize(MAX_SEARCH_POINT_CANDIDATES)
	result.sort_custom(_sort_search_points)
	if result.size() > MAX_SEARCH_POINTS:
		result.resize(MAX_SEARCH_POINTS)
	return result


func _search_point_is_reachable(point: SearchPoint) -> bool:
	if point == null or not is_instance_valid(point) or not point.enemy_accessible:
		return false
	var target := point.target_position()
	var enemy := _enemy_node() as Node3D
	if not _valid_vector(target) or enemy == null or not _valid_vector(enemy.global_position):
		return false
	# SearchPoint authoring is ground-oriented. Reject roof/beam markers even
	# before NavigationServer publishes a synchronized map.
	if absf(target.y - enemy.global_position.y) > SEARCH_VERTICAL_REACH_TOLERANCE:
		return false
	var agent := enemy.get_node_or_null(NodePath("NavigationAgent3D")) as NavigationAgent3D
	if agent == null:
		return true
	var navigation_map := agent.get_navigation_map()
	if not navigation_map.is_valid() or NavigationServer3D.map_get_iteration_id(navigation_map) <= 0:
		# The explicit authoring flag plus vertical guard is the bounded fallback
		# while the map is unavailable; no unbounded query or movement is added.
		return true
	# A valid RID can exist before any navigation regions are baked. Treat that
	# empty map as unsynchronized so isolated/test scenes retain authored points.
	if NavigationServer3D.map_get_regions(navigation_map).is_empty():
		return true
	var closest := NavigationServer3D.map_get_closest_point(navigation_map, target)
	return _valid_vector(closest) and closest.distance_to(target) <= SEARCH_NAVIGATION_SNAP_DISTANCE


func _sort_search_points(left: SearchPoint, right: SearchPoint) -> bool:
	if left == null or not is_instance_valid(left):
		return false
	if right == null or not is_instance_valid(right):
		return true
	if not is_equal_approx(left.confidence, right.confidence):
		return left.confidence > right.confidence
	var left_distance := left.target_position().distance_to(_search_route_anchor)
	var right_distance := right.target_position().distance_to(_search_route_anchor)
	if not is_equal_approx(left_distance, right_distance):
		return left_distance < right_distance
	if left.search_order != right.search_order:
		return left.search_order < right.search_order
	return String(left.name) < String(right.name)


func _advance_search(delta: float) -> void:
	_search_elapsed += delta
	if _search_elapsed >= SEARCH_DURATION_SEC:
		_transition_to(Enums.AlertState.RETURN, null, &"search_timeout")
		return
	var point := current_search_point()
	if point == null:
		_set_navigation_target(search_focus_position())
		return
	var target := point.target_position()
	_set_navigation_target(target)
	if _search_route_complete:
		return
	var arrived := _navigation_has_reached(target)
	var enemy := _enemy_node()
	var bounded_delta := minf(delta, MAX_SEARCH_STEP_DELTA)
	if enemy != null and enemy.has_method(&"face_routine_direction"):
		var facing := point.world_facing_direction()
		if _valid_vector(facing) and facing.length_squared() > 0.000001:
			# Use the bounded full-step factor so the authored inspection cone is
			# active before HideSpot visibility is evaluated.
			enemy.call(&"face_routine_direction", facing, MAX_SEARCH_STEP_DELTA)
	if not arrived and enemy != null and enemy.has_method(&"advance_navigation"):
		var result: Variant = enemy.call(&"advance_navigation", bounded_delta, target, _search_speed())
		arrived = bool(result) if result is bool else _navigation_has_reached(target)
	if not arrived:
		return
	_inspect_hide_spots_at(target)
	if _search_point_index < _search_points.size() - 1:
		_search_point_index += 1
	else:
		_search_route_complete = true


func _inspect_hide_spots_at(position: Vector3) -> void:
	if _search_hide_spot_checks >= MAX_SEARCH_HIDE_SPOTS or not _valid_vector(position):
		return
	_search_hide_spot_anchor = position
	var tree := get_tree()
	if tree == null:
		return
	var candidates: Array[HideSpot] = []
	var scanned := 0
	for candidate in tree.get_nodes_in_group(&"hide_spots"):
		if scanned >= MAX_SEARCH_HIDE_SPOT_SCAN:
			break
		scanned += 1
		var hide_spot := candidate as HideSpot
		if hide_spot == null or not is_instance_valid(hide_spot) or not hide_spot.is_geometry_valid():
			continue
		var distance := hide_spot.entry_world_position().distance_to(position)
		if not is_finite(distance) or distance > SEARCH_HIDE_SPOT_RADIUS:
			continue
		candidates.append(hide_spot)
		if candidates.size() > MAX_SEARCH_HIDE_SPOT_CANDIDATES:
			candidates.sort_custom(_sort_hide_spots)
			candidates.resize(MAX_SEARCH_HIDE_SPOT_CANDIDATES)
	candidates.sort_custom(_sort_hide_spots)
	var perception := _perception()
	for hide_spot: HideSpot in candidates:
		if _search_hide_spot_checks >= MAX_SEARCH_HIDE_SPOTS:
			break
		_search_hide_spot_checks += 1
		_last_search_hide_spot = hide_spot
		var visible_by_perception := (
			perception != null
			and perception.can_see_position(hide_spot.entry_world_position())
		)
		var hidden_player := _detect_hidden_player(hide_spot) if visible_by_perception else null
		_last_search_hide_spot_visible = visible_by_perception or hidden_player != null
		if _last_search_hide_spot_visible:
			_search_hide_spot_visible_count += 1
		if hidden_player != null and _valid_vector(hidden_player.global_position):
			submit_stimulus(PerceptionStimulus.create(
				Enums.StimulusKind.VISUAL,
				4,
				hidden_player.global_position,
				1.0,
			))
		search_hide_spot_inspected.emit(hide_spot, _last_search_hide_spot_visible)


func _detect_hidden_player(hide_spot: HideSpot) -> Node3D:
	if hide_spot == null or not is_instance_valid(hide_spot):
		return null
	var tree := get_tree()
	if tree == null:
		return null
	var examined := 0
	for candidate in tree.get_nodes_in_group(&"player"):
		if examined >= MAX_SEARCH_PLAYER_CANDIDATES:
			break
		examined += 1
		var player := candidate as Node3D
		if player == null or not is_instance_valid(player):
			continue
		if not player.has_method(&"is_hidden") or not bool(player.call(&"is_hidden")):
			continue
		if not player.has_method(&"active_hide_spot") or player.call(&"active_hide_spot") != hide_spot:
			continue
		if player.has_method(&"invalidate_hidden_if_close_range_seen"):
			player.call(&"invalidate_hidden_if_close_range_seen", true)
		return player
	return null


func _sort_hide_spots(left: HideSpot, right: HideSpot) -> bool:
	if left == null or not is_instance_valid(left):
		return false
	if right == null or not is_instance_valid(right):
		return true
	var left_distance := left.entry_world_position().distance_to(_search_hide_spot_anchor)
	var right_distance := right.entry_world_position().distance_to(_search_hide_spot_anchor)
	if not is_equal_approx(left_distance, right_distance):
		return left_distance < right_distance
	return String(left.name) < String(right.name)


func _propagate_search_alert(position: Vector3) -> void:
	var source := _enemy_node() as Node3D
	var tree := get_tree()
	if source == null or tree == null or not _valid_vector(source.global_position):
		return
	var propagation_position := position if _valid_vector(position) else source.global_position
	var examined := 0
	for candidate in tree.get_nodes_in_group(&"enemies"):
		if examined >= MAX_PROPAGATED_ENEMIES:
			break
		examined += 1
		if candidate == source or not candidate is Node3D:
			continue
		var enemy := candidate as Node3D
		var distance := source.global_position.distance_to(enemy.global_position)
		if not is_finite(distance) or distance > SEARCH_PROPAGATION_RADIUS:
			continue
		var brain := enemy.get_node_or_null(NodePath("Brain")) as EnemyBrain
		if brain != null:
			brain.receive_propagated_alert(propagation_position)


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
	# MissionDirector is the single owner of corpse discovery statistics and its
	# deduplication/area-alert transaction.  EnemyBrain owns other severe
	# anomaly escalation, but must not double-count corpses here.
	if stim.anomaly.kind == Enums.AnomalyKind.CORPSE:
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
	if not _relight_pending:
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
	if not _relight_request_sent and _relight_light.request_relight(enemy):
		_relight_request_sent = true
		_set_navigation_target(_relight_light.global_position)
		relight_requested.emit(_relight_light)
	_complete_relight_if_arrived()


func _complete_relight_if_arrived() -> void:
	if not _relight_pending or not _relight_request_sent:
		return
	if _relight_light == null or not is_instance_valid(_relight_light):
		_relight_pending = false
		return
	var enemy := _enemy_node()
	if not enemy is Node3D or not enemy.is_inside_tree():
		return
	if not _relight_light.is_near_interaction((enemy as Node3D).global_position):
		return
	_relight_light.set_extinguished(false)
	_relight_pending = false
	_relight_request_sent = false
	# Re-light arrival is an intermediate destination.  Continue RETURN toward
	# the authored routine target instead of treating the light as the patrol
	# destination itself.
	_routine_arrived = false
	_set_navigation_target(_routine_target())
	_set_substate(&"none")


func _emit_anomaly_spotted(anomaly: Anomaly) -> void:
	var event_bus := _event_bus()
	if event_bus != null:
		event_bus.emit_signal(&"anomaly_spotted", anomaly, _enemy_node())


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
	if (
		anomaly == null
		or anomaly.kind < Enums.AnomalyKind.CORPSE
		or anomaly.kind > Enums.AnomalyKind.KNOCKOUT
		or anomaly.severity < 1
		or anomaly.severity > 3
		or not is_finite(anomaly.expires_at)
		or anomaly.expires_at < 0.0
		or (anomaly.expires_at > 0.0 and Time.get_ticks_msec() / 1000.0 >= anomaly.expires_at)
		or not _valid_vector(anomaly.position)
	):
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


func routine_alert_level() -> int:
	return _area_alert_level()


func refresh_routine_for_alert() -> void:
	_last_area_alert_level = -1
	_sync_routine_alert_level()


func _on_area_alert_changed(_level: int) -> void:
	_sync_routine_alert_level()


func _area_alert_level() -> int:
	var game_state := _autoload(&"GameState")
	if game_state == null:
		return 0
	var value: Variant = game_state.get(&"area_alert_level")
	if not (value is int or value is float):
		return 0
	var numeric := float(value)
	if not is_finite(numeric):
		return 0
	return clampi(int(numeric), 0, MAX_AREA_ALERT_LEVEL)


func _sync_routine_alert_level() -> void:
	var level := _area_alert_level()
	if _last_area_alert_level == level:
		return
	# A newly bound brain has no prior event to compare with.  Treat its
	# baseline as calm so a late-spawned enemy immediately selects the strictest
	# stop already eligible for the current permanent alert level.
	var previous := maxi(_last_area_alert_level, 0)
	_last_area_alert_level = level
	var path := _routine_path
	if path == null or not is_instance_valid(path):
		return
	var stops := path.ordered_stops()
	if stops.is_empty():
		return
	var current_index := clampi(_routine_stop_index, 0, stops.size() - 1)
	var current_stop := stops[current_index]
	var candidate_index := -1

	# On an alert rise, select the strictest newly eligible stop.  This lets a
	# route author place a guard pair/lantern stop at level 1 and an extra patrol
	# stop at level 2 without rebuilding the route resource.
	if previous >= 0 and level > previous:
		var highest_threshold := previous
		for index in stops.size():
			var stop := stops[index]
			if stop == null or not is_instance_valid(stop):
				continue
			var threshold := stop.alert_level_required()
			if threshold > highest_threshold and threshold <= level:
				highest_threshold = threshold
				candidate_index = index

	# Initial binding, alert reduction, or an authored stop that is no longer
	# eligible must always fail closed to the first eligible stop.
	if candidate_index < 0 and (
		current_stop == null
		or not is_instance_valid(current_stop)
		or current_stop.alert_level_required() > level
	):
		for index in stops.size():
			var stop := stops[index]
			if stop != null and is_instance_valid(stop) and stop.alert_level_required() <= level:
				candidate_index = index
				break

	if candidate_index >= 0 and candidate_index != _routine_stop_index:
		_routine_stop_index = candidate_index
		_routine_stop_elapsed = 0.0
		_routine_holding_final_stop = false
		_routine_arrived = false


func _routine_target() -> Vector3:
	_sync_routine_binding()
	_sync_routine_alert_level()
	var path := _routine_path
	if _routine_path_is_usable(path):
		var route_stops := path.ordered_stops()
		if not route_stops.is_empty():
			var bounded_index := clampi(_routine_stop_index, 0, route_stops.size() - 1)
			return route_stops[bounded_index].target_position()
		var length := path.route_length()
		if length > 0.0:
			return path.world_position_at_distance(_routine_curve_distance)
	var enemy := _enemy_node()
	if enemy == null:
		return Vector3.ZERO
	var marker := enemy.get_node_or_null(NodePath("RoutineTarget")) as Node3D
	if marker != null and _valid_vector(marker.global_position):
		return marker.global_position
	return (enemy as Node3D).global_position if enemy is Node3D else Vector3.ZERO


func _advance_routine(delta: float) -> void:
	if not _routine_enabled:
		_update_lantern_light()
		return
	var bounded_delta := minf(delta, MAX_ROUTINE_STEP_DELTA)
	if bounded_delta < 0.0 or not is_finite(bounded_delta):
		return
	_sync_routine_binding()
	var path := _routine_path
	if not _routine_path_is_usable(path):
		_update_lantern_light()
		return
	_routine_clock = fmod(_routine_clock + bounded_delta, MAX_ROUTINE_CLOCK_SECONDS)
	var target := _routine_target()
	if not _valid_vector(target):
		return
	_set_navigation_target(target)
	var arrived := _navigation_has_reached(target)
	var enemy := _enemy_node()
	if not arrived and enemy != null and enemy.has_method(&"advance_navigation"):
		var result: Variant = enemy.call(&"advance_navigation", bounded_delta, target, _routine_speed())
		arrived = bool(result) if result is bool else _navigation_has_reached(target)
	if enemy != null and enemy.has_method(&"face_routine_direction"):
		var facing := _routine_facing_direction()
		if _valid_vector(facing) and facing.length_squared() > 0.000001:
			enemy.call(&"face_routine_direction", facing, bounded_delta)
	_update_lantern_light()
	if not arrived:
		_routine_stop_elapsed = 0.0
		_routine_arrived = false
		return
	_routine_arrived = true
	if _routine_type == &"guard":
		# A standing guard may navigate to its authored first stop once, then
		# remains there without advancing through the route.
		return
	var stop := current_routine_stop()
	if stop != null and not stop.is_active_at(_routine_clock, _area_alert_level()):
		_advance_to_next_routine_stop()
		return
	_routine_stop_elapsed += bounded_delta
	if stop != null:
		if _routine_stop_elapsed >= stop.dwell_duration():
			_advance_to_next_routine_stop()
		return
	# A curve-only PatrolPath advances in bounded baked-distance increments.
	var length := path.route_length()
	if length <= 0.0:
		return
	_routine_curve_distance += _routine_speed() * bounded_delta
	if _routine_curve_distance >= length:
		if path.is_looped():
			_routine_curve_distance = fmod(_routine_curve_distance, length)
		else:
			_routine_curve_distance = length
			_routine_holding_final_stop = true


func _advance_to_next_routine_stop() -> void:
	var path := _routine_path
	if not _routine_path_is_usable(path):
		return
	var next_index := _next_eligible_routine_stop_index(path)
	if next_index < 0 or (not path.is_looped() and next_index == _routine_stop_index):
		_routine_holding_final_stop = true
		_routine_stop_elapsed = 0.0
		_routine_arrived = true
		return
	_routine_stop_index = next_index
	_routine_stop_elapsed = 0.0
	_routine_holding_final_stop = false
	_routine_arrived = false
	_set_navigation_target(_routine_target())


func _next_eligible_routine_stop_index(path: PatrolPath) -> int:
	if path == null or not is_instance_valid(path):
		return -1
	var stops := path.ordered_stops()
	if stops.is_empty():
		return -1
	var current_index := clampi(_routine_stop_index, 0, stops.size() - 1)
	var level := _area_alert_level()
	for _attempt in stops.size():
		var candidate_index := path.next_stop_index_for_alert(current_index, level, true)
		if candidate_index < 0 or candidate_index == _routine_stop_index:
			return -1
		var candidate := path.stop_at(candidate_index)
		if candidate != null and candidate.is_active_at(_routine_clock, level):
			return candidate_index
		current_index = candidate_index
	return -1


func _routine_facing_direction() -> Vector3:
	var stop := current_routine_stop()
	if stop != null:
		return stop.world_facing_direction()
	var path := _routine_path
	if path == null or not _routine_path_is_usable(path):
		return Vector3.ZERO
	var next_position := path.world_position_at_distance(
		minf(path.route_length(), _routine_curve_distance + 0.25),
	)
	var current_position := path.world_position_at_distance(_routine_curve_distance)
	return next_position - current_position if _valid_vector(next_position) and _valid_vector(current_position) else Vector3.ZERO


func _routine_speed() -> float:
	var speed := DEFAULT_ROUTINE_SPEED
	if _routine_path != null and is_instance_valid(_routine_path) and is_finite(_routine_path.route_speed):
		speed = _routine_path.route_speed
	var enemy := _enemy_node()
	if enemy != null:
		var configured: Variant = enemy.get(&"routine_speed")
		if configured is float or configured is int:
			if is_finite(float(configured)) and float(configured) > 0.0:
				speed = float(configured)
	return clampf(speed, 0.1, 12.0)


func _search_speed() -> float:
	return clampf(maxf(_routine_speed(), MIN_SEARCH_SPEED), 0.1, 12.0)


func _routine_path_is_usable(path: PatrolPath) -> bool:
	if path == null or not is_instance_valid(path) or not path is PatrolPath or not path.enabled:
		return false
	var enemy := _enemy_node()
	if enemy == null or not path.is_inside_tree():
		return false
	if enemy.is_inside_tree() and path.get_tree() != enemy.get_tree():
		return false
	return path.is_geometry_valid()


func _sync_routine_binding() -> void:
	if _routine_path != null and is_instance_valid(_routine_path):
		return
	var enemy := _enemy_node()
	if enemy == null:
		return
	if enemy.has_method(&"configured_patrol_path"):
		var configured: Variant = enemy.call(&"configured_patrol_path")
		if configured is PatrolPath:
			_routine_path = configured
	if _routine_path == null:
		var child := enemy.get_node_or_null(NodePath("PatrolPath")) as PatrolPath
		if child != null:
			_routine_path = child
	if _routine_path == null:
		return
	if enemy.has_method(&"configured_routine_type"):
		var configured_type: Variant = enemy.call(&"configured_routine_type")
		if configured_type is StringName:
			set_routine_type(configured_type)
	if _lantern_light == null:
		_lantern_light = lantern_light()


func _update_lantern_light() -> void:
	var light := lantern_light()
	if light == null or not is_instance_valid(light):
		return
	var enemy := _enemy_node() as Node3D
	if enemy == null or not _valid_vector(enemy.global_position):
		return
	var target_position := enemy.global_position + _lantern_offset
	if _valid_vector(target_position):
		light.global_position = target_position
	if _routine_type == &"lantern_bearer" and not light.is_on():
		light.set_extinguished(false)


static func _normalize_routine_type(value: StringName) -> StringName:
	var normalized := String(value).to_lower().strip_edges().replace("-", "_").replace(" ", "_")
	match normalized:
		"patrol", "ashigaru", "ashigaru_patrol":
			return &"ashigaru_patrol"
		"guard", "standing_guard", "stationary", "watch":
			return &"guard"
		"lantern", "lantern_bearer", "moving_light":
			return &"lantern_bearer"
	return &""


func _return_target() -> Vector3:
	if _relight_pending and _relight_light != null and is_instance_valid(_relight_light):
		return _relight_light.global_position
	return _routine_target()


func _set_navigation_target(target: Vector3) -> void:
	if not _valid_vector(target):
		return
	var enemy := _enemy_node()
	if enemy == null:
		return
	var agent := enemy.get_node_or_null(NodePath("NavigationAgent3D")) as NavigationAgent3D
	if agent != null:
		agent.target_position = target


func _navigation_has_reached(target: Vector3) -> bool:
	if not _valid_vector(target):
		return false
	var enemy := _enemy_node() as Node3D
	if enemy == null or not _valid_vector(enemy.global_position):
		return false
	var agent := enemy.get_node_or_null(NodePath("NavigationAgent3D")) as NavigationAgent3D
	var tolerance := 0.5
	if agent != null and is_finite(agent.target_desired_distance):
		tolerance = minf(maxf(agent.target_desired_distance, tolerance), 0.5)
	var distance := enemy.global_position.distance_to(target)
	if not is_finite(distance):
		return false
	if distance <= tolerance:
		return true
	# Do not query is_navigation_finished() here: the agent may not have a
	# synchronized NavigationServer map yet.  Distance is the only fail-closed
	# arrival signal until a route movement step reports success.
	return false


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
		and stim.confidence >= 0.0
		and stim.confidence <= 1.0
	)


static func _valid_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)


static func _bounded_incapacitation_duration(value: float) -> float:
	if not is_finite(value) or value <= 0.0:
		return 0.0
	return clampf(value, 0.0, MAX_INCAPACITATION_DURATION_SEC)
