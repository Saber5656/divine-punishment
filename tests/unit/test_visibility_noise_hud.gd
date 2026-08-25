extends GutTest


const PLAYER_SCENE_PATH := "res://src/player/player.tscn"


func test_hud_ring_follows_visibility_and_keeps_three_empty_tool_frames() -> void:
	var player := (load(PLAYER_SCENE_PATH) as PackedScene).instantiate() as PlayerController
	add_child_autofree(player)
	await get_tree().process_frame
	var hud := player.swim_hud

	hud.set_visibility(0.75)
	assert_almost_eq(hud.visibility(), 0.75, 0.0001)
	assert_true(hud.is_visibility_ring_open())
	assert_lte(hud.displayed_visibility(), 0.75)
	assert_eq(hud.tool_slot_count(), 3)
	assert_eq((hud.get_node("ToolSlots") as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE)
	for slot_index in hud.tool_slot_count():
		assert_eq(hud.tool_slot_frame(slot_index).mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_not_null(hud.tool_slot_frame(0))
	assert_not_null(hud.tool_slot_frame(1))
	assert_not_null(hud.tool_slot_frame(2))
	assert_null(hud.tool_slot_frame(3))

	hud.set_visibility(1.5)
	assert_almost_eq(hud.visibility(), 1.0, 0.0001)
	hud.set_visibility(NAN)
	assert_almost_eq(hud.visibility(), 0.0, 0.0001)
	assert_false(hud.is_visibility_ring_open())


func test_hud_ripple_only_reacts_to_noise_from_local_player() -> void:
	var player := (load(PLAYER_SCENE_PATH) as PackedScene).instantiate() as PlayerController
	add_child_autofree(player)
	await get_tree().process_frame
	var hud := player.swim_hud
	var other_source := Node3D.new()
	add_child_autofree(other_source)
	var before := hud.noise_ripple_count()

	NoiseEventSystem.emit(
		NoiseEvent.create(player.global_position, 4.0, Enums.NoiseKind.FOOTSTEP, player.noise_emitter),
		get_tree(),
	)
	assert_eq(hud.noise_ripple_count(), before + 1)
	assert_true(hud.is_noise_ripple_visible())

	NoiseEventSystem.emit(
		NoiseEvent.create(other_source.global_position, 4.0, Enums.NoiseKind.TOOL, other_source),
		get_tree(),
	)
	assert_eq(hud.noise_ripple_count(), before + 1)

	await get_tree().create_timer(NoiseRippleCue.PULSE_DURATION + 0.05).timeout
	assert_false(hud.is_noise_ripple_visible())
