class_name FootprintTrail
extends RefCounted

const CAPACITY := 60
var interval_m := 0.8
var lifetime_seconds := 90.0
var _slots: Array = []
var _cursor := 0
var _serial := 0
var _tracks: Dictionary = {}
var entries: Array:
	get:
		return _slots.filter(func(entry): return entry != null)

func _init() -> void:
	_slots.resize(CAPACITY)

func clear() -> void:
	_slots.fill(null)
	_tracks.clear()
	_cursor = 0

func expire(now: float) -> void:
	if not is_finite(now) or now < 0.0: return
	for index in CAPACITY:
		if _slots[index] != null and _slots[index].expires_at <= now: _slots[index] = null

func sample(source_id: int, point: Vector3, surface: StringName, now: float) -> void:
	if source_id <= 0 or not point.is_finite() or not is_finite(now) or now < 0.0: return
	if maxf(absf(point.x),maxf(absf(point.y),absf(point.z))) > 10000.0: return
	expire(now)
	if not _tracks.has(source_id):
		if _tracks.size() >= 64: return
		_tracks[source_id] = {"point":point,"distance":0.0,"eligible":surface in [&"snow", &"soil", &"gravel"]}
		return
	var track: Dictionary = _tracks[source_id]
	var previous: Vector3 = track.point
	track.point = point
	var was_eligible: bool = track.eligible
	track.eligible = surface in [&"snow", &"soil", &"gravel"]
	var distance := previous.distance_to(point)
	if not was_eligible or not track.eligible or distance > 10.0:
		track.distance = 0.0
		return
	if distance < 0.000001: return
	var step := clampf(interval_m,0.2,2.0) if is_finite(interval_m) else 0.8
	var lifetime := clampf(lifetime_seconds,1.0,300.0) if is_finite(lifetime_seconds) else 90.0
	var direction := (point-previous)/distance
	track.distance = fmod(float(track.distance),step)
	var needed: float = step-float(track.distance)
	var traveled := 0.0
	while distance-traveled+0.000001 >= needed:
		traveled += needed
		_serial += 1
		_slots[_cursor] = {"id":_serial,"source_id":source_id,"position":previous+direction*minf(traveled,distance),"direction":direction,"expires_at":now+lifetime}
		_cursor = (_cursor+1)%CAPACITY
		needed = step
		track.distance = 0.0
	track.distance += maxf(distance-traveled,0.0)
