extends GutTest

func after_each() -> void:
	MissionDirector.start_mission(null)
	GameState.checkpoint_ref.clear()
	GameState.area_alert_level = 0

func _scene() -> Node3D:
	var level: Node3D = load("res://src/levels/rainy_temple/temple_mission.tscn").instantiate()
	add_child_autofree(level)
	for frame in range(6): await get_tree().physics_frame
	return level

func test_art_covers_the_temple_and_preserves_physical_gameplay_contract() -> void:
	var level := await _scene()
	var art := level.get_node_or_null("TempleArt")
	assert_not_null(art,"M4 needs its original temple visual pass")
	if art == null: return
	assert_eq(art.capture_contract(level),art.before_contract,"Collision, navigation, markers and gameplay lights must stay unchanged")
	for zone in [&"steps",&"gate",&"hall",&"bell",&"lodging",&"graves",&"cell",&"mill",&"court",&"roofs",&"lamps",&"retainers",&"monks",&"target"]:
		assert_gt(int(art.coverage.get(zone,0)),0,"Visible art coverage: "+String(zone))
	assert_eq(level.get_node("Population/Monks").get_child_count(),8)
	assert_eq(level.get_node("TempleEnvironment/Lights").get_child_count(),8)

func test_lanterns_have_independent_glow_and_do_not_shadow_their_own_light() -> void:
	var level := await _scene()
	if level.get_node_or_null("TempleArt") == null:
		fail_test("Temple lantern art is missing")
		return
	var lamps := level.get_node("TempleEnvironment/Lights")
	var first := lamps.get_node("HallWestLamp") as LightSource
	var second := lamps.get_node("HallEastLamp") as LightSource
	var papers: Array[BaseMaterial3D] = []
	for light in [first,second]:
		var shade := light.get_node_or_null("ArtLantern") as MeshInstance3D
		assert_not_null(shade)
		if shade == null: return
		assert_eq(shade.cast_shadow,GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		for index in shade.mesh.get_surface_count():
			var mat := shade.get_active_material(index) as BaseMaterial3D
			if mat.resource_name == "Warm lantern paper": papers.append(mat)
	assert_eq(papers.size(),2)
	if papers.size() != 2: return
	assert_ne(papers[0],papers[1],"Changing one light cannot mutate another source")
	assert_true(papers[0].emission_enabled)
	first.set_extinguished(true)
	assert_false(papers[0].emission_enabled)
	assert_true(papers[1].emission_enabled)
	first.set_extinguished(false)
	assert_true(papers[0].emission_enabled)

func test_retainer_art_preserves_death_and_checkpoint_restoration() -> void:
	var level := await _scene()
	var npc := level.get_node("Mission/Retainers/RetainerA") as CivilianNPC
	var body := npc.get_node("Body") as MeshInstance3D
	assert_false(body.mesh is CapsuleMesh,"Captives need the clothed temple model")
	npc.receive_combat_damage(1)
	assert_almost_eq(body.rotation.z,PI/2,0.001)
	assert_almost_eq(body.position.y,0.25,0.001)
	assert_true(npc.restore_checkpoint_health(1))
	assert_almost_eq(body.rotation.z,0.0,0.001)
	assert_almost_eq(body.position.y,0.825,0.001)

func test_rain_shader_uses_actual_roof_pieces_and_preserves_the_open_beam_hole() -> void:
	var level := await _scene()
	var art := level.get_node("TempleArt")
	assert_true(art.has_method("apply_rain_cover"),"Rain must stop under solid roofs without sealing the real hole")
	if not art.has_method("apply_rain_cover"): return
	var weather := WeatherPresentation.new()
	level.add_child(weather)
	art.apply_rain_cover(weather)
	var material := weather._particles.draw_pass_1.material as ShaderMaterial
	assert_not_null(material)
	if material == null: return
	var count := int(material.get_shader_parameter("roof_count"))
	var rectangles: Array = material.get_shader_parameter("roof_rects")
	var heights: Array = material.get_shader_parameter("roof_heights")
	assert_eq(count,9,"Only the nine physical roof pieces mask precipitation")
	for spec in [[Vector3(51,8,22),false],[Vector3(51,8,25),true],[Vector3(82,5,35),true],[Vector3(48,4,50),false],[Vector3(51,12,25),false]]:
		var point: Vector3 = spec[0]
		var covered := false
		for index in count:
			var rect: Vector4 = rectangles[index]
			covered = covered or (point.x >= rect.x and point.z >= rect.y and point.x <= rect.z and point.z <= rect.w and point.y < heights[index])
		assert_eq(covered,spec[1],"Rain/roof contract at "+str(point))
	assert_eq(weather._particles.amount,600,"Keep the existing outdoor rainfall")
