extends GutTest


const EnemyScene := preload("res://src/enemies/enemy_base.tscn")
const EnemyAlertMeterHudScript := preload("res://src/ui/enemy_alert_meter_hud.gd")


func test_meter_phase_colors_and_symbols_are_state_specific() -> void:
	assert_eq(EnemyAlertMeterHudScript.phase_color(Enums.AlertState.SUSPICIOUS), EnemyAlertMeterHudScript.SUSPICIOUS_COLOR)
	assert_eq(EnemyAlertMeterHudScript.phase_color(Enums.AlertState.SEARCHING), EnemyAlertMeterHudScript.SEARCHING_COLOR)
	assert_eq(EnemyAlertMeterHudScript.phase_color(Enums.AlertState.COMBAT), EnemyAlertMeterHudScript.COMBAT_COLOR)
	assert_eq(EnemyAlertMeterHudScript.phase_symbol(Enums.AlertState.SUSPICIOUS), "●")
	assert_eq(EnemyAlertMeterHudScript.phase_symbol(Enums.AlertState.SEARCHING), "▲")
	assert_eq(EnemyAlertMeterHudScript.phase_symbol(Enums.AlertState.COMBAT), "◆")
	assert_eq(EnemyAlertMeterHudScript.phase_symbol(Enums.AlertState.RETURN), "")
	assert_eq(EnemyAlertMeterHudScript.phase_color(Enums.AlertState.RETURN).a, 0.0)


func test_meter_projection_fails_closed_for_non_finite_behind_and_offscreen_positions() -> void:
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.current = true
	await get_tree().process_frame
	var viewport_size := get_viewport().get_visible_rect().size
	assert_true(EnemyAlertMeterHudScript.project_anchor(camera, Vector3(0.0, 0.0, -5.0), viewport_size).get(&"valid"))
	assert_false(EnemyAlertMeterHudScript.project_anchor(camera, Vector3(NAN, 0.0, -5.0), viewport_size).get(&"valid"))
	assert_false(EnemyAlertMeterHudScript.project_anchor(camera, Vector3(0.0, 0.0, 5.0), viewport_size).get(&"valid"))
	assert_false(EnemyAlertMeterHudScript.project_anchor(camera, Vector3(100000.0, 0.0, -5.0), viewport_size).get(&"valid"))


func test_meter_hud_projects_enemy_anchor_and_rejects_invalid_meter() -> void:
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.current = true
	var enemy := EnemyScene.instantiate() as EnemyBase
	add_child_autofree(enemy)
	enemy.position = Vector3(0.0, 0.0, -5.0)
	var perception := enemy.get_node("Perception") as EnemyPerception
	var brain := enemy.get_node("Brain") as EnemyBrain
	perception.set("_meter", 1.5)
	brain.force_state(Enums.AlertState.SUSPICIOUS, &"meter_test")
	var hud := EnemyAlertMeterHudScript.new() as EnemyAlertMeterHud
	add_child_autofree(hud)
	hud.set_camera(camera)
	hud.set_enemy_candidates([enemy])
	await get_tree().process_frame
	hud.refresh()
	assert_eq(hud.meter_count(), 1)
	assert_true(hud.meter_screen_position(enemy).is_finite())

	perception.set("_meter", NAN)
	hud.refresh()
	assert_eq(hud.meter_count(), 0)


func test_meter_hud_candidate_and_meter_counts_are_bounded() -> void:
	var hud := EnemyAlertMeterHudScript.new() as EnemyAlertMeterHud
	add_child_autofree(hud)
	var candidates: Array[Node] = []
	for index in EnemyAlertMeterHudScript.MAX_ENEMY_CANDIDATES + 32:
		var candidate := Node3D.new()
		candidates.append(candidate)
		add_child_autofree(candidate)
	hud.set_enemy_candidates(candidates)
	assert_lte(hud._candidate_nodes().size(), EnemyAlertMeterHudScript.MAX_ENEMY_CANDIDATES)
	assert_lte(hud._entries.size(), EnemyAlertMeterHudScript.MAX_METERS)
