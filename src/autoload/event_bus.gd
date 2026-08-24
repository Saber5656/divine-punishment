extends Node


signal noise_emitted(event: NoiseEvent)
signal anomaly_registered(anomaly: Anomaly)
signal anomaly_spotted(anomaly: Anomaly, by: Node)
signal alert_changed(enemy: Node, from_state: int, to_state: int)
signal area_alert_changed(level: int)
signal enemy_killed(enemy: Node, method: String)
signal enemy_neutralized(enemy: Node, method: String)
signal civilian_alarmed(civ: Node)
signal civilian_killed(civ: Node)
signal player_detected()
signal light_extinguished(light: Node)
signal light_relit(light: Node)
signal mission_event(event_name: StringName, payload: Dictionary)
signal inner_monologue_requested(text_id: StringName)

const EV_OBJECTIVE_COMPLETED := &"objective_completed"
const EV_OBJECTIVE_CHANGED := &"objective_changed"
const EV_CHECKPOINT_REACHED := &"checkpoint_reached"
const EV_TARGET_KILLED := &"target_killed"
const EV_HOSTAGE_RESCUED := &"hostage_rescued"
const EV_MISSION_FAILED := &"mission_failed"
const EV_ESCAPE_OPENED := &"escape_opened"
const EV_WEATHER_CHANGED := &"weather_changed"
const EV_FIREWORK_BURST := &"firework_burst"
const EV_BELL_RUNG := &"bell_rung"
const EV_BOSS_PHASE := &"boss_phase"
