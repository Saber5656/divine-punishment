extends GutTest

func test_ten_ordered_slots_and_progression_policy() -> void:
	var path := "res://src/core/mission/campaign_catalog.gd"
	assert_true(FileAccess.file_exists(path))
	if not FileAccess.file_exists(path): return
	var catalog = load(path)
	var missions: Array = catalog.missions()
	assert_eq(missions.size(), 10)
	for index in range(10):
		assert_eq(String(missions[index].id), "m%02d" % (index+1))
		assert_false(missions[index].localized_title().is_empty())
		assert_eq(catalog.is_unlocked(missions[index].id, {"unlocked_mission":1}), index == 0)
	assert_eq(missions[1].tool_loadout, {&"stone":10, &"dart":5, &"smoke":2})
	assert_false(catalog.is_unlocked(&"practice", {"unlocked_mission":11}))
	assert_false(catalog.is_unlocked(&"m11", {"unlocked_mission":11}))
	assert_false(catalog.is_complete({"unlocked_mission":11,"mission_results":{}}))
	assert_true(catalog.is_complete({"mission_results":{"m10":{"rank":"shoden"}}}))

func test_first_clears_unlock_each_next_night_without_replay_narrative_changes() -> void:
	var save = load("res://src/autoload/save_manager.gd").new()
	var result := MissionResult.create(70, &"chuden", {})
	result.narrative_counts = {"nontarget_kills":1,"civilian_kills":0,"detections":0}
	for night in range(1,11):
		var id := StringName("m%02d" % night)
		save.record_mission_result(id,result,true)
		assert_eq(save.campaign().unlocked_mission, night+1)
		assert_eq(save.campaign().shura, night)
		save.record_mission_result(id,result,false)
		assert_eq(save.campaign().shura, night)
	save.free()
