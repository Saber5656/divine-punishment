extends GutTest

const SCENE := "res://src/levels/festival_night/festival_night.tscn"
const FIREWORKS := "res://src/levels/festival_night/festival_fireworks.gd"

func after_each() -> void:
	get_tree().paused = false

func _fixture() -> Node3D:
	assert_true(ResourceLoader.exists(FIREWORKS), "M5 needs a scene-owned fireworks cycle")
	if not ResourceLoader.exists(FIREWORKS): return null
	var level: Node3D = load(SCENE).instantiate()
	add_child_autofree(level)
	var fireworks: Node3D = load(FIREWORKS).new()
	fireworks.name = "Fireworks"
	level.add_child(fireworks)
	fireworks.set_physics_process(false)
	return level

func test_three_second_burst_repeats_and_restore_does_not_reemit() -> void:
	var level := _fixture()
	if level == null: return
	var fx := level.get_node("Fireworks")
	var bursts: Array = []
	var listener := func(id, payload):
		if id == EventBus.EV_FIREWORK_BURST and payload.get("active",false): bursts.append(payload)
	EventBus.mission_event.connect(listener)
	for sample in [[0.0,false],[41.99,false],[42.0,true],[44.99,true],[45.0,false],[87.0,true],[90.0,false]]:
		assert_true(fx.synchronize_elapsed(sample[0]))
		assert_eq(fx.masks_gameplay_noise(),sample[1])
	assert_eq(bursts.size(),2)
	assert_true(fx.synchronize_elapsed(43.0,false))
	assert_true(fx.masks_gameplay_noise())
	assert_eq(bursts.size(),2,"Checkpoint restore must not replay the boom event")
	for value in [-1.0,NAN,INF]: assert_false(fx.synchronize_elapsed(value))
	assert_eq(fx.elapsed(),43.0)
	EventBus.mission_event.disconnect(listener)

func test_real_roof_and_bridge_surfaces_double_visibility_without_exposing_interiors() -> void:
	var level := _fixture()
	if level == null: return
	var fx := level.get_node("Fireworks")
	fx.synchronize_elapsed(42.0,false)
	for point in [Vector3(28,4.02,60),Vector3(48,4.02,48),Vector3(70,4.02,44),Vector3(77,5.32,42),Vector3(84,6.9,32),Vector3(51,6.62,17)]:
		assert_eq(fx.visibility_multiplier_at(point),2.0,"Physical roof surface "+str(point))
	for point in [Vector3(48,0.02,60),Vector3(51,3.02,17),Vector3(84,3.02,32),Vector3(84,-3,22.5),Vector3(12,0.02,88),Vector3(84,8,32)]:
		assert_eq(fx.visibility_multiplier_at(point),1.0,"Ground/interior/air stays neutral "+str(point))
	var player := level.get_node("Player") as PlayerController
	player.set_physics_process(false)
	player.global_position = Vector3(28,4.02,60)
	var visibility := player.get_node("Visibility") as PlayerVisibility
	fx.synchronize_elapsed(0,false)
	var baseline := visibility.recompute()
	fx.synchronize_elapsed(42,false)
	assert_almost_eq(visibility.recompute(),baseline*2,0.000001)

func test_masked_scream_still_counts_as_a_mission_event_and_unload_restores_sound() -> void:
	var level := _fixture()
	if level == null: return
	var fx := level.get_node("Fireworks")
	fx.synchronize_elapsed(42,false)
	var civilian := CivilianNPC.new()
	level.add_child(civilian)
	var sounds: Array = []
	var screams: Array = []
	var sound_listener := func(event): sounds.append(event)
	var mission_listener := func(id,_payload):
		if id == &"civilian_scream": screams.append(id)
	EventBus.noise_emitted.connect(sound_listener)
	EventBus.mission_event.connect(mission_listener)
	assert_true(civilian.scream())
	assert_eq(sounds.size(),0)
	assert_eq(screams.size(),1)
	fx.free()
	NoiseEventSystem.emit(NoiseEvent.create(Vector3.ZERO,5,Enums.NoiseKind.FOOTSTEP,civilian),get_tree())
	assert_eq(sounds.size(),1)
	EventBus.noise_emitted.disconnect(sound_listener)
	EventBus.mission_event.disconnect(mission_listener)

func test_paused_scene_does_not_advance_fireworks_clock() -> void:
	var level := _fixture()
	if level == null: return
	var fx := level.get_node("Fireworks")
	fx.set_physics_process(true)
	for frame in range(3): await get_tree().physics_frame
	var before: float = fx.elapsed()
	get_tree().paused = true
	for frame in range(3): await get_tree().process_frame
	assert_eq(fx.elapsed(),before)
	get_tree().paused = false
