extends Node3D

const CARGO := preload("res://src/levels/port_storehouse/port_cargo.gd")
const LEDGER_POINT := Vector3(68,2.94,12)
const EXITS := {&"Entry":Vector3(8,0.02,60),&"RearWater":Vector3(88,-1.65,18)}
var ledger_collected := false
var cargo: RigidBody3D
var target: TargetNpc
var _player: PlayerController
var _level: PortStorehouse
var _population: Node3D
var _ledger: MeshInstance3D
var _ledger_prompt: Label3D
var _cargo_prompt: Label3D
var _initialized := false
var _restoring := false
var _entities: Dictionary = {}
var _npcs: Dictionary = {}
var _civilians: Dictionary = {}
var _lights: Dictionary = {}

func _ready() -> void:
	_level = get_parent() as PortStorehouse
	_population = _level.get_node("Population")
	_player = _level.get_node("Player") as PlayerController
	target = _population.get_node("Target") as TargetNpc
	_npcs["Target"] = target
	for npc: EnemyBase in _population.get_node("Guards").get_children(): _npcs[String(npc.name)] = npc
	for civilian: CivilianNPC in _population.get_node("Civilians").get_children(): _civilians[String(civilian.name)] = civilian
	_entities.merge(_npcs)
	_entities.merge(_civilians)
	for light: LightSource in _level.get_node("PortEnvironment/Lights").get_children(): _lights[String(light.name)] = light
	_ledger = MeshInstance3D.new()
	_ledger.name = "Ledger"
	_ledger.mesh = BoxMesh.new()
	(_ledger.mesh as BoxMesh).size = Vector3(0.5,0.08,0.35)
	_ledger.position = LEDGER_POINT
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color("d8c596")
	_ledger.material_override = paper
	add_child(_ledger)
	var desk := StaticBody3D.new()
	desk.position = Vector3(68,2.5,12)
	desk.collision_layer = 1|16|32
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(1.1,0.8,0.7)
	desk.add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	(mesh.mesh as BoxMesh).size = (shape.shape as BoxShape3D).size
	desk.add_child(mesh)
	add_child(desk)
	cargo = CARGO.new()
	cargo.name = "OpiumCargo"
	cargo.position = Vector3(68,-0.45,36)
	add_child(cargo)
	cargo.disposed.connect(_on_cargo_disposed)
	_ledger_prompt = _prompt(&"m03.prompt.ledger",LEDGER_POINT+Vector3.UP*0.5)
	_cargo_prompt = _prompt(&"m03.prompt.cargo",Vector3(68,0.5,36))
	for point: Vector3 in EXITS.values(): _prompt(&"m03.prompt.exit",point+Vector3.UP*1.5)
	for definition in [[&"port_pier",Vector3(30,0.02,48)],[&"port_house",Vector3(58,3.02,22)]]:
		var checkpoint := CheckpointArea.new()
		checkpoint.checkpoint_id = definition[0]
		checkpoint.position = definition[1]
		var bounds := CollisionShape3D.new()
		bounds.shape = BoxShape3D.new()
		(bounds.shape as BoxShape3D).size = Vector3(2,2,2)
		checkpoint.add_child(bounds)
		add_child(checkpoint)
	EventBus.mission_event.connect(_on_mission_event)
	_initialize()

func _initialize() -> void:
	if not is_inside_tree(): return
	var retained := GameState.checkpoint_ref.duplicate(true) if PlayerRetryFlow.pending_scene == _level.scene_file_path else {}
	MissionDirector.attach_mission_scene(_level,load("res://data/missions/m03.tres") as MissionDefinition)
	if not retained.is_empty(): GameState.checkpoint_ref = retained
	_population.call("apply_alarm",GameState.area_alert_level)
	_initialized = true
	_append_world_snapshot.call_deferred()

func _exit_tree() -> void:
	if EventBus.mission_event.is_connected(_on_mission_event): EventBus.mission_event.disconnect(_on_mission_event)

func _physics_process(_delta: float) -> void:
	if not _initialized or _restoring: return
	_cargo_prompt.visible = not cargo.is_disposed()
	_cargo_prompt.global_position = cargo.global_position+Vector3.UP*0.9
	for identity: StringName in EXITS: try_escape(identity)

func _unhandled_input(event: InputEvent) -> void:
	if not _initialized or _restoring or not event.is_action_pressed(&"interact") or event.is_echo(): return
	var handled := false
	if cargo.is_carried(): handled = cargo.try_interact(_player)
	elif try_collect_ledger(): handled = true
	else: handled = cargo.try_interact(_player)
	if handled: get_viewport().set_input_as_handled()

func try_collect_ledger() -> bool:
	var objective := MissionDirector.current_objective()
	if not _initialized or ledger_collected or not target.is_target_defeated() or objective == null or objective.id != &"m03_ledger": return false
	if not _can_reach(LEDGER_POINT): return false
	ledger_collected = true
	_ledger.visible = false
	_ledger_prompt.visible = false
	MissionDirector.complete_objective(&"m03_ledger")
	return true

func try_escape(identity: StringName) -> bool:
	var objective := MissionDirector.current_objective()
	if not _initialized or not EXITS.has(identity) or not ledger_collected or not target.is_target_defeated() or objective == null or objective.id != &"m03_escape": return false
	if _player.state_machine.is_dead() or _player.global_position.distance_to(EXITS[identity]) > 3.0: return false
	MissionDirector.complete_objective(&"m03_escape")
	return true

func _can_reach(point: Vector3) -> bool:
	if _player.state_machine.current_state() not in [&"Ground",&"Crouch"] or _player.global_position.distance_to(point) > 1.8: return false
	var query := PhysicsRayQueryParameters3D.create(_player.global_position+Vector3.UP*0.4,point,1|16)
	query.exclude = [_player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _on_cargo_disposed() -> void:
	if not _initialized or _restoring: return
	MissionDirector.complete_objective(&"m03_opium")
	var noise := NoiseEvent.create(cargo.global_position,5.0,Enums.NoiseKind.LANDING,cargo)
	noise.audio_cue = &"water"
	NoiseEventSystem.emit(noise,get_tree())

func _on_mission_event(event: StringName,payload: Dictionary) -> void:
	if _restoring: return
	if event == EventBus.EV_CHECKPOINT_REACHED: _append_world_snapshot()
	elif event == EventBus.EV_TARGET_KILLED and payload.get("target") == target: _capture_target_checkpoint.call_deferred()

func _capture_target_checkpoint() -> void:
	if not is_inside_tree() or not target.is_target_defeated(): return
	var deadline := Time.get_ticks_msec()+3000
	while _player.checkpoint_posture().is_empty() and not _player.state_machine.is_dead():
		if Time.get_ticks_msec() >= deadline: return
		await get_tree().physics_frame
		if not is_instance_valid(_player) or not is_inside_tree(): return
	(_player.get_node("RetryFlow") as PlayerRetryFlow).capture_checkpoint(&"assassination_complete")

func _append_world_snapshot() -> void:
	if not is_inside_tree() or not _initialized or _restoring or GameState.checkpoint_ref.is_empty() or not PlayerRetryFlow.pending_scene.is_empty(): return
	var world := {"version":2,"ledger":ledger_collected,"cargo":cargo.capture_checkpoint_state(),"mission":MissionDirector.capture_checkpoint_state(_entities),"npcs":{},"civilians":{},"lights":{}}
	for identity: String in _lights: world["lights"][identity] = (_lights[identity] as LightSource).is_on()
	for identity: String in _npcs: world["npcs"][identity] = MissionNpcSnapshot.capture(_npcs[identity])
	for identity: String in _civilians:
		var civilian := _civilians[identity] as CivilianNPC
		world["civilians"][identity] = {"health":civilian.health(),"position":CARGO._array(civilian.global_position),"yaw":civilian.global_rotation.y}
	GameState.checkpoint_ref["mission_world"] = world

func restore_checkpoint_world(snapshot: Dictionary) -> bool:
	var world: Variant = snapshot.get("mission_world")
	if not world is Dictionary or world.get("version") != 2 or not world.get("ledger") is bool: return false
	if not world.get("lights") is Dictionary or world["lights"].size() != _lights.size(): return false
	for identity: String in _lights:
		if not world["lights"].get(identity) is bool: return false
	if not world.get("npcs") is Dictionary or world["npcs"].size() != _npcs.size(): return false
	if not world.get("civilians") is Dictionary or world["civilians"].size() != _civilians.size(): return false
	if not world.get("mission") is Dictionary or not MissionDirector.checkpoint_state_is_valid(world["mission"],_entities): return false
	if not world.get("cargo") is Dictionary or not cargo.checkpoint_state_is_valid(world["cargo"]): return false
	for identity: String in _npcs:
		var row: Variant = world["npcs"].get(identity)
		if not row is Dictionary or not MissionNpcSnapshot.is_valid(row,_npcs[identity]): return false
	for identity: String in _civilians:
		var row: Variant = world["civilians"].get(identity)
		if not row is Dictionary or not CheckpointSnapshot._whole_number(row.get("health"),0,1) or not CheckpointSnapshot._finite_number(row.get("yaw")): return false
		if not row.get("position") is Array or row["position"].size() != 3: return false
		for coordinate in row["position"]:
			if not CheckpointSnapshot._finite_number(coordinate) or absf(float(coordinate)) > 10000: return false
	var dead: bool = world["npcs"]["Target"]["brain"]["kind"] == "dead"
	var objective := int(world["mission"]["objective"])
	if dead != (objective > 0) or int(world["mission"]["target_kills"]) != int(dead): return false
	if world["ledger"] != (objective >= 2) or world["cargo"]["disposed"] != world["mission"]["stats"]["side_objective_completed"]: return false
	if world["cargo"]["carried"] and snapshot.get("posture") not in ["Ground","Crouch"]: return false
	_restoring = true
	for identity: String in _lights: (_lights[identity] as LightSource).set_extinguished(not world["lights"][identity])
	for identity: String in _npcs: MissionNpcSnapshot.restore(world["npcs"][identity],_npcs[identity])
	for identity: String in _civilians:
		var civilian := _civilians[identity] as CivilianNPC
		var row: Dictionary = world["civilians"][identity]
		civilian.restore_checkpoint_health(int(row["health"]))
		civilian.global_position = CARGO._vector(row["position"])
		civilian.global_rotation.y = float(row["yaw"])
	cargo.restore_checkpoint_state(world["cargo"],_player)
	ledger_collected = world["ledger"]
	_ledger.visible = not ledger_collected
	_ledger_prompt.visible = not ledger_collected
	MissionDirector.restore_checkpoint_state(world["mission"],_entities)
	_population.call("apply_alarm",GameState.area_alert_level)
	_restoring = false
	_initialized = true
	return true

func _prompt(key: StringName,point: Vector3) -> Label3D:
	var label := Label3D.new()
	label.text = GameText.with_bindings(key)
	label.font = load("res://assets/fonts/NotoSerifJP.ttf")
	label.font_size = 48
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = point
	add_child(label)
	return label
