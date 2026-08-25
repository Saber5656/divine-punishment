extends GutTest


const PerceptionFormulasScript := preload("res://src/core/perception_formulas.gd")
const PlayerVisibilityScript := preload("res://src/stealth/player_visibility.gd")


func test_light_attenuation_is_bounded_at_radius_and_occlusion_edges() -> void:
	assert_eq(PerceptionFormulasScript.light_contribution(0.0, 10.0, false), 1.0)
	assert_eq(PerceptionFormulasScript.light_contribution(5.0, 10.0, false), 0.5)
	assert_eq(PerceptionFormulasScript.light_contribution(-1.0, 10.0, false), 1.0)
	assert_eq(PerceptionFormulasScript.light_contribution(10.0, 10.0, false), 0.0)
	assert_eq(PerceptionFormulasScript.light_contribution(11.0, 10.0, false), 0.0)
	assert_eq(PerceptionFormulasScript.light_contribution(0.0, 10.0, true), 0.0)
	assert_eq(PerceptionFormulasScript.light_contribution(1.0, 0.0, false), 0.0)
	assert_eq(PerceptionFormulasScript.light_contribution(1.0, -1.0, false), 0.0)
	assert_eq(PerceptionFormulasScript.light_contribution(NAN, 10.0, false), 0.0)

	# PlayerVisibility keeps its public API while delegating to the shared pure formula.
	assert_eq(PlayerVisibilityScript.light_contribution(5.0, 10.0, false), 0.5)


func test_visibility_modifiers_clamp_the_combined_value() -> void:
	assert_almost_eq(
		PerceptionFormulasScript.combine(1.0, 0.6, 1.3, 0.3),
		0.234,
		0.0001,
	)
	assert_eq(PerceptionFormulasScript.combine(2.0, 1.0, 1.0, 1.0), 1.0)
	assert_eq(PerceptionFormulasScript.combine(-1.0, 1.0, 1.0, 1.0), 0.0)
	assert_eq(PerceptionFormulasScript.combine(1.0, 0.0, 1.0, 1.0), 0.0)
	assert_eq(PerceptionFormulasScript.combine(NAN, 1.0, 1.0, 1.0), 0.0)
	assert_eq(PlayerVisibilityScript.combine(2.0, 1.0, 1.0, 1.0), 1.0)


func test_sound_distance_and_occlusion_attenuation_is_bounded() -> void:
	assert_eq(PerceptionFormulasScript.effective_sound_radius(6.0, 0), 6.0)
	assert_eq(PerceptionFormulasScript.effective_sound_radius(6.0, 1), 3.0)
	assert_eq(PerceptionFormulasScript.effective_sound_radius(6.0, 2), 1.5)
	assert_eq(PerceptionFormulasScript.effective_sound_radius(6.0, -1), 6.0)
	assert_eq(PerceptionFormulasScript.effective_sound_radius(-1.0, 0), 0.0)

	assert_eq(PerceptionFormulasScript.sound_contribution(0.0, 6.0, 0), 1.0)
	assert_almost_eq(PerceptionFormulasScript.sound_contribution(3.0, 6.0, 0), 0.5, 0.0001)
	assert_eq(PerceptionFormulasScript.sound_contribution(6.0, 6.0, 0), 0.0)
	assert_eq(PerceptionFormulasScript.sound_contribution(3.0, 6.0, 1), 0.0)
	assert_almost_eq(PerceptionFormulasScript.sound_contribution(1.5, 6.0, 1), 0.5, 0.0001)
	assert_eq(PerceptionFormulasScript.sound_contribution(1.0, 0.0, 0), 0.0)
	assert_eq(PerceptionFormulasScript.sound_contribution(NAN, 6.0, 0), 0.0)


func test_vision_gain_matches_distance_and_central_view_contract() -> void:
	assert_eq(PerceptionFormulasScript.vision_gain(1.0, 0.0, 10.0, true, 2.0), 2.0)
	assert_almost_eq(
		PerceptionFormulasScript.vision_gain(1.0, 0.0, 10.0, false, 2.0),
		0.8,
		0.0001,
	)
	assert_almost_eq(
		PerceptionFormulasScript.vision_gain(1.0, 5.0, 10.0, true, 2.0),
		0.5,
		0.0001,
	)
	assert_eq(PerceptionFormulasScript.vision_gain(1.0, 10.0, 10.0, true, 2.0), 0.0)
	assert_eq(PerceptionFormulasScript.vision_gain(1.0, 11.0, 10.0, true, 2.0), 0.0)
	assert_eq(PerceptionFormulasScript.vision_gain(0.0, 0.0, 10.0, true, 2.0), 0.0)
	assert_eq(PerceptionFormulasScript.vision_gain(2.0, 0.0, 10.0, true, 2.0), 2.0)
	assert_eq(PerceptionFormulasScript.vision_gain(1.0, 0.0, 0.0, true, 2.0), 0.0)
	assert_eq(PerceptionFormulasScript.vision_gain(1.0, 0.0, 10.0, true, -1.0), 0.0)
	assert_eq(PerceptionFormulasScript.vision_gain(NAN, 0.0, 10.0, true, 2.0), 0.0)


func test_detection_meter_accumulates_gain_decays_and_clamps() -> void:
	var gain := PerceptionFormulasScript.vision_gain(1.0, 0.0, 10.0, true, 2.0)
	assert_eq(PerceptionFormulasScript.meter_step(0.0, 0.25, gain, 0.5, true), 0.5)
	assert_almost_eq(
		PerceptionFormulasScript.meter_step(0.5, 0.5, gain, 0.5, false),
		0.25,
		0.0001,
	)
	assert_eq(PerceptionFormulasScript.meter_step(2.9, 1.0, gain, 0.5, true), 3.0)
	assert_eq(PerceptionFormulasScript.meter_step(0.1, 1.0, gain, 0.5, false), 0.0)
	assert_eq(PerceptionFormulasScript.meter_step(2.0, 1.0, gain, 0.5, true, 2.5), 2.5)
	assert_eq(PerceptionFormulasScript.meter_step(2.0, -1.0, gain, 0.5, true), 0.0)
	assert_eq(
		PerceptionFormulasScript.accumulate_detection_meter(0.0, 0.25, gain, 0.5, true),
		0.5,
	)
	assert_eq(PerceptionFormulasScript.accumulate_meter(0.0, gain, 0.25, true, 0.5), 0.5)
