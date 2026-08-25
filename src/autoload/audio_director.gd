extends Node


var current_alert_tier: int = 0
var current_bgm_set: StringName = &"normal"
var current_ambience: StringName = &""


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
