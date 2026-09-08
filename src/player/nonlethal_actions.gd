class_name NonlethalActions
extends Node

const STRIKE_RANGE := 1.2
const RESTRAIN_RANGE := 2.0
const STRIKE_SECONDS := 60.0
const RESTRAIN_SECONDS := 2.0
var _binding: EnemyBase
var _inventory: ToolInventory
var _remaining := 0.0
var _strike_cooldown := 0.0
var _prompt: Label

func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_prompt = Label.new()
	_prompt.theme = GameUi.theme()
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt.offset_top = -130
	_prompt.offset_bottom = -95
	layer.add_child(_prompt)

func _process(delta: float) -> void:
	_strike_cooldown = maxf(0.0,_strike_cooldown-delta)
	advance_restraint(delta)
	if _prompt != null:
		_prompt.text = GameText.get_text(&"nonlethal.binding") if is_instance_valid(_binding) else GameText.with_bindings(&"nonlethal.prompt") if find_target(false) != null else ""

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"knockout") and try_knockout(find_target(false)):
		get_viewport().set_input_as_handled()

func _can_act() -> bool:
	var player := get_parent() as PlayerController
	if player == null or not player.is_inside_tree() or get_tree().paused or player.is_carrying_body(): return false
	var state: PlayerStateMachine = player.get_node("StateMachine")
	return state.current_state() in [PlayerStateMachine.STATE_GROUND, PlayerStateMachine.STATE_CROUCH]

func _near_visible(enemy: EnemyBase, distance: float) -> bool:
	var player := get_parent() as Node3D
	if not _can_act() or not is_instance_valid(enemy) or not enemy.is_inside_tree() or enemy.get_tree() != get_tree(): return false
	var delta := enemy.global_position-player.global_position
	if not delta.is_finite() or delta.length() > distance or delta.length_squared() < 0.000001: return false
	var query := PhysicsRayQueryParameters3D.create(player.global_position+Vector3.UP*0.6,enemy.global_position+Vector3.UP*0.6,17)
	return player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func can_knockout(enemy: EnemyBase) -> bool:
	if not _near_visible(enemy,STRIKE_RANGE) or enemy.brain() == null or enemy.brain().is_incapacitated() or enemy.brain().knockout_immune: return false
	var player := get_parent() as Node3D
	var from_enemy := (player.global_position-enemy.global_position).normalized()
	return (-enemy.global_basis.z).normalized().dot(from_enemy) <= -0.5 and (-player.global_basis.z).normalized().dot(-from_enemy) >= 0.5

func try_knockout(enemy: EnemyBase) -> bool:
	if _strike_cooldown > 0.0 or not MissionDirector.allows_action(&"knockout") or not can_knockout(enemy): return false
	if not enemy.set_incapacitated(&"knockout",STRIKE_SECONDS): return false
	_strike_cooldown = 0.45
	var visual := get_parent().get_node_or_null("Visual/Model") as ActorAnimation
	if visual != null: visual.play_nonlethal_strike()
	enemy.set_incapacitation_wake_by_noise(false)
	EventBus.enemy_neutralized.emit(enemy,"knockout")
	EventBus.audio_cue_requested.emit(&"combat_hit",enemy.global_position)
	return true

func find_target(stunned: bool) -> EnemyBase:
	if not _can_act(): return null
	var interactor := get_parent().get_node_or_null("Interactor") as Area3D
	if interactor == null: return null
	var examined := 0
	var nearest: EnemyBase
	var distance := INF
	for area in interactor.get_overlapping_areas():
		examined += 1
		if examined > 64: break
		var enemy := area.get_parent() as EnemyBase
		if enemy == null: continue
		var valid := _can_bind(enemy) if stunned else can_knockout(enemy)
		var candidate_distance := (get_parent() as Node3D).global_position.distance_squared_to(enemy.global_position)
		if valid and candidate_distance < distance:
			nearest = enemy
			distance = candidate_distance
	return nearest

func _can_bind(enemy: EnemyBase) -> bool:
	return _near_visible(enemy,RESTRAIN_RANGE) and enemy.brain() != null and enemy.brain().incapacitated_kind() in [&"sleep", &"knockout"]

func begin_restraint(enemy: EnemyBase, inventory: ToolInventory) -> bool:
	if is_instance_valid(_binding) or not _can_bind(enemy) or not is_instance_valid(inventory): return false
	var tool := inventory.current_definition()
	if tool == null or tool.id != &"rope" or not inventory.can_use(): return false
	_binding = enemy
	_inventory = inventory
	_remaining = RESTRAIN_SECONDS
	return true

func advance_restraint(delta: float) -> void:
	if not is_instance_valid(_binding): return
	if not is_finite(delta) or delta < 0.0: return
	if not _can_bind(_binding) or not is_instance_valid(_inventory) or _inventory.current_definition() == null or _inventory.current_definition().id != &"rope" or not _inventory.can_use():
		_binding = null
		_inventory = null
		return
	_remaining -= delta
	if _remaining > 0.0: return
	var enemy := _binding
	if enemy.set_incapacitated(&"restrained"):
		_inventory.consume()
		EventBus.enemy_neutralized.emit(enemy,"restrained")
		EventBus.audio_cue_requested.emit(&"tool_rope",enemy.global_position)
	_binding = null
	_inventory = null
