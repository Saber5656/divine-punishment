extends Node3D

const DUTIES := preload("res://src/levels/rainy_temple/temple_duties.gd")
const RETAINER := preload("res://src/npcs/temple_retainer.tscn")
const BELL := Vector3(26,4.02,54)
const EXIT := Vector3(12,0.02,88)
const RETAINER_IDS := ["retainer_a","retainer_b"]
var side_failed := false
var target: TargetNpc
var _level: Node3D
var _population: Node3D
var _player: PlayerController
var _duties: Node3D
var _retainers: Dictionary = {}
var _prompts: Dictionary = {}
var _boss_hint: Label3D
var _initialized := false

func _ready() -> void:
	process_priority = 30
	_level = get_parent()
	_population = _level.get_node("Population")
	_player = _level.get_node("Player")
	target = _population.get_node("Tetsusenbo")
	_duties = DUTIES.new()
	_duties.name = "Duties"
	_population.add_child(_duties)
	_duties.set_physics_process(false)
	var folder := Node3D.new()
	folder.name = "Retainers"
	add_child(folder)
	for index in RETAINER_IDS.size():
		var npc := RETAINER.instantiate() as ProtectedNPC
		npc.name = "RetainerA" if index == 0 else "RetainerB"
		npc.npc_id = StringName(RETAINER_IDS[index])
		npc.position = DUTIES.EXECUTION_POINTS[index]-Vector3.UP*0.92
		npc.set_meta(&"mission_entity_id",npc.npc_id)
		folder.add_child(npc)
		_retainers[RETAINER_IDS[index]] = npc
		_prompts[RETAINER_IDS[index]] = _prompt(&"m04.prompt.rescue",npc.position+Vector3.UP*1.9)
	_prompts["bell"] = _prompt(&"m04.prompt.bell",BELL+Vector3.UP*1.7)
	_prompts["exit"] = _prompt(&"m04.prompt.exit",EXIT+Vector3.UP*1.7)
	_boss_hint = _prompt(&"m04.prompt.counter",target.global_position+Vector3.UP*2)
	var bell := MeshInstance3D.new()
	bell.name = "BellBody"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.5
	cylinder.bottom_radius = 0.7
	cylinder.height = 1.2
	bell.mesh = cylinder
	bell.position = Vector3(26,6,54)
	var bronze := StandardMaterial3D.new()
	bronze.albedo_color = Color("716b40")
	bronze.metallic = 0.7
	bell.material_override = bronze
	add_child(bell)
	EventBus.mission_event.connect(_on_mission_event)
	MissionDirector.attach_mission_scene(_level,load("res://data/missions/m04.tres") as MissionDefinition)
	_initialized = true
	advance_mission()

func _exit_tree() -> void:
	if EventBus.mission_event.is_connected(_on_mission_event): EventBus.mission_event.disconnect(_on_mission_event)

func _physics_process(_delta: float) -> void:
	advance_mission()

func advance_mission() -> void:
	if not _initialized: return
	_duties.call("advance_duties")
	for index in RETAINER_IDS.size():
		var npc := _retainers[RETAINER_IDS[index]] as ProtectedNPC
		if not npc.rescued and not npc.is_defeated() and _duties.call("execution_ready",index):
			var executioner := _population.get_node("Monks/"+str(DUTIES.PARTY_NAMES[index]))
			npc.receive_combat_damage(1,executioner)
		(_prompts[RETAINER_IDS[index]] as Label3D).visible = not npc.rescued and not npc.is_defeated()
	_sync_side_objective()
	(_prompts["bell"] as Label3D).visible = not bool(_duties.get("_gather_used"))
	var escaped := 0
	for npc in _retainers.values():
		if npc.get("escaped"): escaped += 1
	(_prompts["exit"] as Label3D).text = GameText.with_bindings(&"m04.prompt.exit")+" (%d/2)"%escaped
	_boss_hint.global_position = target.global_position+Vector3.UP*2
	_boss_hint.visible = not target.is_target_defeated() and target.brain().alert_state() == Enums.AlertState.COMBAT

func try_ring_bell() -> bool:
	return _initialized and _can_reach(BELL) and bool(_duties.call("use_bell"))

func try_rescue(id: StringName) -> bool:
	if not _initialized or not _retainers.has(String(id)): return false
	var npc := _retainers[String(id)] as ProtectedNPC
	return _can_reach(npc.global_position+Vector3.UP*0.9) and npc.rescue()

func try_escape() -> bool:
	var objective := MissionDirector.current_objective()
	if not _initialized or objective == null or objective.id != &"m04_escape" or not target.is_target_defeated(): return false
	if _player.state_machine.is_dead() or _player.global_position.distance_to(EXIT) > 3.0: return false
	MissionDirector.complete_objective(&"m04_escape")
	return true

func _unhandled_input(event: InputEvent) -> void:
	if not _initialized or not event.is_action_pressed(&"interact") or event.is_echo(): return
	if try_ring_bell() or try_rescue(&"retainer_a") or try_rescue(&"retainer_b") or try_escape():
		get_viewport().set_input_as_handled()

func _can_reach(point: Vector3) -> bool:
	if _player.state_machine.current_state() not in [&"Ground",&"Crouch"] or _player.global_position.distance_to(point) > 1.8: return false
	var query := PhysicsRayQueryParameters3D.create(_player.global_position+Vector3.UP*0.4,point+Vector3.UP*0.4,1|16)
	query.exclude = [_player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _on_mission_event(event: StringName,payload: Dictionary) -> void:
	if event == &"protected_target_lost" and _retainers.has(String(payload.get("id",""))):
		side_failed = true
		MissionDirector.stats().side_objective_completed = false
	elif event == &"temple_retainer_escaped":
		_sync_side_objective()

func _sync_side_objective() -> void:
	if not _initialized or side_failed: return
	for npc in _retainers.values():
		if npc.is_defeated() or not npc.get("escaped"): return
	MissionDirector.complete_objective(&"m04_retainers")

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
