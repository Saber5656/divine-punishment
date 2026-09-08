extends GutTest

class Store extends Node:
	var last_error: Error = OK
	var data := {"mission_results":{},"seen_cutscenes":[],"shura":3}
	func campaign() -> Dictionary: return data
	func record_mission_result(id: StringName, result: RefCounted, _first: bool) -> void:
		data.mission_results[String(id)] = {"rank":result.rank,"score":result.score}
	func commit() -> void: pass

func test_eight_resources_branch_at_threshold_boundaries() -> void:
	for i in range(1,9):
		var path := "res://data/narrative/hideout/h%d.tres" % i
		assert_true(FileAccess.file_exists(path), "Hideout resources must exist")
		if not FileAccess.file_exists(path): return
		var scene = load(path)
		assert_true(scene.to_cutscene(0).is_valid())
		assert_true(scene.to_cutscene(100).is_valid())
		if scene.shura_threshold >= 0:
			assert_eq(scene.variant(scene.shura_threshold), &"calm")
			assert_eq(scene.variant(scene.shura_threshold+1), &"blood")
		else:
			assert_eq(scene.variant(100), &"calm")

func test_first_residence_result_continues_to_hideout_then_selection() -> void:
	var main = load("res://src/ui/main.tscn").instantiate()
	var director = main.get_node("SceneDirector")
	var store := Store.new()
	add_child_autofree(store)
	director.save_manager = store
	add_child_autofree(main)
	assert_true(director.has_method(&"continue_from_result"))
	if not director.has_method(&"continue_from_result"): return
	director.start_mission(SceneDirector.RESIDENCE)
	for frame in range(4): await get_tree().process_frame
	MissionDirector.complete_objective(&"m02_target")
	MissionDirector.complete_objective(&"m02_escape")
	for frame in range(2): await get_tree().process_frame
	assert_eq(director.screen, &"results")
	assert_true(director.continue_from_result())
	assert_eq(director.screen, &"hideout")
	var player = director.get_node("HideoutPlayer")
	assert_true(player.active)
	assert_true(player._reduced, "Hideout keeps its background fixed")
	assert_true(str(player._data.id).ends_with("blood"))
	for i in range(6): player.advance()
	assert_eq(director.screen, &"select")
	assert_false(get_tree().paused)
	assert_eq(store.data.seen_cutscenes, ["h1.blood"])
	assert_false(director.continue_from_result(), "Cannot replay a result from selection")
	director.start_mission(SceneDirector.RESIDENCE)
	for frame in range(4): await get_tree().process_frame
	MissionDirector.complete_objective(&"m02_target")
	MissionDirector.complete_objective(&"m02_escape")
	for frame in range(2): await get_tree().process_frame
	assert_true(director.continue_from_result())
	assert_eq(director.screen, &"select", "Repeat clears do not replay first-clear conversations")
	director.show_title()
