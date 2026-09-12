extends Node3D

const GUARD := preload("res://src/enemies/enemy_base.tscn")
const TARGET := preload("res://src/enemies/target_npc.tscn")
const NAVIGATION := preload("res://src/levels/festival_night/festival_navigation.gd")
const DAIS := Vector3(84,3.02,32)
const PRAYER := Vector3(51,3.02,17)
const SHRINE_ESCORTS := [Vector3(48,3.02,19),Vector3(54,3.02,19)]
const EXTERIOR_ESCORTS := [Vector3(47,0.02,31),Vector3(55,0.02,31)]
@export var tuning: FestivalTuning = preload("res://data/tuning/festival.tres")
var target: TargetNpc
var escorts: Array[EnemyBase] = []
var doshin: Array[EnemyBase] = []
var civilians: Array[CivilianNPC] = []
var _elapsed: float = 0.0
var _prayer_stage: int = 0
var _prayer_elapsed: float = 0.0
var _previous_phase: StringName = &""
var _previous_cycle: int = -1

func _ready() -> void:
	process_priority = 10
	NAVIGATION.build(self,get_parent().get_node("Geometry"))
	var patrols := _folder("Doshin")
	for spec in [
		["SouthWest",Vector3(39,0.02,70),Vector3(39,0.02,60)],
		["SouthEast",Vector3(58,0.02,76),Vector3(58,0.02,60)],
		["MiddleWest",Vector3(40,0.02,52),Vector3(40,0.02,42)],
		["MiddleEast",Vector3(58,0.02,50),Vector3(58,0.02,40)],
		["ShrineWest",Vector3(42,0.02,31),Vector3(46,0.02,31)],
		["ShrineEast",Vector3(58,0.02,30),Vector3(58,0.02,35)],
		["DaisEast",Vector3(96,0.02,34),Vector3(96,0.02,44)],
		["RearAlley",Vector3(72,0.02,23),Vector3(64,0.02,23)]
	]:
		var npc := _spawn(GUARD,patrols,spec[0],spec[1])
		doshin.append(npc)
		_assign(npc,[spec[1],spec[2]],tuning.patrol_dwell_seconds)
	target = _spawn(TARGET,self,"Kurosawa",DAIS) as TargetNpc
	target.add_to_group(&"m05_target")
	_assign(target,[DAIS],RoutineStop.MAX_DWELL_SECONDS)
	var guards := _folder("Escorts")
	for index in range(2):
		var point := Vector3(82+index*4,3.02,30)
		var escort := _spawn(GUARD,guards,"Escort"+str(index),point)
		escorts.append(escort)
		_assign(escort,[point],RoutineStop.MAX_DWELL_SECONDS)
	var crowds := _folder("Crowds")
	_add_crowd(crowds,"Introduction",[Vector3(24,-0.9,80),Vector3(48,-0.9,76),Vector3(48,-0.9,40),Vector3(52,-0.9,40),Vector3(52,-0.9,78),Vector3(24,-0.9,80)])
	_add_crowd(crowds,"Stalls",[Vector3(48,-0.9,36),Vector3(56,-0.9,36),Vector3(56,-0.9,54),Vector3(48,-0.9,54),Vector3(48,-0.9,36)])
	var visitors := _folder("Visitors")
	for point in [Vector3(39,-0.9,67),Vector3(59,-0.9,55)]:
		var civilian := CivilianNPC.new()
		civilian.name = "Visitor"+str(visitors.get_child_count())
		civilian.position = point
		civilian.set_meta(&"mission_entity_id",civilian.name)
		visitors.add_child(civilian)
		civilians.append(civilian)
	advance_schedule(0.0)

func _physics_process(delta: float) -> void:
	advance_schedule(delta)

static func phase_at(elapsed: float,durations: Vector3) -> StringName:
	if not is_finite(elapsed) or elapsed < 0.0 or not durations.is_finite() or durations.x <= 0.0 or durations.y <= 0.0 or durations.z <= 0.0: return &""
	var cycle := durations.x+durations.y+durations.z
	if not is_finite(cycle): return &""
	var time := fmod(elapsed,cycle)
	return &"dais" if time < durations.x else (&"shrine" if time < durations.x+durations.y else &"stalls")

func phase() -> StringName:
	return phase_at(_elapsed,tuning.durations())

func schedule_elapsed() -> float:
	return _elapsed

func prayer_elapsed() -> float:
	return _prayer_elapsed

func prayer_active() -> bool:
	return phase() == &"shrine" and _prayer_stage == 2 and _prayer_ready()

func important_actors() -> Array[EnemyBase]:
	return [target,escorts[0],escorts[1]]

func advance_schedule(delta: float) -> bool:
	if not is_finite(delta) or delta < 0.0 or delta > 86400.0: return false
	_elapsed = minf(_elapsed+delta,86399.0)
	var current := phase()
	if current == &"": return false
	var cycle := int(_elapsed/tuning.cycle_seconds())
	if current != _previous_phase or cycle != _previous_cycle:
		_prayer_stage = 0
		_prayer_elapsed = 0.0
	_previous_phase = current
	_previous_cycle = cycle
	if current == &"dais":
		_goal(target,DAIS,&"watch")
		for index in escorts.size(): _goal(escorts[index],Vector3(82+index*4,3.02,30),&"guard")
	elif current == &"stalls":
		var local_time := fmod(_elapsed,tuning.cycle_seconds())-tuning.dais_seconds-tuning.shrine_seconds
		var point := Vector3(48,0.02,56) if local_time < tuning.stalls_seconds/2 else Vector3(58,0.02,42)
		_goal(target,point,&"browse")
		for index in escorts.size(): _goal(escorts[index],point+Vector3(-2+index*4,0,0),&"escort")
	else:
		_advance_shrine(delta)
	return true

func _advance_shrine(delta: float) -> void:
	if _prayer_stage == 0:
		_goal(target,PRAYER,&"approach_shrine")
		for index in escorts.size(): _goal(escorts[index],SHRINE_ESCORTS[index],&"escort")
		if _arrived(target,PRAYER) and _arrived(escorts[0],SHRINE_ESCORTS[0]) and _arrived(escorts[1],SHRINE_ESCORTS[1]): _prayer_stage = 1
	if _prayer_stage in [1,2]:
		for index in escorts.size(): _goal(escorts[index],EXTERIOR_ESCORTS[index],&"wait_outside")
		if _prayer_stage == 1 and _prayer_ready():
			_prayer_stage = 2
			_goal(target,PRAYER,&"pray")
		elif _prayer_stage == 2:
			_prayer_elapsed = minf(_prayer_elapsed+delta,tuning.prayer_seconds) if _prayer_ready() else 0.0
			if _prayer_elapsed >= tuning.prayer_seconds: _prayer_stage = 3
	if _prayer_stage == 3:
		_goal(target,Vector3(51,3.02,24),&"leave_prayer")
		for index in escorts.size(): _goal(escorts[index],Vector3(48+index*6,3.02,24),&"escort")

func _prayer_ready() -> bool:
	return _arrived(target,PRAYER) and _arrived(escorts[0],EXTERIOR_ESCORTS[0]) and _arrived(escorts[1],EXTERIOR_ESCORTS[1])

func _arrived(npc: EnemyBase,point: Vector3) -> bool:
	return is_instance_valid(npc) and not npc.is_defeated() and not npc.brain().is_incapacitated() and npc.brain().alert_state() == Enums.AlertState.UNAWARE and npc.global_position.distance_to(point) <= tuning.arrival_tolerance

func _goal(npc: EnemyBase,point: Vector3,action: StringName) -> void:
	if not is_instance_valid(npc): return
	var stop := npc.current_routine_stop()
	if stop == null: return
	stop.global_position = point
	stop.routine_action = action
	stop.facing_direction = Vector3.FORWARD

func _spawn(scene: PackedScene,parent: Node,label: String,point: Vector3) -> EnemyBase:
	var npc := scene.instantiate() as EnemyBase
	npc.name = label
	npc.position = point
	npc.set_meta(&"mission_entity_id",label)
	parent.add_child(npc)
	var agent := npc.get_node("NavigationAgent3D") as NavigationAgent3D
	agent.path_desired_distance = 0.1
	agent.target_desired_distance = 0.15
	return npc

func _assign(npc: EnemyBase,points: Array,dwell: float) -> void:
	var path := PatrolPath.new()
	path.name = "FestivalRoutine"
	path.top_level = true
	npc.add_child(path)
	path.global_position = Vector3(54,0,48)
	if points.size() == 1:
		# A single dynamic goal still needs real authored path geometry.
		# The preview follows the ordinary stairs; Brain uses the RoutineStop.
		path.curve = Curve3D.new()
		for point: Vector3 in [points[0],Vector3(76,3.02,32),Vector3(68,0.02,32),Vector3(51,0.02,33),Vector3(51,3.02,25),PRAYER]:
			path.curve.add_point(path.to_local(point))
	for index in points.size():
		var stop := RoutineStop.new()
		stop.route_index = index
		stop.dwell_seconds = dwell
		path.add_child(stop)
		stop.global_position = points[index]
	if npc is TargetNpc: (npc as TargetNpc).set_target_routine_path(path)
	else:
		npc.brain().set_routine_type(&"patrol")
		npc.brain().set_routine_path(path)
	npc.brain().set_routine_cycle_seconds(tuning.cycle_seconds())

func _add_crowd(parent: Node,label: String,points: Array) -> void:
	var crowd := CrowdHideSpot.new()
	crowd.name = label
	crowd.position = points[0]
	crowd.route_speed = tuning.crowd_speed
	crowd.route = Curve3D.new()
	for point: Vector3 in points: crowd.route.add_point(point)
	parent.add_child(crowd)
	for index in crowd.members.size():
		crowd.members[index].set_meta(&"mission_entity_id",label+str(index))
		civilians.append(crowd.members[index])

func _folder(label: String) -> Node3D:
	var folder := Node3D.new()
	folder.name = label
	add_child(folder)
	return folder
