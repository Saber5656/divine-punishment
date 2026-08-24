extends GutTest


class NoiseListener:
	extends Node3D

	var events: Array[NoiseEvent] = []

	func _init() -> void:
		add_to_group(&"enemies")

	func on_noise(event: NoiseEvent) -> void:
		events.append(event)


const NoiseEventScript := preload("res://src/core/noise_event.gd")
const NoiseEmitterScript := preload("res://src/stealth/noise_emitter.gd")
const MovementConfigScript := preload("res://src/core/tuning/movement_config.gd")
const PLAYER_SCENE_PATH := "res://src/player/player.tscn"


func test_noise_event_has_typed_payload() -> void:
	var source := Node.new()
	var event: NoiseEvent = NoiseEventScript.create(Vector3.ONE, 6.0, Enums.NoiseKind.TOOL, source)
	assert_eq(event.position, Vector3.ONE)
	assert_eq(event.radius, 6.0)
	assert_eq(event.kind, Enums.NoiseKind.TOOL)
	assert_eq(event.source, source)
	source.free()


func test_footstep_radius_uses_stance_and_material_multiplier() -> void:
	var config := MovementConfigScript.new()
	assert_eq(NoiseEmitterScript.footstep_radius(Enums.Stance.SNEAK, &"tatami", config), 0.5)
	assert_eq(NoiseEmitterScript.footstep_radius(Enums.Stance.SPRINT, &"gravel", config), 18.0)
	var floor_body := StaticBody3D.new()
	floor_body.set_meta(&"floor_material", &"gravel")
	assert_eq(NoiseEmitterScript.floor_material_for(floor_body), &"gravel")
	floor_body.free()


func test_occluded_noise_radius_is_halved() -> void:
	assert_eq(NoiseEventSystem.OCCLUDED_RADIUS_MULTIPLIER, 0.5)
	assert_eq(NoiseEventSystem.HEARING_OCCLUSION_MASK, 1 << 5)


func test_emit_delivers_to_enemy_once_and_keeps_eventbus_telemetry_once() -> void:
	var source := Node3D.new()
	var listener := NoiseListener.new()
	listener.position = Vector3(2.0, 0.0, 0.0)
	add_child_autofree(source)
	add_child_autofree(listener)
	await get_tree().physics_frame
	var events: Array[NoiseEvent] = []
	var capture := func(event: NoiseEvent) -> void: events.append(event)
	EventBus.noise_emitted.connect(capture)
	NoiseEventSystem.emit(
		NoiseEvent.create(source.global_position, 3.0, Enums.NoiseKind.FOOTSTEP, source),
		get_tree(),
	)
	EventBus.noise_emitted.disconnect(capture)

	assert_eq(events.size(), 1)
	assert_eq(listener.events.size(), 1)
	assert_eq(listener.events[0].kind, Enums.NoiseKind.FOOTSTEP)
	assert_eq(listener.events[0].source, source)


func test_sound_blocker_halves_radius_but_other_layers_do_not() -> void:
	var source := Node3D.new()
	var listener := NoiseListener.new()
	listener.position = Vector3(4.0, 0.0, 0.0)
	add_child_autofree(source)
	add_child_autofree(listener)
	await get_tree().physics_frame
	assert_eq(
		NoiseEventSystem.radius_at_listener(
			get_tree(), source.global_position, listener.global_position, 6.0, source,
		),
		6.0,
	)

	var blocker := _add_blocker(Vector3(2.0, 0.0, 0.0), 1 << 5)
	await get_tree().physics_frame
	assert_eq(
		NoiseEventSystem.radius_at_listener(
			get_tree(), source.global_position, listener.global_position, 6.0, source,
		),
		3.0,
	)
	blocker.collision_layer = 1
	await get_tree().physics_frame
	assert_eq(
		NoiseEventSystem.radius_at_listener(
			get_tree(), source.global_position, listener.global_position, 6.0, source,
		),
		6.0,
	)


func test_multiple_sound_blockers_attenuate_once_per_blocker() -> void:
	var source := Node3D.new()
	var listener := NoiseListener.new()
	listener.position = Vector3(6.0, 0.0, 0.0)
	add_child_autofree(source)
	add_child_autofree(listener)
	await get_tree().physics_frame
	var first_blocker := _add_blocker(Vector3(2.0, 0.0, 0.0), 1 << 5)
	var second_blocker := _add_blocker(Vector3(4.0, 0.0, 0.0), 1 << 5)
	await get_tree().physics_frame

	assert_eq(
		NoiseEventSystem.radius_at_listener(
			get_tree(), source.global_position, listener.global_position, 6.0, source,
		),
		1.5,
	)
	first_blocker.queue_free()
	second_blocker.queue_free()


func test_player_scene_wires_noise_emitter_and_emits_landing_and_door() -> void:
	var player := (load(PLAYER_SCENE_PATH) as PackedScene).instantiate() as Node3D
	add_child_autofree(player)
	var emitter := player.get_node("NoiseEmitter") as NoiseEmitter
	assert_not_null(emitter)
	var events: Array[NoiseEvent] = []
	var capture := func(event: NoiseEvent) -> void: events.append(event)
	EventBus.noise_emitted.connect(capture)
	emitter.emit_landing()
	emitter.emit_door(true)
	EventBus.noise_emitted.disconnect(capture)
	assert_eq(events.size(), 2)
	assert_eq(events[0].kind, Enums.NoiseKind.LANDING)
	assert_eq(events[1].kind, Enums.NoiseKind.DOOR)


func test_player_ground_noise_path_emits_landing_then_material_footstep_once() -> void:
	var floor_body := _add_floor(Vector3(0.0, 0.0, 0.0), &"gravel")
	var player := (load(PLAYER_SCENE_PATH) as PackedScene).instantiate() as PlayerController
	player.position = Vector3(0.0, 1.0, 0.0)
	add_child_autofree(player)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(player.is_on_floor())
	var events: Array[NoiseEvent] = []
	var capture := func(event: NoiseEvent) -> void: events.append(event)
	EventBus.noise_emitted.connect(capture)
	player._emit_ground_noise(0.1, false)
	player.velocity = Vector3(3.0, 0.0, 0.0)
	player._emit_ground_noise(0.5, true)
	EventBus.noise_emitted.disconnect(capture)

	assert_eq(events.size(), 2)
	assert_eq(events[0].kind, Enums.NoiseKind.LANDING)
	assert_eq(events[1].kind, Enums.NoiseKind.FOOTSTEP)
	assert_eq(events[1].radius, 6.0)
	floor_body.queue_free()


func test_player_noise_cadence_has_finite_delta_and_single_tick_bound() -> void:
	assert_gt(PlayerController.MAX_NOISE_DELTA, 0.0)
	assert_lt(PlayerController.MAX_NOISE_DELTA, 1.0)


func _add_blocker(at: Vector3, layer: int) -> StaticBody3D:
	var blocker := StaticBody3D.new()
	blocker.collision_layer = layer
	blocker.collision_mask = 0
	blocker.position = at
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.5, 2.0, 2.0)
	collision.shape = shape
	blocker.add_child(collision)
	add_child_autofree(blocker)
	return blocker


func _add_floor(at: Vector3, material: StringName) -> StaticBody3D:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	floor_body.position = at
	floor_body.set_meta(&"floor_material", material)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(10.0, 0.2, 10.0)
	collision.shape = shape
	floor_body.add_child(collision)
	add_child_autofree(floor_body)
	return floor_body
