extends GutTest

const SAVE := preload("res://src/autoload/save_manager.gd")
const PATH := "user://temple_story_test.json"

func after_each() -> void:
	for suffix in ["",".tmp",".bak"]:
		if FileAccess.file_exists(PATH+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH+suffix))

func test_first_clear_rescue_outcome_survives_reload_and_a_better_repeat_score() -> void:
	for rescued in [true,false]:
		var writer := SAVE.new()
		writer.save_path = PATH
		writer.record_mission_result(&"m04",MissionResult.create(60,&"chuden",{"completed":true,"side_objective":rescued}),true)
		writer.record_mission_result(&"m04",MissionResult.create(100,&"kaiden",{"completed":true,"side_objective":not rescued}),false)
		writer.commit()
		assert_eq(writer.last_error,OK)
		var reader := SAVE.new()
		reader.save_path = PATH
		reader.load_save()
		var row: Dictionary = reader.campaign().mission_results.m04
		assert_eq(row.score,100)
		assert_eq(row.flags.side_objective,not rescued,"Best-run flags still describe the best run")
		assert_true(row.has("first_clear_flags"),"Story outcome is saved independently of the best score")
		if row.has("first_clear_flags"): assert_eq(row.first_clear_flags.side_objective,rescued)
		reader.free()
		writer.free()

func test_legacy_result_keeps_its_available_story_flags_when_best_is_replaced() -> void:
	var manager := SAVE.new()
	manager.campaign().mission_results.m04 = {"score":60,"rank":"chuden","flags":{"side_objective":true}}
	manager.record_mission_result(&"m04",MissionResult.create(100,&"kaiden",{"side_objective":false}),false)
	var row: Dictionary = manager.campaign().mission_results.m04
	assert_true(row.has("first_clear_flags"))
	if row.has("first_clear_flags"): assert_true(row.first_clear_flags.side_objective)
	manager.free()

func test_optional_story_flags_are_validated_during_migration() -> void:
	var data := SAVE.default_save()
	data.campaign.mission_results.m04 = {"score":60,"rank":"chuden","flags":{},"first_clear_flags":[]}
	assert_true(SAVE.migrate(data).is_empty(),"Malformed optional state cannot enter a writable save")
	data.campaign.mission_results.m04.erase("first_clear_flags")
	assert_false(SAVE.migrate(data).is_empty(),"Existing saves remain compatible")

func test_h3_rescue_outcomes_append_to_both_existing_shura_variants() -> void:
	var scene := load("res://data/narrative/hideout/h3.tres") as HideoutScene
	assert_eq(scene.get("outcome_flag"),&"side_objective","H3 declares its rescue branch")
	if scene.get("outcome_flag") != &"side_objective": return
	for shura in [0,100]:
		var base := scene.to_cutscene(shura)
		for rescued in [true,false]:
			var data: CutsceneData = scene.call("to_cutscene",shura,{"side_objective":rescued})
			assert_true(data.is_valid())
			assert_eq(data.id,base.id,"Existing seen-scene IDs remain compatible")
			assert_eq(data.slides[0].lines.size(),base.slides[0].lines.size()+1)
			assert_eq(data.slides[0].lines[-1].text_key,&"hideout.h3.rescued" if rescued else &"hideout.h3.lost")
			assert_eq(base.slides[0].lines.size(),6,"Authored base lines are not mutated")
