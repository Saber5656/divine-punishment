extends GutTest

func test_art_replaces_each_required_area_without_changing_gameplay_contracts() -> void:
	var path := "res://src/levels/samurai_residence/residence_art.gd"
	assert_true(FileAccess.file_exists(path), "Residence requires production art replacement")
	if not FileAccess.file_exists(path): return
	var level = load("res://src/levels/samurai_residence/samurai_residence.tscn").instantiate()
	level.get_node("ResidenceArt").use_baked = false
	add_child_autofree(level)
	for frame in range(3): await get_tree().process_frame
	var art = level.get_node_or_null("ResidenceArt")
	assert_not_null(art)
	if art == null: return
	for area in [&"tatami", &"fusuma", &"veranda", &"garden", &"walls", &"roofs"]:
		assert_gt(art.coverage.get(area, 0), 0, "Authored visuals cover %s" % area)
	assert_eq(art.before_contract, art.capture_contract(level), "Art cannot mutate collisions, markers or navigation")
	assert_true(level.is_contract_valid())
	assert_eq(art.find_children("*", "CollisionObject3D", true, false).size(), 0)
	assert_gt(art.find_children("*", "MultiMeshInstance3D", true, false).size(), 0, "Repeated modules are instanced in batches")

func test_floor_layers_do_not_fight_and_roofs_keep_solid_undersides() -> void:
	var level = load("res://src/levels/samurai_residence/samurai_residence.tscn").instantiate()
	level.get_node("ResidenceArt").use_baked = false
	add_child_autofree(level)
	for frame in range(3): await get_tree().process_frame
	var ground = level.get_node("Geometry/OuterPerimeter/GroundSupport").find_children("*","MeshInstance3D",false,false)[0]
	var gravel = level.get_node("Geometry/Garden/GardenGravel").find_children("*","MeshInstance3D",false,false)[0]
	assert_ne(ground.global_position.y,gravel.global_position.y,"Overlapping ground surfaces need distinct render depths")
	var roof = level.get_node("Geometry/Overhead/OuterRoofPlatform").find_children("*","MeshInstance3D",false,false)[0]
	assert_true(roof.visible,"Modular seams must not turn the solid roof into a transparent ceiling")
