extends Node


var current_alert_tier: int = 0
var current_bgm_set: StringName = &"normal"
var current_ambience: StringName = &""
var assassination_audio_phase: StringName = &"ambient"
var assassination_context: StringName = &""
var _assassination_previous_ambience: StringName = &"ambient"


func set_alert_tier(tier: int) -> void:
	current_alert_tier = clampi(tier, 0, 2)
	push_warning("AudioDirector.set_alert_tier is a M0 skeleton")


func play_bgm_set(set_id: StringName) -> void:
	current_bgm_set = set_id
	push_warning("AudioDirector.play_bgm_set is a M0 skeleton")


func play_stinger(id: StringName) -> void:
	push_warning("AudioDirector.play_stinger is a M0 skeleton: %s" % id)


func set_ambience(id: StringName) -> void:
	current_ambience = id
	push_warning("AudioDirector.set_ambience is a M0 skeleton")


## Presentation hooks keep the authored sequence observable even before real
## audio streams are assigned: silence -> one beat -> ambient restoration.
func begin_assassination_audio(context: StringName) -> void:
	_assassination_previous_ambience = current_ambience
	if _assassination_previous_ambience == &"" or _assassination_previous_ambience == &"silence":
		_assassination_previous_ambience = &"ambient"
	assassination_context = context
	assassination_audio_phase = &"silence"
	current_ambience = &"silence"


func play_assassination_beat(context: StringName) -> void:
	assassination_context = context
	assassination_audio_phase = &"beat"


func restore_assassination_ambient() -> void:
	assassination_audio_phase = &"ambient"
	assassination_context = &""
	current_ambience = _assassination_previous_ambience
	_assassination_previous_ambience = &"ambient"
