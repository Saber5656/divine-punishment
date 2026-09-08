extends GutTest

const SaveScript := preload("res://src/autoload/save_manager.gd")
const PATH := "user://narrative51-test.json"
func after_each() -> void:
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(PATH+suffix): DirAccess.remove_absolute(PATH+suffix)

func test_result_statistics_accumulate_and_round_trip_in_v2() -> void:
	var save = SaveScript.new()
	save.save_path = PATH
	save.load_save()
	var stats := MissionStats.new()
	stats.nontarget_kills = 2
	stats.civilian_kills = 1
	stats.detections = 1
	var definition := MissionDefinition.new()
	definition.id = &"m02"
	var result := MissionDirector.compute_score(stats, ScoringConfig.new(), definition)
	save.record_mission_result(&"m02", result, true)
	assert_eq(save.campaign().total_nontarget_kills, 2)
	assert_eq(save.campaign().total_civilian_kills, 1)
	assert_eq(save.campaign().total_detections, 1)
	assert_eq(save.campaign().shura, 5)
	stats.nontarget_kills = 0
	stats.civilian_kills = 0
	result = MissionDirector.compute_score(stats, ScoringConfig.new(), definition)
	save.record_mission_result(&"m03", result, true)
	assert_eq(save.campaign().shura, 6, "Detection pairs cross mission boundaries")
	save.commit()
	assert_eq(save.last_error, OK)
	var reader = SaveScript.new()
	reader.save_path = PATH
	reader.load_save()
	assert_eq(reader.campaign().shura, 6)
	assert_eq(reader.campaign().total_detections, 2)
	save.free()
	reader.free()

func test_shura_formula_is_pure_and_counts_cumulative_detection_pairs() -> void:
	var path := "res://src/core/mission/narrative_totals.gd"
	assert_true(FileAccess.file_exists(path))
	if not FileAccess.file_exists(path): return
	var formula = load(path)
	assert_eq(formula.shura(0,0,0), 0)
	assert_eq(formula.shura(0,0,1), 0)
	assert_eq(formula.shura(0,0,2), 1)
	assert_eq(formula.shura(5,2,3), 12)
	assert_eq(formula.shura(-1,-1,-1), 0)

func test_v1_counters_migrate_without_mutating_source_then_continue_in_v2() -> void:
	var original := {"version":1,"campaign":{"total_nontarget_kills":4,"total_civilian_kills":2,"total_detections":3,"shura":11}}
	var migrated: Dictionary = SaveScript.migrate(original)
	assert_eq(migrated.version, 2)
	assert_eq(migrated.campaign.total_nontarget_kills, 4)
	assert_eq(migrated.campaign.total_civilian_kills, 2)
	assert_eq(migrated.campaign.total_detections, 3)
	assert_eq(migrated.campaign.shura, 11)
	assert_eq(original.version, 1)
	assert_false(original.has("settings"))

func test_game_state_reads_the_canonical_saved_totals() -> void:
	var campaign: Dictionary = SaveManager.campaign()
	var original := campaign.duplicate(true)
	campaign.shura = 12
	campaign.total_nontarget_kills = 5
	campaign.total_civilian_kills = 2
	campaign.total_detections = 3
	assert_eq(GameState.shura, 12)
	assert_eq(GameState.total_nontarget_kills, 5)
	assert_eq(GameState.total_civilian_kills, 2)
	assert_eq(GameState.total_detections, 3)
	for key in ["shura","total_nontarget_kills","total_civilian_kills","total_detections"]:
		campaign[key] = original[key]

func test_replay_updates_rank_without_recounting_narrative_even_if_first_clear_is_wrong() -> void:
	var save = SaveScript.new()
	save.save_path = PATH
	save.load_save()
	var stats := MissionStats.new()
	stats.nontarget_kills = 3
	stats.detections = 2
	var definition := MissionDefinition.new()
	definition.id = &"m02"
	var result := MissionDirector.compute_score(stats, ScoringConfig.new(), definition)
	save.record_mission_result(&"m02", result, true)
	var before: int = save.campaign().shura
	result.rank = &"kaiden"
	result.score = 100
	save.record_mission_result(&"m02", result, false)
	assert_eq(save.campaign().shura, before)
	assert_eq(save.campaign().mission_results.m02.rank, "kaiden")
	save.record_mission_result(&"m02", result, true)
	assert_eq(save.campaign().shura, before, "Existing clear receipt overrides a mistaken first_clear flag")
	save.free()

func test_training_and_noncampaign_ids_cannot_change_story_totals_or_unlocks() -> void:
	var save = SaveScript.new()
	save.save_path = PATH
	save.load_save()
	var stats := MissionStats.new()
	stats.nontarget_kills = 5
	stats.detections = 2
	var definition := MissionDefinition.new()
	for id in [&"practice", &"custom", &"m11"]:
		definition.id = id
		var result := MissionDirector.compute_score(stats, ScoringConfig.new(), definition)
		save.record_mission_result(id, result, true)
		assert_eq(save.campaign().shura, 0)
		assert_eq(save.campaign().total_detections, 0)
		assert_eq(save.campaign().unlocked_mission, 1)
		assert_true(save.campaign().mission_results.has(String(id)), "Training still records best rank")
	save.free()
