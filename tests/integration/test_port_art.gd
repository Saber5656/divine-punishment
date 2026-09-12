extends GutTest

func after_each() -> void:
	MissionDirector.start_mission(null)
	GameState.checkpoint_ref.clear()
	GameState.area_alert_level = 0

func test_port_art_replaces_each_area_without_changing_physics_or_light_rules() -> void:
	var level: PortStorehouse = load("res://src/levels/port_storehouse/port_mission.tscn").instantiate()
	add_child_autofree(level)
	for frame in range(5): await get_tree().physics_frame
	var art := level.get_node_or_null("PortArt")
	assert_not_null(art,"The complete port needs a visual art pass")
	if art == null: return
	assert_eq(art.capture_contract(level),art.before_contract,"Art preserves authored collision/navigation/marker/light parameters")
	for zone in [&"pier",&"storehouses",&"roofs",&"house",&"ship",&"cargo",&"lamps"]:
		assert_gt(int(art.coverage.get(zone,0)),0,"Visible replacement for "+String(zone))
	assert_eq(level.get_node("Population/Civilians").get_child_count(),6)
	assert_eq(level.get_node("PortEnvironment/Lights").get_child_count(),8)

func test_repeated_cargo_names_and_lanterns_keep_readable_visuals() -> void:
	var level: PortStorehouse = load("res://src/levels/port_storehouse/port_mission.tscn").instantiate()
	add_child_autofree(level)
	for frame in range(5): await get_tree().physics_frame
	var art := level.get_node("PortArt")
	assert_eq(int(art.coverage.get(&"cargo",0)),48,"All six solid cargo stacks must receive eight fitted crates")
	var light := level.get_node("PortEnvironment/Lights/PierWestLamp") as LightSource
	var shade := light.get_node_or_null("ArtLantern") as MeshInstance3D
	assert_not_null(shade,"The paper lantern must follow its real light's state")
	if shade == null: return
	assert_eq(shade.cast_shadow,GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"A closed shade must not block its own light")
	var paper: BaseMaterial3D
	for index in shade.mesh.get_surface_count():
		var mat := shade.get_active_material(index) as BaseMaterial3D
		if mat.resource_name == "Rice paper": paper = mat
	assert_not_null(paper)
	if paper == null: return
	assert_true(paper.emission_enabled)
	light.set_extinguished(true)
	assert_false(paper.emission_enabled,"Extinguished lamps must stop glowing")
	light.set_extinguished(false)
	assert_true(paper.emission_enabled,"Checkpoint relight restores the visible glow")

func test_dressed_civilian_keeps_existing_death_and_checkpoint_pose() -> void:
	var level: PortStorehouse = load("res://src/levels/port_storehouse/port_mission.tscn").instantiate()
	add_child_autofree(level)
	for frame in range(5): await get_tree().physics_frame
	var civilian := level.get_node("Population/Civilians").get_child(0) as CivilianNPC
	var body := civilian.get_node("Body") as MeshInstance3D
	assert_false(body.mesh is CapsuleMesh,"The visible worker must wear the port model")
	civilian.receive_combat_damage(1)
	assert_almost_eq(body.rotation.z,PI/2,0.001)
	assert_almost_eq(body.position.y,0.25,0.001)
	assert_true(civilian.restore_checkpoint_health(1))
	assert_almost_eq(body.rotation.z,0.0,0.001)
	assert_almost_eq(body.position.y,0.825,0.001)
