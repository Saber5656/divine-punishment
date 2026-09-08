extends GutTest

func test_no_kill_failure_restores_checkpoint_and_filtered_loadout() -> void:
	var main = load("res://src/ui/main.tscn").instantiate()
	add_child_autofree(main)
	var director: SceneDirector = main.get_node("SceneDirector")
	var definition := MissionDefinition.new()
	definition.id = &"m09"
	definition.level_scene = load("res://tests/fixtures/nonlethal_mission.tscn")
	definition.kill_policy = MissionDefinition.KillPolicy.FORBIDDEN
	definition.forbidden_actions = [&"sword",&"assassinate_lethal",&"dart"]
	definition.tool_loadout = {&"stone":10,&"smoke":2,&"rope":4}
	var objective := ObjectiveData.new()
	objective.id = &"rescue"
	objective.kind = &"RESCUE"
	objective.text_key = &"objective.practice_escape"
	definition.objectives = [objective]
	assert_true(director.start_mission(definition))
	for frame in range(5): await get_tree().process_frame
	var old_id := director.mission.get_instance_id()
	var inventory: ToolInventory = director.mission.get_node("Player/ToolRig").inventory
	assert_eq(inventory.definition_at(1).id,&"smoke")
	assert_eq(inventory.definition_at(2).id,&"rope")
	EventBus.enemy_killed.emit(director.mission.get_node("Enemy"),"combat")
	for frame in range(12): await get_tree().process_frame
	assert_ne(director.mission.get_instance_id(),old_id)
	assert_eq(director.screen,&"playing")
	assert_false(get_tree().paused)
	assert_eq(MissionDirector.active_mission_id(),&"m09")
	assert_eq(MissionDirector.current_objective().id,&"rescue")
	director.show_title()
