extends GutTest


const PlayerVisibilityScript := preload("res://src/stealth/player_visibility.gd")


func test_light_contribution_is_distance_attenuated_and_occlusion_halves_it() -> void:
	assert_eq(PlayerVisibilityScript.light_contribution(0.0, 10.0, false), 1.0)
	assert_eq(PlayerVisibilityScript.light_contribution(5.0, 10.0, false), 0.5)
	assert_eq(PlayerVisibilityScript.light_contribution(5.0, 10.0, true), 0.0)
	assert_eq(PlayerVisibilityScript.light_contribution(10.0, 10.0, false), 0.0)


func test_combine_clamps_visibility_after_stance_movement_and_cover_modifiers() -> void:
	assert_almost_eq(PlayerVisibilityScript.combine(1.0, 0.6, 1.3, 0.3), 0.234, 0.0001)
	assert_eq(PlayerVisibilityScript.combine(2.0, 1.0, 1.0, 1.0), 1.0)
	assert_eq(PlayerVisibilityScript.combine(1.0, 0.0, 1.0, 1.0), 0.0)


func test_light_occlusion_mask_uses_documented_layers() -> void:
	assert_eq(PlayerVisibilityScript.LIGHT_OCCLUSION_MASK, (1 << 0) | (1 << 4))
