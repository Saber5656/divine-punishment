extends GutTest

func test_restoring_a_living_target_undoes_assassination_and_corpse_state_without_new_events() -> void:
	var target := load("res://src/enemies/target_npc.tscn").instantiate() as TargetNpc
	add_child_autofree(target)
	var alive := MissionNpcSnapshot.capture(target)
	assert_true(MissionNpcSnapshot.is_valid(alive,target))
	assert_true(target.begin_assassination(&"back"))
	assert_eq(target.collision_layer,EnemyBase.CORPSE_LAYER)
	var deaths: Array = []
	var on_death := func(_enemy,_method): deaths.append(true)
	EventBus.enemy_killed.connect(on_death)
	assert_true(MissionNpcSnapshot.restore(alive,target))
	assert_false(target.is_target_defeated())
	assert_false(target.is_assassinating())
	assert_false(target.is_assassinated())
	assert_true(target.can_be_assassinated())
	assert_eq(target.collision_layer,4)
	assert_eq(deaths.size(),0)
	EventBus.enemy_killed.disconnect(on_death)
