extends GutTest

class VolatileStore extends Node:
	var last_error := OK
	var rows := {"mission_results":{}}
	func campaign() -> Dictionary: return rows
	func record_mission_result(_id,_result,_first) -> void: pass
	func commit() -> void: pass

var _prior_inner: bool

func before_each() -> void:
	_prior_inner = SaveManager.settings().get("inner_monologue",true)
	SaveManager.settings()["inner_monologue"] = true

func after_each() -> void:
	MissionDirector.start_mission(null)
	SaveManager.settings()["inner_monologue"] = _prior_inner

func test_monologue_event_displays_one_column_for_four_seconds_and_setting_hides_it() -> void:
	var path := "res://src/ui/narrative_overlay.gd"
	assert_true(FileAccess.file_exists(path))
	if not FileAccess.file_exists(path): return
	var overlay = load(path).new()
	add_child_autofree(overlay)
	overlay.set_process(false)
	EventBus.inner_monologue_requested.emit(&"m02.inner_monologue")
	assert_eq(overlay.monologue_text(),"同じことだ、と言った。……本当にそうか。")
	overlay.advance(3.99)
	assert_false(overlay.monologue_text().is_empty())
	overlay.advance(0.01)
	assert_eq(overlay.monologue_text(),"")
	SaveManager.settings()["inner_monologue"] = false
	EventBus.inner_monologue_requested.emit(&"m02.inner_monologue")
	assert_eq(overlay.monologue_text(),"")

func test_target_last_words_and_once_per_mission_assassination_monologue() -> void:
	var definition := load("res://data/missions/m02.tres") as MissionDefinition
	assert_eq(definition.inner_monologue_id,&"m02.inner_monologue")
	var inner: Array = []
	var last: Array = []
	var on_inner := func(id): inner.append(id)
	var on_event := func(id,payload):
		if id == &"target_last_words": last.append(payload.text_id)
	EventBus.inner_monologue_requested.connect(on_inner)
	EventBus.mission_event.connect(on_event)
	MissionDirector.start_mission(definition)
	var target := Node3D.new()
	target.add_to_group(&"m02_target")
	add_child_autofree(target)
	EventBus.enemy_killed.emit(target,"assassination")
	EventBus.enemy_killed.emit(target,"assassination")
	assert_eq(inner,[&"m02.inner_monologue"])
	assert_eq(last,[&"m02.last_words"])
	MissionDirector.start_mission(definition)
	EventBus.enemy_killed.emit(target,"combat")
	assert_eq(inner.size(),1,"Melee death displays last words without an assassination monologue")
	assert_eq(last.size(),2)
	EventBus.inner_monologue_requested.disconnect(on_inner)
	EventBus.mission_event.disconnect(on_event)

func test_oko_report_uses_current_mission_non_target_kill_count() -> void:
	var path := "res://src/core/narrative/narrative_text.gd"
	assert_true(FileAccess.file_exists(path))
	if not FileAccess.file_exists(path): return
	var text = load(path)
	assert_eq(text.oko_report(0),"静かな仕事だったね")
	assert_ne(text.oko_report(1),text.oko_report(0))
	assert_eq(text.oko_report(5),"……ずいぶん、殺したね")
	assert_eq(text.oko_report(100),text.oko_report(5))

func test_m6_target_assassination_requests_hesitation_motion() -> void:
	var definition := (load("res://data/missions/m06.tres") as MissionDefinition).duplicate(true)
	var objective := ObjectiveData.new()
	objective.kind = &"KILL_TARGET"
	objective.target_group = &"m06_target"
	definition.objectives.clear()
	definition.objectives.append(objective)
	MissionDirector.start_mission(definition)
	var enemy := load("res://src/enemies/target_npc.tscn").instantiate() as TargetNpc
	enemy.add_to_group(&"m06_target")
	add_child_autofree(enemy)
	var presentation := AssassinationPresentation.new()
	add_child_autofree(presentation)
	var clips: Array = []
	presentation.animation_requested.connect(func(_context,clip): clips.append(clip))
	presentation.begin(enemy,&"back")
	assert_eq(clips,[&"assassination_hesitation_back"])
	assert_almost_eq(presentation.remaining_sec(),1.6,0.001)
	presentation.cancel()

func test_monologue_setting_migrates_and_rejects_non_boolean_values() -> void:
	var save = load("res://src/autoload/save_manager.gd")
	var old: Dictionary = save.default_save()
	old.settings.erase("inner_monologue")
	assert_eq(save.migrate(old).settings.get("inner_monologue"),true)
	old.settings["inner_monologue"] = "false"
	assert_true(save.migrate(old).is_empty())

func test_final_dialogue_remains_visible_before_result_and_retry_cancels_old_transition() -> void:
	var main := load("res://src/ui/main.tscn").instantiate() as Node
	var director := main.get_node("SceneDirector") as SceneDirector
	var store := VolatileStore.new()
	add_child_autofree(store)
	director.save_manager = store
	add_child_autofree(main)
	var definition := SceneDirector.PRACTICE.duplicate(true) as MissionDefinition
	definition.objectives.resize(1)
	definition.inner_monologue_id = &"m02.inner_monologue"
	definition.last_words_id = &"m02.last_words"
	assert_true(director.start_mission(definition))
	var target := director.mission.get_node("Target")
	EventBus.enemy_killed.emit(target,"assassination")
	for frame in range(2): await get_tree().process_frame
	assert_eq(director.screen,&"playing","Do not cover final dialogue with the result menu")
	assert_true(get_tree().paused,"Victory remains safe while final dialogue finishes")
	assert_true(director.start_mission(SceneDirector.PRACTICE))
	await get_tree().create_timer(4.1).timeout
	assert_eq(director.screen,&"playing","A timer owned by the old mission must not finish the retry")
	director._clear_mission()
