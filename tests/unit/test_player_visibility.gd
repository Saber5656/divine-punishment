extends GutTest


const PlayerVisibilityScript := preload("res://src/stealth/player_visibility.gd")
const PLAYER_SCENE_PATH := "res://src/player/player.tscn"


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


func test_visibility_uses_three_point_fraction_and_darkness_floor() -> void:
	assert_eq(PlayerVisibilityScript.DETECTION_POINT_NAMES.size(), 3)
	assert_eq(PlayerVisibilityScript.DARKNESS_FLOOR, 0.05)
	assert_eq(PlayerVisibilityScript.apply_darkness_floor(0.0), 0.05)
	assert_eq(PlayerVisibilityScript.apply_darkness_floor(0.01), 0.05)
	assert_eq(PlayerVisibilityScript.apply_darkness_floor(0.05), 0.05)
	assert_eq(PlayerVisibilityScript.apply_darkness_floor(0.06), 0.06)


func test_player_detection_points_are_spatially_distinct() -> void:
	var player := (load(PLAYER_SCENE_PATH) as PackedScene).instantiate() as Node3D
	add_child_autofree(player)
	var points := [
		(player.get_node("DetectPoints/Head") as Node3D).position,
		(player.get_node("DetectPoints/Chest") as Node3D).position,
		(player.get_node("DetectPoints/Hips") as Node3D).position,
	]
	assert_ne(points[0], points[1])
	assert_ne(points[1], points[2])
