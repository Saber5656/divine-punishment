class_name ArcherLookout
extends EnemyBase

signal arrow_released

const WINDUP_SECONDS := 0.6
const SHOT_COOLDOWN := 2.0
const MAX_ARROWS := 16
var _windup := -1.0
var _cooldown := 0.0
var _aim := Vector3.ZERO
var shots_fired := 0

func _ready() -> void:
	super._ready()
	brain().set_routine_enabled(false)
	combat().set_physics_process(false)

func advance_navigation(_delta: float,_target: Vector3,_speed: float = DEFAULT_ROUTINE_SPEED) -> bool:
	return false

func _physics_process(delta: float) -> void:
	advance_archery(delta)

func advance_archery(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0: return
	_cooldown = maxf(0.0,_cooldown-delta)
	if brain().is_incapacitated() or alert_state() != Enums.AlertState.COMBAT:
		_windup = -1.0
		return
	var player := get_tree().get_first_node_in_group(&"player") as PlayerController
	var perception := get_node("Perception") as EnemyPerception
	if player == null or player.state_machine.is_dead() or player.is_visibility_excluded() or not perception.can_see_position(player.global_position+Vector3.UP):
		_windup = -1.0
		return
	if _windup < 0.0:
		if _cooldown > 0.0: return
		_aim = player.global_position+Vector3.UP
		_windup = WINDUP_SECONDS
		EventBus.audio_cue_requested.emit(&"tool_dart",global_position)
		return
	_windup -= delta
	if _windup > 0.0: return
	_windup = -1.0
	_cooldown = SHOT_COOLDOWN
	if get_tree().get_nodes_in_group(&"enemy_arrows").size() >= MAX_ARROWS: return
	var arrow := ArrowShot.new()
	get_parent().add_child(arrow)
	var origin := (get_node("Perception/EyePoint") as Node3D).global_position
	if arrow.launch(origin,_aim-origin,self):
		shots_fired += 1
		arrow_released.emit()
	else: arrow.queue_free()
