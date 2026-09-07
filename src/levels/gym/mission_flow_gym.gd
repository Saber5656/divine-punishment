class_name MissionFlowGym
extends Node3D


func _ready() -> void:
	$Target.target_defeated_event.connect(_on_target_defeated)
	$Escape.body_entered.connect(_on_escape_entered)
	$ExitLabel.text = GameText.get_text(&"objective.practice_escape")
	$TargetLabel.text = GameText.get_text(&"objective.practice_target")
	$ExitLabel.font = GameUi.theme().default_font
	$TargetLabel.font = $ExitLabel.font
	$ExitLabel.hide()


func _on_target_defeated(_method: StringName) -> void:
	$TargetLabel.hide()
	$ExitLabel.show()
	$Target/Visual/Model.rotation.z = PI * 0.5
	for body in $Escape.get_overlapping_bodies():
		_on_escape_entered(body)


func _on_escape_entered(body: Node3D) -> void:
	if not body is PlayerController or not ($Target as TargetNpc).is_target_defeated():
		return
	var objective := MissionDirector.current_objective()
	if objective != null and objective.id == &"practice_escape":
		MissionDirector.complete_objective(&"practice_escape")
