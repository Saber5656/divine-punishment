class_name TuningService
extends Node


signal reloaded()

const PERCEPTION_PATHS: Dictionary = {
	&"ashigaru": "res://data/tuning/perception_ashigaru.tres",
	&"archer": "res://data/tuning/perception_archer.tres",
	&"shinobi": "res://data/tuning/perception_shinobi.tres",
	&"sogen": "res://data/tuning/perception_sogen.tres",
}

const MOVEMENT_PATH := "res://data/tuning/movement.tres"
const SCORING_PATH := "res://data/tuning/scoring.tres"
const WEATHER_PATH := "res://data/tuning/weather.tres"

var _perceptions: Dictionary = {}
var _movement: MovementConfig
var _scoring: ScoringConfig
var _weather: WeatherConfig


func _ready() -> void:
	reload()


func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F5:
		reload()


func perception(kind: StringName) -> PerceptionConfig:
	var cfg := _perceptions.get(kind) as PerceptionConfig
	if cfg != null:
		return cfg
	return _perceptions.get(&"ashigaru") as PerceptionConfig


func movement() -> MovementConfig:
	return _movement


func scoring() -> ScoringConfig:
	return _scoring


func weather() -> WeatherConfig:
	return _weather


func reload() -> void:
	_perceptions.clear()
	for kind: StringName in PERCEPTION_PATHS:
		_perceptions[kind] = _load_resource(PERCEPTION_PATHS[kind]) as PerceptionConfig
	_movement = _load_resource(MOVEMENT_PATH) as MovementConfig
	_scoring = _load_resource(SCORING_PATH) as ScoringConfig
	_weather = _load_resource(WEATHER_PATH) as WeatherConfig
	reloaded.emit()


func _load_resource(path: String) -> Resource:
	var resource := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if resource == null:
		push_error("Failed to load tuning resource: %s" % path)
	return resource
