extends Node

var current: StringName = &"clear"
var elapsed := 0.0
var _rain_remaining := -1.0
var trail := FootprintTrail.new()

func _ready() -> void:
	EventBus.mission_event.connect(_on_mission_event)

func _process(delta: float) -> void:
	advance(delta)

func start(mode: MissionDefinition.Weather) -> void:
	elapsed = 0.0
	trail.clear()
	trail.interval_m = Tuning.weather().snow_footprint_interval_m
	trail.lifetime_seconds = Tuning.weather().snow_footprint_lifetime_sec
	_rain_remaining = 900.0 if mode == MissionDefinition.Weather.RAIN_THEN_CLEAR else -1.0
	set_weather(&"rain" if mode in [MissionDefinition.Weather.RAIN,MissionDefinition.Weather.RAIN_THEN_CLEAR] else &"snow" if mode == MissionDefinition.Weather.SNOW else &"clear")

func advance(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0: return
	elapsed += delta
	trail.expire(elapsed)
	if _rain_remaining >= 0.0:
		_rain_remaining -= delta
		if _rain_remaining <= 0.0:
			_rain_remaining = -1.0
			set_weather(&"clear")

func set_weather(next: StringName, notify: bool = true) -> void:
	if next not in [&"clear",&"rain",&"snow"]: return
	var previous := current
	current = next
	if next != &"rain": _rain_remaining = -1.0
	if previous != current and notify:
		EventBus.mission_event.emit(EventBus.EV_WEATHER_CHANGED,{"weather":String(current),"previous":String(previous)})

func _on_mission_event(event: StringName, payload: Dictionary) -> void:
	if event == EventBus.EV_WEATHER_CHANGED:
		set_weather(StringName(payload.get("weather",current)),false)

func noise_multiplier() -> float:
	return _multiplier(Tuning.weather().player_noise_mult)

func view_multiplier() -> float:
	return _multiplier(Tuning.weather().enemy_view_mult)

func _multiplier(values: Dictionary) -> float:
	var value := float(values.get(current,1.0))
	return clampf(value,0.1,2.0) if is_finite(value) else 1.0

func extinguishes_fragile() -> bool:
	return current == &"rain" and Tuning.weather().rain_extinguishes_fragile_lights
