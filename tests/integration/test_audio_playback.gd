extends GutTest

func test_director_uses_real_layers_and_crossfades_alert_levels() -> void:
	var director=load("res://src/autoload/audio_director.gd").new()
	add_child_autofree(director)
	assert_true(director.has_method("music_levels"),"AudioDirector needs real BGM playback")
	if not director.has_method("music_levels"): return
	director.play_bgm_set(&"normal")
	director.set_alert_tier(1)
	director.advance_audio(.4)
	assert_gt(director.music_levels()[0],0.0)
	assert_lt(director.music_levels()[0],1.0,"Crossfade cannot jump immediately")
	director.advance_audio(1.0)
	assert_almost_eq(director.music_levels()[0],1.0,.001)
	director.set_alert_tier(2)
	director.advance_audio(1.0)
	assert_almost_eq(director.music_levels()[1],1.0,.001)
	for layer in director.get_node("Music").get_children():
		assert_not_null(layer.stream)
		assert_gt(layer.stream.data.size(),0)
		assert_eq(layer.bus,&"BGM")
	director.begin_assassination_audio(&"back")
	assert_lte(director.get_node("Ambience").volume_db,-70.0)

func test_material_identity_is_available_before_the_noise_event_is_dispatched() -> void:
	var source=Node3D.new();add_child_autofree(source)
	var emitter=NoiseEmitter.new();source.add_child(emitter)
	var received: Array=[]
	var callback=func(event): received.append(event.get("audio_cue"))
	EventBus.noise_emitted.connect(callback)
	emitter.emit_footstep(Enums.Stance.WALK,&"gravel")
	EventBus.noise_emitted.disconnect(callback)
	assert_eq(received,[&"footstep_gravel"])

func test_effect_voices_are_bounded_and_unknown_cues_fail_safely() -> void:
	var director=load("res://src/autoload/audio_director.gd").new()
	add_child_autofree(director)
	assert_true(director.has_method("play_effect"))
	if not director.has_method("play_effect"): return
	assert_false(director.play_effect(&"unknown",Vector3.ZERO))
	for i in range(40): assert_true(director.play_effect(&"footstep_wood",Vector3.ZERO))
	assert_lte(director.get_node("Effects").get_child_count(),24)
