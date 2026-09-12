extends Node3D

const EXIT := Vector3(12,0.02,88)
var scream_count: int = 0
var target: TargetNpc
var _level: Node3D
var _player: PlayerController
var _initialized := false
var _restoring := false

func _ready() -> void:
	process_priority = 30
	_level = get_parent()
	_player = _level.get_node("Player")
	target = _level.get_node("Population/Kurosawa")
	var label := Label3D.new()
	label.text = GameText.with_bindings(&"m05.prompt.exit")
	label.font = preload("res://assets/fonts/NotoSerifJP.ttf")
	label.font_size = 48
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = EXIT+Vector3.UP*1.7
	add_child(label)
	EventBus.mission_event.connect(_on_mission_event)
	var retained := GameState.checkpoint_ref.duplicate(true) if PlayerRetryFlow.pending_scene == _level.scene_file_path else {}
	MissionDirector.attach_mission_scene(_level,load("res://data/missions/m05.tres") as MissionDefinition)
	if not retained.is_empty(): GameState.checkpoint_ref = retained
	_initialized = true

func _exit_tree() -> void:
	if EventBus.mission_event.is_connected(_on_mission_event): EventBus.mission_event.disconnect(_on_mission_event)

func try_escape() -> bool:
	var objective := MissionDirector.current_objective()
	if not _initialized or objective == null or objective.id != &"m05_escape" or not target.is_target_defeated(): return false
	if _player.state_machine.current_state() not in [&"Ground",&"Crouch"] or _player.global_position.distance_to(EXIT) > 3.0: return false
	if scream_count == 0: MissionDirector.complete_objective(&"m05_no_screams")
	MissionDirector.complete_objective(&"m05_escape")
	return true

func _unhandled_input(event: InputEvent) -> void:
	if _initialized and event.is_action_pressed(&"interact") and not event.is_echo() and try_escape(): get_viewport().set_input_as_handled()

func _on_mission_event(event: StringName,_payload: Dictionary) -> void:
	if not _initialized or _restoring or MissionDirector.current_objective() == null: return
	if event == &"civilian_scream":
		scream_count = mini(scream_count+1,1000000)
		MissionDirector.stats().side_objective_completed = false
