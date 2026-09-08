extends GutTest

func test_tool_names_and_mission_title_resolve_through_catalog() -> void:
	var tool = load("res://data/tools/stone.tres")
	assert_true(tool.has_method(&"localized_name"))
	if not tool.has_method(&"localized_name"): return
	assert_eq(tool.localized_name(), GameText.get_text(&"tool.stone"))
	assert_ne(tool.localized_name(), "tool.stone")
	assert_true(tool.is_valid())
	var mission = load("res://data/missions/m02.tres")
	assert_true(mission.has_method(&"localized_title"))
	if mission.has_method(&"localized_title"):
		assert_eq(mission.localized_title(), GameText.get_text(&"m02.title"))
