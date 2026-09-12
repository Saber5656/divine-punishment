extends Node3D

const NAVIGATION := preload("res://src/levels/port_storehouse/port_navigation.gd")
const COUNTING_ROOM := Vector3(66,3.02,14)
const INSPECTION := Vector3(48,0.02,36)
const PIER_MEETING := Vector3(68,0.02,52)
const TARGET := preload("res://src/enemies/target_npc.tscn")
const GUARD := preload("res://src/enemies/enemy_base.tscn")
const ESCORT := preload("res://src/enemies/escort_guard.tscn")
const ARCHER := preload("res://src/enemies/archer_lookout.tscn")
const CIVILIAN := preload("res://src/npcs/civilian_npc.tscn")
var target: TargetNpc
var reserve: EscortGuard
var _alarmed := false
var _abacus: AudioStreamPlayer3D

func _ready() -> void:
	NAVIGATION.build(self)
	target = _spawn(TARGET,self,"Target",COUNTING_ROOM) as TargetNpc
	target.add_to_group(&"m03_target")
	_assign_routine(target,[COUNTING_ROOM,INSPECTION,PIER_MEETING],[0.0,180.0,240.0],300.0,[&"count",&"inspect",&"meet"])
	var guards := _folder("Guards")
	for spec in [["PierWest",Vector3(40,0.02,52),Vector3.LEFT],["PierEast",Vector3(72,0.02,49),Vector3.RIGHT]]:
		var guard := _spawn(GUARD,guards,spec[0],spec[1])
		_assign_routine(guard,[spec[1],spec[1]],[0.0,30.0],60.0,[&"stand",&"stand"],spec[2])
	var patrol := _spawn(GUARD,guards,"StorehousePatrol",Vector3(36,0.02,27))
	_assign_routine(patrol,[Vector3(36,0.02,27),Vector3(48,0.02,27),Vector3(48,0.02,46),Vector3(36,0.02,46)],[0.0,15.0,30.0,45.0],60.0,[&"walk",&"walk",&"walk",&"walk"])
	patrol = _spawn(GUARD,guards,"PierPatrol",Vector3(56,0.02,46))
	_assign_routine(patrol,[Vector3(56,0.02,46),Vector3(72,0.02,46)],[0.0,20.0],40.0,[&"walk",&"walk"])
	var escort := _spawn(ESCORT,guards,"TargetEscort",COUNTING_ROOM+Vector3(-1.3,0,1.2)) as EscortGuard
	escort.follow_offset = Vector3(-1.3,0,1.2)
	escort.set_escort_target(target)
	reserve = _spawn(ESCORT,guards,"HouseReserve",Vector3(62,3.02,10)) as EscortGuard
	reserve.follow_offset = Vector3(1.3,0,1.2)
	reserve.set_escort_target(target)
	reserve.set_physics_process(false)
	for spec in [["WestArcher",Vector3(30,5.02,34),-PI/2],["EastArcher",Vector3(62,5.02,38),PI/2]]:
		var archer := _spawn(ARCHER,guards,spec[0],spec[1])
		archer.rotation.y = spec[2]
	var civilians := _folder("Civilians")
	var points := [Vector3(24,-0.9,52),Vector3(35,-0.9,55),Vector3(48,-0.9,51),Vector3(67,-0.9,54),Vector3(45,-0.9,44),Vector3(73,-0.9,24)]
	for index in points.size():
		var civilian := CIVILIAN.instantiate() as CivilianNPC
		civilian.name = "Worker%d"%index if index < 4 else ("Clerk" if index == 4 else "Courtesan")
		civilian.set_meta(&"mission_entity_id",civilian.name)
		civilian.position = points[index]
		civilian.rotation.y = PI/2 if index%2 == 0 else -PI/2
		civilians.add_child(civilian)
	_abacus = AudioStreamPlayer3D.new()
	_abacus.name = "CountingAbacus"
	_abacus.stream = _abacus_stream()
	_abacus.bus = &"SE"
	_abacus.max_distance = 22
	_abacus.unit_size = 3
	_abacus.volume_db = -8
	_abacus.position = COUNTING_ROOM
	add_child(_abacus)
	EventBus.area_alert_changed.connect(apply_alarm)
	apply_alarm(GameState.area_alert_level)

func _exit_tree() -> void:
	if EventBus.area_alert_changed.is_connected(apply_alarm): EventBus.area_alert_changed.disconnect(apply_alarm)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target): return
	if _alarmed and not target.is_target_defeated() and not target.is_assassinating():
		if target.brain().is_incapacitated(): target.brain().tick(delta)
		else:
			target.advance_navigation(delta,COUNTING_ROOM,2.5)
			target.face_routine_direction(COUNTING_ROOM-target.global_position,delta)
	var counting := not _alarmed and not target.brain().is_incapacitated() and not target.is_target_defeated() and target.routine_action() == &"count" and target.global_position.distance_to(COUNTING_ROOM) < 0.5
	if counting and not _abacus.playing: _abacus.play()
	elif not counting and _abacus.playing: _abacus.stop()

func apply_alarm(level: int) -> void:
	_alarmed = level > 0
	if not is_instance_valid(target): return
	# The merchant flees instead of investigating a stimulus or chasing the player.
	# Damage/assassination APIs remain active, and knockout timers continue above.
	target.brain().set_physics_process(not _alarmed)
	target.combat().set_physics_process(not _alarmed)
	reserve.set_physics_process(_alarmed)
	if _alarmed and _abacus != null: _abacus.stop()

func active_escort_count() -> int:
	return 2 if _alarmed else 1

func _spawn(scene: PackedScene,parent: Node,name_: String,point: Vector3) -> EnemyBase:
	var npc := scene.instantiate() as EnemyBase
	npc.name = name_
	npc.position = point
	npc.set_meta(&"mission_entity_id",name_)
	parent.add_child(npc)
	var agent := npc.get_node("NavigationAgent3D") as NavigationAgent3D
	agent.path_desired_distance = 0.05
	agent.target_desired_distance = 0.15
	return npc

func _folder(name_: String) -> Node3D:
	var folder := Node3D.new()
	folder.name = name_
	add_child(folder)
	return folder

func _assign_routine(npc: EnemyBase,points: Array,starts: Array,period: float,actions: Array,facing := Vector3.FORWARD) -> void:
	var path := PatrolPath.new()
	path.name = "PortRoutine"
	path.top_level = true
	npc.add_child(path)
	for index in points.size():
		var stop := RoutineStop.new()
		stop.route_index = index
		stop.dwell_seconds = 600
		stop.active_from_seconds = starts[index]
		stop.active_until_seconds = starts[index+1] if index+1 < starts.size() else period
		stop.routine_action = actions[index]
		stop.facing_direction = facing
		path.add_child(stop)
		stop.global_position = points[index]
	if npc is TargetNpc:
		(npc as TargetNpc).set_target_routine_path(path)
		(npc as TargetNpc).set_routine_cycle_seconds(period)
	else:
		npc.brain().set_routine_type(&"patrol")
		npc.brain().set_routine_path(path)
		npc.brain().set_routine_cycle_seconds(period)

static func _abacus_stream() -> AudioStreamWAV:
	# Original deterministic wooden bead clicks; no recordings or external samples.
	var rate := 22050
	var samples := PackedByteArray()
	samples.resize(rate*2*2)
	for sample in range(rate*2):
		var time := float(sample)/rate
		var value := 0.0
		for onset in [0.0,0.085,0.24,0.29,0.65,0.79,1.3,1.37]:
			var age: float = time-onset
			if age >= 0 and age < 0.06:
				value += 0.3*sin(age*TAU*1700)*exp(-age*110)+0.15*sin(age*TAU*2700)*exp(-age*180)
		samples.encode_s16(sample*2,int(clampf(value,-0.95,0.95)*32767))
	var stream := AudioStreamWAV.new()
	stream.mix_rate = rate
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.data = samples
	return stream
