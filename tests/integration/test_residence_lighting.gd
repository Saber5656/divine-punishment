extends GutTest

func test_residence_has_baked_static_moonlight_and_only_gameplay_dynamic_shadows() -> void:
	var path := "res://src/levels/samurai_residence/residence_lighting.gd"
	assert_true(FileAccess.file_exists(path), "Production lighting integration must exist")
	if not FileAccess.file_exists(path): return
	var level = load("res://src/levels/samurai_residence/samurai_residence.tscn").instantiate()
	add_child_autofree(level)
	for frame in range(4): await get_tree().process_frame
	var gi: LightmapGI = level.find_children("*","LightmapGI",true,false)[0]
	assert_not_null(gi.light_data)
	assert_gt(gi.light_data.get_user_count(),0,"Static visuals must reference baked lightmaps")
	var moon: DirectionalLight3D = level.find_children("*","DirectionalLight3D",true,false)[0]
	assert_eq(moon.light_bake_mode,Light3D.BAKE_STATIC)
	assert_false(moon.shadow_enabled)
	for light in level.get_node("Markers/Lights").get_children():
		assert_true(light.render_light.shadow_enabled)
		assert_true(light.render_light.distance_fade_enabled, "Distant light/shadow work must fade outside the gameplay radius")
		assert_eq(light.render_light.light_bake_mode,Light3D.BAKE_DISABLED)
		assert_almost_eq(light.render_light.omni_range,light.gameplay_radius,0.001)
		light.set_extinguished(true)
		assert_false(light.render_light.visible)
		assert_eq(light.gameplay_contribution(1.0,false),0.0)
		light.set_extinguished(false)
		assert_true(light.render_light.visible)
