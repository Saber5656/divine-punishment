extends GutTest


class DirectorProbe:
	extends Node
	var accepts := false
	var snapshot: Dictionary = {}
	var abandoned := false
	func retry_from_checkpoint(value: Dictionary) -> bool:
		snapshot = value.duplicate(true)
		return accepts
	func show_mission_select() -> bool:
		abandoned = true
		return true


const PLAYER := preload("res://src/player/player.tscn")
var _previous_scene: Node
var _mission: Node3D
var _player: PlayerController
var _flow: PlayerRetryFlow
var _prior_checkpoint: Dictionary
var _prior_alert: int


func before_each() -> void:
	_previous_scene = get_tree().current_scene
	_prior_checkpoint = GameState.checkpoint_ref.duplicate(true)
	_prior_alert = GameState.area_alert_level
	_mission = Node3D.new()
	_mission.scene_file_path = "res://src/levels/samurai_residence/samurai_residence.tscn"
	autofree(_mission)
	get_tree().root.add_child(_mission)
	get_tree().current_scene = _mission
	_player = PLAYER.instantiate() as PlayerController
	_mission.add_child(_player)
	_player.set_physics_process(false)
	_flow = _player.get_node("RetryFlow") as PlayerRetryFlow
	_flow.config = RetryConfig.new()
	_flow.config.death_fade_seconds = 0.0
	await get_tree().process_frame


func after_each() -> void:
	get_tree().paused = false
	get_tree().current_scene = _previous_scene
	GameState.checkpoint_ref = _prior_checkpoint
	GameState.area_alert_level = _prior_alert
	PlayerRetryFlow.pending_scene = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_entry_checkpoint_captures_and_restores_counts_position_and_alert() -> void:
	assert_eq(GameState.checkpoint_ref["id"], "mission_entry")
	_player.global_position = Vector3(2, 3, 4)
	var inventory := (_player.get_node("ToolRig") as ToolRig).inventory
	inventory.set_remaining_count(0, 1)
	inventory.select_slot(1)
	GameState.area_alert_level = 2
	assert_true(_flow.capture_checkpoint(&"first"))
	var snapshot := GameState.checkpoint_ref.duplicate(true)
	inventory.consume(0)
	inventory.select_slot(0)
	_player.global_position = Vector3.ZERO
	GameState.area_alert_level = 5
	assert_true(CheckpointSnapshot.restore(snapshot, _player, _mission.scene_file_path))
	assert_eq(_player.global_position, Vector3(2, 3, 4))
	assert_eq(inventory.remaining_count(0), 1)
	assert_eq(inventory.selected_slot(), 1)
	assert_eq(GameState.area_alert_level, 2)
	assert_eq(snapshot["tools"][0]["count"], 1)


func test_incompatible_inventory_rejected_without_partial_restore() -> void:
	var snapshot := GameState.checkpoint_ref.duplicate(true)
	snapshot["tools"][0]["id"] = "unknown"
	_player.global_position = Vector3(5, 6, 7)
	GameState.area_alert_level = 4
	assert_false(CheckpointSnapshot.restore(snapshot, _player, _mission.scene_file_path))
	assert_eq(_player.global_position, Vector3(5, 6, 7))
	assert_eq(GameState.area_alert_level, 4)


func test_checkpoint_real_overlap_ignores_non_player_and_captures_player() -> void:
	var area := CheckpointArea.new()
	area.checkpoint_id = &"physical"
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4, 4, 4)
	collision.shape = shape
	area.add_child(collision)
	_mission.add_child(area)
	var other := CharacterBody3D.new()
	_mission.add_child(other)
	area._on_body_entered(other)
	assert_ne(GameState.checkpoint_ref["id"], "physical")
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	assert_eq(GameState.checkpoint_ref["id"], "physical")


func test_death_reaches_menu_and_blocks_checkpoint_writes() -> void:
	var combat := _player.get_node("AssassinationResolver/Combat") as PlayerCombat
	combat.receive_damage(20)
	assert_true(_player.state_machine.is_dead())
	assert_true(get_tree().paused)
	assert_false(_flow.capture_checkpoint(&"after_death"))
	await get_tree().create_timer(0.05, true).timeout
	assert_true(_flow.choices_visible())
	assert_eq(GameState.checkpoint_ref["id"], "mission_entry")
	GameState.checkpoint_ref.clear()
	assert_false(_flow.retry())
	assert_false(_flow._transitioning)


func test_director_retry_failure_keeps_menu_and_snapshot() -> void:
	var director := DirectorProbe.new()
	_mission.add_child(director)
	director.add_to_group(&"scene_director")
	(_player.get_node("AssassinationResolver/Combat") as PlayerCombat).receive_damage(20)
	await get_tree().create_timer(0.05, true).timeout
	var snapshot := GameState.checkpoint_ref.duplicate(true)
	assert_false(_flow.retry())
	assert_true(_flow.choices_visible())
	assert_eq(PlayerRetryFlow.pending_scene, "")
	assert_eq(director.snapshot, snapshot)
	assert_eq(GameState.checkpoint_ref, snapshot)
	assert_true(get_tree().paused)


func test_director_abandon_preserves_persistent_campaign_and_settings() -> void:
	var director := DirectorProbe.new()
	_mission.add_child(director)
	director.add_to_group(&"scene_director")
	var campaign := SaveManager.campaign().duplicate(true)
	var settings := SaveManager.settings().duplicate(true)
	(_player.get_node("AssassinationResolver/Combat") as PlayerCombat).receive_damage(20)
	await get_tree().create_timer(0.05, true).timeout
	assert_true(_flow.abandon())
	assert_true(director.abandoned)
	assert_true(GameState.checkpoint_ref.is_empty())
	assert_false(get_tree().paused)
	assert_eq(SaveManager.campaign(), campaign)
	assert_eq(SaveManager.settings(), settings)
