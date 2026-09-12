class_name ProtectedNPC
extends CivilianNPC

@export var npc_id: StringName = &"protected"
@export_range(0.0,3600.0,1.0) var soft_deadline_seconds := 720.0
var protection_elapsed := 0.0
var threatened := false
var rescued := false

func _physics_process(delta: float) -> void:
	advance_protection(delta)

func can_see_player(_player: PlayerController) -> bool:
	return false

func advance_protection(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0 or is_defeated() or rescued or threatened or soft_deadline_seconds <= 0.0: return
	protection_elapsed += delta
	if protection_elapsed >= soft_deadline_seconds:
		threatened = true
		EventBus.mission_event.emit(&"protected_target_threatened",{"id":String(npc_id),"node":self})

func rescue() -> bool:
	if is_defeated() or rescued: return false
	rescued = true
	EventBus.mission_event.emit(&"protected_target_rescued",{"id":String(npc_id)})
	return true

func _report_death(source: Node) -> void:
	EventBus.mission_event.emit(&"protected_target_lost",{"id":String(npc_id)})
	var player := get_tree().get_first_node_in_group(&"player")
	if player != null and source != null and (source == player or player.is_ancestor_of(source)):
		super._report_death(source)
