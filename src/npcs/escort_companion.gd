class_name EscortCompanion
extends ProtectedNPC

var _leader: PlayerController
var _following := false
var _navigation: NavigationAgent3D
var _prompt: Label3D

func _ready() -> void:
	super._ready()
	soft_deadline_seconds = 0.0
	add_to_group(&"escort_companions")
	_navigation = NavigationAgent3D.new()
	_navigation.navigation_layers = 1|4
	_navigation.path_desired_distance = 0.2
	_navigation.target_desired_distance = 0.3
	# NPC origins are at their feet; the shared navigation mesh is at actor center height.
	var navigation_anchor := Node3D.new()
	navigation_anchor.position.y = 0.9
	add_child(navigation_anchor)
	navigation_anchor.add_child(_navigation)
	_prompt = Label3D.new()
	_prompt.font = load("res://assets/fonts/NotoSerifJP.ttf")
	_prompt.font_size = 48
	_prompt.pixel_size = 0.003
	_prompt.position.y = 2.0
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_prompt)

func follow(player: PlayerController) -> bool:
	if is_defeated() or not is_instance_valid(player) or global_position.distance_to(player.global_position) > 3.0: return false
	if player.state_machine.current_state() not in [&"Ground",&"Crouch",&"Escort"]: return false
	var existing = player.get_meta(&"escort_companion") if player.has_meta(&"escort_companion") else null
	if is_instance_valid(existing) and existing != self: return false
	if not player.state_machine.change_state(&"Escort"): return false
	_leader = player
	_following = true
	player.state_machine.escort_active = true
	player.set_meta(&"escort_companion",self)
	rescue()
	return true

func wait_here() -> void:
	_following = false
	if is_instance_valid(_leader):
		_leader.state_machine.escort_active = false
		if _leader.has_meta(&"escort_companion"): _leader.remove_meta(&"escort_companion")
		if _leader.state_machine.current_state() == &"Escort": _leader.state_machine.change_state(&"Ground")
	_leader = null
	show()
	collision_layer = 1 << 8 if is_defeated() else 1 << 3
	collision_mask = 1

func _exit_tree() -> void:
	wait_here()

func _physics_process(delta: float) -> void:
	advance_follow(delta)

func advance_follow(delta: float) -> void:
	if is_defeated():
		wait_here()
		return
	if not _following or not is_instance_valid(_leader) or not is_finite(delta) or delta <= 0.0: return
	var hidden := _leader.is_hidden()
	visible = not hidden
	collision_layer = 0 if hidden else 1 << 3
	collision_mask = 0 if hidden else 1
	if hidden: return
	var crawling := _leader.state_machine.current_state() == &"Crawlspace"
	var shape := get_node("BodyCollision") as CollisionShape3D
	(shape.shape as CapsuleShape3D).height = 0.6 if crawling else 1.65
	shape.position.y = 0.3 if crawling else 0.825
	(_body.mesh as CapsuleMesh).height = 0.6 if crawling else 1.65
	_body.position.y = shape.position.y
	if not EnemyBase._navigation_map_ready(_navigation): return
	var target := _leader.global_position+_leader.global_basis.z*0.8
	if _navigation.get_current_navigation_path().is_empty() or not _navigation.target_position.is_equal_approx(target): _navigation.target_position = target
	var next := _navigation.get_next_path_position()-Vector3.UP*0.9
	var offset := next-global_position
	if global_position.distance_to(_leader.global_position) < 0.9 or offset.length_squared() < 0.0001: return
	move_and_collide(offset.normalized()*minf(2.2*minf(delta,0.1),offset.length()),false,0.001)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"escort_command") or is_defeated(): return
	var player := get_tree().get_first_node_in_group(&"player") as PlayerController
	if player == null or player.is_hidden() or global_position.distance_to(player.global_position) > 3.0: return
	for other in get_tree().get_nodes_in_group(&"escort_companions"):
		if other != self and not other.is_defeated() and other.global_position.distance_to(player.global_position) < global_position.distance_to(player.global_position): return
	if _following: wait_here()
	else: follow(player)
	get_viewport().set_input_as_handled()

func is_visibility_excluded() -> bool:
	return _following and is_instance_valid(_leader) and _leader.is_hidden()

func _process(_delta: float) -> void:
	if _prompt == null: return
	var player := get_tree().get_first_node_in_group(&"player") as PlayerController
	_prompt.visible = not is_defeated() and player != null and global_position.distance_to(player.global_position) <= 3.0
	if _prompt.visible: _prompt.text = GameText.with_bindings(&"npc.escort_command")
