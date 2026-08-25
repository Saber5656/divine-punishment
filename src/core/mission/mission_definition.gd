class_name MissionDefinition
extends Resource


enum KillPolicy { NORMAL = 0, CIVILIAN_HEAVY = 1, FORBIDDEN = 2 }
enum Weather { CLEAR = 0, RAIN = 1, SNOW = 2, RAIN_THEN_CLEAR = 3 }

@export var id: StringName = &""
@export var title: String = ""
@export var level_scene: PackedScene
@export var objectives: Array[ObjectiveData] = []
@export var side_objective: ObjectiveData
@export var tool_loadout: Dictionary = {}
@export var forbidden_actions: Array[StringName] = []
@export var kill_policy: KillPolicy = KillPolicy.NORMAL
@export var weather: Weather = Weather.CLEAR
@export var par_time_minutes: float = 0.0
@export var pre_cutscene: Resource
@export var post_cutscene: Resource
@export var inner_monologue_id: StringName = &""
@export var shura_rules: Dictionary = {
	&"nontarget_kill": 1,
	&"civilian_kill": 3,
	&"detection_pair": 1,
}
