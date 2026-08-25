extends GutTest


const PresentationScript := preload("res://src/player/assassination_presentation.gd")
const PlayerScene := preload("res://src/player/player.tscn")
const EnemyScene := preload("res://src/enemies/enemy_base.tscn")

const CONTEXTS: Array[StringName] = [&"back", &"above", &"below", &"corner"]
const EXPECTED_CLIPS: Array[StringName] = [
	&"assassination_back",
	&"assassination_above",
	&"assassination_below",
	&"assassination_corner",
]


func _enemy() -> EnemyBase:
	var enemy := EnemyScene.instantiate() as EnemyBase
	add_child_autofree(enemy)
	return enemy


func _presentation(parent: Node = null) -> AssassinationPresentation:
	var presentation := PresentationScript.new() as AssassinationPresentation
	if parent == null:
		add_child_autofree(presentation)
	else:
		parent.add_child(presentation)
	return presentation


func test_four_contexts_emit_animation_camera_and_audio_hooks() -> void:
	var presentation := _presentation()
	var enemy := _enemy()
	var clips: Array[StringName] = []
	var camera_contexts: Array[StringName] = []
	var se_cues: Array[StringName] = []
	var phases: Array[StringName] = []
	presentation.animation_requested.connect(func(_context: StringName, clip: StringName) -> void: clips.append(clip))
	presentation.camera_blend_requested.connect(func(context: StringName) -> void: camera_contexts.append(context))
	presentation.se_requested.connect(func(_context: StringName, cue: StringName) -> void: se_cues.append(cue))
	presentation.audio_phase_changed.connect(func(_context: StringName, phase: StringName) -> void: phases.append(phase))
	presentation.duration_sec = 1.0

	for index in CONTEXTS.size():
		assert_true(presentation.begin(enemy, CONTEXTS[index]))
		assert_eq(presentation.context(), CONTEXTS[index])
		assert_eq(presentation.animation_clip_for(CONTEXTS[index]), EXPECTED_CLIPS[index])
		assert_true(presentation.is_active())
		presentation.advance(0.25)
		presentation.advance(0.25)
		assert_eq(presentation.audio_phase(), &"beat")
		presentation.advance(0.25)
		presentation.advance(0.25)
		assert_false(presentation.is_active())

	assert_eq(clips, EXPECTED_CLIPS)
	assert_eq(camera_contexts, CONTEXTS)
	assert_eq(se_cues, [&"assassination_se_back", &"assassination_se_above", &"assassination_se_below", &"assassination_se_corner"])
	assert_eq(phases, [&"silence", &"beat", &"ambient", &"silence", &"beat", &"ambient", &"silence", &"beat", &"ambient", &"silence", &"beat", &"ambient"])


func test_duration_is_bounded_and_missing_assets_complete_safely() -> void:
	var presentation := _presentation()
	var enemy := _enemy()
	presentation.duration_sec = 999.0
	assert_true(presentation.begin(enemy, &"back"))
	assert_lte(presentation.remaining_sec(), 2.0)
	assert_gte(presentation.remaining_sec(), 1.0)
	assert_false(presentation.advance(NAN))
	assert_true(presentation.is_active())
	for _step in 8:
		presentation.advance(0.25)
	assert_false(presentation.is_active())
	assert_eq(presentation.audio_phase(), &"ambient")
	assert_false(get_tree().paused)


func test_large_frame_delta_does_not_stretch_presentation_lock() -> void:
	var presentation := _presentation()
	var enemy := _enemy()
	presentation.duration_sec = 2.0
	assert_true(presentation.begin(enemy, &"back"))
	assert_true(presentation.advance(1.0))
	assert_true(presentation.is_active())
	assert_eq(presentation.audio_phase(), &"beat")
	assert_true(presentation.advance(1.0))
	assert_false(presentation.is_active())
	assert_eq(presentation.audio_phase(), &"ambient")


func test_cancel_emits_ambient_phase_for_presentation_consumers() -> void:
	var presentation := _presentation()
	var enemy := _enemy()
	var phases: Array[StringName] = []
	presentation.audio_phase_changed.connect(func(_context: StringName, phase: StringName) -> void: phases.append(phase))
	assert_true(presentation.begin(enemy, &"back"))
	assert_true(presentation.cancel())
	assert_eq(phases, [&"silence", &"ambient"])
	assert_eq(presentation.audio_phase(), &"ambient")
	assert_eq(AudioDirector.assassination_audio_phase, &"ambient")


func test_cancel_restores_previous_ambience_after_assassination() -> void:
	AudioDirector.current_ambience = &"mission_festival"
	var presentation := _presentation()
	var enemy := _enemy()
	assert_true(presentation.begin(enemy, &"back"))
	assert_eq(AudioDirector.current_ambience, &"silence")
	assert_true(presentation.cancel())
	assert_eq(AudioDirector.current_ambience, &"mission_festival")
	AudioDirector.current_ambience = &"ambient"


func test_other_enemy_perception_runs_during_presentation() -> void:
	var presentation := _presentation()
	var target := _enemy()
	var witness := _enemy()
	var witness_brain := witness.brain()
	assert_not_null(witness_brain)
	assert_true(presentation.begin(target, &"back"))
	assert_false(get_tree().paused)
	witness_brain.submit_stimulus(
		PerceptionStimulus.create(
			Enums.StimulusKind.VISUAL,
			4,
			Vector3.ZERO,
			1.0,
		)
	)
	witness_brain.tick(0.1)
	assert_eq(witness_brain.alert_state(), Enums.AlertState.COMBAT)
	assert_true(presentation.is_active())
	presentation.cancel()


func test_camera_rig_receives_bounded_context_blend_and_resets() -> void:
	var player := Node3D.new()
	add_child_autofree(player)
	var camera := PlayerCameraRig.new()
	camera.name = "CameraRig"
	player.add_child(camera)
	var presentation := _presentation(player)
	var enemy := _enemy()
	presentation.duration_sec = 1.0
	await get_tree().process_frame
	assert_true(presentation.begin(enemy, &"corner"))
	presentation.advance(0.25)
	assert_eq(camera.assassination_context(), &"corner")
	assert_eq(camera.assassination_progress(), presentation.progress())
	assert_true(camera.position.length_squared() > 0.0)
	presentation.cancel()
	assert_eq(camera.assassination_context(), &"")
	assert_eq(camera.position, Vector3.ZERO)


func test_presentation_exit_tree_restores_owned_camera_and_audio_hooks() -> void:
	var player := Node3D.new()
	add_child_autofree(player)
	var camera := PlayerCameraRig.new()
	camera.name = "CameraRig"
	player.add_child(camera)
	var presentation := _presentation(player)
	var enemy := _enemy()
	assert_true(presentation.begin(enemy, &"back"))
	presentation.advance(0.25)
	presentation.advance(0.25)
	assert_eq(camera.assassination_context(), &"back")
	assert_eq(presentation.audio_phase(), &"beat")
	assert_eq(AudioDirector.assassination_audio_phase, &"beat")
	presentation.queue_free()
	await get_tree().process_frame
	assert_false(is_instance_valid(presentation))
	assert_eq(camera.assassination_context(), &"")
	assert_eq(camera.assassination_progress(), 0.0)
	assert_eq(camera.position, Vector3.ZERO)
	assert_eq(AudioDirector.assassination_audio_phase, &"ambient")
	assert_eq(AudioDirector.assassination_context, &"")
	assert_eq(AudioDirector.current_ambience, &"ambient")


func test_resolver_exit_tree_cancels_active_presentation() -> void:
	var player := PlayerScene.instantiate() as PlayerController
	var enemy := EnemyScene.instantiate() as EnemyBase
	enemy.position = Vector3(0.0, 0.0, 1.0)
	add_child_autofree(player)
	add_child_autofree(enemy)
	await get_tree().physics_frame
	var resolver := player.get_node("AssassinationResolver") as AssassinationResolver
	var presentation := resolver.get_node("AssassinationPresentation") as AssassinationPresentation
	assert_eq(resolver.evaluate(enemy), &"back")
	assert_true(resolver.confirm())
	presentation.advance(0.5)
	assert_true(presentation.is_active())
	assert_eq(player.camera_rig.assassination_context(), &"back")
	resolver.queue_free()
	await get_tree().process_frame
	assert_false(is_instance_valid(resolver))
	assert_eq(player.camera_rig.assassination_context(), &"")
	assert_eq(player.camera_rig.assassination_progress(), 0.0)
	assert_eq(AudioDirector.assassination_audio_phase, &"ambient")
	assert_eq(AudioDirector.assassination_context, &"")


func test_resolver_releases_lock_when_bounded_presentation_completes() -> void:
	var player := PlayerScene.instantiate() as PlayerController
	var enemy := EnemyScene.instantiate() as EnemyBase
	enemy.position = Vector3(0.0, 0.0, 1.0)
	add_child_autofree(player)
	add_child_autofree(enemy)
	await get_tree().physics_frame
	var resolver := player.get_node("AssassinationResolver") as AssassinationResolver
	var presentation := resolver.get_node("AssassinationPresentation") as AssassinationPresentation
	presentation.duration_sec = 1.0
	assert_eq(resolver.evaluate(enemy), &"back")
	assert_true(resolver.confirm())
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_ASSASSINATE)
	assert_true(presentation.is_active())
	for _step in 4:
		presentation.advance(0.25)
	assert_false(presentation.is_active())
	assert_eq(resolver.active_enemy(), null)
	assert_eq(player.state_machine.current_state(), PlayerStateMachine.STATE_GROUND)
