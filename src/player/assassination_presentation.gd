class_name AssassinationPresentation
extends Node


## The presentation is deliberately an orchestration layer, not an animation
## asset dependency.  Content can attach real animation/camera/audio assets to
## these hooks later; the deterministic timing and fail-safe completion remain
## valid when those assets are absent.
const MIN_DURATION_SEC := 1.0
const MAX_DURATION_SEC := 2.0
const DEFAULT_DURATION_SEC := 1.25
const MAX_ADVANCE_STEP_SEC := 0.25
const AUDIO_BEAT_RATIO := 0.35

const CONTEXT_BACK: StringName = &"back"
const CONTEXT_ABOVE: StringName = &"above"
const CONTEXT_BELOW: StringName = &"below"
const CONTEXT_CORNER: StringName = &"corner"
const CONTEXTS: Array[StringName] = [
	CONTEXT_BACK,
	CONTEXT_ABOVE,
	CONTEXT_BELOW,
	CONTEXT_CORNER,
]

signal started(enemy: EnemyBase, context: StringName)
signal animation_requested(context: StringName, clip: StringName)
signal camera_blend_requested(context: StringName)
signal se_requested(context: StringName, cue: StringName)
signal audio_phase_changed(context: StringName, phase: StringName)
signal completed(enemy: EnemyBase, context: StringName)

@export_range(MIN_DURATION_SEC, MAX_DURATION_SEC, 0.05)
var duration_sec: float = DEFAULT_DURATION_SEC
@export var animation_player_path: NodePath

var _active := false
var _elapsed_sec := 0.0
var _duration_sec := DEFAULT_DURATION_SEC
var _enemy: EnemyBase
var _context: StringName = &""
var _audio_phase: StringName = &""


func _ready() -> void:
	set_process(true)


func begin(enemy: EnemyBase, context: StringName) -> bool:
	if _active or enemy == null or not is_instance_valid(enemy) or not CONTEXTS.has(context):
		return false
	_active = true
	_elapsed_sec = 0.0
	_duration_sec = clampf(duration_sec, MIN_DURATION_SEC, MAX_DURATION_SEC)
	if not is_finite(_duration_sec):
		_duration_sec = DEFAULT_DURATION_SEC
	_enemy = enemy
	_context = context
	_audio_phase = &""
	_invoke_animation_hook()
	_invoke_camera_hook()
	_set_audio_phase(&"silence")
	started.emit(enemy, context)
	return true


## Advance the presentation deterministically.  Production calls this from
## _process; tests and alternate presentation drivers can use it directly.
## Large frame deltas are bounded so a stalled frame cannot skip the hook
## sequence or keep the player locked indefinitely.
func advance(delta_sec: float) -> bool:
	if not _active:
		return false
	if not is_finite(delta_sec) or delta_sec < 0.0:
		return false
	var step := minf(delta_sec, MAX_ADVANCE_STEP_SEC)
	_elapsed_sec = minf(_elapsed_sec + step, _duration_sec)
	_update_camera_progress()
	if _audio_phase == &"silence" and _elapsed_sec >= _duration_sec * AUDIO_BEAT_RATIO:
		_set_audio_phase(&"beat")
	if _active and _elapsed_sec >= _duration_sec:
		_finish()
	return true


func complete() -> bool:
	if not _active:
		return false
	_finish()
	return true


## Cancel is used by an explicit player-side release.  It restores camera and
## audio state without emitting `completed`, avoiding a release callback loop.
func cancel() -> bool:
	if not _active:
		return false
	_reset_hooks()
	_clear_state()
	return true


func is_active() -> bool:
	return _active


func elapsed_sec() -> float:
	return _elapsed_sec


func remaining_sec() -> float:
	return maxf(_duration_sec - _elapsed_sec, 0.0) if _active else 0.0


func progress() -> float:
	if not _active or _duration_sec <= 0.0:
		return 0.0
	return clampf(_elapsed_sec / _duration_sec, 0.0, 1.0)


func active_enemy() -> EnemyBase:
	return _enemy


func context() -> StringName:
	return _context


func audio_phase() -> StringName:
	return _audio_phase


func animation_clip_for(context: StringName) -> StringName:
	match context:
		CONTEXT_BACK:
			return &"assassination_back"
		CONTEXT_ABOVE:
			return &"assassination_above"
		CONTEXT_BELOW:
			return &"assassination_below"
		CONTEXT_CORNER:
			return &"assassination_corner"
	return &""


func se_cue_for(context: StringName) -> StringName:
	match context:
		CONTEXT_BACK:
			return &"assassination_se_back"
		CONTEXT_ABOVE:
			return &"assassination_se_above"
		CONTEXT_BELOW:
			return &"assassination_se_below"
		CONTEXT_CORNER:
			return &"assassination_se_corner"
	return &""


func _process(delta: float) -> void:
	advance(delta)


func _invoke_animation_hook() -> void:
	var clip := animation_clip_for(_context)
	if clip == &"":
		return
	animation_requested.emit(_context, clip)
	if animation_player_path == NodePath():
		return
	var animation_player := get_node_or_null(animation_player_path)
	if animation_player != null and animation_player.has_method(&"play"):
		animation_player.call(&"play", clip)


func _invoke_camera_hook() -> void:
	camera_blend_requested.emit(_context)
	var player_node := _player_node()
	if player_node == null:
		return
	var camera_rig := player_node.get_node_or_null(NodePath("CameraRig"))
	if camera_rig != null and camera_rig.has_method(&"begin_assassination_blend"):
		camera_rig.call(&"begin_assassination_blend", _context, _duration_sec)


func _update_camera_progress() -> void:
	var player_node := _player_node()
	if player_node == null:
		return
	var camera_rig := player_node.get_node_or_null(NodePath("CameraRig"))
	if camera_rig != null and camera_rig.has_method(&"set_assassination_progress"):
		camera_rig.call(&"set_assassination_progress", progress())


func _set_audio_phase(phase: StringName) -> void:
	if _audio_phase == phase:
		return
	_audio_phase = phase
	audio_phase_changed.emit(_context, phase)
	if phase == &"beat":
		se_requested.emit(_context, se_cue_for(_context))
	var audio_director := get_node_or_null(NodePath("/root/AudioDirector"))
	if audio_director == null:
		return
	match phase:
		&"silence":
			if audio_director.has_method(&"begin_assassination_audio"):
				audio_director.call(&"begin_assassination_audio", _context)
		&"beat":
			if audio_director.has_method(&"play_assassination_beat"):
				audio_director.call(&"play_assassination_beat", _context)
		&"ambient":
			if audio_director.has_method(&"restore_assassination_ambient"):
				audio_director.call(&"restore_assassination_ambient")


func _finish() -> void:
	if not _active:
		return
	var finished_enemy := _enemy
	var finished_context := _context
	_update_camera_progress()
	_reset_hooks()
	_set_audio_phase(&"ambient")
	_clear_state()
	completed.emit(finished_enemy, finished_context)


func _reset_hooks() -> void:
	var player_node := _player_node()
	if player_node != null:
		var camera_rig := player_node.get_node_or_null(NodePath("CameraRig"))
		if camera_rig != null and camera_rig.has_method(&"end_assassination_blend"):
			camera_rig.call(&"end_assassination_blend")
	var audio_director := get_node_or_null(NodePath("/root/AudioDirector"))
	if audio_director != null and audio_director.has_method(&"restore_assassination_ambient"):
		audio_director.call(&"restore_assassination_ambient")
	_audio_phase = &""


func _player_node() -> Node:
	var candidate := get_parent()
	for _depth in 4:
		if candidate == null:
			return null
		if candidate.get_node_or_null(NodePath("CameraRig")) != null:
			return candidate
		candidate = candidate.get_parent()
	return null


func _clear_state() -> void:
	_active = false
	_elapsed_sec = 0.0
	_enemy = null
	_context = &""
