class_name AssassinationResolver
extends Node


const AssassinationConfigScript := preload("res://src/core/tuning/assassination_config.gd")
const DEFAULT_CONFIG_PATH := "res://data/tuning/assassination.tres"
const MAX_TARGET_CANDIDATES := 64
const MAX_ASSASSINATION_PATH_HITS := 8
const MAX_SUPPORT_SURFACE_SKIPS := 2
const MAX_WORLD_COORDINATE := 10000.0
const EPSILON_SQUARED := 0.000001
const SUPPORT_SURFACE_MAX_DISTANCE := 1.0
const SUPPORT_SURFACE_MIN_NORMAL_Y := 0.5
const ASSASSINATE_TARGET_LAYER := 1 << 10
const ASSASSINATION_OCCLUSION_MASK := (1 << 0) | (1 << 4)
const DEFAULT_PRESENTATION_DURATION_SECONDS := 1.0
const CONFIG_PROPERTY_NAMES := [
	&"presentation_duration_seconds",
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
var _active_origin_state: StringName = PlayerStateMachine.STATE_GROUND
var _active_elapsed_seconds := 0.0
var _presentation_fallback_remaining := 0.0
var _tuning_service: Node
var _config_override: Resource


func _ready() -> void:
	if _config_is_compatible(config) and not _is_default_config_resource(config):
		_config_override = config
	_refresh_config()
	_tuning_service = _find_tuning_service()
	if _tuning_service != null and _tuning_service.has_signal(&"reloaded"):
		var tuning_callback := Callable(self, &"_refresh_config")
		if not _tuning_service.is_connected(&"reloaded", tuning_callback):
			_tuning_service.connect(&"reloaded", tuning_callback)
	var presentation := _presentation()
	if presentation != null and not presentation.completed.is_connected(_on_presentation_completed):
		presentation.completed.connect(_on_presentation_completed)
	set_process(true)
	set_process_unhandled_input(true)


func _exit_tree() -> void:
	if _tuning_service != null and _tuning_service.has_signal(&"reloaded"):
		var tuning_callback := Callable(self, &"_refresh_config")
		if _tuning_service.is_connected(&"reloaded", tuning_callback):
			_tuning_service.disconnect(&"reloaded", tuning_callback)
	var presentation := _presentation()
	if presentation != null:
		if presentation.completed.is_connected(_on_presentation_completed):
			presentation.completed.disconnect(_on_presentation_completed)
		if presentation.is_active():
			# Scene teardown must not bypass presentation-owned camera/audio
			# restoration. cancel() is completion-signal-free and idempotent.
			presentation.cancel()
	_prompt_enemy = null
	_prompt_context = &""
	if _active_enemy != null:
		# _release_lock() clears the resolver ownership even when a scene
		# transition already moved the player to Dead or another state.  It only
		# restores the origin posture while Assassinate is still current.
		_release_lock()
	else:
		_active_context = &""
		_active_origin_state = PlayerStateMachine.STATE_GROUND
		_active_elapsed_seconds = 0.0
		_presentation_fallback_remaining = 0.0


func _refresh_config() -> void:
	if _config_override != null:
		config = _config_override
		return
	var candidate: Resource
	var tuning := _find_tuning_service()
	if tuning != null and tuning.has_method(&"assassination"):
		candidate = tuning.call(&"assassination") as Resource
	if candidate == null:
		candidate = ResourceLoader.load(
			DEFAULT_CONFIG_PATH,
			"",
			ResourceLoader.CACHE_MODE_IGNORE,
		) as Resource
	config = candidate if _config_is_compatible(candidate) else AssassinationConfigScript.new()


func _find_tuning_service() -> Node:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath("Tuning"))


func _is_default_config_resource(candidate: Resource) -> bool:
	return candidate != null and candidate.resource_path == DEFAULT_CONFIG_PATH


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
			# Consume the complete finite frame delta, bounded only by the
			# remaining fallback duration.  Capping each frame at 0.5 seconds
			# would stretch a no-presentation lock during a stalled frame.
			_presentation_fallback_remaining = maxf(
				_presentation_fallback_remaining - minf(delta, _presentation_fallback_remaining),
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
	if _active_enemy != null:
		return false
	if _player_is_carrying_body():
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
	var origin_state := state_machine.current_state()
	if not state_machine.change_state(PlayerStateMachine.STATE_ASSASSINATE):
		return false
	if not enemy.has_method(&"begin_assassination") or not bool(
		enemy.call(&"begin_assassination", resolved_context)
	):
		# begin_assassination is validated before the normal path, but retain a
		# best-effort rollback if a custom enemy implementation rejects it.
		if state_machine.current_state() == PlayerStateMachine.STATE_ASSASSINATE:
			state_machine.change_state(_release_state_for_origin(origin_state))
		return false
	_active_enemy = enemy
	_active_context = resolved_context
	_active_origin_state = origin_state
	_active_elapsed_seconds = 0.0
	var presentation := _presentation()
	if presentation != null:
		# Keep the presentation lock aligned with the shared assassination tuning
		# resource while retaining the presentation's own 1–2 second clamp.
		presentation.duration_sec = _presentation_duration_seconds()
	if presentation != null and presentation.begin(enemy, resolved_context):
		_presentation_fallback_remaining = 0.0
	else:
		# Custom player scenes may omit the presentation node.  Keep the #26
		# lock bounded even when no animation/camera/audio asset is available.
		_presentation_fallback_remaining = _presentation_duration_seconds()
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
	if _active_enemy == null:
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
	var had_active_lock := _active_enemy != null
	var state_machine := _state_machine()
	var release_state := _release_state_for_origin(_active_origin_state)
	var can_restore_origin := (
		state_machine != null
		and state_machine.current_state() == PlayerStateMachine.STATE_ASSASSINATE
	)
	_active_enemy = null
	_active_context = &""
	_active_origin_state = PlayerStateMachine.STATE_GROUND
	_active_elapsed_seconds = 0.0
	_presentation_fallback_remaining = 0.0
	if not had_active_lock:
		return false
	# A fatal hit or another state transition may legitimately interrupt the
	# authored presentation.  Never overwrite that state, but always clear the
	# resolver ownership so a dead player cannot remain permanently locked.
	if not can_restore_origin:
		return true
	return state_machine.change_state(release_state)


func _release_state_for_origin(origin_state: StringName) -> StringName:
	return (
		PlayerStateMachine.STATE_CRAWLSPACE
		if origin_state == PlayerStateMachine.STATE_CRAWLSPACE
		else PlayerStateMachine.STATE_GROUND
	)


func _presentation_duration_seconds() -> float:
	var value: Variant = _resource_value(
		config,
		"presentation_duration_seconds",
		DEFAULT_PRESENTATION_DURATION_SECONDS,
	)
	if not value is float and not value is int:
		return DEFAULT_PRESENTATION_DURATION_SECONDS
	var duration := float(value)
	return clampf(duration, 0.1, 5.0) if is_finite(duration) else DEFAULT_PRESENTATION_DURATION_SECONDS


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
		or _player_is_carrying_body()
		or not player.is_inside_tree()
		or not enemy.is_inside_tree()
		or enemy.get_tree() != player.get_tree()
		or not _target_area_is_valid(enemy)
		or not _sensor_overlaps_enemy(player, enemy)
	):
		return &""
	if enemy.has_method(&"can_be_assassinated") and not bool(enemy.call(&"can_be_assassinated")):
		return &""
	if not _valid_vector(player.global_position) or not _valid_vector(enemy.global_position):
		return &""
	var to_enemy_local := player.global_transform.affine_inverse() * enemy.global_position
	var seen := _enemy_sees_player(enemy)
	var context := resolve(
		_state_name(),
		to_enemy_local,
		enemy.alert_state(),
		seen,
		config,
	)
	if context == &"" or not _assassination_path_is_clear(player, enemy, context):
		return &""
	if context == CONTEXT_BACK and not _enemy_facing_allows_backstab(player, enemy):
		return &""
	return context


func _player_is_carrying_body() -> bool:
	var player := get_parent()
	return (
		player != null
		and player.has_method(&"is_carrying_body")
		and bool(player.call(&"is_carrying_body"))
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
		var examined := 0
		for area: Area3D in interactor.get_overlapping_areas():
			if examined >= MAX_TARGET_CANDIDATES:
				break
			examined += 1
			var enemy := _enemy_from_area(area)
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


func _sensor_overlaps_enemy(player: Node3D, enemy: EnemyBase) -> bool:
	var interactor := player.get_node_or_null(NodePath("Interactor")) as Area3D
	var target_area := enemy.get_node_or_null(NodePath("AssassinateTarget")) as Area3D
	if (
		interactor == null
		or not interactor.monitoring
		or target_area == null
		or not target_area.is_inside_tree()
		or not target_area.monitorable
	):
		return false
	# Explicit target evaluation uses a direct physics pair query so unrelated
	# overlap entries cannot hide a valid assassination target.  Headless Godot
	# can expose the synchronized overlap list one frame before `overlaps_area`
	# reflects the same pair, so retain the engine-owned membership as a
	# deterministic compatibility fallback without truncating explicit targets.
	if interactor.overlaps_area(target_area) or interactor.get_overlapping_areas().has(target_area):
		return true
	# The monitoring list is updated asynchronously from the physics broadphase.
	# Query the same interactor shape directly as a bounded, engine-owned fallback
	# for an explicit target; this preserves collision-layer and actual geometry
	# checks without trusting groups, distance-only heuristics, or arbitrary nodes.
	var shape_node := interactor.get_node_or_null(NodePath("CollisionShape3D")) as CollisionShape3D
	var world := interactor.get_world_3d()
	if shape_node == null or shape_node.shape == null or world == null:
		return false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape_node.shape
	query.transform = shape_node.global_transform
	query.collision_mask = interactor.collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.exclude = [interactor.get_rid()]
	var hits := world.direct_space_state.intersect_shape(query, 8)
	for hit: Dictionary in hits:
		if hit.get("collider") == target_area or hit.get("rid") == target_area.get_rid():
			return true
	return false


func _assassination_path_is_clear(
	player: Node3D,
	enemy: EnemyBase,
	context: StringName = &"",
) -> bool:
	var target_area := enemy.get_node_or_null(NodePath("AssassinateTarget")) as Area3D
	if target_area == null or not target_area.is_inside_tree():
		return false
	var from := player.global_position
	var to := target_area.global_position
	if not _valid_vector(from) or not _valid_vector(to) or from.distance_squared_to(to) <= EPSILON_SQUARED:
		return false
	var world := player.get_world_3d()
	if world == null:
		return false
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = ASSASSINATION_OCCLUSION_MASK
	var excluded := _assassination_ray_exclusions(player, enemy)
	var support_skips := 0
	for _hit_index in MAX_ASSASSINATION_PATH_HITS:
		query.exclude = excluded
		var hit := world.direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return true
		if (
			context != CONTEXT_ABOVE
			or support_skips >= MAX_SUPPORT_SURFACE_SKIPS
			or not _is_immediate_support_surface(hit, from)
		):
			return false
		var hit_rid: RID = hit.get("rid", RID())
		if not hit_rid.is_valid():
			return false
		excluded.append(hit_rid)
		support_skips += 1
	return false


func _is_immediate_support_surface(hit: Dictionary, from: Vector3) -> bool:
	var hit_position: Variant = hit.get("position")
	var hit_normal: Variant = hit.get("normal")
	var collider := hit.get("collider") as CollisionObject3D
	if (
		not hit_position is Vector3
		or not hit_normal is Vector3
		or collider == null
		or (collider.collision_layer & (1 << 0)) == 0
	):
		return false
	var position := hit_position as Vector3
	var normal := hit_normal as Vector3
	if not _valid_vector(position) or not _valid_vector(normal):
		return false
	var distance := from.distance_to(position)
	return (
		is_finite(distance)
		and distance <= SUPPORT_SURFACE_MAX_DISTANCE
		and position.y <= from.y + 0.05
		and normal.y >= SUPPORT_SURFACE_MIN_NORMAL_Y
	)


func _assassination_ray_exclusions(player: Node3D, enemy: EnemyBase) -> Array[RID]:
	var result: Array[RID] = []
	if player is CollisionObject3D:
		result.append((player as CollisionObject3D).get_rid())
	if enemy is CollisionObject3D:
		result.append((enemy as CollisionObject3D).get_rid())
	var target_area := enemy.get_node_or_null(NodePath("AssassinateTarget")) as Area3D
	if target_area != null:
		result.append(target_area.get_rid())
	return result


func _enemy_facing_allows_backstab(player: Node3D, enemy: EnemyBase) -> bool:
	var enemy_forward := -enemy.global_transform.basis.z
	var enemy_to_player := player.global_position - enemy.global_position
	var horizontal_forward := Vector3(enemy_forward.x, 0.0, enemy_forward.z)
	var horizontal_to_player := Vector3(enemy_to_player.x, 0.0, enemy_to_player.z)
	if (
		not _valid_vector(horizontal_forward)
		or not _valid_vector(horizontal_to_player)
		or horizontal_forward.length_squared() <= EPSILON_SQUARED
		or horizontal_to_player.length_squared() <= EPSILON_SQUARED
	):
		return false
	return horizontal_forward.normalized().dot(horizontal_to_player.normalized()) < 0.0


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
