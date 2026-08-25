class_name AssassinationResolver
extends Node


const AssassinationConfigScript := preload("res://src/core/tuning/assassination_config.gd")
const DEFAULT_CONFIG_PATH := "res://data/tuning/assassination.tres"
const PRESENTATION_FALLBACK_DURATION_SEC := 1.25
const MAX_TARGET_CANDIDATES := 64
const MAX_WORLD_COORDINATE := 10000.0
const EPSILON_SQUARED := 0.000001
const ASSASSINATE_TARGET_LAYER := 1 << 10
const CONFIG_PROPERTY_NAMES := [
	&"back_max_distance_m",
	&"back_max_angle_degrees",
	&"back_allowed_alert_states",
	&"above_max_distance_m",
	&"above_max_angle_degrees",
	&"above_allowed_alert_states",
	&"below_max_distance_m",
	&"below_max_angle_degrees",
	&"below_allowed_alert_states",
	&"corner_max_distance_m",
	&"corner_max_angle_degrees",
	&"corner_allowed_alert_states",
]

const CONTEXT_BACK: StringName = &"back"
const CONTEXT_ABOVE: StringName = &"above"
const CONTEXT_BELOW: StringName = &"below"
const CONTEXT_CORNER: StringName = &"corner"

signal prompt_changed(enemy: EnemyBase, context: StringName)

## Keep the exported contract Resource-typed so Godot can load tuning files even
## when the editor's script-class cache is not available yet (for example, on a
## clean headless CI import).  The pure resolver still accepts AssassinationConfig
## and uses bounded property fallbacks for compatible Resource implementations.
@export var config: Resource

var _prompt_enemy: EnemyBase
var _prompt_context: StringName = &""
var _active_enemy: EnemyBase
var _active_context: StringName = &""
var _presentation_fallback_remaining := 0.0


func _ready() -> void:
	if config == null:
		config = ResourceLoader.load(DEFAULT_CONFIG_PATH) as Resource
	if not _config_is_compatible(config):
		config = AssassinationConfigScript.new()
	var presentation := _presentation()
	if presentation != null and not presentation.completed.is_connected(_on_presentation_completed):
		presentation.completed.connect(_on_presentation_completed)
	set_process(true)
	set_process_unhandled_input(true)


func _exit_tree() -> void:
	var presentation := _presentation()
	if presentation != null and presentation.completed.is_connected(_on_presentation_completed):
		presentation.completed.disconnect(_on_presentation_completed)


static func _config_is_compatible(candidate: Resource) -> bool:
	if candidate == null:
		return false
	for property_name: StringName in CONFIG_PROPERTY_NAMES:
		if candidate.get(property_name) == null:
			return false
	return true


func _process(delta: float) -> void:
	if _active_enemy != null:
		if not is_instance_valid(_active_enemy):
			var presentation := _presentation()
			if presentation != null and presentation.is_active():
				presentation.cancel()
			_release_lock()
			return
		var presentation := _presentation()
		if presentation != null and presentation.is_active():
			return
		if is_finite(delta) and delta >= 0.0:
			_presentation_fallback_remaining = maxf(
				_presentation_fallback_remaining - minf(delta, 0.25),
				0.0,
			)
		if _presentation_fallback_remaining <= 0.0:
			_release_lock()
		return
	var candidate := _nearest_valid_target()
	if candidate == null:
		_set_prompt(null, &"")
		return
	var context := _context_for_enemy(candidate)
	_set_prompt(candidate if context != &"" else null, context)


func _unhandled_input(event: InputEvent) -> void:
	if event == null or not event.is_action_pressed(&"assassinate"):
		return
	confirm()


## Evaluate a target from the player's current transform and perception state.
## The result is one of the four contract tags or an empty StringName.
func evaluate(enemy: EnemyBase) -> StringName:
	var context := _context_for_enemy(enemy)
	_set_prompt(enemy if context != &"" else null, context)
	return context


## Execute the currently valid one-input assassination.  The public contract
## intentionally returns void; callers that need a success value can use
## try_execute() or confirm().
func execute(enemy: EnemyBase, context: StringName) -> void:
	try_execute(enemy, context)


func try_execute(enemy: EnemyBase, context: StringName = &"") -> bool:
	if _active_enemy != null and is_instance_valid(_active_enemy):
		return false
	if enemy == null or not is_instance_valid(enemy):
		return false
	var resolved_context := _context_for_enemy(enemy)
	if resolved_context == &"" or (context != &"" and context != resolved_context):
		return false
	if not enemy.has_method(&"can_be_assassinated") or not bool(enemy.call(&"can_be_assassinated")):
		return false
	var state_machine := _state_machine()
	if state_machine == null:
		return false
	if not state_machine.change_state(PlayerStateMachine.STATE_ASSASSINATE):
		return false
	if not enemy.has_method(&"begin_assassination") or not bool(
		enemy.call(&"begin_assassination", resolved_context)
	):
		# begin_assassination is validated before the normal path, but retain a
		# best-effort rollback if a custom enemy implementation rejects it.
		if state_machine.current_state() == PlayerStateMachine.STATE_ASSASSINATE:
			state_machine.change_state(PlayerStateMachine.STATE_GROUND)
		return false
	_active_enemy = enemy
	_active_context = resolved_context
	var presentation := _presentation()
	if presentation != null and presentation.begin(enemy, resolved_context):
		_presentation_fallback_remaining = 0.0
	else:
		# Custom player scenes may omit the presentation node.  Keep the #26
		# lock bounded even when no animation/camera/audio asset is available.
		_presentation_fallback_remaining = PRESENTATION_FALLBACK_DURATION_SEC
	_set_prompt(null, &"")
	return true


## Confirm the prompt currently shown to the player with one input.
func confirm() -> bool:
	if _prompt_enemy == null or _prompt_context == &"":
		return false
	var enemy := _prompt_enemy
	var context := _prompt_context
	return try_execute(enemy, context)


func prompt_enemy() -> EnemyBase:
	return _prompt_enemy


func prompt_context() -> StringName:
	return _prompt_context


func active_enemy() -> EnemyBase:
	return _active_enemy


func active_context() -> StringName:
	return _active_context


## Release the player-side lock after the presentation/animation hand-off.
## The enemy remains dead and cannot be targeted again.
func release() -> bool:
	if _active_enemy == null or not is_instance_valid(_active_enemy):
		return false
	var state_machine := _state_machine()
	if state_machine == null or state_machine.current_state() != PlayerStateMachine.STATE_ASSASSINATE:
		return false
	var presentation := _presentation()
	if presentation != null and presentation.is_active():
		presentation.cancel()
	return _release_lock()


func _on_presentation_completed(enemy: EnemyBase, context: StringName) -> void:
	if enemy != _active_enemy or context != _active_context:
		return
	_release_lock()


func _release_lock() -> bool:
	var state_machine := _state_machine()
	if state_machine == null or state_machine.current_state() != PlayerStateMachine.STATE_ASSASSINATE:
		return false
	_active_enemy = null
	_active_context = &""
	_presentation_fallback_remaining = 0.0
	return state_machine.change_state(PlayerStateMachine.STATE_GROUND)


## Pure deterministic judgment required by docs/08-content-specs.md §10.
## `to_enemy_local` is expressed in the player's local frame.  Godot's
## forward axis is -Z, so +Z is behind the player.
static func resolve(
	player_state: StringName,
	to_enemy_local: Vector3,
	enemy_alert: Enums.AlertState,
	seen_by_target: bool,
	cfg: Resource,
) -> StringName:
	if seen_by_target or enemy_alert == Enums.AlertState.COMBAT:
		return &""
	if not _valid_alert_state(enemy_alert) or not _valid_vector(to_enemy_local):
		return &""
	if to_enemy_local.length_squared() <= EPSILON_SQUARED:
		return &""
	var context := _context_for_state(player_state)
	if context == &"" or not _alert_allowed(cfg, context, enemy_alert):
		return &""
	var distance := to_enemy_local.length()
	if not is_finite(distance) or distance <= 0.0:
		return &""
	var max_distance := _max_distance(cfg, context)
	if distance > max_distance:
		return &""
	var axis := _context_axis(context, to_enemy_local)
	if axis == Vector3.ZERO:
		return &""
	var max_angle := _max_angle(cfg, context)
	if _angle_degrees(axis, to_enemy_local) > max_angle:
		return &""
	return context


static func _context_for_state(player_state: StringName) -> StringName:
	match player_state:
		&"Ground", &"Crouch":
			return CONTEXT_BACK
		&"Beam":
			return CONTEXT_ABOVE
		&"Crawlspace":
			return CONTEXT_BELOW
		&"WallCling":
			return CONTEXT_CORNER
	return &""


static func _context_axis(context: StringName, to_enemy_local: Vector3) -> Vector3:
	match context:
		CONTEXT_BACK:
			if to_enemy_local.z <= 0.0:
				return Vector3.ZERO
			return Vector3(0.0, 0.0, 1.0)
		CONTEXT_ABOVE:
			if to_enemy_local.y >= 0.0:
				return Vector3.ZERO
			return Vector3.DOWN
		CONTEXT_BELOW:
			if to_enemy_local.y <= 0.0:
				return Vector3.ZERO
			return Vector3.UP
		CONTEXT_CORNER:
			var horizontal := Vector3(to_enemy_local.x, 0.0, to_enemy_local.z)
			if horizontal.length_squared() <= EPSILON_SQUARED or absf(horizontal.x) < absf(horizontal.z):
				return Vector3.ZERO
			return Vector3(signf(horizontal.x), 0.0, 0.0)
	return Vector3.ZERO


static func _angle_degrees(axis: Vector3, direction: Vector3) -> float:
	if axis.length_squared() <= EPSILON_SQUARED or direction.length_squared() <= EPSILON_SQUARED:
		return 180.0
	var cosine := clampf(axis.normalized().dot(direction.normalized()), -1.0, 1.0)
	return rad_to_deg(acos(cosine))


static func _alert_allowed(cfg: Resource, context: StringName, alert_state: Enums.AlertState) -> bool:
	if alert_state == Enums.AlertState.COMBAT:
		return false
	if cfg is AssassinationConfig:
		return (cfg as AssassinationConfig).is_alert_allowed(context, alert_state)
	var values: Variant = _resource_value(cfg, String(context) + "_allowed_alert_states", [0, 1, 2, 4])
	if values is Array and not (values as Array).is_empty():
		return (values as Array).has(int(alert_state))
	return true


static func _max_distance(cfg: Resource, context: StringName) -> float:
	var fallback := 1.5
	if context == CONTEXT_ABOVE:
		fallback = 4.0
	if cfg is AssassinationConfig:
		return (cfg as AssassinationConfig).max_distance_for(context)
	var value: Variant = _resource_value(cfg, String(context) + "_max_distance_m", fallback)
	var numeric := value is float or value is int
	return float(value) if numeric and is_finite(float(value)) and float(value) > 0.0 else fallback


static func _max_angle(cfg: Resource, context: StringName) -> float:
	var fallback := 60.0 if context == CONTEXT_CORNER else 45.0 if context != CONTEXT_BACK else 70.0
	if cfg is AssassinationConfig:
		return (cfg as AssassinationConfig).max_angle_for(context)
	var value: Variant = _resource_value(cfg, String(context) + "_max_angle_degrees", fallback)
	var numeric := value is float or value is int
	return clampf(float(value), 0.0, 180.0) if numeric and is_finite(float(value)) else fallback


static func _resource_value(cfg: Resource, property_name: String, fallback: Variant) -> Variant:
	if cfg == null:
		return fallback
	var value: Variant = cfg.get(property_name)
	return fallback if value == null else value


static func _valid_alert_state(value: Enums.AlertState) -> bool:
	return value >= Enums.AlertState.UNAWARE and value <= Enums.AlertState.RETURN


static func _valid_vector(value: Vector3) -> bool:
	return (
		is_finite(value.x)
		and is_finite(value.y)
		and is_finite(value.z)
		and absf(value.x) <= MAX_WORLD_COORDINATE
		and absf(value.y) <= MAX_WORLD_COORDINATE
		and absf(value.z) <= MAX_WORLD_COORDINATE
	)


func _context_for_enemy(enemy: EnemyBase) -> StringName:
	if enemy == null or not is_instance_valid(enemy):
		return &""
	var player := get_parent() as Node3D
	if (
		player == null
		or not player.is_inside_tree()
		or not enemy.is_inside_tree()
		or enemy.get_tree() != player.get_tree()
		or not _target_area_is_valid(enemy)
	):
		return &""
	if enemy.has_method(&"can_be_assassinated") and not bool(enemy.call(&"can_be_assassinated")):
		return &""
	if not _valid_vector(player.global_position) or not _valid_vector(enemy.global_position):
		return &""
	var to_enemy_local := player.global_transform.affine_inverse() * enemy.global_position
	var seen := _enemy_sees_player(enemy)
	return resolve(
		_state_name(),
		to_enemy_local,
		enemy.alert_state(),
		seen,
		config,
	)


func _state_name() -> StringName:
	var state_machine := _state_machine()
	return state_machine.current_state() if state_machine != null else &""


func _state_machine() -> PlayerStateMachine:
	var player := get_parent()
	return player.get_node_or_null(NodePath("StateMachine")) as PlayerStateMachine if player != null else null


func _presentation() -> AssassinationPresentation:
	return get_node_or_null(NodePath("AssassinationPresentation")) as AssassinationPresentation


func _nearest_valid_target() -> EnemyBase:
	var player := get_parent() as Node3D
	if player == null:
		return null
	var candidates: Array[EnemyBase] = []
	var seen_ids: Dictionary = {}
	var interactor := player.get_node_or_null(NodePath("Interactor")) as Area3D
	if interactor != null:
		for area: Area3D in interactor.get_overlapping_areas():
			var enemy := _enemy_from_area(area)
			if enemy != null and not seen_ids.has(enemy.get_instance_id()):
				seen_ids[enemy.get_instance_id()] = true
				candidates.append(enemy)
	if candidates.is_empty() and player.get_tree() != null:
		var examined := 0
		for candidate: Node in player.get_tree().get_nodes_in_group(&"enemies"):
			if examined >= MAX_TARGET_CANDIDATES:
				break
			examined += 1
			var enemy := candidate as EnemyBase
			if enemy != null and not seen_ids.has(enemy.get_instance_id()):
				seen_ids[enemy.get_instance_id()] = true
				candidates.append(enemy)
	var selected: EnemyBase
	var selected_distance := INF
	var selected_id := INF
	for enemy: EnemyBase in candidates:
		var context := _context_for_enemy(enemy)
		if context == &"":
			continue
		var distance := player.global_position.distance_squared_to(enemy.global_position)
		var id := enemy.get_instance_id()
		if distance < selected_distance or (is_equal_approx(distance, selected_distance) and id < selected_id):
			selected = enemy
			selected_distance = distance
			selected_id = id
	return selected


func _enemy_from_area(area: Area3D) -> EnemyBase:
	var current: Node = area
	for _depth in 4:
		if current is EnemyBase:
			return current as EnemyBase
		current = current.get_parent() if current != null else null
		if current == null:
			break
	return null


func _target_area_is_valid(enemy: EnemyBase) -> bool:
	var target_area := enemy.get_node_or_null(NodePath("AssassinateTarget")) as Area3D
	return (
		target_area != null
		and target_area.is_inside_tree()
		and target_area.collision_layer == ASSASSINATE_TARGET_LAYER
		and target_area.collision_mask == 0
	)


func _enemy_sees_player(enemy: EnemyBase) -> bool:
	var perception := enemy.get_node_or_null(NodePath("Perception")) as EnemyPerception
	if perception != null and perception.target_visible():
		return true
	var brain := enemy.brain()
	return brain != null and brain.target_visible()


func _set_prompt(enemy: EnemyBase, context: StringName) -> void:
	if _prompt_enemy == enemy and _prompt_context == context:
		return
	var previous := _prompt_enemy
	_prompt_enemy = enemy
	_prompt_context = context
	if enemy != null:
		prompt_changed.emit(enemy, context)
	elif previous != null:
		prompt_changed.emit(previous, &"")
