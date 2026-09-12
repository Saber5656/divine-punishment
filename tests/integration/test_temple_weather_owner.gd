extends GutTest

func test_campaign_start_creates_one_rain_emitter_and_one_ambience_player() -> void:
	var main: Node = load("res://src/ui/main.tscn").instantiate()
	add_child_autofree(main)
	var director := main.get_node("SceneDirector") as SceneDirector
	var definition := (load("res://data/missions/m04.tres") as MissionDefinition).duplicate(true) as MissionDefinition
	definition.level_scene = load("res://src/levels/rainy_temple/temple_population.tscn")
	assert_true(director.start_mission(definition))
	await get_tree().physics_frame
	await get_tree().process_frame
	assert_eq(_presentations(director.mission),1,"Campaign startup owns weather presentation")
	assert_eq(director.mission.find_children("Precipitation","GPUParticles3D",true,false).size(),1)
	assert_eq(director.mission.find_children("RainAudio","AudioStreamPlayer",true,false).size(),1)
	director._clear_mission()
	WeatherSystem.start(MissionDefinition.Weather.CLEAR)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _presentations(node: Node) -> int:
	var count := 1 if node is WeatherPresentation else 0
	for child in node.get_children(): count += _presentations(child)
	return count
