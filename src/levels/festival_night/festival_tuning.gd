class_name FestivalTuning
extends Resource

@export var dais_seconds: float = 180.0
@export var shrine_seconds: float = 120.0
@export var stalls_seconds: float = 60.0
@export var prayer_seconds: float = 30.0
@export var arrival_tolerance: float = 0.5
@export var crowd_speed: float = 0.4
@export var patrol_dwell_seconds: float = 4.0

func durations() -> Vector3:
	return Vector3(dais_seconds, shrine_seconds, stalls_seconds)

func cycle_seconds() -> float:
	return dais_seconds+shrine_seconds+stalls_seconds
