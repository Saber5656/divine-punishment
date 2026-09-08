extends GutTest
var main: Node
var director: SceneDirector

func before_each() -> void:
	main = load("res://src/ui/main.tscn").instantiate()
	add_child_autofree(main)
	director = main.get_node("SceneDirector") as SceneDirector
	await get_tree().process_frame

func after_each() -> void:
	director._clear_mission()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func test_mission_selection_offers_residence_with_localized_objectives() -> void:
	var previous_unlock: int = SaveManager.campaign().unlocked_mission
	SaveManager.campaign().unlocked_mission = 2
	director.show_mission_select()
	SaveManager.campaign().unlocked_mission = previous_unlock
	var found := false
	for node in director._content.find_children("*","Button",true,false):
		if node.text == "屋敷へ潜入": found = true
	assert_true(found,"Residence must be reachable from the production mission selection")
	assert_eq(GameText.get_text(&"m02.objective.target"),"毒山刑部を討て。庭・屋根・床下から好機を探れ")

func test_director_retry_restores_dead_target_escape_goal_and_score() -> void:
	assert_true(director.start_mission(load("res://data/missions/m02.tres")))
	for frame in 6: await get_tree().physics_frame
	var mission := director.mission.get_node("Mission") as SamuraiMission
	# Fixture models a kill inside the house, away from the entry escape area.
	(director.mission.get_node("Player") as PlayerController).global_position = Vector3(58,1.32,23)
	assert_true(mission.target.begin_assassination(&"below"))
	for frame in 4: await get_tree().physics_frame
	var saved := GameState.checkpoint_ref.duplicate(true)
	var old_id := director.mission.get_instance_id()
	assert_eq(saved["id"],"assassination_complete")
	director.show_pause()
	assert_true(director.request_checkpoint_retry())
	for frame in 6: await get_tree().process_frame
	assert_ne(director.mission.get_instance_id(),old_id)
	assert_false(get_tree().paused,"retry must resume gameplay")
	var restored := director.mission.get_node("Mission") as SamuraiMission
	assert_true(restored.target.is_target_defeated(),"target must remain dead")
	assert_not_null(MissionDirector.current_objective(),"escape objective must remain active")
	if MissionDirector.current_objective() == null: return
	assert_eq(MissionDirector.current_objective().kind,&"ESCAPE")
	assert_eq(MissionDirector.stats().detections,saved["mission_world"]["mission"]["stats"]["detections"])
	assert_eq(GameState.checkpoint_ref["id"],"assassination_complete")


func test_director_retry_preserves_crawl_clearance_after_below_target_checkpoint() -> void:
	assert_true(director.start_mission(load("res://data/missions/m02.tres")))
	for frame in 6: await get_tree().physics_frame
	var level := director.mission as SamuraiResidence
	var player := level.get_node("Player") as PlayerController
	var entrance := level.get_node("Markers/CrawlEntrances/U1_WestWaterEntry") as CrawlEntrance
	player.global_position = entrance.outside_world_position()
	assert_true(player.try_enter_crawlspace(entrance))
	player.global_position = Vector3(58,0.02,19.5)
	assert_true((level.get_node("Mission") as SamuraiMission).target.begin_assassination(&"below"))
	for frame in 4: await get_tree().physics_frame
	assert_eq(GameState.checkpoint_ref.get("posture"),"Crawlspace")
	director.show_pause()
	assert_true(director.request_checkpoint_retry())
	for frame in 6: await get_tree().process_frame
	assert_false(get_tree().paused,"Crawl checkpoint must restore without a geometry error")
	player = director.mission.get_node("Player") as PlayerController
	for frame in 12: await get_tree().physics_frame
	assert_eq(player.state_machine.current_state(),&"Crawlspace")
	assert_true(player._has_capsule_clearance_at(player.crawl_capsule_height,player.global_position))
	assert_eq(MissionDirector.current_objective().kind,&"ESCAPE")
