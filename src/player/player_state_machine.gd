class_name PlayerStateMachine
extends Node


signal state_changed(from: StringName, to: StringName)

const STATE_GROUND: StringName = &"Ground"
const STATE_CROUCH: StringName = &"Crouch"
const STATE_SPRINT: StringName = &"Sprint"
const STATE_WALL_CLING: StringName = &"WallCling"
const STATE_CLIMB: StringName = &"Climb"
const STATE_BEAM: StringName = &"Beam"
const STATE_CRAWLSPACE: StringName = &"Crawlspace"
const STATE_SWIM_SURFACE: StringName = &"SwimSurface"
const STATE_SWIM_UNDERWATER: StringName = &"SwimUnderwater"
const STATE_HIDDEN: StringName = &"Hidden"
const STATE_ASSASSINATE: StringName = &"Assassinate"
const STATE_COMBAT: StringName = &"Combat"
const STATE_DEAD: StringName = &"Dead"
const DEFAULT_PROFILE_PATH := "res://data/profiles/default.tres"

const TRANSITIONS: Dictionary = {
	STATE_GROUND: [STATE_CROUCH, STATE_SPRINT, STATE_WALL_CLING, STATE_CLIMB, STATE_CRAWLSPACE, STATE_SWIM_SURFACE, STATE_HIDDEN, STATE_ASSASSINATE, STATE_COMBAT, STATE_DEAD],
	STATE_CROUCH: [STATE_GROUND, STATE_SPRINT, STATE_WALL_CLING, STATE_CLIMB, STATE_CRAWLSPACE, STATE_SWIM_SURFACE, STATE_HIDDEN, STATE_ASSASSINATE, STATE_COMBAT, STATE_DEAD],
	STATE_SPRINT: [STATE_GROUND, STATE_CROUCH, STATE_SWIM_SURFACE, STATE_ASSASSINATE, STATE_COMBAT, STATE_DEAD],
	STATE_WALL_CLING: [STATE_GROUND, STATE_CLIMB, STATE_ASSASSINATE, STATE_COMBAT, STATE_DEAD],
	STATE_CLIMB: [STATE_GROUND, STATE_BEAM, STATE_ASSASSINATE, STATE_COMBAT, STATE_DEAD],
	STATE_BEAM: [STATE_GROUND, STATE_CLIMB, STATE_ASSASSINATE, STATE_COMBAT, STATE_DEAD],
	STATE_CRAWLSPACE: [STATE_CROUCH, STATE_ASSASSINATE, STATE_COMBAT, STATE_DEAD],
	STATE_SWIM_SURFACE: [STATE_GROUND, STATE_SWIM_UNDERWATER, STATE_COMBAT, STATE_DEAD],
	STATE_SWIM_UNDERWATER: [STATE_GROUND, STATE_SWIM_SURFACE, STATE_COMBAT, STATE_DEAD],
	STATE_HIDDEN: [STATE_CROUCH, STATE_ASSASSINATE, STATE_COMBAT, STATE_DEAD],
	STATE_ASSASSINATE: [STATE_GROUND, STATE_DEAD],
	STATE_COMBAT: [STATE_GROUND, STATE_CROUCH, STATE_SPRINT, STATE_DEAD],
	STATE_DEAD: [],
}

@export var player_profile: PlayerProfile

var _state: StringName = STATE_GROUND
var _sprint_origin: StringName = STATE_GROUND
var _tuning_profile: PlayerProfile
var _tuning_source: MovementConfig


func _ready() -> void:
	if player_profile == null:
		_ensure_tuning_profile()
		_refresh_tuning_profile()
		if not Tuning.reloaded.is_connected(_refresh_tuning_profile):
			Tuning.reloaded.connect(_refresh_tuning_profile)


func current_state() -> StringName:
	return _state


func is_hidden() -> bool:
	return _state == STATE_HIDDEN


func is_dead() -> bool:
	return _state == STATE_DEAD


func is_visibility_excluded() -> bool:
	return is_hidden()


func can_enter(next: StringName) -> bool:
	if next == _state:
		return true
	var allowed: Array = TRANSITIONS.get(_state, [])
	return allowed.has(next)


func change_state(next: StringName, _ctx: Dictionary = {}) -> bool:
	if not can_enter(next):
		return false
	if next == _state:
		return true

	var previous := _state
	if next == STATE_SPRINT and previous != STATE_SPRINT:
		_sprint_origin = previous
	_state = next
	state_changed.emit(previous, _state)
	return true


func resume_from_sprint() -> bool:
	if _state != STATE_SPRINT:
		return false
	return change_state(_sprint_origin)


func stance() -> Enums.Stance:
	match _state:
		STATE_CRAWLSPACE:
			return Enums.Stance.CRAWL
		STATE_SWIM_SURFACE, STATE_SWIM_UNDERWATER:
			return Enums.Stance.SWIM
		STATE_CROUCH, STATE_WALL_CLING, STATE_CLIMB, STATE_BEAM, STATE_HIDDEN:
			return Enums.Stance.SNEAK
		STATE_SPRINT:
			return Enums.Stance.SPRINT
		STATE_ASSASSINATE:
			return Enums.Stance.SNEAK
		_:
			return Enums.Stance.WALK


func movement_params() -> Dictionary:
	var profile := _resolved_profile()
	if profile == null:
		return {}

	var key := stance()
	return {
		&"speed": float(profile.move_speeds.get(key, 0.0)),
		&"noise_radius": float(profile.noise_radii.get(key, 0.0)),
		&"visibility_mod": (
			0.0
			if is_visibility_excluded()
			else float(profile.visibility_mods.get(key, 0.0))
		),
	}


func breath_capacity() -> float:
	var profile := _resolved_profile()
	return float(profile.breath_seconds) if profile != null else 0.0


func swim_exhaustion_noise_radius() -> float:
	var profile := _resolved_profile()
	return float(profile.noise_radii.get(Enums.Stance.SPRINT, 0.0)) if profile != null else 0.0


func swim_noise_radius() -> float:
	var profile := _resolved_profile()
	return float(profile.noise_radii.get(Enums.Stance.SWIM, 0.0)) if profile != null else 0.0


func swim_speed() -> float:
	var profile := _resolved_profile()
	return float(profile.move_speeds.get(Enums.Stance.SWIM, NAN)) if profile != null else NAN


func _resolved_profile() -> PlayerProfile:
	if player_profile != null:
		return player_profile
	_refresh_tuning_profile()
	return _tuning_profile


func _ensure_tuning_profile() -> void:
	if _tuning_profile == null:
		var default_profile := ResourceLoader.load(DEFAULT_PROFILE_PATH) as PlayerProfile
		if default_profile != null:
			_tuning_profile = default_profile.duplicate(true) as PlayerProfile


func _refresh_tuning_profile() -> void:
	if player_profile != null:
		return
	_ensure_tuning_profile()
	var current_source := Tuning.movement()
	if _tuning_profile == null or current_source == null or current_source == _tuning_source:
		return
	_tuning_profile.apply_movement_config(current_source)
	_tuning_source = current_source
