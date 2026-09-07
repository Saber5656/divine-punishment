extends Node


@onready var _tree: SceneTree = get_tree()


const RESIDENCE := "res://src/levels/samurai_residence/samurai_residence.tscn"
var _failures := 0
var _measurements: Array[float] = []
var _output_directory := ""


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="):
			_output_directory = argument.trim_prefix("--output-dir=")
	_detach_and_run.call_deferred()


func _run() -> void:
	_tree.create_timer(25.0).timeout.connect(func() -> void:
		printerr("RETRY_SMOKE_TIMEOUT")
		_tree.quit(2))
	var game_state := _tree.root.get_node("GameState")
	game_state.area_alert_level = 0
	_check(_tree.change_scene_to_file(RESIDENCE) == OK, "production scene loads")
	await _frames(8)
	for cycle in 2:
		var player := _tree.current_scene.get_node("Player") as PlayerController
		var flow := player.get_node("RetryFlow") as PlayerRetryFlow
		_check(game_state.checkpoint_ref.get("scene") == RESIDENCE, "mission entry baseline")
		var marker := _tree.current_scene.get_node("Markers/Checkpoints/CheckpointInsidePerimeter") as CheckpointArea
		var inventory := (player.get_node("ToolRig") as ToolRig).inventory
		player.set_physics_process(false)
		inventory.set_remaining_count(0, 2)
		inventory.select_slot(1)
		game_state.area_alert_level = 2
		player.global_position = marker.global_position + Vector3(0.1, 0.0, 0.1)
		await _frames(5)
		# After reload the player may already overlap this checkpoint. Cross its boundary again.
		if cycle > 0:
			player.global_position += Vector3(6, 0, 0)
			await _frames(4)
			player.global_position = marker.global_position + Vector3(0.1, 0, 0.1)
			await _frames(4)
		_check(game_state.checkpoint_ref.get("id") == "perimeter_reached", "physical checkpoint reached")
		var saved_position: Array = game_state.checkpoint_ref["position"]
		inventory.consume(0, 2)
		game_state.area_alert_level = 5
		player.global_position += Vector3(5, 0, 5)
		var transient := Node.new()
		transient.name = "PostCheckpointTransient"
		_tree.current_scene.add_child(transient)
		var previous_id := player.get_instance_id()
		var combat := player.get_node("AssassinationResolver/Combat") as PlayerCombat
		combat.receive_damage(20)
		_check(player.state_machine.is_dead(), "damage enters terminal Dead")
		_check(_tree.paused, "death freezes gameplay")
		await _tree.create_timer(0.8, true).timeout
		_check(flow.choices_visible(), "death fade leads to choices")
		if cycle == 0:
			await _screenshot("death-menu.png")
		flow._retry_button.emit_signal("pressed")
		_check(not flow.retry(), "second retry request rejected")
		await _frames(12)
		player = _tree.current_scene.get_node("Player") as PlayerController
		flow = player.get_node("RetryFlow") as PlayerRetryFlow
		inventory = (player.get_node("ToolRig") as ToolRig).inventory
		combat = player.get_node("AssassinationResolver/Combat") as PlayerCombat
		_check(player.get_instance_id() != previous_id, "retry recreates player")
		_check(not player.state_machine.is_dead() and combat.health() == combat.max_health(), "full health and live FSM")
		_check(not _tree.paused and not flow.visible, "gameplay and HUD resume")
		_check(_tree.current_scene.get_node_or_null("PostCheckpointTransient") == null, "transient scene state reset")
		_check(inventory.remaining_count(0) == 2 and inventory.selected_slot() == 1, "tool state restored")
		_check(game_state.area_alert_level == 2, "area alert restored")
		_check(player.global_position.distance_to(Vector3(saved_position[0], saved_position[1], saved_position[2])) < 0.3, "checkpoint position restored")
		_check(PlayerRetryFlow.last_retry_elapsed_ms > 0 and PlayerRetryFlow.last_retry_elapsed_ms < 3000, "retry under 3 seconds")
		_measurements.append(PlayerRetryFlow.last_retry_elapsed_ms)
		await _screenshot("retry-restored-%d.png" % cycle)
	var player := _tree.current_scene.get_node("Player") as PlayerController
	(player.get_node("AssassinationResolver/Combat") as PlayerCombat).receive_damage(20)
	await _tree.create_timer(0.8, true).timeout
	var flow := player.get_node("RetryFlow") as PlayerRetryFlow
	flow._choices.get_node("Abandon").emit_signal("pressed")
	await _frames(5)
	_check(_tree.current_scene.scene_file_path == PlayerRetryFlow.ABANDON_SCENE, "abandon screen reached")
	_check(game_state.checkpoint_ref.is_empty() and not _tree.paused, "abandon clears only runtime checkpoint")
	await _screenshot("abandon-menu.png")
	_tree.current_scene.get_node("Center/Choices/Restart").emit_signal("pressed")
	await _frames(8)
	_check(_tree.current_scene.scene_file_path == RESIDENCE and game_state.area_alert_level == 0, "abandon menu can start a fresh mission")
	print("RETRY_SMOKE_RESULT ", JSON.stringify({"failures": _failures, "retry_ms": _measurements, "renderer": DisplayServer.get_name(), "runtime": Engine.get_version_info()["string"]}))
	_tree.quit(0 if _failures == 0 else 1)


func _frames(count: int) -> void:
	for index in count:
		await _tree.physics_frame
		await _tree.process_frame


func _screenshot(filename: String) -> void:
	if DisplayServer.get_name() == "headless" or _output_directory.is_empty():
		return
	await RenderingServer.frame_post_draw
	var image := _tree.root.get_texture().get_image()
	if image != null:
		image.save_png(_output_directory.path_join(filename))


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		printerr("RETRY_SMOKE_FAILED ", label)


func _detach_and_run() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_parent().remove_child(self)
	_tree.root.add_child(self)
	_run()
