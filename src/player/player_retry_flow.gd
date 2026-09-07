class_name PlayerRetryFlow
extends CanvasLayer


signal choices_shown()
signal retry_finished(elapsed_ms: float)

const DEFAULT_CONFIG: RetryConfig = preload("res://data/tuning/retry.tres")
const ABANDON_SCENE := "res://src/ui/mission_abandoned.tscn"

static var pending_scene := ""
static var abandoned_scene := ""
static var retry_started_usec := 0
static var last_retry_elapsed_ms := 0.0

@export var config: RetryConfig = DEFAULT_CONFIG

var _player: PlayerController
var _scene_path := ""
var _active := false
var _transitioning := false
var _owns_pause := false
var _mouse_mode: Input.MouseMode
var _veil: ColorRect
var _message: Label
var _choices: VBoxContainer
var _retry_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_player = get_parent() as PlayerController
	_build_ui()
	if _player != null:
		(_player.get_node("StateMachine") as PlayerStateMachine).state_changed.connect(_on_state_changed)
	_initialize.call_deferred()


func _initialize() -> void:
	var scene := _mission_root()
	if _player == null or scene == null:
		return
	_scene_path = scene.scene_file_path
	if _scene_path.is_empty():
		return
	if pending_scene == _scene_path:
		pending_scene = ""
		if not CheckpointSnapshot.restore(GameState.checkpoint_ref, _player, _scene_path):
			_show_restore_error()
			return
		var world_owner: Node = scene if scene.has_method(&"restore_checkpoint_world") else scene.get_node_or_null("Mission")
		if world_owner != null and world_owner.has_method(&"restore_checkpoint_world"):
			if world_owner.call(&"restore_checkpoint_world", GameState.checkpoint_ref.duplicate(true)) != true:
				_show_restore_error()
				return
		_finish_retry()
	else:
		# A freshly entered mission always starts a fresh in-memory baseline.
		capture_checkpoint(&"mission_entry")


func capture_checkpoint(checkpoint_id: StringName) -> bool:
	if _player == null or _scene_path.is_empty() or _active or _player.state_machine.is_dead():
		return false
	var snapshot := CheckpointSnapshot.capture(_player, _scene_path, checkpoint_id)
	if not CheckpointSnapshot.is_valid(snapshot, _scene_path):
		return false
	GameState.checkpoint_ref = snapshot.duplicate(true)
	EventBus.mission_event.emit(EventBus.EV_CHECKPOINT_REACHED, {"id": checkpoint_id})
	return true


func choices_visible() -> bool:
	return _active and _choices.visible and not _transitioning


func retry() -> bool:
	return request_retry() if choices_visible() else false


## The pause menu may request retry before death.
func request_retry() -> bool:
	var requested_usec := Time.get_ticks_usec()
	if _transitioning or not CheckpointSnapshot.is_valid(GameState.checkpoint_ref, _scene_path):
		return false
	if not CheckpointSnapshot.matches_inventory(GameState.checkpoint_ref, (_player.get_node("ToolRig") as ToolRig).inventory):
		return false
	var scene := ResourceLoader.load(_scene_path) as PackedScene
	if scene == null:
		_message.text = GameText.get_text(&"death.load_error")
		return false
	_transitioning = true
	_retry_button.disabled = true
	pending_scene = _scene_path
	retry_started_usec = requested_usec
	var director := get_tree().get_first_node_in_group(&"scene_director")
	var accepted := false
	if director != null and director.has_method(&"retry_from_checkpoint"):
		accepted = director.call(&"retry_from_checkpoint", GameState.checkpoint_ref.duplicate(true)) == true
	else:
		accepted = get_tree().change_scene_to_packed(scene) == OK
	if not accepted:
		pending_scene = ""
		_transitioning = false
		_retry_button.disabled = false
		_message.text = GameText.get_text(&"error.retry")
		return false
	return true


func abandon() -> bool:
	if not choices_visible():
		return false
	var director := get_tree().get_first_node_in_group(&"scene_director")
	var accepted := false
	if director != null and director.has_method(&"show_mission_select"):
		var result: Variant = director.call(&"show_mission_select")
		accepted = result == null or result == true
	else:
		accepted = get_tree().change_scene_to_file(ABANDON_SCENE) == OK
	if not accepted:
		_message.text = GameText.get_text(&"error.exit")
		return false
	_transitioning = true
	abandoned_scene = _scene_path
	pending_scene = ""
	GameState.checkpoint_ref.clear()
	_release_pause()
	return true


func _on_state_changed(_from: StringName, to: StringName) -> void:
	if to != PlayerStateMachine.STATE_DEAD or _active or _scene_path.is_empty():
		return
	_active = true
	_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_owns_pause = not get_tree().paused
	get_tree().paused = true
	visible = true
	_message.text = GameText.get_text(&"death.title")
	_veil.modulate.a = 0.0
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_veil, "modulate:a", 1.0, clampf(config.death_fade_seconds, 0.0, 3.0))
	tween.tween_callback(_show_choices)


func _show_choices() -> void:
	_choices.show()
	_retry_button.disabled = not CheckpointSnapshot.is_valid(GameState.checkpoint_ref, _scene_path)
	_retry_button.grab_focus()
	choices_shown.emit()


func _show_restore_error() -> void:
	_active = true
	_owns_pause = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = true
	_message.text = GameText.get_text(&"error.restore")
	_choices.show()
	_retry_button.disabled = true
	(_choices.get_node("Abandon") as Button).grab_focus()


func _finish_retry() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await get_tree().physics_frame
	await get_tree().process_frame
	last_retry_elapsed_ms = float(Time.get_ticks_usec() - retry_started_usec) / 1000.0
	retry_finished.emit(last_retry_elapsed_ms)


func _exit_tree() -> void:
	if not _transitioning:
		_release_pause()


func _release_pause() -> void:
	if _owns_pause:
		get_tree().paused = false
		_owns_pause = false
		Input.mouse_mode = _mouse_mode


func _build_ui() -> void:
	_veil = ColorRect.new()
	_veil.theme = GameUi.theme()
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.color = Color(0.12, 0.015, 0.02, clampf(config.death_veil_opacity, 0.0, 0.9))
	add_child(_veil)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.add_child(center)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 24)
	center.add_child(content)
	_message = Label.new()
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", 42)
	content.add_child(_message)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 16)
	content.add_child(_choices)
	_retry_button = Button.new()
	_retry_button.name = "Retry"
	_retry_button.text = GameText.get_text(&"nav.retry")
	_retry_button.custom_minimum_size = Vector2(340, 56)
	_retry_button.pressed.connect(retry)
	_choices.add_child(_retry_button)
	var abandon_button := Button.new()
	abandon_button.name = "Abandon"
	abandon_button.text = GameText.get_text(&"nav.abandon")
	abandon_button.custom_minimum_size = Vector2(340, 56)
	abandon_button.pressed.connect(abandon)
	_choices.add_child(abandon_button)
	_choices.hide()
	visible = false


func _mission_root() -> Node:
	if _player == null:
		return null
	var node := _player.get_parent()
	while node != null and node != get_tree().root:
		if not node.scene_file_path.is_empty():
			return node
		node = node.get_parent()
	return null
