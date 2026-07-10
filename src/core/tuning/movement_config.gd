class_name MovementConfig
extends Resource


@export var move_speeds: Dictionary = {
	&"sneak": 1.5,
	&"walk": 3.0,
	&"sprint": 6.0,
	&"crawl": 1.0,
	&"swim": 1.2,
}

@export var noise_radii: Dictionary = {
	&"sneak": 1.0,
	&"walk": 4.0,
	&"sprint": 12.0,
	&"crawl": 1.0,
	&"swim": 0.0,
}

@export var visibility_mods: Dictionary = {
	&"sneak": 0.6,
	&"walk": 1.0,
	&"sprint": 1.3,
	&"crawl": 0.3,
	&"swim": 0.2,
}

@export var stationary_visibility_mod: float = 0.8
@export var breath_seconds: float = 20.0

@export var material_noise_multipliers: Dictionary = {
	&"tatami": 0.5,
	&"wood": 1.0,
	&"creaky_wood": 2.0,
	&"gravel": 1.5,
	&"shallow_water": 1.8,
}
