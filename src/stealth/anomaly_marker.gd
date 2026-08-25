@tool
class_name AnomalyMarker
extends Marker3D


## Authored, persistent visual anomaly.
##
## The marker is deliberately independent from EnemyPerception.  It owns the
## stable Anomaly instance so a persistent open door or body is deduplicated per
## enemy even when the observer's 10 Hz scan sees it repeatedly.

const MIN_SEVERITY := 1
const MAX_SEVERITY := 3
const MAX_EXPIRES_SECONDS := 86400.0
const MAX_WORLD_COORDINATE := 10000.0

@export var anomaly_kind: int = Enums.AnomalyKind.DOOR_OPEN:
	set(value):
		anomaly_kind = _bounded_kind(value)
		_anomaly = null
		_registered = false
		_update_editor_state()
@export_range(MIN_SEVERITY, MAX_SEVERITY, 1) var severity := 1:
	set(value):
		severity = clampi(value, MIN_SEVERITY, MAX_SEVERITY)
		_anomaly = null
		_registered = false
		_update_editor_state()
@export_range(0.0, MAX_EXPIRES_SECONDS, 0.1) var expires_in_seconds := 0.0:
	set(value):
		expires_in_seconds = _bounded_expires(value)
		_anomaly = null
		_registered = false
		_update_editor_state()
@export var active := true:
	set(value):
		active = value
		if not active:
			_anomaly = null
			_registered = false
		elif is_inside_tree():
			_register_anomaly()
		_update_editor_state()

var _anomaly: Anomaly
var _registered := false


func _enter_tree() -> void:
	set_notify_transform(true)
	if not is_in_group(&"anomaly_markers"):
		add_to_group(&"anomaly_markers")
	_update_editor_state()


func _ready() -> void:
	if active:
		_register_anomaly()


func _exit_tree() -> void:
	set_notify_transform(false)
	_registered = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and _anomaly != null:
		_anomaly.position = global_position
		_update_editor_state()


## Return the stable anomaly for visual perception, or null when the marker is
## disabled/invalid.  The position is refreshed so moved markers remain safe.
func current_anomaly() -> Anomaly:
	if not active or not is_geometry_valid():
		return null
	if (
		_anomaly != null
		and _anomaly.expires_at > 0.0
		and Time.get_ticks_msec() / 1000.0 >= _anomaly.expires_at
	):
		return null
	if _anomaly == null:
		_anomaly = _new_anomaly()
	else:
		_anomaly.position = global_position
	return _anomaly


## Compatibility alias for marker consumers that use the shorter API.
func anomaly() -> Anomaly:
	return current_anomaly()


var kind: int:
	get:
		return anomaly_kind
	set(value):
		anomaly_kind = value


func set_anomaly_kind(value: int) -> void:
	anomaly_kind = value


func set_active(value: bool) -> void:
	active = value


func is_active() -> bool:
	return active and current_anomaly() != null


func set_open(value: bool) -> void:
	if anomaly_kind == Enums.AnomalyKind.DOOR_OPEN:
		set_active(value)


func is_geometry_valid() -> bool:
	return (
		is_inside_tree()
		and _is_safe_world_position(global_position)
		and anomaly_kind >= Enums.AnomalyKind.CORPSE
		and anomaly_kind <= Enums.AnomalyKind.KNOCKOUT
		and severity >= MIN_SEVERITY
		and severity <= MAX_SEVERITY
		and is_finite(expires_in_seconds)
		and expires_in_seconds >= 0.0
		and expires_in_seconds <= MAX_EXPIRES_SECONDS
	)


func _new_anomaly() -> Anomaly:
	var expires_at := 0.0
	if expires_in_seconds > 0.0:
		expires_at = Time.get_ticks_msec() / 1000.0 + expires_in_seconds
	return Anomaly.create(anomaly_kind, global_position, self, severity, expires_at)


func _register_anomaly() -> void:
	if not active or not is_geometry_valid():
		return
	var anomaly := current_anomaly()
	if anomaly == null or _registered:
		return
	_registered = true
	var event_bus := get_node_or_null(NodePath("/root/EventBus"))
	if event_bus != null and event_bus.has_signal(&"anomaly_registered"):
		event_bus.emit_signal(&"anomaly_registered", anomaly)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not is_geometry_valid():
		warnings.append("AnomalyMarker requires a finite, bounded world position and anomaly payload.")
	return warnings


func _update_editor_state() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		update_configuration_warnings()
		update_gizmos()


static func _bounded_kind(value: int) -> int:
	return clampi(value, Enums.AnomalyKind.CORPSE, Enums.AnomalyKind.KNOCKOUT)


static func _bounded_expires(value: float) -> float:
	return clampf(value, 0.0, MAX_EXPIRES_SECONDS) if is_finite(value) else 0.0


static func _is_safe_world_position(value: Vector3) -> bool:
	return (
		is_finite(value.x)
		and is_finite(value.y)
		and is_finite(value.z)
		and absf(value.x) <= MAX_WORLD_COORDINATE
		and absf(value.y) <= MAX_WORLD_COORDINATE
		and absf(value.z) <= MAX_WORLD_COORDINATE
	)
