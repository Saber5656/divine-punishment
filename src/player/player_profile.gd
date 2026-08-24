class_name PlayerProfile
extends Resource


const TUNING_KEYS_BY_STANCE: Dictionary = {
	Enums.Stance.SNEAK: &"sneak",
	Enums.Stance.WALK: &"walk",
	Enums.Stance.SPRINT: &"sprint",
	Enums.Stance.CRAWL: &"crawl",
	Enums.Stance.SWIM: &"swim",
}

@export var move_speeds: Dictionary = {
	Enums.Stance.SNEAK: 1.5,
	Enums.Stance.WALK: 3.0,
	Enums.Stance.SPRINT: 6.0,
	Enums.Stance.CRAWL: 1.0,
	Enums.Stance.SWIM: 1.2,
}
@export var noise_radii: Dictionary = {
	Enums.Stance.SNEAK: 1.0,
	Enums.Stance.WALK: 4.0,
	Enums.Stance.SPRINT: 12.0,
	Enums.Stance.CRAWL: 1.0,
	Enums.Stance.SWIM: 0.0,
}
@export var visibility_mods: Dictionary = {
	Enums.Stance.SNEAK: 0.6,
	Enums.Stance.WALK: 1.0,
	Enums.Stance.SPRINT: 1.3,
	Enums.Stance.CRAWL: 0.3,
	Enums.Stance.SWIM: 0.2,
}
@export var stationary_visibility_mod: float = 0.8
@export var breath_seconds: float = 20.0
@export var max_health: int = 3
@export var tool_slots: int = 3
@export var allowed_actions: Array[StringName] = [
	&"move_forward",
	&"move_backward",
	&"move_left",
	&"move_right",
	&"camera_up",
	&"camera_down",
	&"camera_left",
	&"camera_right",
	&"stance_toggle",
	&"sprint",
	&"interact",
	&"assassinate",
	&"tool_use",
	&"tool_cycle",
	&"aim",
	&"peek",
	&"attack",
	&"parry",
	&"dodge",
	&"pause",
	&"sword",
	&"assassinate_lethal",
	&"dart",
]


func apply_movement_config(config: MovementConfig) -> void:
	if config == null:
		return
	move_speeds = _profile_values(config.move_speeds)
	noise_radii = _profile_values(config.noise_radii)
	visibility_mods = _profile_values(config.visibility_mods)
	stationary_visibility_mod = config.stationary_visibility_mod
	breath_seconds = config.breath_seconds


func _profile_values(tuning_values: Dictionary) -> Dictionary:
	var profile_values: Dictionary = {}
	for stance: int in TUNING_KEYS_BY_STANCE:
		var tuning_key: StringName = TUNING_KEYS_BY_STANCE[stance]
		profile_values[stance] = float(tuning_values.get(tuning_key, 0.0))
	return profile_values
