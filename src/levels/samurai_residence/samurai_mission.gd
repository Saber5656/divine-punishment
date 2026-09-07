class_name SamuraiMission
extends Node3D

const BASE := preload("res://src/enemies/enemy_base.tscn")
const TARGET := preload("res://src/enemies/target_npc.tscn")
const ESCORT := preload("res://src/enemies/escort_guard.tscn")
const LANTERN := preload("res://src/enemies/lantern_bearer.tscn")
const HOUSE_Y := 1.32
const GROUND_Y := 0.02
const WORLD_VERSION := 1

var npcs: Dictionary = {}
var target: TargetNpc
var gate: StaticBody3D
var _level: SamuraiResidence
var _restoring := false
var _shift_changed := false
var _initialized := false


func _ready() -> void:
	if Engine.is_editor_hint(): return
	_level = get_parent() as SamuraiResidence
	_spawn_npcs()
	_build_exits()
	EventBus.mission_event.connect(_on_mission_event)
	EventBus.area_alert_changed.connect(_on_area_alert_changed)
	_initialize.call_deferred()


func _initialize() -> void:
	MissionDirector.attach_mission_scene(_level, load("res://data/missions/m02.tres") as MissionDefinition)
	_initialized = true
	_capture_entry_if_missing.call_deferred()
	_on_area_alert_changed(GameState.area_alert_level)
	# RetryFlow runs its own deferred initialization. Fresh entry snapshots must
	# include the world even when its callback preceded this mission's startup.
	if PlayerRetryFlow.pending_scene.is_empty() and GameState.checkpoint_ref.get("id") == "mission_entry":
		_append_world_snapshot()


func _physics_process(_delta: float) -> void:
	if not _initialized or _restoring: return
	if not _shift_changed and MissionDirector.stats().elapsed_sec >= 300.0:
		_shift_changed = true
		_assign_path(npcs["E7_CorridorPatrol"], [
			_stop(52,13,HOUSE_Y,0,86400,&"rest")],86400)
		_assign_corridor(npcs["E8_RoomRest"])
	# Lantern's stricter route is a mission-authored route switch, never a warp.
	var lantern := npcs["E5_LanternBearer"] as EnemyBase
	var stricter := GameState.area_alert_level >= 1
	if lantern.get_meta(&"strict_route", false) != stricter:
		lantern.set_meta(&"strict_route", stricter)
		_assign_lantern(lantern, stricter)


func _exit_tree() -> void:
	if EventBus.mission_event.is_connected(_on_mission_event): EventBus.mission_event.disconnect(_on_mission_event)
	if EventBus.area_alert_changed.is_connected(_on_area_alert_changed): EventBus.area_alert_changed.disconnect(_on_area_alert_changed)


func _spawn_npcs() -> void:
	for marker: Node3D in _level.get_node("Markers/EnemySpawns").get_children():
		var identity := String(marker.name)
		var scene := TARGET if identity.begins_with("TGT") else (ESCORT if identity.begins_with("G") else (LANTERN if identity.begins_with("E5") else BASE))
		var npc := scene.instantiate() as EnemyBase
		npc.name = marker.name
		npc.position = marker.position
		npc.set_meta(&"mission_entity_id", identity)
		add_child(npc)
		npcs[identity] = npc
		_add_visual(npc, Color(0.55,0.18,0.12) if identity.begins_with("TGT") else Color(0.46,0.49,0.55))
		if npc is TargetNpc:
			target = npc
			target.add_to_group(&"m02_target")
	_assign_path(target, [
		_stop(58,19,HOUSE_Y,0,120,&"study"),
		_stop(58,17,HOUSE_Y,120,126,&"toilet"),
		_stop(66,17,HOUSE_Y,126,132,&"toilet"),
		_stop(66,19,HOUSE_Y,132,180,&"toilet"),
		_stop(52,13,HOUSE_Y,180,300,&"drink"),
		_stop(58,19,HOUSE_Y,300,360,&"return")],360)
	for identity in ["G1_TargetGuard", "G2_TargetGuard"]:
		var escort := npcs[identity] as EscortGuard
		escort.follow_offset = Vector3(-2 if identity.begins_with("G1") else 2,0,-2)
		escort.separation_offset = escort.follow_offset
		escort.set_escort_target(target)
	for identity in ["E1_GateGuard", "E2_GateGuard"]:
		var guard := npcs[identity] as EnemyBase
		_assign_path(guard, [_stop(guard.position.x,guard.position.z,GROUND_Y,0,86400,&"stand",Vector3.BACK)],86400)
	var garden := [Vector2(20,8),Vector2(32,8),Vector2(40,20),Vector2(40,32),Vector2(20,32),Vector2(20,20)]
	for identity in ["E3_GardenPatrol", "E4_GardenPatrol"]:
		var stops: Array[Dictionary] = []
		var route := garden.duplicate()
		if identity.begins_with("E4"):
			route = [Vector2(54,32),Vector2(40,32),Vector2(40,20),Vector2(32,8),Vector2(20,8),Vector2(20,32)]
		for i in route.size():
			stops.append(_stop(route[i].x,route[i].y,GROUND_Y,i*15,(i+1)*15,&"walk"))
		_assign_path(npcs[identity],stops,90)
	_assign_lantern(npcs["E5_LanternBearer"],false)
	_assign_path(npcs["E6_VerandaSentry"],[
		_stop(34,17,HOUSE_Y,0,50,&"stand",Vector3.RIGHT),
		_stop(34,17,HOUSE_Y,50,60,&"stand",Vector3.BACK)],60)
	_assign_corridor(npcs["E7_CorridorPatrol"])
	_assign_path(npcs["E8_RoomRest"],[_stop(52,13,HOUSE_Y,0,86400,&"rest")],86400)


func _assign_corridor(npc: EnemyBase) -> void:
	_assign_path(npc,[
		_stop(66,17,HOUSE_Y,0,22.5,&"walk",Vector3.LEFT),
		_stop(46,17,HOUSE_Y,22.5,45,&"walk",Vector3.RIGHT)],45)


func _assign_lantern(npc: EnemyBase, strict: bool) -> void:
	var points := [Vector2(40,26),Vector2(32,32),Vector2(24,26),Vector2(32,20),Vector2(40,26),Vector2(48,32),Vector2(54,38),Vector2(48,42)]
	if strict: points = [Vector2(40,32),Vector2(54,38)]
	var stops: Array[Dictionary] = []
	for index in points.size():
		stops.append(_stop(points[index].x,points[index].y,GROUND_Y,index*120.0/points.size(),(index+1)*120.0/points.size(),&"walk"))
	_assign_path(npc,stops,120)


func _stop(x: float,z: float,y: float,from: float,until: float,action: StringName,facing := Vector3.FORWARD) -> Dictionary:
	return {"point":Vector3(x,y,z),"from":from,"until":until,"action":action,"facing":facing}


func _assign_path(npc: EnemyBase, definitions: Array[Dictionary], period: float) -> void:
	# PatrolPath requires two authored stops even for a stationary schedule.
	# A repeated identical hold preserves that contract without moving the guard.
	if definitions.size() == 1:
		definitions = [definitions[0],definitions[0].duplicate()]
	var old := npc.get_node_or_null("MissionRoutine")
	if old != null:
		# Preserve the authored child and swap it out only for this runtime route.
		npc.remove_child(old)
		old.queue_free()
	var path := PatrolPath.new()
	path.name = "MissionRoutine"
	# Stops are world-authored, even though the actor owns their lifecycle.
	path.top_level = true
	path.looped = true
	npc.add_child(path)
	for index in definitions.size():
		var definition := definitions[index]
		var stop := RoutineStop.new()
		stop.route_index = index
		stop.dwell_seconds = 600
		stop.active_from_seconds = definition["from"]
		stop.active_until_seconds = definition["until"]
		stop.routine_action = definition["action"]
		stop.facing_direction = definition["facing"]
		stop.time_tag = StringName("m02_%s_%d" % [npc.name,index])
		path.add_child(stop)
		stop.global_position = definition["point"]
	if npc is TargetNpc:
		(npc as TargetNpc).set_target_routine_path(path)
		(npc as TargetNpc).set_routine_cycle_seconds(period)
	else:
		npc.brain().set_routine_type(&"lantern_bearer" if npc.name.begins_with("E5") else &"patrol")
		npc.brain().set_routine_path(path)
		npc.brain().set_routine_cycle_seconds(period)


func _add_visual(npc: EnemyBase,color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	mesh.mesh = capsule
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material_override = material
	npc.get_node("Visual").add_child(mesh)


func _build_exits() -> void:
	gate = _level._add_box(self,&"AlertGate",Vector3(34,0.6,51),Vector3(6,3,0.35),&"",&"wall")
	for entry in [["EscapeEntry",Vector3(8,0,8)],["EscapeWaterway",Vector3(84,0,56)],["EscapeGate",Vector3(34,0,54)]]:
		var area := Area3D.new()
		area.name = entry[0]
		area.position = entry[1]
		area.collision_layer = 1 << 14
		area.collision_mask = 1 << 1
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(4,3,4)
		shape.shape = box
		area.add_child(shape)
		add_child(area)
		area.body_entered.connect(_on_escape_entered.bind(area))


func _on_area_alert_changed(level: int) -> void:
	if gate == null: return
	gate.collision_layer = SamuraiResidence.GEOMETRY_COLLISION_LAYERS if level > 0 else 0
	gate.visible = level > 0


func _on_escape_entered(body: Node3D, area: Area3D) -> void:
	if not body is PlayerController: return
	try_escape(area.name)


func try_escape(exit_id: StringName) -> bool:
	var objective := MissionDirector.current_objective()
	if objective == null or objective.kind != &"ESCAPE" or not target.is_target_defeated(): return false
	if exit_id not in [&"EscapeEntry",&"EscapeWaterway",&"EscapeGate"]: return false
	if exit_id == &"EscapeGate" and GameState.area_alert_level > 0: return false
	MissionDirector.complete_objective(objective.id)
	return true


func _on_mission_event(event: StringName, payload: Dictionary) -> void:
	if _restoring: return
	if event == EventBus.EV_CHECKPOINT_REACHED:
		_append_world_snapshot()
	elif event == EventBus.EV_TARGET_KILLED and payload.get("target") == target:
		_capture_target_checkpoint.call_deferred()


func _capture_target_checkpoint() -> void:
	if not is_inside_tree() or not target.is_target_defeated(): return
	var flow := _level.get_node("Player/RetryFlow") as PlayerRetryFlow
	flow.capture_checkpoint(&"assassination_complete")


func _append_world_snapshot() -> void:
	if GameState.checkpoint_ref.is_empty(): return
	var world := {"version":WORLD_VERSION,"mission":MissionDirector.capture_checkpoint_state(npcs),"npcs":{},"shift":_shift_changed}
	for identity: String in npcs:
		var npc := npcs[identity] as EnemyBase
		world["npcs"][identity] = MissionNpcSnapshot.capture(npc)
	GameState.checkpoint_ref["mission_world"] = world


func restore_checkpoint_world(snapshot: Dictionary) -> bool:
	var value: Variant = snapshot.get("mission_world")
	if not value is Dictionary or value.get("version") != WORLD_VERSION: return false
	if not value.get("npcs") is Dictionary or value["npcs"].size() != npcs.size() or not value.get("shift") is bool: return false
	if not value.get("mission") is Dictionary or not MissionDirector.checkpoint_state_is_valid(value["mission"],npcs): return false
	for identity: String in npcs:
		var row: Variant = value["npcs"].get(identity)
		if not row is Dictionary or not MissionNpcSnapshot.is_valid(row,npcs[identity]): return false
	# Reject objective/world disagreement before changing any NPC or counter.
	var dead: bool = value["npcs"]["TGT_Toyama"]["brain"]["kind"] == "dead"
	if (int(value["mission"]["objective"]) > 0) != dead: return false
	_restoring = true
	_shift_changed = value["shift"]
	if _shift_changed:
		_assign_path(npcs["E7_CorridorPatrol"],[_stop(52,13,HOUSE_Y,0,86400,&"rest")],86400)
		_assign_corridor(npcs["E8_RoomRest"])
	for identity: String in npcs:
		var npc := npcs[identity] as EnemyBase
		var row: Dictionary = value["npcs"][identity]
		MissionNpcSnapshot.restore(row,npc)
	MissionDirector.restore_checkpoint_state(value["mission"],npcs)
	_on_area_alert_changed(GameState.area_alert_level)
	_restoring = false
	_initialized = true
	return true


func _capture_entry_if_missing() -> void:
	if not is_inside_tree() or not PlayerRetryFlow.pending_scene.is_empty(): return
	if GameState.checkpoint_ref.is_empty():
		(_level.get_node("Player/RetryFlow") as PlayerRetryFlow).capture_checkpoint(&"mission_entry")
	elif not GameState.checkpoint_ref.has("mission_world"):
		_append_world_snapshot()
