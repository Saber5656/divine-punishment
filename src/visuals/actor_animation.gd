class_name ActorAnimation
extends Node3D

## Visual-only skeletal presentation. Never writes actor transforms or collisions.
const SOURCE := "res://assets/animations/quaternius_standard.glb"
const SOURCES := {
	&"idle": &"Idle", &"walk": &"Walk", &"sprint": &"Sprint",
	&"crouch_idle": &"Crouch_Idle", &"crouch_walk": &"Crouch_Fwd",
	&"swim_idle": &"Swim_Idle", &"swim": &"Swim_Fwd",
	&"combat": &"Sword_Idle", &"attack": &"Sword_Attack", &"dodge": &"Roll",
	&"investigate": &"Idle_Talking", &"search": &"Walk_Formal", &"death": &"Death01",
	&"wall_cling": &"Idle", &"climb": &"Walk", &"beam": &"Walk_Formal",
	&"crawl": &"Swim_Fwd", &"hidden": &"Crouch_Idle",
	&"assassination_back": &"Sword_Attack", &"assassination_above": &"Sword_Attack",
	&"assassination_below": &"Swim_Fwd", &"assassination_corner": &"Sword_Attack",
}
const ONESHOTS: Array[StringName] = [&"death", &"attack", &"dodge", &"assassination_back", &"assassination_above", &"assassination_below", &"assassination_corner"]
static var _libraries: Dictionary = {}
static var _models: Dictionary = {}
var _actor: CharacterBody3D
var _skeleton: Skeleton3D
var _player: AnimationPlayer
var _tree: AnimationTree
var _clip: StringName = &""
var _action: StringName = &""
var _action_remaining := 0.0
var _rig: Node3D
var _weapon: BoneAttachment3D

static func player_clip(state: StringName, moving: bool) -> StringName:
	match state:
		&"Crouch": return &"crouch_walk" if moving else &"crouch_idle"
		&"Sprint": return &"sprint"
		&"WallCling": return &"wall_cling"
		&"Climb": return &"climb"
		&"Beam": return &"beam"
		&"Crawlspace": return &"crawl"
		&"SwimSurface", &"SwimUnderwater": return &"swim" if moving else &"swim_idle"
		&"Hidden": return &"hidden"
		&"Assassinate": return &"assassination_back"
		&"Combat": return &"combat"
		&"Dead": return &"death"
	return &"walk" if moving else &"idle"

static func assassination_clip(context: StringName) -> StringName:
	return StringName("assassination_" + str(context)) if context in [&"back", &"above", &"below", &"corner"] else &"assassination_back"

static func enemy_clip(alert: int, moving: bool, dead: bool) -> StringName:
	if dead: return &"death"
	match alert:
		Enums.AlertState.SUSPICIOUS: return &"walk" if moving else &"investigate"
		Enums.AlertState.SEARCHING: return &"search" if moving else &"investigate"
		Enums.AlertState.COMBAT: return &"sprint" if moving else &"combat"
	return &"walk" if moving else &"idle"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	call_deferred("_setup")

func _setup() -> void:
	_actor = get_parent().get_parent() as CharacterBody3D
	if _actor == null: return
	for child in get_children():
		if child is MeshInstance3D: child.free()
	var role := "shinobi" if _actor is PlayerController else ("magistrate" if _actor is TargetNpc else "ashigaru")
	if not _models.has(role): _models[role] = load("res://assets/characters/%s.glb" % role)
	_rig = _models[role].instantiate() as Node3D
	_rig.name = "Rig"
	add_child(_rig)
	rotation.y = PI
	_skeleton = _rig.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_build_weapon()
	_player = AnimationPlayer.new()
	_player.name = "AnimationPlayer"
	add_child(_player)
	if not _libraries.has(role): _libraries[role] = _build_library()
	_player.add_animation_library(&"", _libraries[role])
	_build_tree()
	var combat := _actor.get_node_or_null("Combat")
	if combat != null:
		if combat.has_signal(&"attack_started"):
			combat.connect(&"attack_started", func(_value): _play_action(&"attack", 0.6))
		if combat.has_signal(&"dodge_started"):
			combat.connect(&"dodge_started", func(_value): _play_action(&"dodge", 0.6))
	var presentation := _actor.get_node_or_null("AssassinationResolver/AssassinationPresentation")
	if presentation != null:
		presentation.connect(&"animation_requested", func(_context, clip): _play_action(clip, presentation.duration_sec))
	show_clip(&"idle")

func _build_library() -> AnimationLibrary:
	var source = load(SOURCE).instantiate()
	var source_skeleton := source.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var source_player := source.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var library := AnimationLibrary.new()
	for name in SOURCES:
		var animation := source_player.get_animation(SOURCES[name]).duplicate(true) as Animation
		_retarget(animation, source_skeleton)
		animation.loop_mode = Animation.LOOP_NONE if name in ONESHOTS else Animation.LOOP_LINEAR
		_author_traversal(animation, name)
		library.add_animation(name, animation)
	source.free()
	return library

func _retarget(animation: Animation, source: Skeleton3D) -> void:
	for track in range(animation.get_track_count() - 1, -1, -1):
		var old_path := animation.track_get_path(track)
		if old_path.get_subname_count() != 1:
			animation.remove_track(track)
			continue
		var bone := old_path.get_subname(0)
		var source_index := source.find_bone(bone)
		var target_index := _skeleton.find_bone(bone)
		if source_index < 0 or target_index < 0:
			animation.remove_track(track)
			continue
		animation.track_set_path(track, NodePath(str(get_path_to(_skeleton)) + ":" + str(bone)))
		var source_rest := source.get_bone_rest(source_index)
		var target_rest := _skeleton.get_bone_rest(target_index)
		for key in range(animation.track_get_key_count(track)):
			match animation.track_get_type(track):
				Animation.TYPE_ROTATION_3D:
					var value: Quaternion = animation.track_get_key_value(track, key)
					var rotation_delta := source_rest.basis.get_rotation_quaternion().inverse() * value
					animation.track_set_key_value(track, key, (target_rest.basis.get_rotation_quaternion() * rotation_delta).normalized())
				Animation.TYPE_POSITION_3D:
					var value: Vector3 = animation.track_get_key_value(track, key)
					var offset := value - source_rest.origin
					if bone == &"root": offset = Vector3.ZERO
					animation.track_set_key_value(track, key, target_rest.origin + offset)

func _author_traversal(animation: Animation, name: StringName) -> void:
	# Add original local skeletal rotations to the licensed base motion. These
	# tracks move bones only; gameplay keeps ownership of climbing and strikes.
	if name == &"wall_cling":
		_offset_rotation(animation, &"upperarm_l", Vector3.FORWARD, -0.65)
		_offset_rotation(animation, &"upperarm_r", Vector3.FORWARD, 0.65)
	elif name == &"climb":
		_aim_bone(animation, &"upperarm_l", Vector3(0.15, 0.98, 0.05))
		_aim_bone(animation, &"upperarm_r", Vector3(-0.15, 0.98, 0.05))
	elif name == &"beam":
		_aim_bone(animation, &"upperarm_l", Vector3.RIGHT)
		_aim_bone(animation, &"upperarm_r", Vector3.LEFT)
	elif name == &"crawl":
		_offset_rotation(animation, &"spine_03", Vector3.RIGHT, 0.12)
	elif name == &"assassination_above":
		_offset_rotation(animation, &"pelvis", Vector3.RIGHT, -0.65)
	elif name == &"assassination_below":
		_aim_bone(animation, &"upperarm_r", Vector3(0.1, 1.0, 0.1))
	elif name == &"assassination_corner":
		_offset_rotation(animation, &"spine_03", Vector3.UP, -0.75)
	if str(name).begins_with("assassination_"):
		var scale_time := 1.25 / animation.length
		for track in range(animation.get_track_count()):
			for key in range(animation.track_get_key_count(track)):
				animation.track_set_key_time(track, key, animation.track_get_key_time(track, key) * scale_time)
		animation.length = 1.25

func _offset_rotation(animation: Animation, bone: StringName, axis: Vector3, angle: float) -> void:
	var path := NodePath(str(get_path_to(_skeleton)) + ":" + str(bone))
	var track := animation.find_track(path, Animation.TYPE_ROTATION_3D)
	if track < 0:
		track = animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(track, path)
		animation.rotation_track_insert_key(track, 0.0, _skeleton.get_bone_rest(_skeleton.find_bone(bone)).basis.get_rotation_quaternion())
	for key in range(animation.track_get_key_count(track)):
		var value: Quaternion = animation.track_get_key_value(track, key)
		animation.track_set_key_value(track, key, (value * Quaternion(axis, angle)).normalized())

func _aim_bone(animation: Animation, bone: StringName, direction: Vector3) -> void:
	var path := NodePath(str(get_path_to(_skeleton)) + ":" + str(bone))
	var track := animation.find_track(path, Animation.TYPE_ROTATION_3D)
	if track < 0: return
	var index := _skeleton.find_bone(bone)
	var parent := _skeleton.get_bone_parent(index)
	for key in range(animation.track_get_key_count(track)):
		var value: Quaternion = animation.track_get_key_value(track, key)
		var parent_rotation := _animated_rotation(animation, parent, animation.track_get_key_time(track, key))
		var current_direction := (parent_rotation * value) * Vector3.UP
		var turn := Quaternion(current_direction.normalized(), direction.normalized())
		animation.track_set_key_value(track, key, (parent_rotation.inverse() * turn * parent_rotation * value).normalized())

func _animated_rotation(animation: Animation, index: int, time: float) -> Quaternion:
	if index < 0: return Quaternion.IDENTITY
	var path := NodePath(str(get_path_to(_skeleton)) + ":" + _skeleton.get_bone_name(index))
	var track := animation.find_track(path, Animation.TYPE_ROTATION_3D)
	var local := _skeleton.get_bone_rest(index).basis.get_rotation_quaternion()
	if track >= 0: local = animation.rotation_track_interpolate(track, time)
	return _animated_rotation(animation, _skeleton.get_bone_parent(index), time) * local

func _build_weapon() -> void:
	_weapon = BoneAttachment3D.new()
	_weapon.name = "Weapon"
	_weapon.bone_name = "hand_r"
	_skeleton.add_child(_weapon)
	# Original simple short blade, bound to the hand rather than gameplay space.
	for part in [Vector3(0.035, 0.012, 0.6), Vector3(0.12, 0.025, 0.025), Vector3(0.035, 0.035, 0.14)]:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = part
		mesh.mesh = box
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.65, 0.7, 0.76) if part.z > 0.2 else Color(0.15, 0.12, 0.08)
		material.metallic = 0.75 if part.z > 0.2 else 0.0
		material.roughness = 0.35
		mesh.material_override = material
		mesh.position = Vector3(0, 0.06, -0.37 if part.z > 0.2 else (-0.07 if part.x > 0.1 else 0.0))
		_weapon.add_child(mesh)

func _build_tree() -> void:
	var graph := AnimationNodeBlendTree.new()
	var transition := AnimationNodeTransition.new()
	transition.set_input_count(SOURCES.size())
	transition.xfade_time = 0.1
	graph.add_node(&"state", transition)
	var index := 0
	for name in SOURCES:
		var node := AnimationNodeAnimation.new()
		node.animation = name
		graph.add_node(name, node)
		transition.set_input_name(index, name)
		graph.connect_node(&"state", index, name)
		index += 1
	graph.connect_node(&"output", 0, &"state")
	_tree = AnimationTree.new()
	_tree.name = "AnimationTree"
	_tree.tree_root = graph
	add_child(_tree)
	_tree.anim_player = _tree.get_path_to(_player)
	_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_tree.active = true

func _process(delta: float) -> void:
	update_actor_presentation(delta)

func update_actor_presentation(delta: float) -> void:
	if _tree == null or not is_instance_valid(_actor): return
	_action_remaining = maxf(0.0, _action_remaining - delta)
	var next: StringName
	var moving := _actor.velocity.length_squared() > 0.01
	if _actor is PlayerController:
		var state: StringName = _actor.state_machine.current_state()
		next = player_clip(state, moving)
		if state == &"Assassinate" and str(_action).begins_with("assassination_"): next = _action
		visible = state != &"Hidden"
	else:
		var brain: EnemyBrain = _actor.brain()
		var dead: bool = _actor.is_assassinated() or (brain != null and brain.incapacitated_kind() == &"dead")
		next = enemy_clip(_actor.alert_state(), moving, dead)
	if _action_remaining > 0.0 and next != &"death": next = _action
	show_clip(next)
	advance_visual(delta)

func show_clip(clip: StringName) -> void:
	if _tree == null: return
	if not SOURCES.has(clip): clip = &"idle"
	if clip == _clip: return
	_clip = clip
	_weapon.visible = clip in [&"combat", &"attack"] or str(clip).begins_with("assassination_")
	_tree.set("parameters/state/transition_request", clip)

func advance_visual(delta: float) -> void:
	if _tree == null or not is_finite(delta) or delta < 0.0: return
	_tree.advance(delta)
	var shape_node := _actor.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node != null and shape_node.shape is CapsuleShape3D:
		position.y = 0.0 if _clip in [&"crawl", &"swim", &"swim_idle", &"assassination_below"] else -shape_node.shape.height * 0.5

func bone_pose(bone: StringName) -> Transform3D:
	return _skeleton.get_bone_pose(_skeleton.find_bone(bone)) if _skeleton != null else Transform3D.IDENTITY

func current_clip() -> StringName:
	return _clip

func _play_action(clip: StringName, duration: float) -> void:
	_action = clip
	_action_remaining = duration
	show_clip(clip)
