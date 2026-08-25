extends Node


const MAX_TRACKED_ENEMIES := 64

signal alert_tier_changed(tier: int)

var current_alert_tier: int = 0
var current_bgm_set: StringName = &"normal"
var current_ambience: StringName = &""
var assassination_audio_phase: StringName = &"ambient"
var assassination_context: StringName = &""
var _assassination_previous_ambience: StringName = &"ambient"
var _tracked_alerts: Dictionary = {}


func _ready() -> void:
	_bind_event_bus()
	set_process(true)


func _exit_tree() -> void:
	_unbind_event_bus()


func _process(_delta: float) -> void:
	if not _tracked_alerts.is_empty():
		_refresh_highest_tier()


func set_alert_tier(tier: int) -> void:
	var next_tier := clampi(tier, 0, 2)
	if current_alert_tier == next_tier:
		return
	current_alert_tier = next_tier
	alert_tier_changed.emit(current_alert_tier)


func alert_tier() -> int:
	return current_alert_tier


func highest_alert_state() -> Enums.AlertState:
	_prune_tracked_alerts()
	var highest := Enums.AlertState.UNAWARE
	for entry: Dictionary in _tracked_alerts.values():
		var value: Variant = entry.get(&"state", Enums.AlertState.UNAWARE)
		if not value is int and not value is float:
			continue
		var state := int(value)
		if _is_active_alert_state(state) and state > highest:
			highest = state as Enums.AlertState
	return highest


func active_alert_count() -> int:
	_prune_tracked_alerts()
	return _tracked_alerts.size()


func tracked_alert_state(enemy: Node) -> Enums.AlertState:
	if enemy == null or not is_instance_valid(enemy):
		return Enums.AlertState.UNAWARE
	_prune_tracked_alerts()
	var entry: Variant = _tracked_alerts.get(enemy.get_instance_id())
	if not entry is Dictionary:
		return Enums.AlertState.UNAWARE
	var value: Variant = (entry as Dictionary).get(&"state", Enums.AlertState.UNAWARE)
	return int(value) as Enums.AlertState if value is int or value is float else Enums.AlertState.UNAWARE


## Update the aggregate from EventBus.alert_changed.  Only the five-state
## contract is accepted; inactive states are removed so freed enemies cannot
## hold an alert tier forever.
func update_enemy_alert(enemy: Node, to_state: int) -> bool:
	if enemy == null or not is_instance_valid(enemy) or not _valid_alert_state(to_state):
		return false
	var instance_id := enemy.get_instance_id()
	if not _is_active_alert_state(to_state):
		_tracked_alerts.erase(instance_id)
		_refresh_highest_tier()
		return true
	_prune_tracked_alerts()
	if not _tracked_alerts.has(instance_id) and _tracked_alerts.size() >= MAX_TRACKED_ENEMIES:
		# Keep the table bounded while retaining a higher-severity contribution.
		# The aggregate is a maximum, so replacing a lower state is equivalent
		# for the lower state and prevents a full table from masking Combat.
		var weakest_id: Variant = null
		var weakest_state := Enums.AlertState.COMBAT
		for tracked_id: Variant in _tracked_alerts.keys():
			var tracked_entry: Variant = _tracked_alerts.get(tracked_id)
			if not tracked_entry is Dictionary:
				continue
			var tracked_value: Variant = (tracked_entry as Dictionary).get(&"state")
			if (tracked_value is int or tracked_value is float) and int(tracked_value) < weakest_state:
				weakest_state = int(tracked_value) as Enums.AlertState
				weakest_id = tracked_id
		if weakest_id == null or to_state <= int(weakest_state):
			return false
		_tracked_alerts.erase(weakest_id)
	_tracked_alerts[instance_id] = {&"enemy": enemy, &"state": to_state}
	_refresh_highest_tier()
	return true


func clear_alert_tracking() -> void:
	_tracked_alerts.clear()
	_refresh_highest_tier()


static func alert_tier_for_state(state: int) -> int:
	if not _valid_alert_state(state):
		return -1
	match state:
		Enums.AlertState.SEARCHING:
			return 1
		Enums.AlertState.COMBAT:
			return 2
		_:
			return 0


func _on_alert_changed(enemy: Node, _from_state: int, to_state: int) -> void:
	update_enemy_alert(enemy, to_state)


func _on_enemy_neutralized(enemy: Node, _method: String) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	_tracked_alerts.erase(enemy.get_instance_id())
	_refresh_highest_tier()


func _refresh_highest_tier() -> void:
	var highest_state := highest_alert_state()
	var tier := alert_tier_for_state(int(highest_state))
	if tier >= 0:
		set_alert_tier(tier)


func _prune_tracked_alerts() -> void:
	for instance_id: Variant in _tracked_alerts.keys():
		var entry: Variant = _tracked_alerts.get(instance_id)
		if not entry is Dictionary:
			_tracked_alerts.erase(instance_id)
			continue
		var enemy: Variant = (entry as Dictionary).get(&"enemy")
		var state: Variant = (entry as Dictionary).get(&"state", Enums.AlertState.UNAWARE)
		if (
			not is_instance_valid(enemy)
			or not enemy is Node
			or _is_incapacitated_enemy(enemy as Node)
			or not (state is int or state is float)
			or not _is_active_alert_state(int(state))
		):
			_tracked_alerts.erase(instance_id)


func _bind_event_bus() -> void:
	var event_bus := _event_bus()
	if event_bus == null:
		return
	if event_bus.has_signal(&"alert_changed"):
		var alert_callback := Callable(self, &"_on_alert_changed")
		if not event_bus.is_connected(&"alert_changed", alert_callback):
			event_bus.connect(&"alert_changed", alert_callback)
	var neutralized_callback := Callable(self, &"_on_enemy_neutralized")
	for signal_name in [&"enemy_killed", &"enemy_neutralized"]:
		if event_bus.has_signal(signal_name) and not event_bus.is_connected(signal_name, neutralized_callback):
			event_bus.connect(signal_name, neutralized_callback)


func _unbind_event_bus() -> void:
	var event_bus := _event_bus()
	if event_bus == null:
		return
	if event_bus.has_signal(&"alert_changed"):
		var alert_callback := Callable(self, &"_on_alert_changed")
		if event_bus.is_connected(&"alert_changed", alert_callback):
			event_bus.disconnect(&"alert_changed", alert_callback)
	var neutralized_callback := Callable(self, &"_on_enemy_neutralized")
	for signal_name in [&"enemy_killed", &"enemy_neutralized"]:
		if event_bus.has_signal(signal_name) and event_bus.is_connected(signal_name, neutralized_callback):
			event_bus.disconnect(signal_name, neutralized_callback)


func _event_bus() -> Node:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath("EventBus"))


static func _is_active_alert_state(state: int) -> bool:
	return state >= Enums.AlertState.SUSPICIOUS and state <= Enums.AlertState.COMBAT


static func _valid_alert_state(state: int) -> bool:
	return state >= Enums.AlertState.UNAWARE and state <= Enums.AlertState.RETURN


static func _is_incapacitated_enemy(enemy: Node) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	if enemy.has_method(&"is_incapacitated"):
		return bool(enemy.call(&"is_incapacitated"))
	var brain := enemy.get_node_or_null(NodePath("Brain"))
	return brain != null and brain.has_method(&"is_incapacitated") and bool(brain.call(&"is_incapacitated"))


func play_bgm_set(set_id: StringName) -> void:
	current_bgm_set = set_id
	push_warning("AudioDirector.play_bgm_set is a M0 skeleton")


func play_stinger(id: StringName) -> void:
	push_warning("AudioDirector.play_stinger is a M0 skeleton: %s" % id)


func set_ambience(id: StringName) -> void:
	current_ambience = id
	push_warning("AudioDirector.set_ambience is a M0 skeleton")


## Presentation hooks keep the authored sequence observable even before real
## audio streams are assigned: silence -> one beat -> ambient restoration.
func begin_assassination_audio(context: StringName) -> void:
	_assassination_previous_ambience = current_ambience
	if _assassination_previous_ambience == &"" or _assassination_previous_ambience == &"silence":
		_assassination_previous_ambience = &"ambient"
	assassination_context = context
	assassination_audio_phase = &"silence"
	current_ambience = &"silence"


func play_assassination_beat(context: StringName) -> void:
	assassination_context = context
	assassination_audio_phase = &"beat"


func restore_assassination_ambient() -> void:
	assassination_audio_phase = &"ambient"
	assassination_context = &""
	current_ambience = _assassination_previous_ambience
	_assassination_previous_ambience = &"ambient"
