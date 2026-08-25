class_name WeatherConfig
extends Resource


@export var player_noise_mult: Dictionary = {
	&"clear": 1.0,
	&"rain": 0.5,
	&"snow": 1.0,
}

@export var enemy_view_mult: Dictionary = {
	&"clear": 1.0,
	&"rain": 0.8,
	&"snow": 1.0,
}

@export var snow_footprint_interval_m: float = 0.8
@export var snow_footprint_lifetime_sec: float = 90.0
@export var rain_extinguishes_fragile_lights: bool = true
