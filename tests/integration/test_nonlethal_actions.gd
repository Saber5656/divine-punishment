extends GutTest

func after_each() -> void:
	MissionDirector.start_mission(null)

func test_strike_requires_close_rear_approach_and_lasts_sixty_seconds() -> void:
	var player = load("res://src/player/player.tscn").instantiate()
	var enemy = load("res://src/enemies/enemy_base.tscn").instantiate()
	add_child_autofree(player)
	add_child_autofree(enemy)
	player.set_physics_process(false)
	enemy.set_physics_process(false)
	assert_true(player.has_node("NonlethalActions"))
	if not player.has_node("NonlethalActions"): return
	var action = player.get_node("NonlethalActions")
	player.position = Vector3(0,0,-1)
	assert_false(action.try_knockout(enemy))
	player.position = Vector3(0,0,1.21)
	assert_false(action.try_knockout(enemy))
	player.position = Vector3(0,0,1)
	var health: int = enemy.health()
	assert_true(action.try_knockout(enemy))
	assert_eq(enemy.health(),health)
	assert_eq(enemy.brain().incapacitated_kind(), &"knockout")
	enemy.brain()._advance_incapacitation(59.0)
	assert_true(enemy.brain().is_incapacitated())
	enemy.brain()._advance_incapacitation(1.0)
	assert_false(enemy.brain().is_incapacitated())

func test_rope_finishes_after_two_seconds_and_preserves_life() -> void:
	var player = load("res://src/player/player.tscn").instantiate()
	var enemy = load("res://src/enemies/enemy_base.tscn").instantiate()
	add_child_autofree(player)
	add_child_autofree(enemy)
	player.set_physics_process(false)
	enemy.set_physics_process(false)
	player.position = Vector3(0,0,1)
	assert_true(player.has_node("NonlethalActions"))
	if not player.has_node("NonlethalActions"): return
	var inventory: ToolInventory = player.get_node("ToolRig").inventory
	inventory.configure([load("res://data/tools/rope.tres")])
	var action = player.get_node("NonlethalActions")
	enemy.set_incapacitated(&"knockout",60.0)
	assert_true(action.begin_restraint(enemy,inventory))
	action.advance_restraint(1.0)
	assert_eq(enemy.brain().incapacitated_kind(),&"knockout")
	assert_eq(inventory.remaining_count(0),4)
	action.advance_restraint(1.0)
	assert_eq(enemy.brain().incapacitated_kind(),&"restrained")
	assert_eq(inventory.remaining_count(0),3)
	assert_false(enemy.is_defeated(),"Restraint must not report a lethal defeat")
	assert_true(enemy.is_body_carryable())

func test_forbidden_actions_block_public_combat_and_tool_entry_points() -> void:
	var player = load("res://src/player/player.tscn").instantiate()
	var enemy = load("res://src/enemies/enemy_base.tscn").instantiate()
	add_child_autofree(player)
	add_child_autofree(enemy)
	player.set_physics_process(false)
	player.position = Vector3(0,0,1)
	var definition := MissionDefinition.new()
	definition.forbidden_actions = [&"sword",&"assassinate_lethal",&"dart"]
	MissionDirector.start_mission(definition)
	var tools: ToolRig = player.get_node("ToolRig")
	tools.inventory.select_slot(1)
	assert_false(tools.use_selected(player))
	assert_eq(tools.inventory.remaining_count(1),5)
	assert_eq(player.get_node("AssassinationResolver").evaluate(enemy), &"")
	assert_false(player.get_node("AssassinationResolver/Combat").start_attack())

func test_incapacitation_uses_a_prone_visual_without_a_lethal_state() -> void:
	var enemy = load("res://src/enemies/enemy_base.tscn").instantiate()
	add_child_autofree(enemy)
	enemy.set_incapacitated(&"knockout",60.0)
	await get_tree().process_frame
	var visual: ActorAnimation = enemy.get_node("Visual/Model")
	visual.update_actor_presentation(0.1)
	assert_eq(visual.current_clip(),&"knockout")
	assert_false(enemy.is_defeated())
