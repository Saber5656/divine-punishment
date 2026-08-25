extends GutTest


const EnemyScene := preload("res://src/enemies/enemy_base.tscn")
const EnemyAlertMeterHudScript := preload("res://src/ui/enemy_alert_meter_hud.gd")


func test_meter_phase_colors_and_symbols_are_state_specific() -> void:
	assert_eq(EnemyAlertMeterHudScript.phase_color(Enums.AlertState.SUSPICIOUS), EnemyAlertMeterHudScript.SUSPICIOUS_COLOR)
	assert_eq(EnemyAlertMeterHudScript.phase_color(Enums.AlertState.SEARCHING), EnemyAlertMeterHudScript.SEARCHING_COLOR)
	assert_eq(EnemyAlertMeterHudScript.phase_color(Enums.AlertState.COMBAT), EnemyAlertMeterHudScript.COMBAT_COLOR)
	assert_eq(EnemyAlertMeterHudScript.phase_color(Enums.AlertState.RETURN), EnemyAlertMeterHudScript.RETURN_COLOR)
	assert_eq(EnemyAlertMeterHudScript.phase_symbol(Enums.AlertState.SUSPICIOUS), "●")
	assert_eq(EnemyAlertMeterHudScript.phase_symbol(Enums.AlertState.SEARCHING), "▲")
	assert_eq(EnemyAlertMeterHudScript.phase_symbol(Enums.AlertState.COMBAT), "◆")
	assert_eq(EnemyAlertMeterHudScript.phase_symbol(Enums.AlertState.RETURN), "●")
	assert_gt(EnemyAlertMeterHudScript.phase_color(Enums.AlertState.RETURN).a, 0.0)


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


func test_meter_hud_evicts_stale_entries_under_candidate_churn() -> void:
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.current = true
	var hud := EnemyAlertMeterHudScript.new() as EnemyAlertMeterHud
	add_child_autofree(hud)
	hud.set_camera(camera)

	var first_batch: Array[Node] = []
	for index in EnemyAlertMeterHudScript.MAX_METERS + 8:
		var enemy := EnemyScene.instantiate() as EnemyBase
		enemy.position = Vector3(0.0, 0.0, -5.0)
		add_child_autofree(enemy)
		(enemy.get_node("Perception") as EnemyPerception).set("_meter", 1.5)
		(enemy.get_node("Brain") as EnemyBrain).force_state(Enums.AlertState.SUSPICIOUS, &"meter_churn")
		first_batch.append(enemy)
	hud.set_enemy_candidates(first_batch)
	await get_tree().process_frame
	hud.refresh()
	assert_lte(hud._entries.size(), EnemyAlertMeterHudScript.MAX_METERS)
	var old_id := first_batch[0].get_instance_id()
	var old_holder := (hud._entries.get(old_id) as Dictionary).get(&"holder") as Control

	var second_batch: Array[Node] = []
	for index in EnemyAlertMeterHudScript.MAX_METERS + 8:
		var enemy := EnemyScene.instantiate() as EnemyBase
		enemy.position = Vector3(0.0, 0.0, -5.0)
		add_child_autofree(enemy)
		(enemy.get_node("Perception") as EnemyPerception).set("_meter", 1.5)
		(enemy.get_node("Brain") as EnemyBrain).force_state(Enums.AlertState.SUSPICIOUS, &"meter_churn")
		second_batch.append(enemy)
	hud.set_enemy_candidates(second_batch)
	await get_tree().process_frame
	hud.refresh()
	assert_lte(hud._entries.size(), EnemyAlertMeterHudScript.MAX_METERS)
	assert_false(hud._entries.has(old_id))
	await get_tree().process_frame
	assert_false(is_instance_valid(old_holder))


func test_meter_hud_visible_cap_ignores_offscreen_candidates() -> void:
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.current = true
	var hud := EnemyAlertMeterHudScript.new() as EnemyAlertMeterHud
	add_child_autofree(hud)
	hud.set_camera(camera)

	var visible_enemy := EnemyScene.instantiate() as EnemyBase
	visible_enemy.position = Vector3(0.0, 0.0, -5.0)
	add_child_autofree(visible_enemy)
	(visible_enemy.get_node("Perception") as EnemyPerception).set("_meter", 1.5)
	(visible_enemy.get_node("Brain") as EnemyBrain).force_state(Enums.AlertState.SUSPICIOUS, &"onscreen")
	var candidates: Array[Node] = [visible_enemy]
	for index in EnemyAlertMeterHudScript.MAX_METERS:
		var enemy := EnemyScene.instantiate() as EnemyBase
		enemy.position = Vector3(100.0, 0.0, -5.0)
		add_child_autofree(enemy)
		(enemy.get_node("Perception") as EnemyPerception).set("_meter", 1.5)
		(enemy.get_node("Brain") as EnemyBrain).force_state(Enums.AlertState.SUSPICIOUS, &"offscreen")
		candidates.append(enemy)

	hud.set_enemy_candidates(candidates)
	await get_tree().process_frame
	hud.refresh()
	assert_eq(hud.meter_count(), 1)
	assert_true(hud.meter_screen_position(visible_enemy).is_finite())


func test_meter_hud_uses_edge_indicator_for_world_occlusion() -> void:
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.current = true
	var wall := StaticBody3D.new()
	wall.collision_layer = EnemyAlertMeterHudScript.OCCLUSION_COLLISION_MASK
	wall.collision_mask = 0
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(4.0, 4.0, 0.2)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	wall.position = Vector3(0.0, 0.0, -2.5)
	add_child_autofree(wall)

	var enemy := EnemyScene.instantiate() as EnemyBase
	enemy.position = Vector3(0.0, 0.0, -5.0)
	add_child_autofree(enemy)
	(enemy.get_node("Perception") as EnemyPerception).set("_meter", 1.5)
	(enemy.get_node("Brain") as EnemyBrain).force_state(Enums.AlertState.SUSPICIOUS, &"occlusion")
	var hud := EnemyAlertMeterHudScript.new() as EnemyAlertMeterHud
	add_child_autofree(hud)
	hud.set_camera(camera)
	hud.set_enemy_candidates([enemy])
	await get_tree().physics_frame
	await get_tree().process_frame
	hud.refresh()

	assert_eq(hud.meter_count(), 1)
	var entry := hud._entries.get(enemy.get_instance_id()) as Dictionary
	assert_false((entry.get(&"fill") as ColorRect).visible)
	assert_true((entry.get(&"symbol") as Label).text in ["↑", "↓", "←", "→"])


func test_meter_hud_edge_indicator_keeps_horizontal_symbol_inside_viewport() -> void:
	var viewport_size := Vector2(640.0, 360.0)
	var indicator := EnemyAlertMeterHudScript._occlusion_indicator_position(
		Vector2(-100.0, viewport_size.y * 0.5),
		viewport_size,
	)
	var holder_origin := indicator - Vector2(
		EnemyAlertMeterHudScript.METER_WIDTH * 0.5,
		(EnemyAlertMeterHudScript.METER_HEIGHT + EnemyAlertMeterHudScript.METER_OFFSET_Y) * 0.5,
	)
	var symbol_width := 16.0
	var symbol_left := holder_origin.x + (EnemyAlertMeterHudScript.METER_WIDTH - symbol_width) * 0.5
	assert_gte(symbol_left, 0.0)
	assert_lte(symbol_left + symbol_width, viewport_size.x)
