extends GutTest

func test_scroll_slots_lock_and_crest_contract() -> void:
	var path := "res://src/ui/campaign_selection.gd"
	assert_true(FileAccess.file_exists(path))
	if not FileAccess.file_exists(path): return
	var board = load(path).new()
	add_child_autofree(board)
	board.configure({"unlocked_mission":2,"mission_results":{"m01":{"rank":"kaiden","flags":{"shadow_walker":true}}}})
	assert_eq(board.slots.size(), 10)
	assert_false(board.slots[0].disabled)
	assert_false(board.slots[1].disabled)
	assert_true(board.slots[2].disabled)
	assert_eq(board.crest_ids.size(), 5)
	board.select_mission(1)
	assert_eq(board.selected.id, &"m02")
	assert_false(board.start_button.disabled)
	board.select_mission(2)
	assert_eq(board.selected.id, &"m02", "Locked night cannot be selected")

func test_title_bonus_and_campaign_board_are_connected_to_saved_progress() -> void:
	var main = load("res://src/ui/main.tscn").instantiate()
	add_child_autofree(main)
	var director = main.get_node("SceneDirector")
	assert_true(director.has_method(&"title_background"))
	if not director.has_method(&"title_background"): return
	var campaign: Dictionary = SaveManager.campaign()
	var original: Dictionary = campaign.mission_results.duplicate(true)
	campaign.mission_results.erase("m10")
	var before: Texture2D = director.title_background()
	campaign.mission_results.m10 = {"rank":"shoden","score":0,"flags":{}}
	assert_ne(director.title_background(), before)
	campaign.mission_results = original
	director.show_mission_select()
	assert_eq(director.find_children("*", "CampaignSelection", true, false).size(), 1)
	director.show_title()

func test_unlocked_third_night_launches_the_port_from_the_mission_board() -> void:
	var main: Node = load("res://src/ui/main.tscn").instantiate()
	add_child_autofree(main)
	var director := main.get_node("SceneDirector") as SceneDirector
	director.show_mission_select()
	var board := director.find_children("*","CampaignSelection",true,false)[0] as CampaignSelection
	board.configure({"unlocked_mission":3,"mission_results":{}})
	board.select_mission(2)
	assert_false(board.start_button.disabled,"A completed port gameplay loop can launch from its unlocked slot")
	if board.start_button.disabled: return
	board.start_button.pressed.emit()
	for frame in range(5): await get_tree().physics_frame
	assert_eq(director.screen,&"playing")
	assert_true(director.mission is PortStorehouse)
	assert_eq(MissionDirector.current_objective().id,&"m03_target")
	director.show_title()
