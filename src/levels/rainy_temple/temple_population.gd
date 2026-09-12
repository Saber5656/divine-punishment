extends Node3D

const HALL := Vector3(51,8.02,22)
const CELL := Vector3(78,5.02,28)
const SUTRA_CYCLE := 36.0
const GUARD := preload("res://src/enemies/enemy_base.tscn")
const TARGET := preload("res://src/enemies/target_npc.tscn")
const NAVIGATION := preload("res://src/levels/rainy_temple/temple_navigation.gd")
@export var target_scene: PackedScene = TARGET
var _elapsed := 0.0
var target: TargetNpc
var monks: Array[EnemyBase] = []
var _sutra_bell: AudioStreamPlayer3D

func _ready() -> void:
	# Reconcile after ordinary Brain ticks; no AI state or perception is suspended.
	process_priority = 10
	WeatherSystem.start(MissionDefinition.Weather.RAIN)
	NAVIGATION.build(self,get_parent().get_node("Geometry"))
	var folder := Node3D.new()
	folder.name = "Monks"
	add_child(folder)
	for spec in [
		["GateWest",Vector3(44,4.02,64),Vector3(44,4.02,56)],
		["GateEast",Vector3(52,4.02,64),Vector3(52,4.02,56)],
		["CourtWest",Vector3(40,4.02,54),Vector3(40,4.02,44)],
		["CourtEast",Vector3(60,4.02,56),Vector3(60,4.02,44)],
		["Graveyard",Vector3(16,4.02,62),Vector3(22,4.02,62)],
		["Bell",Vector3(26,4.02,58),Vector3(30,4.02,54)],
		["Lodging",Vector3(27,4.02,46),Vector3(27,4.02,54)],
		["HallFront",Vector3(54,8.02,29),Vector3(62,8.02,29)]
	]:
		var monk := _spawn(GUARD,folder,spec[0],spec[1],true)
		monks.append(monk)
		_assign(monk,[spec[1],spec[2],spec[1]],[0.0,4.0,20.0],SUTRA_CYCLE,[&"chant",&"walk",&"walk"])
	target = _spawn(target_scene,self,"Tetsusenbo",HALL) as TargetNpc
	target.add_to_group(&"m04_target")
	_assign(target,[HALL,CELL],[0.0,720.0],86400.0,[&"train",&"inspect"])
	var guard := _spawn(GUARD,self,"CellGuard",Vector3(80,5.02,35))
	_assign(guard,[Vector3(80,5.02,35)],[0.0],86400.0,[&"stand"])
	_sutra_bell = AudioStreamPlayer3D.new()
	_sutra_bell.name = "SutraBell"
	_sutra_bell.position = Vector3(26,6,54)
	_sutra_bell.stream = _bell_stream()
	_sutra_bell.bus = &"SE"
	_sutra_bell.unit_size = 20
	_sutra_bell.max_distance = 100
	_sutra_bell.volume_db = -5
	add_child(_sutra_bell)
	advance_schedule(0.0)

func _physics_process(delta: float) -> void:
	advance_schedule(delta)

func schedule_elapsed() -> float:
	return _elapsed

func restore_schedule_elapsed(value: float) -> bool:
	if not is_finite(value) or value < 0.0 or value > 86399.0: return false
	_elapsed = value
	return advance_schedule(0.0)

func advance_schedule(delta: float) -> bool:
	if not is_finite(delta) or delta < 0.0: return false
	_elapsed = minf(_elapsed+delta,86399.0)
	for monk in monks:
		if not is_instance_valid(monk): continue
		monk.brain().synchronize_routine_clock(fmod(_elapsed,SUTRA_CYCLE))
		var stop := monk.current_routine_stop()
		if stop != null and stop.routine_action == &"chant":
			# Chant where the current patrol reached; never drag an actor back home.
			stop.global_position = monk.global_position
			var toward := HALL-monk.global_position
			toward.y = 0
			stop.facing_direction = toward.normalized()
	if is_instance_valid(target): target.brain().synchronize_routine_clock(_elapsed)
	if _sutra_bell != null:
		var chanting := fmod(_elapsed,SUTRA_CYCLE) <= 4.0
		if chanting and not _sutra_bell.playing: _sutra_bell.play()
		elif not chanting and _sutra_bell.playing: _sutra_bell.stop()
	return true

func _spawn(scene: PackedScene,parent: Node,name_: String,point: Vector3,umbrella := false) -> EnemyBase:
	var npc := scene.instantiate() as EnemyBase
	npc.name = name_
	npc.position = point
	npc.set_meta(&"mission_entity_id",name_)
	if umbrella:
		var vision := npc.get_node("Perception") as EnemyPerception
		vision.perception_config = vision.perception_config.duplicate()
		vision.perception_config.view_distance_m *= 0.8
	parent.add_child(npc)
	var agent := npc.get_node("NavigationAgent3D") as NavigationAgent3D
	agent.path_desired_distance = 0.1
	agent.target_desired_distance = 0.15
	return npc

func _assign(npc: EnemyBase,points: Array,starts: Array,period: float,actions: Array) -> void:
	var path := PatrolPath.new()
	path.name = "TempleRoutine"
	path.top_level = true
	npc.add_child(path)
	for index in points.size():
		var stop := RoutineStop.new()
		stop.route_index = index
		stop.dwell_seconds = 600
		stop.active_from_seconds = starts[index]
		stop.active_until_seconds = starts[index+1] if index+1 < starts.size() else period
		stop.routine_action = actions[index]
		path.add_child(stop)
		stop.global_position = points[index]
	if npc is TargetNpc:
		(npc as TargetNpc).set_target_routine_path(path)
		(npc as TargetNpc).set_routine_cycle_seconds(period)
	else:
		npc.brain().set_routine_type(&"patrol")
		npc.brain().set_routine_path(path)
		npc.brain().set_routine_cycle_seconds(period)

static func _bell_stream() -> AudioStreamWAV:
	# Original four-second bronze-like partials; the cue is ordinary ambience.
	var rate := 22050
	var samples := PackedByteArray()
	samples.resize(rate*4*2)
	for sample in range(rate*4):
		var time := float(sample)/rate
		var value := 0.0
		for partial in [[110.0,0.45,0.9],[233.0,0.25,1.3],[317.0,0.12,1.8],[521.0,0.08,2.5]]:
			value += sin(time*TAU*partial[0])*partial[1]*exp(-time*partial[2])
		samples.encode_s16(sample*2,int(value*minf(time*200,1.0)*32767))
	var stream := AudioStreamWAV.new()
	stream.mix_rate = rate
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.data = samples
	return stream
