extends GutTest

const SCENE := "res://src/enemies/tetsusenbo.tscn"
var player: PlayerController

func before_each() -> void:
	MissionDirector.start_mission(null)
	player = load("res://src/player/player.tscn").instantiate()
	add_child_autofree(player)
	player.position = Vector3(0,0,1.2)
	player.set_physics_process(false)
	player.get_node("AssassinationResolver/Combat").set_physics_process(false)

func _boss() -> TargetNpc:
	assert_true(ResourceLoader.exists(SCENE),"Tetsusenbo combat archetype exists")
	if not ResourceLoader.exists(SCENE): return null
	var boss := load(SCENE).instantiate() as TargetNpc
	add_child_autofree(boss)
	boss.set_physics_process(false)
	boss.brain().set_physics_process(false)
	boss.combat().set_physics_process(false)
	return boss

func test_boss_has_eight_health_and_deals_two_real_damage() -> void:
	var boss := _boss()
	if boss == null: return
	assert_eq(boss.health(),8)
	var combat := player.get_node("AssassinationResolver/Combat") as PlayerCombat
	assert_true(boss.combat().attack(player))
	assert_eq(combat.health(),1)

func test_parry_opens_a_bounded_counter_window_and_other_attacker_does_not() -> void:
	var boss := _boss()
	if boss == null: return
	assert_eq(boss.receive_combat_damage(1,player),0)
	var combat := player.get_node("AssassinationResolver/Combat") as PlayerCombat
	assert_false(combat.attack(boss),"The actual sword source cannot bypass the guard")
	combat.tick(1.0)
	combat.tick(0.3)
	assert_true(combat.start_parry())
	assert_false(boss.combat().attack(player))
	assert_eq(combat.health(),3)
	assert_true(combat.attack(boss))
	assert_eq(boss.health(),7)
	boss._physics_process(2.0)
	assert_eq(boss.receive_combat_damage(1,player),0)
	combat.tick(2.0)
	assert_true(combat.start_parry())
	var other := Node3D.new()
	add_child_autofree(other)
	assert_eq(combat.receive_damage(1,other),0)
	assert_eq(boss.receive_combat_damage(1,player),0)

func test_normal_assassination_bypasses_combat_guard_once() -> void:
	var boss := _boss()
	if boss == null: return
	assert_true(boss.begin_assassination(&"back"))
	assert_true(boss.is_target_defeated())
	assert_false(boss.begin_assassination(&"back"))
