extends Node3D

const GATHER_SECONDS := 60.0
const EXECUTION_START := 720.0
const PARTY_NAMES := [&"CourtWest",&"CourtEast"]
const EXECUTION_POINTS := [Vector3(76,5.02,35),Vector3(82,5.02,35)]
var _population: Node3D
var _actors: Array[EnemyBase] = []
var _routes: Dictionary = {}
var _gather_used := false
var _gather_until := 0.0
var _bell: AudioStreamPlayer3D

func _ready() -> void:
	process_priority = 20
	_population = get_parent()
	for actor in _population.get_node("Monks").get_children(): _actors.append(actor as EnemyBase)
	_actors.append(_population.get_node("Tetsusenbo") as EnemyBase)
	_actors.append(_population.get_node("CellGuard") as EnemyBase)
	for index in _actors.size():
		var actor := _actors[index]
		var path := actor.patrol_path()
		var count := path.ordered_stops().size()
		var gather := _stop(path,count,gathering_point(actor),&"gather")
		var party_index := PARTY_NAMES.find(actor.name)
		var destination: Vector3 = EXECUTION_POINTS[party_index] if party_index >= 0 else gathering_point(actor)
		var execute := _stop(path,count+1,destination,&"execute")
		_routes[actor] = {"normal_count":count,"mode":&"normal","gather":gather,"execute":execute}
	_bell = AudioStreamPlayer3D.new()
	_bell.name = "GatheringBell"
	_bell.stream = load("res://assets/audio/bell.wav")
	_bell.position = Vector3(26,6,54)
	_bell.bus = &"SE"
	_bell.unit_size = 20
	_bell.max_distance = 100
	add_child(_bell)

func _physics_process(_delta: float) -> void:
	advance_duties()

func actors() -> Array[EnemyBase]:
	return _actors.duplicate()

func capture_checkpoint_state() -> Dictionary:
	return {"gather_used":_gather_used,"gather_until":_gather_until}

func checkpoint_state_is_valid(value: Dictionary,elapsed: float) -> bool:
	if not value.get("gather_used") is bool or not CheckpointSnapshot._finite_number(value.get("gather_until")): return false
	var until := float(value["gather_until"])
	return (until >= GATHER_SECONDS and until <= minf(elapsed+GATHER_SECONDS,86400.0)) if value["gather_used"] else until == 0.0

func restore_checkpoint_state(value: Dictionary) -> bool:
	if not checkpoint_state_is_valid(value,_elapsed()): return false
	_gather_used = value["gather_used"]
	_gather_until = float(value["gather_until"])
	_bell.stop()
	# Restore route gates even when the currently dead actor will be revived.
	for actor in _actors:
		_routes[actor].mode = &""
		var mode: StringName = &"gather" if _gather_used and _elapsed() < _gather_until else (&"execute" if execution_started() and actor.name in PARTY_NAMES else &"normal")
		_apply_mode(actor,mode)
	return true

func gathering_point(actor: EnemyBase) -> Vector3:
	var index := _actors.find(actor)
	return Vector3(39+(index%5)*5,8.02,25+(index/5)*4)

func use_bell() -> bool:
	if _gather_used: return false
	_gather_used = true
	_gather_until = minf(_elapsed()+GATHER_SECONDS,86400.0)
	GameState.area_alert_level = mini(GameState.area_alert_level+1,5)
	EventBus.area_alert_changed.emit(GameState.area_alert_level)
	EventBus.mission_event.emit(&"temple_bell_rung",{"area_alert":GameState.area_alert_level})
	_bell.play()
	advance_duties()
	return true

func execution_started() -> bool:
	return _elapsed() >= EXECUTION_START

func execution_ready(index: int) -> bool:
	if index < 0 or index >= PARTY_NAMES.size() or not execution_started(): return false
	var actor := _population.get_node("Monks/"+str(PARTY_NAMES[index])) as EnemyBase
	return not actor.brain().is_incapacitated() and actor.brain().alert_state() == Enums.AlertState.UNAWARE and _routes[actor].mode == &"execute" and actor.global_position.distance_to(EXECUTION_POINTS[index]) < 1.0

func advance_duties() -> void:
	var gathering := _gather_used and _elapsed() < _gather_until
	for actor in _actors:
		if actor.is_defeated() or actor.brain().incapacitated_kind() == &"dead": continue
		var mode: StringName = &"gather" if gathering else (&"execute" if execution_started() and actor.name in PARTY_NAMES else &"normal")
		_apply_mode(actor,mode)

func _apply_mode(actor: EnemyBase,mode: StringName) -> void:
	var route: Dictionary = _routes[actor]
	if route.mode == mode: return
	var stops := actor.patrol_path().ordered_stops()
	for index in int(route.normal_count): stops[index].enabled = mode == &"normal"
	(route.gather as RoutineStop).enabled = mode == &"gather"
	(route.execute as RoutineStop).enabled = mode == &"execute"
	route.mode = mode
	actor.brain().synchronize_routine_clock(actor.brain().routine_clock())

func _stop(path: PatrolPath,index: int,point: Vector3,action: StringName) -> RoutineStop:
	var stop := RoutineStop.new()
	stop.route_index = index
	stop.routine_action = action
	stop.dwell_seconds = 600
	stop.enabled = false
	path.add_child(stop)
	stop.global_position = point
	return stop

func _elapsed() -> float:
	return float(_population.call("schedule_elapsed"))
