extends GutTest


const ToolDefinitionScript := preload("res://src/tools/tool_definition.gd")
const ToolInventoryScript := preload("res://src/tools/tool_inventory.gd")
const ToolBaseScript := preload("res://src/tools/tool_base.gd")
const ToolRigScript := preload("res://src/tools/tool_rig.gd")
const TrajectoryDisplayScript := preload("res://src/tools/trajectory_display.gd")
const PLAYER_SCENE_PATH := "res://src/player/player.tscn"


func _definition(id: StringName, count: int = 2, projectile: bool = true) -> ToolDefinition:
	var definition := ToolDefinitionScript.new() as ToolDefinition
	definition.id = id
	definition.display_name = String(id)
	definition.default_count = count
	definition.is_projectile = projectile
	definition.projectile_speed = 10.0
	definition.trajectory_gravity = 9.8
	definition.trajectory_seconds = 1.0
	definition.trajectory_steps = 8
	return definition


func test_tool_definitions_are_data_driven_and_have_bounded_aim_tuning() -> void:
	for path in [
		"res://data/tools/stone.tres",
		"res://data/tools/dart.tres",
		"res://data/tools/smoke.tres",
		"res://data/tools/naruko.tres",
		"res://data/tools/rope.tres",
	]:
		var definition := load(path) as ToolDefinition
		assert_not_null(definition)
		assert_true(definition.is_valid())
		assert_gte(definition.default_count, 0)
		assert_lte(definition.default_count, ToolDefinition.MAX_COUNT)
		assert_lte(definition.trajectory_sample_count(), ToolDefinition.MAX_TRAJECTORY_STEPS)

	var rope := load("res://data/tools/rope.tres") as ToolDefinition
	assert_false(rope.is_projectile)
	assert_false(rope.supports_aiming())
	assert_almost_eq(rope.parameter_float(&"restrain_time"), 2.0, 0.0001)


func test_inventory_keeps_three_bounded_slots_and_never_consumes_below_zero() -> void:
	var inventory := ToolInventoryScript.new() as ToolInventory
	add_child_autofree(inventory)
	var stone := _definition(&"stone", 2)
	var smoke := _definition(&"smoke", 1)
	var rope := _definition(&"rope", 4, false)
	inventory.configure([stone, smoke, rope], 3)

	assert_eq(inventory.slot_count(), 3)
	assert_eq(inventory.selected_slot(), 0)
	assert_eq(inventory.remaining_count(), 2)
	assert_true(inventory.consume())
	assert_eq(inventory.remaining_count(), 1)
	assert_true(inventory.consume())
	assert_eq(inventory.remaining_count(), 0)
	assert_false(inventory.consume())
	assert_eq(inventory.remaining_count(), 0)
	assert_false(inventory.select_slot(-1))
	assert_false(inventory.select_slot(3))
	assert_true(inventory.cycle(1))
	assert_eq(inventory.selected_slot(), 1)
	assert_true(inventory.cycle(-1))
	assert_eq(inventory.selected_slot(), 0)
	assert_true(inventory.select_slot(2))
	assert_eq(inventory.remaining_count(), 4)
	assert_true(inventory.set_remaining_count(2, -100))
	assert_eq(inventory.remaining_count(), 0)
	assert_true(inventory.set_remaining_count(2, ToolDefinition.MAX_COUNT + 100))
	assert_eq(inventory.remaining_count(), ToolDefinition.MAX_COUNT)


func test_tool_base_only_accepts_finite_nonzero_aim() -> void:
	var tool := ToolBaseScript.new() as ToolBase
	add_child_autofree(tool)
	tool.tool_definition = _definition(&"stone")
	var user := Node3D.new()
	add_child_autofree(user)

	assert_false(tool.use(user, {}))
	assert_false(tool.use(user, {&"origin": Vector3.ZERO, &"dir": Vector3.ZERO, &"target": null}))
	assert_false(tool.use(user, {&"origin": Vector3(NAN, 0.0, 0.0), &"dir": Vector3.FORWARD, &"target": null}))
	assert_true(tool.use(user, {&"origin": Vector3.ZERO, &"dir": Vector3.FORWARD, &"target": null}))


func test_trajectory_is_finite_bounded_and_hud_reads_inventory() -> void:
	var rig := ToolRigScript.new() as ToolRig
	add_child_autofree(rig)
	var stone := _definition(&"stone", 3)
	rig.set_tool_definitions([stone])
	var points := rig.trajectory(Vector3.ZERO, Vector3.FORWARD)
	assert_eq(points.size(), stone.trajectory_sample_count())
	for point in points:
		assert_true(point.is_finite())
	assert_true(rig.set_aiming(true))
	assert_true(rig.is_aiming())
	assert_eq(rig.current_aim().keys().size(), 3)
	var user := Node3D.new()
	add_child_autofree(user)
	assert_true(rig.use_selected(user))
	assert_eq(rig.remaining_count(), 2)

	var display := TrajectoryDisplayScript.new() as TrajectoryDisplay
	add_child_autofree(display)
	display.set_trajectory(Vector3.ZERO, Vector3.FORWARD * 5.0, 9.8, 1.0, 12)
	assert_eq(display.points().size(), 12)
	display.clear()
	assert_eq(display.points().size(), 0)


func test_player_scene_exposes_tool_rig_and_aim_arc_contract() -> void:
	var player := (load(PLAYER_SCENE_PATH) as PackedScene).instantiate() as PlayerController
	add_child_autofree(player)
	await get_tree().process_frame
	assert_not_null(player.get_node_or_null("ToolRig"))
	assert_not_null(player.get_node_or_null("ToolRig/AimArc"))
	assert_not_null(player.tool_rig.selected_definition())
	assert_eq(player.swim_hud.tool_slot_count(), 3)
	assert_eq(player.swim_hud.tool_slot_definition(0).id, &"stone")
	assert_eq(player.swim_hud.tool_slot_remaining(0), 10)
