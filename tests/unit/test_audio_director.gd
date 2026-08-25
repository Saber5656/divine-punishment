extends GutTest


const AudioDirectorScript := preload("res://src/autoload/audio_director.gd")
const EnemyScene := preload("res://src/enemies/enemy_base.tscn")


func test_audio_director_tracks_highest_active_alert_and_clears_inactive_states() -> void:
	var director := AudioDirectorScript.new()
	add_child_autofree(director)
	var suspicious := Node.new()
	var searching := Node.new()
	add_child_autofree(suspicious)
	add_child_autofree(searching)

	director.clear_alert_tracking()
	assert_true(director.update_enemy_alert(suspicious, Enums.AlertState.SUSPICIOUS))
	assert_eq(director.highest_alert_state(), Enums.AlertState.SUSPICIOUS)
	assert_eq(director.alert_tier(), 0)
	assert_true(director.update_enemy_alert(searching, Enums.AlertState.SEARCHING))
	assert_eq(director.highest_alert_state(), Enums.AlertState.SEARCHING)
	assert_eq(director.alert_tier(), 1)
	assert_true(director.update_enemy_alert(suspicious, Enums.AlertState.COMBAT))
	assert_eq(director.highest_alert_state(), Enums.AlertState.COMBAT)
	assert_eq(director.alert_tier(), 2)
	assert_true(director.update_enemy_alert(suspicious, Enums.AlertState.RETURN))
	assert_eq(director.highest_alert_state(), Enums.AlertState.SEARCHING)
	assert_eq(director.alert_tier(), 1)
	assert_eq(director.active_alert_count(), 1)


func test_audio_director_rejects_invalid_states_and_bounds_enemy_table() -> void:
	var director := AudioDirectorScript.new()
	add_child_autofree(director)
	director.clear_alert_tracking()
	assert_false(director.update_enemy_alert(null, Enums.AlertState.COMBAT))
	var invalid_enemy := Node.new()
	add_child_autofree(invalid_enemy)
	assert_false(director.update_enemy_alert(invalid_enemy, 99))

	var accepted := 0
	for index in AudioDirectorScript.MAX_TRACKED_ENEMIES + 1:
		var enemy := Node.new()
		add_child_autofree(enemy)
		if director.update_enemy_alert(enemy, Enums.AlertState.SEARCHING):
			accepted += 1
	assert_eq(accepted, AudioDirectorScript.MAX_TRACKED_ENEMIES)
	assert_eq(director.active_alert_count(), AudioDirectorScript.MAX_TRACKED_ENEMIES)


func test_audio_director_event_bus_hook_consumes_alert_changed() -> void:
	var director := AudioDirectorScript.new()
	add_child_autofree(director)
	var enemy := Node.new()
	add_child_autofree(enemy)
	director.clear_alert_tracking()
	EventBus.alert_changed.emit(enemy, Enums.AlertState.UNAWARE, Enums.AlertState.COMBAT)
	assert_eq(director.highest_alert_state(), Enums.AlertState.COMBAT)
	EventBus.alert_changed.emit(enemy, Enums.AlertState.COMBAT, Enums.AlertState.UNAWARE)
	assert_eq(director.highest_alert_state(), Enums.AlertState.UNAWARE)


func test_audio_director_drops_incapacitated_enemy_from_bgm_aggregate() -> void:
	var director := AudioDirectorScript.new()
	add_child_autofree(director)
	var enemy := EnemyScene.instantiate() as EnemyBase
	add_child_autofree(enemy)
	await get_tree().process_frame

	assert_true(director.update_enemy_alert(enemy, Enums.AlertState.COMBAT))
	assert_eq(director.highest_alert_state(), Enums.AlertState.COMBAT)
	assert_true(enemy.set_incapacitated(&"knockout", 0.0))
	assert_eq(director.highest_alert_state(), Enums.AlertState.UNAWARE)

	assert_true(director.update_enemy_alert(enemy, Enums.AlertState.COMBAT))
	EventBus.enemy_neutralized.emit(enemy, "knockout")
	assert_eq(director.highest_alert_state(), Enums.AlertState.UNAWARE)


func test_audio_director_retains_higher_alert_when_tracking_table_is_full() -> void:
	var director := AudioDirectorScript.new()
	add_child_autofree(director)
	director.clear_alert_tracking()
	for index in AudioDirectorScript.MAX_TRACKED_ENEMIES:
		var enemy := Node.new()
		add_child_autofree(enemy)
		assert_true(director.update_enemy_alert(enemy, Enums.AlertState.SUSPICIOUS))

	var combat_enemy := Node.new()
	add_child_autofree(combat_enemy)
	assert_true(director.update_enemy_alert(combat_enemy, Enums.AlertState.COMBAT))
	assert_eq(director.active_alert_count(), AudioDirectorScript.MAX_TRACKED_ENEMIES)
	assert_eq(director.highest_alert_state(), Enums.AlertState.COMBAT)

	assert_true(director.update_enemy_alert(combat_enemy, Enums.AlertState.RETURN))
	assert_eq(director.highest_alert_state(), Enums.AlertState.SUSPICIOUS)


func test_audio_director_retains_overflow_combat_after_tracked_entries_leave() -> void:
	var director := AudioDirectorScript.new()
	add_child_autofree(director)
	director.clear_alert_tracking()
	var tracked: Array[Node] = []
	for index in AudioDirectorScript.MAX_TRACKED_ENEMIES:
		var enemy := Node.new()
		add_child_autofree(enemy)
		tracked.append(enemy)
		assert_true(director.update_enemy_alert(enemy, Enums.AlertState.COMBAT))

	var overflow_enemy := Node.new()
	add_child_autofree(overflow_enemy)
	assert_false(director.update_enemy_alert(overflow_enemy, Enums.AlertState.COMBAT))
	assert_eq(director.highest_alert_state(), Enums.AlertState.COMBAT)
	assert_eq(director.overflow_alert_count(), 1)

	for enemy: Node in tracked:
		assert_true(director.update_enemy_alert(enemy, Enums.AlertState.RETURN))
	assert_eq(director.active_alert_count(), 1)
	assert_eq(director.highest_alert_state(), Enums.AlertState.COMBAT)
	assert_eq(director.tracked_alert_state(overflow_enemy), Enums.AlertState.COMBAT)

	assert_true(director.update_enemy_alert(overflow_enemy, Enums.AlertState.RETURN))
	assert_eq(director.overflow_alert_count(), 0)
	assert_eq(director.highest_alert_state(), Enums.AlertState.UNAWARE)


func test_audio_director_query_prune_refreshes_current_tier() -> void:
	var director := AudioDirectorScript.new()
	add_child_autofree(director)
	var enemy := Node.new()
	add_child_autofree(enemy)
	assert_true(director.update_enemy_alert(enemy, Enums.AlertState.COMBAT))
	assert_eq(director.alert_tier(), 2)

	enemy.free()
	assert_eq(director.highest_alert_state(), Enums.AlertState.UNAWARE)
	assert_eq(director.alert_tier(), 0)
