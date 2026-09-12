extends "res://tests/smoke/port_routes_smoke.gd"

class VolatileStore extends Node:
	var last_error := OK
	var rows := {"mission_results":{}}
	func campaign() -> Dictionary: return rows
	func record_mission_result(_id,_result,_first) -> void: pass
	func commit() -> void: pass

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir=" ): output = arg.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(output)
	SaveManager.save_path = "user://port172-retry-smoke-only.json"
	var main: Node = load("res://src/ui/main.tscn").instantiate()
	add_child(main)
	var director := main.get_node("SceneDirector") as SceneDirector
	var store := VolatileStore.new()
	add_child(store)
	director.save_manager = store
	var definition := (load("res://data/missions/m03.tres") as MissionDefinition).duplicate(true) as MissionDefinition
	definition.level_scene = load("res://src/levels/port_storehouse/port_mission.tscn")
	if not director.start_mission(definition): failures.append("Could not start the development mission")
	for frame in range(5): await get_tree().physics_frame
	var level := director.mission as PortStorehouse
	var player := level.get_node("Player") as PlayerController
	var mission := level.get_node("Mission")
	# Target death and initial player placement isolate interaction/retry, not a stealth clear.
	(level.get_node("Population/Target") as TargetNpc).begin_assassination(&"back")
	player.global_position = Vector3(68,3.02,13.2)
	await _key(KEY_E)
	if not mission.ledger_collected: failures.append("Mapped E did not collect the ledger")
	var flow := player.get_node("RetryFlow") as PlayerRetryFlow
	if not flow.capture_checkpoint(&"ledger_collected"): failures.append("Could not capture the ledger checkpoint")
	var retained := GameState.checkpoint_ref.duplicate(true)
	var previous_id := level.get_instance_id()
	if not flow.request_retry(): failures.append("Production retry request was rejected")
	for frame in range(15): await get_tree().physics_frame
	level = director.mission as PortStorehouse
	if level.get_instance_id() == previous_id: failures.append("Retry did not replace the mission scene")
	mission = level.get_node("Mission")
	player = level.get_node("Player") as PlayerController
	if not mission.ledger_collected or not (level.get_node("Population/Target") as TargetNpc).is_target_defeated(): failures.append("Retry lost the ledger or target state")
	if MissionDirector.current_objective() == null or MissionDirector.current_objective().id != &"m03_escape": failures.append("Retry lost the escape objective")
	if (player.get_node("RetryFlow") as PlayerRetryFlow).choices_visible(): failures.append("Retry displayed a restore error")
	var restored_point := player.global_position
	# Exit proximity is separately covered by collision-route and unit tests.
	player.global_position = Vector3(8,0.02,60)
	for frame in range(12): await get_tree().physics_frame
	if director.screen != &"results": failures.append("Completed mission did not reach the result screen")
	var result := {"failures":failures,"fixture":"direct target death and player placement; real E pickup, scene replacement and result UI; volatile save store","checkpoint_objective":retained.get("mission_world",{}).get("mission",{}).get("objective",-1),"restored_position":str(restored_point),"screen":director.screen,"retry_ms":PlayerRetryFlow.last_retry_elapsed_ms}
	var file := FileAccess.open(output+"/result.json",FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(result,"  "))
	print("PORT_RETRY ",JSON.stringify(result))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output+"/result.png")
	get_tree().paused = false
	get_tree().quit(failures.size())
