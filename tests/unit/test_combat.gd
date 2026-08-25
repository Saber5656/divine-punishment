extends GutTest


const CombatConfigScript := preload("res://src/core/tuning/combat_config.gd")
const EnemyStatsScript := preload("res://src/core/tuning/enemy_stats.gd")
const PlayerCombatScript := preload("res://src/player/player_combat.gd")
const EnemyCombatScript := preload("res://src/enemies/enemy_combat.gd")
const EnemyBrainScript := preload("res://src/enemies/enemy_brain.gd")
const PLAYER_SCENE_PATH := "res://src/player/player.tscn"
const ENEMY_SCENE_PATH := "res://src/enemies/enemy_base.tscn"
const COMBAT_TUNING_PATH := "res://data/tuning/combat.tres"
const ENEMY_STATS_PATH := "res://data/tuning/enemy_ashigaru.tres"

var player: Node3D
var player_combat: PlayerCombat
var enemy: Node3D
var enemy_combat: EnemyCombat


func before_each() -> void:
	player = Node3D.new()
	player.name = "TestPlayer"
	add_child_autofree(player)
	player_combat = PlayerCombatScript.new()
	player.add_child(player_combat)

	enemy = Node3D.new()
	enemy.name = "TestEnemy"
	add_child_autofree(enemy)
	enemy_combat = EnemyCombatScript.new()
	enemy.add_child(enemy_combat)


func test_combat_resources_expose_bounded_issue_29_tuning() -> void:
	var config := load(COMBAT_TUNING_PATH) as CombatConfig
	var stats := load(ENEMY_STATS_PATH) as EnemyStats
	assert_not_null(config)
	assert_not_null(stats)
	assert_eq(config.combo_damage, [1, 1, 1])
	assert_eq(config.player_max_health, 3)
	assert_eq(config.enemy_attack_power, 1)
	assert_eq(config.reinforcement_radius_m, 12.0)
	assert_eq(config.max_reinforcements, 8)
	assert_eq(stats.max_health, 3)
	assert_eq(stats.attack_power, 1)
	assert_true(config.normalized().combo_damage.size() == 3)


func test_three_slash_combo_damages_enemy_once_per_hit_and_defeats_it() -> void:
	for expected_step in range(1, 4):
		assert_true(player_combat.start_attack())
		assert_eq(player_combat.combo_index(), expected_step)
		player_combat.tick(0.1)
		assert_true(player_combat.is_attack_active())
		assert_true(player_combat.resolve_attack(enemy))
		player_combat.tick(0.3)
		player_combat.tick(0.25)
	assert_eq(enemy_combat.health(), 0)
	assert_true(enemy_combat.is_defeated())


func test_combo_window_resets_after_timeout() -> void:
	assert_true(player_combat.start_attack())
	player_combat.tick(0.1)
	player_combat.tick(0.3)
	assert_eq(player_combat.combo_index(), 1)
	assert_false(player_combat.start_attack())
	player_combat.tick(0.8)
	assert_eq(player_combat.combo_index(), 0)
	assert_true(player_combat.start_attack())
	assert_eq(player_combat.combo_index(), 1)


func test_parry_and_dodge_negate_enemy_attack() -> void:
	enemy_combat.set_target(player)
	assert_true(player_combat.start_parry())
	assert_eq(enemy_combat.attack_target(), false)
	assert_eq(player_combat.health(), 3)
	enemy_combat.reset_combat()
	player_combat.tick(0.4)
	assert_true(player_combat.start_dodge(Vector3.RIGHT))
	enemy_combat.set_target(player)
	assert_eq(enemy_combat.attack_target(), false)
	assert_eq(player_combat.health(), 3)


func test_three_enemy_hits_defeat_player_and_block_after_defeat() -> void:
	assert_eq(player_combat.receive_damage(1, enemy), 1)
	player_combat.tick(0.21)
	assert_eq(player_combat.receive_damage(1, enemy), 1)
	player_combat.tick(0.21)
	assert_eq(player_combat.receive_damage(1, enemy), 1)
	assert_true(player_combat.is_defeated())
	assert_eq(player_combat.health(), 0)
	assert_eq(player_combat.receive_damage(1, enemy), 0)


func test_enemy_attack_uses_target_and_cooldown() -> void:
	enemy_combat.set_target(player)
	assert_true(enemy_combat.attack_target())
	assert_eq(player_combat.health(), 2)
	assert_false(enemy_combat.attack_target())
	enemy_combat.tick(1.0)
	player_combat.tick(0.21)
	assert_true(enemy_combat.attack_target())
	assert_eq(player_combat.health(), 1)


func test_enemy_combat_calls_nearby_reinforcements_through_brain_api() -> void:
	var source := (load(ENEMY_SCENE_PATH) as PackedScene).instantiate()
	var nearby := (load(ENEMY_SCENE_PATH) as PackedScene).instantiate()
	add_child_autofree(source)
	add_child_autofree(nearby)
	source.global_position = Vector3.ZERO
	nearby.global_position = Vector3(4.0, 0.0, 0.0)
	var source_brain := source.get_node("Brain") as EnemyBrain
	var nearby_brain := nearby.get_node("Brain") as EnemyBrain
	source_brain.force_state(Enums.AlertState.COMBAT, &"test")
	var source_combat := source.get_node("Combat") as EnemyCombat
	assert_eq(source_combat.call_for_help(), 1)
	assert_eq(nearby_brain.alert_state(), Enums.AlertState.SUSPICIOUS)


func test_player_and_enemy_scenes_wire_combat_nodes_without_changing_contract_order() -> void:
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	var enemy_scene := load(ENEMY_SCENE_PATH) as PackedScene
	assert_not_null(player_scene)
	assert_not_null(enemy_scene)
	var player_instance := player_scene.instantiate()
	var enemy_instance := enemy_scene.instantiate()
	add_child_autofree(player_instance)
	add_child_autofree(enemy_instance)
	assert_true(player_instance.get_node("AssassinationResolver/Combat") is PlayerCombat)
	assert_true(enemy_instance.get_node("Combat") is EnemyCombat)
	assert_eq(player_instance.get_node("AssassinationResolver/Combat").combat_config.player_max_health, 3)
	assert_eq(enemy_instance.get_node("Combat").enemy_stats.max_health, 3)
