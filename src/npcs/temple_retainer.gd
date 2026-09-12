class_name TempleRetainer
extends ProtectedNPC

const ESCAPE := Vector3(12,0.02,88)
const SPEED := 1.4
var escaped := false
var _anchor: Node3D
var _agent: NavigationAgent3D

func _ready() -> void:
	super._ready()
	soft_deadline_seconds = 0.0
	# Civilian origins are at their feet; navigation follows a capsule centre.
	_anchor = Node3D.new()
	_anchor.name = "NavigationAnchor"
	_anchor.position.y = 0.9
	add_child(_anchor)
	_agent = NavigationAgent3D.new()
	_agent.path_desired_distance = 0.1
	_agent.target_desired_distance = 0.15
	_anchor.add_child(_agent)

func _physics_process(delta: float) -> void:
	advance_escape(delta)

func advance_escape(delta: float) -> void:
	if not rescued or escaped or is_defeated() or not is_finite(delta) or delta <= 0.0: return
	if not EnemyBase._navigation_map_ready(_agent): return
	if _anchor.global_position.distance_to(ESCAPE) < 0.5:
		escaped = true
		visible = false
		collision_layer = 0
		EventBus.mission_event.emit(&"temple_retainer_escaped",{"id":String(npc_id)})
		return
	if _agent.get_current_navigation_path().is_empty() or not _agent.target_position.is_equal_approx(ESCAPE):
		_agent.target_position = ESCAPE
	var candidate := _agent.get_next_path_position()
	if not EnemyBase._navigation_point_is_valid(_agent,candidate): return
	var motion := candidate-_anchor.global_position
	if not motion.is_finite() or motion.length_squared() < 0.000001: return
	move_and_collide(motion.limit_length(SPEED*minf(delta,0.25)))

func receive_combat_damage(amount: int,source: Node = null) -> int:
	if escaped: return 0
	return super.receive_combat_damage(amount,source)
